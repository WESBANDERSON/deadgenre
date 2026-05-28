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
const DATABASE_NAME  := "deadgenre"
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
		_simulate_gather(skill, target_id)
		return
	# _db.call_reducer("use_skill", [skill, target_id])

func set_respawn_point(x: float, y: float) -> void:
	if OFFLINE_MODE:
		return
	# _db.call_reducer("set_respawn_point", [x, y])

func equip_item(slot_index: int) -> void:
	if OFFLINE_MODE:
		_simulate_equip(slot_index)
		return
	# _db.call_reducer("equip_item", [slot_index])

func unequip_item(equip_slot: String) -> void:
	if OFFLINE_MODE:
		_simulate_unequip(equip_slot)
		return
	# _db.call_reducer("unequip_item", [equip_slot])

func craft_item(recipe_id: int) -> void:
	if OFFLINE_MODE:
		_simulate_craft(recipe_id)
		return
	# _db.call_reducer("craft_item", [recipe_id])

func drop_item(slot_index: int, quantity: int) -> void:
	if OFFLINE_MODE:
		_simulate_drop(slot_index, quantity)
		return
	# _db.call_reducer("drop_item", [slot_index, quantity])

func player_died_reducer() -> void:
	if OFFLINE_MODE:
		_simulate_death()
		return
	# _db.call_reducer("player_died", [])

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
	is_connected = true
	GameManager.session_identity = "offline_player"
	EventBus.connected_to_server.emit()

	# Show character select if no saved name
	var saved_name: String = GameManager.settings.get("player_name", "")
	if saved_name == "":
		GameManager.game_state = GameManager.GameState.CHARACTER_SELECT
	else:
		GameManager.game_state = GameManager.GameState.PLAYING

	await get_tree().process_frame
	_seed_offline_data()

func _seed_offline_data() -> void:
	EventBus.player_health_changed.emit(null, 100, 100)
	EventBus.player_mana_changed.emit(null, 50, 50)

	var skills = ["melee", "ranged", "magic", "defense", "health", "crafting", "gathering", "agility"]
	for skill in skills:
		EventBus.player_skill_leveled.emit(skill, 1)

	# Spawn starter mobs in offline mode
	await get_tree().create_timer(0.5).timeout
	var mob_positions := [
		Vector2(160, 96), Vector2(256, 160), Vector2(-128, 192),
		Vector2(320, -96), Vector2(-192, -160),
	]
	for i in mob_positions.size():
		EventBus.entity_spawned.emit(1000 + i, "mob", "goblin", mob_positions[i])

	# Spawn resource nodes for gathering
	var resources := [
		[2000, "npc", "resource_oak_tree", Vector2(200, 50)],
		[2001, "npc", "resource_oak_tree", Vector2(-150, 80)],
		[2002, "npc", "resource_copper", Vector2(180, -120)],
		[2003, "npc", "resource_copper", Vector2(-200, -80)],
		[2004, "npc", "resource_fish_spot", Vector2(0, 250)],
	]
	for r in resources:
		EventBus.entity_spawned.emit(r[0], r[1], r[2], r[3])

	# Spawn merchant NPC
	EventBus.entity_spawned.emit(3000, "npc", "merchant_alice", Vector2(64, 32))

	# Seed item definitions for offline inventory display
	var items := [
		{"id": 1, "name": "Worn Sword", "item_type": "weapon", "icon_path": ""},
		{"id": 2, "name": "Iron Sword", "item_type": "weapon", "icon_path": ""},
		{"id": 3, "name": "Oak Shortbow", "item_type": "weapon", "icon_path": ""},
		{"id": 4, "name": "Apprentice Staff", "item_type": "weapon", "icon_path": ""},
		{"id": 10, "name": "Leather Helm", "item_type": "armor", "icon_path": ""},
		{"id": 11, "name": "Leather Chest", "item_type": "armor", "icon_path": ""},
		{"id": 20, "name": "Minor Health Potion", "item_type": "consumable", "icon_path": ""},
		{"id": 21, "name": "Minor Mana Potion", "item_type": "consumable", "icon_path": ""},
		{"id": 30, "name": "Copper Ore", "item_type": "material", "icon_path": ""},
		{"id": 31, "name": "Iron Ore", "item_type": "material", "icon_path": ""},
		{"id": 32, "name": "Oak Log", "item_type": "material", "icon_path": ""},
		{"id": 33, "name": "Raw Fish", "item_type": "material", "icon_path": ""},
	]
	for item in items:
		InventorySystem.apply_item_definition(item)

	# Give starter item
	InventorySystem.apply_slot_update({"slot_index": 0, "item_id": 1, "quantity": 1})

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

func _simulate_gather(skill: String, target_id: int) -> void:
	if skill != "gathering":
		return
	var gathering_level: int = GameManager.player_skills.get("gathering", {}).get("level", 1)
	var qty: int = 1 + gathering_level / 10
	var item_names := {30: "Copper Ore", 31: "Iron Ore", 32: "Oak Log", 33: "Raw Fish"}
	var item_id: int = 30
	if target_id >= 1000:
		item_id = [30, 31, 32, 33][target_id % 4]
	var item_name: String = item_names.get(item_id, "Resource")
	EventBus.item_picked_up.emit(item_name, qty)
	EventBus.notification_shown.emit("Gathered %d × %s" % [qty, item_name], "loot")
	EventBus.player_xp_gained.emit("gathering", 15, 0)
	InventorySystem.apply_slot_update({"slot_index": _find_empty_slot(), "item_id": item_id, "quantity": qty})

func _simulate_equip(slot_index: int) -> void:
	var slot: Dictionary = InventorySystem.get_slot(slot_index)
	if slot.item_id == 0:
		return
	var item_type: String = InventorySystem.get_item_type(slot.item_id)
	if item_type not in ["weapon", "armor"]:
		EventBus.notification_shown.emit("Cannot equip this item", "warn")
		return
	InventorySystem.clear_slot(slot_index)
	EventBus.notification_shown.emit("Equipped %s" % slot.item_name, "info")
	EventBus.equipment_changed.emit()

func _simulate_unequip(equip_slot: String) -> void:
	var empty := _find_empty_slot()
	if empty < 0:
		EventBus.notification_shown.emit("Inventory full!", "warn")
		return
	EventBus.notification_shown.emit("Unequipped from %s" % equip_slot, "info")
	EventBus.equipment_changed.emit()

func _simulate_craft(recipe_id: int) -> void:
	EventBus.notification_shown.emit("Crafted item!", "loot")
	EventBus.player_xp_gained.emit("crafting", 20, 0)

func _simulate_drop(slot_index: int, _quantity: int) -> void:
	var slot: Dictionary = InventorySystem.get_slot(slot_index)
	if slot.item_id == 0:
		return
	InventorySystem.clear_slot(slot_index)
	EventBus.notification_shown.emit("Dropped %s" % slot.item_name, "info")

func _simulate_death() -> void:
	GameManager.player_health = GameManager.player_max_health
	GameManager.player_mana = GameManager.player_max_mana
	EventBus.player_health_changed.emit(GameManager.local_player, GameManager.player_max_health, GameManager.player_max_health)
	EventBus.player_mana_changed.emit(GameManager.local_player, GameManager.player_max_mana, GameManager.player_max_mana)
	EventBus.local_player_respawned.emit(Vector2.ZERO)
	EventBus.notification_shown.emit("You have died. Respawning...", "error")

func _find_empty_slot() -> int:
	for i in InventorySystem.MAX_SLOTS:
		if InventorySystem.is_slot_empty(i):
			return i
	return -1

func _pcg_hash(input: int) -> int:
	var state: int = input * 6364136223846793005 + 1442695040888963407
	var word: int = ((state >> 22) ^ state) >> (((state >> 61) + 22) & 0x3F)
	return word * 2685821657736338717 & 0xFFFFFFFFFFFFFFFF
