## NetworkManager — SpacetimeDB connection and subscription management.
##
## This is the bridge between the SpacetimeDB server and all client systems.
## It handles the connection lifecycle, table subscriptions, and reducer calls.
##
## SpacetimeDB pushes table row changes to subscribed clients automatically.
## We receive these as callbacks and convert them to EventBus signals.
##
## OFFLINE MODE:
##   Set OFFLINE_MODE = true to run without a server. The WorldGenerator
##   will produce client-side terrain and a mock player state is used.
##
## EXTENDING:
##   To sync a new table, add a subscription query in _subscribe() and
##   implement on_<table>_row callbacks below.
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
const SPACETIME_HOST := "ws://localhost:3000"
const DATABASE_NAME  := "aethermoor"
const RECONNECT_DELAY_SEC := 3.0

## Set true to run without a server (uses local world generation)
var OFFLINE_MODE: bool = true

# ─────────────────────────────────────────────────────────────────────────────
# Connection State
# ─────────────────────────────────────────────────────────────────────────────
var is_connected: bool = false
var _reconnect_timer: float = 0.0
var _position_sync_timer: float = 0.0

const POSITION_SYNC_RATE := 0.1  # seconds between position updates (10 Hz)

# ─────────────────────────────────────────────────────────────────────────────
# Signals re-emitted after processing (systems subscribe to these)
# ─────────────────────────────────────────────────────────────────────────────
signal entity_spawned(data: Dictionary)
signal entity_despawned(entity_id: int)
signal entity_updated(data: Dictionary)
signal chunk_received(chunk_x: int, chunk_y: int, tile_data: PackedByteArray)
signal player_row_updated(data: Dictionary)

# ─────────────────────────────────────────────────────────────────────────────
# SpacetimeDB SDK Adapter
# ─────────────────────────────────────────────────────────────────────────────
## The actual SpacetimeDB Godot SDK (com.clockworklabs.spacetimedbsdk) is an
## addon that should be installed at client/addons/spacetimedb/.
## Until then, we use a duck-typed adapter so all reducer calls and
## subscription logic are isolated here and easy to wire up.
var _db = null  # SpacetimeDBClient instance when SDK is available

func _ready() -> void:
	if OFFLINE_MODE:
		print("[NetworkManager] OFFLINE MODE — no server connection")
		_setup_offline_mode()
		return
	_connect_to_server()

func _process(delta: float) -> void:
	if OFFLINE_MODE:
		return

	# Throttled position sync: send current player position at 10 Hz
	_position_sync_timer -= delta
	if _position_sync_timer <= 0 and is_connected and GameManager.local_player:
		_position_sync_timer = POSITION_SYNC_RATE
		var pos: Vector2 = GameManager.local_player.global_position
		move_player(pos.x, pos.y)

	# Reconnect logic
	if not is_connected:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0:
			_connect_to_server()
			_reconnect_timer = RECONNECT_DELAY_SEC

# ─────────────────────────────────────────────────────────────────────────────
# Connection Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _connect_to_server() -> void:
	print("[NetworkManager] Connecting to %s/%s ..." % [SPACETIME_HOST, DATABASE_NAME])
	# TODO: Replace with real SpacetimeDB SDK call once addon is installed:
	#   _db = SpacetimeDBClient.new()
	#   _db.connect_db(SPACETIME_HOST, DATABASE_NAME, false)
	#   _db.on_connect.connect(_on_connected)
	#   _db.on_disconnect.connect(_on_disconnected)
	#   add_child(_db)
	#   _subscribe()
	print("[NetworkManager] SDK not yet installed — switch OFFLINE_MODE to true or install the addon.")

func _subscribe() -> void:
	# Subscribe to all tables we care about.
	# SpacetimeDB will push row changes to our callbacks automatically.
	# _db.subscribe([
	#     "SELECT * FROM player",
	#     "SELECT * FROM entity WHERE is_active = true",
	#     "SELECT * FROM world_chunk",
	#     "SELECT * FROM player_inventory WHERE player_identity = :identity",
	#     "SELECT * FROM player_skill WHERE player_identity = :identity",
	#     "SELECT * FROM combat_event",
	#     "SELECT * FROM item_definition",
	# ])
	pass

func _on_connected(identity: String, _token: String) -> void:
	is_connected = true
	GameManager.session_identity = identity
	EventBus.connected_to_server.emit()
	# Create player if this is a first-time connection
	var saved_name: String = GameManager.settings.get("player_name", "")
	if saved_name != "":
		create_player(saved_name)

func _on_disconnected() -> void:
	is_connected = false
	EventBus.disconnected_from_server.emit()

# ─────────────────────────────────────────────────────────────────────────────
# Reducer Calls (client → server)
# All calls are fire-and-forget; results come back via table subscriptions.
# ─────────────────────────────────────────────────────────────────────────────
func create_player(username: String) -> void:
	if OFFLINE_MODE:
		return
	# _db.call_reducer("create_player", [username])

func move_player(x: float, y: float) -> void:
	if OFFLINE_MODE:
		return
	# _db.call_reducer("move_player", [x, y])

func attack_entity(entity_id: int) -> void:
	if OFFLINE_MODE:
		_simulate_attack(entity_id)
		return
	# _db.call_reducer("attack_entity", [entity_id])

func pick_up_item(entity_id: int) -> void:
	if OFFLINE_MODE:
		return
	# _db.call_reducer("pick_up_item", [entity_id])

func request_chunk(chunk_x: int, chunk_y: int) -> void:
	if OFFLINE_MODE:
		_generate_chunk_offline(chunk_x, chunk_y)
		return
	# _db.call_reducer("request_chunk", [chunk_x, chunk_y])

func use_skill(skill: String, target_id: int) -> void:
	if OFFLINE_MODE:
		return
	# _db.call_reducer("use_skill", [skill, target_id])

func set_respawn_point(x: float, y: float) -> void:
	if OFFLINE_MODE:
		return
	# _db.call_reducer("set_respawn_point", [x, y])

# ─────────────────────────────────────────────────────────────────────────────
# Table Row Callbacks (server → client)
# These are called by the SpacetimeDB SDK when subscribed rows change.
# ─────────────────────────────────────────────────────────────────────────────

## Called when a Player row is inserted or updated.
func _on_player_row(row: Dictionary, _is_insert: bool) -> void:
	if row.get("identity", "") == GameManager.session_identity:
		EventBus.player_health_changed.emit(
			GameManager.local_player, row.health, row.max_health)
		EventBus.player_mana_changed.emit(
			GameManager.local_player, row.mana, row.max_mana)
		player_row_updated.emit(row)
	else:
		# Remote player update
		entity_updated.emit(row)

## Called when an Entity row changes.
func _on_entity_row(row: Dictionary, is_insert: bool) -> void:
	if is_insert:
		entity_spawned.emit(row)
		EventBus.entity_spawned.emit(
			row.id, row.entity_type, row.subtype,
			Vector2(row.pos_x, row.pos_y))
	else:
		entity_updated.emit(row)
		EventBus.entity_health_changed.emit(row.id, row.health, row.max_health)

## Called when an Entity row is deleted (entity removed from world).
func _on_entity_row_delete(row: Dictionary) -> void:
	entity_despawned.emit(row.id)
	EventBus.entity_despawned.emit(row.id)

## Called when a WorldChunk row arrives (new chunk generated by server).
func _on_chunk_row(row: Dictionary, _is_insert: bool) -> void:
	chunk_received.emit(row.chunk_x, row.chunk_y, PackedByteArray(row.tile_data))

## Called when a CombatEvent row arrives.
func _on_combat_event_row(row: Dictionary, _is_insert: bool) -> void:
	EventBus.combat_hit.emit(
		row.attacker_id, row.target_id, row.damage, row.is_critical)

## Called when a PlayerSkill row changes.
func _on_player_skill_row(row: Dictionary, _is_insert: bool) -> void:
	if row.get("player_identity", "") == GameManager.session_identity:
		EventBus.player_xp_gained.emit(row.skill_type, 0, row.experience)
		EventBus.player_skill_leveled.emit(row.skill_type, row.level)

# ─────────────────────────────────────────────────────────────────────────────
# Offline Mode — client-side simulation for development without a server
# ─────────────────────────────────────────────────────────────────────────────
func _setup_offline_mode() -> void:
	# Emit a fake connected signal so systems start normally
	is_connected = true
	GameManager.session_identity = "offline_player"
	EventBus.connected_to_server.emit()

	# Emit initial player stats
	await get_tree().process_frame
	EventBus.player_health_changed.emit(null, 100, 100)
	EventBus.player_mana_changed.emit(null, 50, 50)

	# Seed offline skill data
	var skills = ["melee", "ranged", "magic", "defense", "health", "crafting", "gathering", "agility"]
	for skill in skills:
		EventBus.player_skill_leveled.emit(skill, 1)

	# Spawn starter mobs in offline mode
	await get_tree().create_timer(0.5).timeout
	var positions := [
		Vector2(160, 96), Vector2(256, 160), Vector2(-128, 192),
		Vector2(320, -96), Vector2(-192, -160),
	]
	for i in positions.size():
		EventBus.entity_spawned.emit(1000 + i, "mob", "goblin", positions[i])

func _generate_chunk_offline(chunk_x: int, chunk_y: int) -> void:
	# Mirror the server's generation logic in GDScript for offline dev
	var tile_data := PackedByteArray()
	tile_data.resize(32 * 32)
	var seed := _pcg_hash(chunk_x ^ (chunk_y * 2654435761))
	for y in 32:
		for x in 32:
			var wx := chunk_x * 32 + x
			var wy := chunk_y * 32 + y
			var h := _pcg_hash(seed ^ _pcg_hash(wx)) ^ _pcg_hash(_pcg_hash(wy) ^ seed + 7919)
			var n := (h & 0xFFFF) / 65535.0
			var dist := sqrt(float(wx * wx + wy * wy)) / 256.0
			var tile: int
			if n < 0.08:
				tile = 3    # WATER
			elif n < 0.20 and dist < 1.5:
				tile = 1    # FOREST
			elif n < 0.22:
				tile = 5    # DIRT
			elif dist > 4.0 and _pcg_hash(h) % 4 == 0:
				tile = 6    # SNOW
			elif dist > 3.0 and _pcg_hash(h) % 5 == 0:
				tile = 2    # STONE
			elif n > 0.88:
				tile = 4    # SAND
			else:
				tile = 0    # GRASS
			tile_data[y * 32 + x] = tile
	chunk_received.emit(chunk_x, chunk_y, tile_data)

func _simulate_attack(entity_id: int) -> void:
	EventBus.combat_hit.emit("local_player", str(entity_id), randi_range(3, 12), false)
	EventBus.entity_health_changed.emit(entity_id, 20, 40)

func _pcg_hash(input: int) -> int:
	var state: int = input * 6364136223846793005 + 1442695040888963407
	var word: int = ((state >> 22) ^ state) >> (((state >> 61) + 22) & 0x3F)
	return word * 2685821657736338717 & 0xFFFFFFFFFFFFFFFF
