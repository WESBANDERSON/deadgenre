## InventorySystem — Client-side inventory state management.
##
## Mirrors the player_inventory table from the server.
## Provides a clean API for HUD and UI panels to read and request inventory changes.
##
## The server is authoritative on all inventory state.
## Client changes are optimistic (show immediately), then corrected on server sync.
extends Node

const MAX_SLOTS := 28  # 28 slots, OSRS homage

## Slot structure: Array of Dictionaries
## { "slot_index": int, "item_id": int, "quantity": int, "item_name": String, "icon_path": String }
var slots: Array = []

## Item definition cache: item_id -> Dictionary (populated from server subscription)
var item_definitions: Dictionary = {}

func _ready() -> void:
	# Initialize empty slots
	slots.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		slots[i] = {"slot_index": i, "item_id": 0, "quantity": 0, "item_name": "", "icon_path": ""}

	EventBus.item_picked_up.connect(_on_item_picked_up)
	NetworkManager.player_row_updated.connect(_on_player_row_updated)

# ─────────────────────────────────────────────────────────────────────────────
# Server Sync
# ─────────────────────────────────────────────────────────────────────────────

## Called when the server sends an inventory slot update.
## slot_data mirrors the player_inventory table row.
func apply_slot_update(slot_data: Dictionary) -> void:
	var idx: int = slot_data.get("slot_index", -1)
	if idx < 0 or idx >= MAX_SLOTS:
		return
	var item_id: int = slot_data.get("item_id", 0)
	var name := item_definitions.get(item_id, {}).get("name", "Unknown Item")
	var icon := item_definitions.get(item_id, {}).get("icon_path", "")
	slots[idx] = {
		"slot_index": idx,
		"item_id":    item_id,
		"quantity":   slot_data.get("quantity", 0),
		"item_name":  name,
		"icon_path":  icon,
	}
	EventBus.inventory_changed.emit()

## Clear a slot (item removed or moved).
func clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
	slots[slot_index] = {"slot_index": slot_index, "item_id": 0, "quantity": 0, "item_name": "", "icon_path": ""}
	EventBus.inventory_changed.emit()

## Populate item definition cache from server subscription.
func apply_item_definition(item_data: Dictionary) -> void:
	item_definitions[item_data.get("id", 0)] = item_data

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────
func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= MAX_SLOTS:
		return {}
	return slots[index]

func is_slot_empty(index: int) -> bool:
	return get_slot(index).get("item_id", 0) == 0

func has_item(item_id: int) -> bool:
	return slots.any(func(s): return s.item_id == item_id)

func count_item(item_id: int) -> int:
	var total := 0
	for s in slots:
		if s.item_id == item_id:
			total += s.quantity
	return total

func is_full() -> bool:
	return slots.all(func(s): return s.item_id != 0)

func get_item_name(item_id: int) -> String:
	return item_definitions.get(item_id, {}).get("name", "Unknown")

func get_item_type(item_id: int) -> String:
	return item_definitions.get(item_id, {}).get("item_type", "")

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_item_picked_up(item_name: String, _quantity: int) -> void:
	if is_full():
		EventBus.notification_shown.emit("Your inventory is full!", "warn")

func _on_player_row_updated(_data: Dictionary) -> void:
	pass  # Inventory is its own table; handled via apply_slot_update()
