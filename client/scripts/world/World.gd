## World — The top-level game world manager.
##
## Responsibilities:
##   - Initializing and managing the TileMap (terrain rendering)
##   - Chunk streaming: requesting and applying chunks as the player moves
##   - Entity lifecycle: spawning and despawning player/NPC/mob nodes
##   - Camera attachment to the local player
##
## EXTENSION POINTS:
##   - Add new entity types in _spawn_entity()
##   - Add world events (day/night, weather) in _process()
##   - Adjust LOAD_RADIUS to trade bandwidth for visual density
class_name World
extends Node2D

const TILE_SIZE        := 32
const CHUNK_SIZE       := 32
const CHUNK_PIXEL_SIZE := TILE_SIZE * CHUNK_SIZE   # 1024 pixels per chunk axis
const LOAD_RADIUS      := 2   # chunks loaded around player in each direction

# ─────────────────────────────────────────────────────────────────────────────
# Node References
# ─────────────────────────────────────────────────────────────────────────────
@onready var tile_map:          TileMap  = $TileMap
@onready var entity_container:  Node2D   = $EntityContainer
@onready var camera:            Camera2D = $Camera

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var tile_registry:  TileRegistry = TileRegistry.new()
var pathfinder:     Pathfinder   = Pathfinder.new()
var local_player:   Node         = null

## Tracks which chunks have been requested or loaded: chunk_key -> "pending"|"loaded"
var chunk_states: Dictionary = {}

## Entity nodes keyed by their server entity_id
var entity_nodes: Dictionary = {}

## Scene preloads for each entity subtype.
## Add new subtypes here when creating new entity scenes.
var _entity_scenes: Dictionary = {}

func _ready() -> void:
	tile_registry.build_tileset(tile_map)
	GameManager.world = self
	_preload_entity_scenes()
	_connect_signals()
	_spawn_local_player()

func _preload_entity_scenes() -> void:
	# Preload entity scenes once to avoid repeated disk reads.
	# Add entries here as new entity types are created.
	_entity_scenes = {
		# "goblin":          preload("res://scenes/entities/Goblin.tscn"),
		# "merchant_alice":  preload("res://scenes/entities/Merchant.tscn"),
		# "resource_oak_tree": preload("res://scenes/entities/ResourceNode.tscn"),
	}
	# Generic fallback scenes used when a specific scene isn't found
	_entity_scenes["_mob_fallback"] = preload("res://scenes/entities/Mob.tscn")
	_entity_scenes["_npc_fallback"] = preload("res://scenes/entities/NPC.tscn")

func _connect_signals() -> void:
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.entity_spawned.connect(_on_entity_spawned)
	EventBus.entity_despawned.connect(_on_entity_despawned)
	NetworkManager.chunk_received.connect(_on_chunk_received)

# ─────────────────────────────────────────────────────────────────────────────
# Local Player
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_local_player() -> void:
	var player_scene: PackedScene = preload("res://scenes/entities/Player.tscn")
	local_player = player_scene.instantiate()
	local_player.is_local_player = true
	local_player.player_name = GameManager.settings.get("player_name", "Adventurer")
	entity_container.add_child(local_player)
	local_player.global_position = Vector2.ZERO
	local_player.world = self

	# Attach camera to player (reparent keeps world-space position)
	camera.reparent(local_player)
	camera.zoom = Vector2.ONE * GameManager.settings.get("camera_zoom", 2.0)

	GameManager.local_player = local_player
	EventBus.local_player_spawned.emit(local_player)

	# Immediately load the starting chunks
	_update_loaded_chunks(Vector2i.ZERO)

# ─────────────────────────────────────────────────────────────────────────────
# Chunk Streaming
# ─────────────────────────────────────────────────────────────────────────────
func _on_player_moved(world_position: Vector2) -> void:
	var player_chunk := _world_to_chunk(world_position)
	_update_loaded_chunks(player_chunk)

func _update_loaded_chunks(center: Vector2i) -> void:
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var cp := center + Vector2i(dx, dy)
			var key := _chunk_key(cp)
			if not chunk_states.has(key):
				chunk_states[key] = "pending"
				NetworkManager.request_chunk(cp.x, cp.y)

func _on_chunk_received(chunk_x: int, chunk_y: int, tile_data: PackedByteArray) -> void:
	var chunk_pos   := Vector2i(chunk_x, chunk_y)
	var origin_tile := Vector2i(chunk_x * CHUNK_SIZE, chunk_y * CHUNK_SIZE)

	# Write tiles into the TileMap (layer 0 = terrain)
	for i in tile_data.size():
		var tx  := i % CHUNK_SIZE
		var ty  := i / CHUNK_SIZE
		var map_pos := origin_tile + Vector2i(tx, ty)
		var tile_id := tile_data[i]
		tile_map.set_cell(0, map_pos, 0, Vector2i(tile_id, 0))

	# Update pathfinder for this chunk
	pathfinder.update_chunk(origin_tile, tile_data, tile_registry)

	chunk_states[_chunk_key(chunk_pos)] = "loaded"
	EventBus.chunk_loaded.emit(chunk_x, chunk_y)

# ─────────────────────────────────────────────────────────────────────────────
# Entity Management
# ─────────────────────────────────────────────────────────────────────────────
func _on_entity_spawned(entity_id: int, entity_type: String, subtype: String, pos: Vector2) -> void:
	if entity_nodes.has(entity_id):
		return  # Already exists

	var node := _spawn_entity(entity_id, entity_type, subtype, pos)
	if node:
		entity_nodes[entity_id] = node

func _on_entity_despawned(entity_id: int) -> void:
	if entity_nodes.has(entity_id):
		var node: Node = entity_nodes[entity_id]
		entity_nodes.erase(entity_id)
		node.queue_free()

func _spawn_entity(entity_id: int, entity_type: String, subtype: String, pos: Vector2) -> Node:
	var scene: PackedScene = null

	# Try specific subtype scene first, then type fallback
	if _entity_scenes.has(subtype):
		scene = _entity_scenes[subtype]
	elif entity_type == "mob" and _entity_scenes.has("_mob_fallback"):
		scene = _entity_scenes["_mob_fallback"]
	elif entity_type == "npc" and _entity_scenes.has("_npc_fallback"):
		scene = _entity_scenes["_npc_fallback"]

	if scene == null:
		return null

	var node := scene.instantiate()
	entity_container.add_child(node)
	node.global_position = pos

	if node.has_method("initialize"):
		node.initialize(entity_id, entity_type, subtype)

	return node

# ─────────────────────────────────────────────────────────────────────────────
# Coordinate Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _world_to_chunk(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / CHUNK_PIXEL_SIZE),
		floori(world_pos.y / CHUNK_PIXEL_SIZE))

func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)
