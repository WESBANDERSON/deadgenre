## World3D — 2.5D Dreadmyst-style world manager.
##
## ROLE:
##   Owns terrain mesh chunks, entity instancing, environment fog/lighting,
##   and the orbit camera attached to the local player. Everything visible
##   in the playable world is either a child of this node or routed through
##   it.
##
## RELATIONSHIP TO 2D WORLD.GD:
##   This is an addition, not a mutation, of the original 2D World node.
##   Game systems (CombatSystem, InventorySystem, NetworkManager) are
##   2D/3D-agnostic because they speak via EventBus.
##   `GameManager.world` is still set to this node; methods used by other
##   systems (`world_to_tile`, `tile_to_world`, `pathfinder`, `entity_nodes`)
##   are preserved with 3D-friendly equivalents.
##
## COORDINATE BRIDGE:
##   The server (and pathfinder) speak in 2D pixel space (TILE_SIZE = 32).
##   The 3D scene uses 1 tile == TILE_UNITS world units.
##     world_3d.x  =  pixel_x  / TILE_SIZE * TILE_UNITS
##     world_3d.z  =  pixel_y  / TILE_SIZE * TILE_UNITS
##     pixel_x     =  world_3d.x * TILE_SIZE / TILE_UNITS
##   This keeps the server schema unchanged.
class_name World3D
extends Node3D

const TILE_SIZE        := 32       # pixels per tile (matches server)
const TILE_UNITS       := 1.0      # 3D units per tile
const CHUNK_SIZE       := 32
const CHUNK_PIXEL_SIZE := TILE_SIZE * CHUNK_SIZE
const LOAD_RADIUS      := 2

# ─────────────────────────────────────────────────────────────────────────────
# Node References
# ─────────────────────────────────────────────────────────────────────────────
@onready var terrain_root:    Node3D = $TerrainRoot
@onready var entity_container: Node3D = $EntityContainer
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var moon_light: DirectionalLight3D = $MoonLight
@onready var player_torch: OmniLight3D = $PlayerTorch if has_node("PlayerTorch") else null

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var tile_registry: TileRegistry      = TileRegistry.new()
var pathfinder:    Pathfinder        = Pathfinder.new()
var terrain_builder: TerrainBuilder
var sprite_factory: SpriteFactory    = SpriteFactory.new()

var local_player: Node = null
var camera: OrbitCamera3D = null

var chunk_states: Dictionary = {}
var chunk_nodes:  Dictionary = {}
var entity_nodes: Dictionary = {}
var _entity_scenes: Dictionary = {}

func _ready() -> void:
	terrain_builder = TerrainBuilder.new(tile_registry)
	GameManager.world = self
	_configure_environment()
	_preload_entity_scenes()
	_connect_signals()
	_spawn_local_player()

func _configure_environment() -> void:
	# Build a Dreadmyst-flavored environment: dense gray-blue fog, low ambient,
	# desaturated tonemap. Override any default project settings.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.30)
	env.ambient_light_energy = 0.45

	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.30, 0.40)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.25
	env.fog_density = 0.045
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 1.0
	env.fog_height = 6.0
	env.fog_height_density = 0.10

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.10

	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	world_environment.environment = env

func _preload_entity_scenes() -> void:
	_entity_scenes = {}
	_entity_scenes["_mob_fallback"] = preload("res://scenes/entities3d/Mob3D.tscn")
	_entity_scenes["_npc_fallback"] = preload("res://scenes/entities3d/NPC3D.tscn")

func _connect_signals() -> void:
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.entity_spawned.connect(_on_entity_spawned)
	EventBus.entity_despawned.connect(_on_entity_despawned)
	EventBus.local_player_respawned.connect(_on_player_respawned)
	NetworkManager.chunk_received.connect(_on_chunk_received)

# ─────────────────────────────────────────────────────────────────────────────
# Local Player
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_local_player() -> void:
	var scene: PackedScene = preload("res://scenes/entities3d/Player3D.tscn")
	local_player = scene.instantiate()
	local_player.is_local_player = true
	local_player.player_name = GameManager.settings.get("player_name", "Adventurer")
	local_player.player_class = GameManager.settings.get("player_class", "player_warrior")
	local_player.world = self
	entity_container.add_child(local_player)
	local_player.global_position = Vector3.ZERO

	# Attach orbit camera
	camera = preload("res://scripts/world3d/OrbitCamera3D.gd").new() as OrbitCamera3D
	camera.name = "OrbitCamera"
	camera.follow_target = local_player
	add_child(camera)
	local_player.camera_ref = camera

	GameManager.local_player = local_player
	EventBus.local_player_spawned.emit(local_player)

	_update_loaded_chunks(Vector2i.ZERO)

# ─────────────────────────────────────────────────────────────────────────────
# Chunk Streaming
# ─────────────────────────────────────────────────────────────────────────────
func _on_player_moved(world_position) -> void:
	# world_position arrives as Vector2 (legacy 2D pixel space)
	var px: float
	var py: float
	if world_position is Vector2:
		px = world_position.x
		py = world_position.y
	elif world_position is Vector3:
		px = world_position.x * TILE_SIZE / TILE_UNITS
		py = world_position.z * TILE_SIZE / TILE_UNITS
	else:
		return
	var player_chunk := Vector2i(
		floori(px / CHUNK_PIXEL_SIZE),
		floori(py / CHUNK_PIXEL_SIZE))
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
	var origin_tile := Vector2i(chunk_x * CHUNK_SIZE, chunk_y * CHUNK_SIZE)
	pathfinder.update_chunk(origin_tile, tile_data, tile_registry)

	# Build 3D mesh for the chunk
	var mesh_instance := terrain_builder.build_chunk_mesh(tile_data)
	mesh_instance.transform.origin = Vector3(
		chunk_x * CHUNK_SIZE * TILE_UNITS,
		0.0,
		chunk_y * CHUNK_SIZE * TILE_UNITS)
	terrain_root.add_child(mesh_instance)
	chunk_nodes[_chunk_key(Vector2i(chunk_x, chunk_y))] = mesh_instance

	# Spawn props (trees / rocks) on forest/stone tiles for visual density
	_decorate_chunk(chunk_x, chunk_y, tile_data)

	chunk_states[_chunk_key(Vector2i(chunk_x, chunk_y))] = "loaded"
	EventBus.chunk_loaded.emit(chunk_x, chunk_y)

func _decorate_chunk(chunk_x: int, chunk_y: int, tile_data: PackedByteArray) -> void:
	# Deterministic decoration: place a tree/rock billboard on certain tiles.
	# Decoration entity IDs are negative + deterministic so they never collide
	# with server entity IDs.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("decor:%d,%d" % [chunk_x, chunk_y])
	var npc_scene: PackedScene = preload("res://scenes/entities3d/Prop3D.tscn")
	if npc_scene == null:
		return

	for ty in CHUNK_SIZE:
		for tx in CHUNK_SIZE:
			var tile_id: int = tile_data[ty * CHUNK_SIZE + tx]
			var name := tile_registry.get_tile_name(tile_id)
			var roll := rng.randf()
			var prop_subtype := ""

			if name == "forest" and roll < 0.55:
				prop_subtype = "oak_tree"
			elif name == "stone" and roll < 0.25:
				prop_subtype = "stone_pillar"

			if prop_subtype == "":
				continue

			var world_x := (chunk_x * CHUNK_SIZE + tx + 0.5) * TILE_UNITS
			var world_z := (chunk_y * CHUNK_SIZE + ty + 0.5) * TILE_UNITS
			var prop := npc_scene.instantiate()
			entity_container.add_child(prop)
			prop.global_position = Vector3(world_x, 0.0, world_z)
			if prop.has_method("setup"):
				prop.setup(prop_subtype)

# ─────────────────────────────────────────────────────────────────────────────
# Entity Management
# ─────────────────────────────────────────────────────────────────────────────
func _on_entity_spawned(entity_id: int, entity_type: String, subtype: String, pos) -> void:
	if entity_nodes.has(entity_id):
		return
	var node := _spawn_entity(entity_id, entity_type, subtype, pos)
	if node:
		entity_nodes[entity_id] = node

func _on_entity_despawned(entity_id: int) -> void:
	if entity_nodes.has(entity_id):
		var node: Node = entity_nodes[entity_id]
		entity_nodes.erase(entity_id)
		node.queue_free()

func _spawn_entity(entity_id: int, entity_type: String, subtype: String, pos) -> Node:
	var scene: PackedScene = null
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
	# Convert legacy 2D pixel position to 3D world position
	var world_pos := pixel_to_world(pos if pos is Vector2 else Vector2.ZERO)
	node.global_position = world_pos
	if node.has_method("initialize"):
		node.initialize(entity_id, entity_type, subtype)
	return node

func _on_player_respawned(position) -> void:
	if local_player == null:
		return
	var world_pos: Vector3
	if position is Vector2:
		world_pos = pixel_to_world(position)
	elif position is Vector3:
		world_pos = position
	else:
		world_pos = Vector3.ZERO
	local_player.global_position = world_pos
	local_player.cancel_movement()
	_update_loaded_chunks(Vector2i.ZERO)

# ─────────────────────────────────────────────────────────────────────────────
# Coordinate Helpers (bridge 2D ↔ 3D)
# ─────────────────────────────────────────────────────────────────────────────
func pixel_to_world(p: Vector2) -> Vector3:
	return Vector3(p.x / TILE_SIZE * TILE_UNITS, 0.0, p.y / TILE_SIZE * TILE_UNITS)

func world_to_pixel(p: Vector3) -> Vector2:
	return Vector2(p.x * TILE_SIZE / TILE_UNITS, p.z * TILE_SIZE / TILE_UNITS)

func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

func world_to_tile(world_pos) -> Vector2i:
	if world_pos is Vector3:
		return Vector2i(floori(world_pos.x / TILE_UNITS),
				floori(world_pos.z / TILE_UNITS))
	return Vector2i(floori(world_pos.x / TILE_SIZE),
			floori(world_pos.y / TILE_SIZE))

func tile_to_world(tile_pos: Vector2i) -> Vector3:
	return Vector3((tile_pos.x + 0.5) * TILE_UNITS, 0.0,
			(tile_pos.y + 0.5) * TILE_UNITS)

## Game systems use this to convert tile-based design values (combat range,
## interact range) into the active world's distance units.
func units_per_tile() -> float:
	return TILE_UNITS
