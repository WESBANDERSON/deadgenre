## Client-side inventory manager. Maintains a local mirror of the player's
## inventory and equipment. Syncs with SpacetimeDB when connected.
extends Node

const MAX_SLOTS: int = 28  # Classic 28-slot inventory (OSRS-inspired)

var slots: Array[Dictionary] = []  # [{item_id, quantity}, ...]
var equipment: Dictionary = {}     # slot_name -> item_id

func _ready() -> void:
	_init_empty_inventory()
	EventBus.item_picked_up.connect(_on_item_picked_up)

func _init_empty_inventory() -> void:
	slots.clear()
	for i in range(MAX_SLOTS):
		slots.append({"item_id": "", "quantity": 0})

func add_item(item_id: String, quantity: int = 1) -> bool:
	var item_def := ContentDB.get_item(item_id)
	if item_def.is_empty():
		push_warning("InventorySystem: Unknown item '%s'" % item_id)
		return false

	var max_stack: int = item_def.get("max_stack", 1)

	for i in range(MAX_SLOTS):
		if slots[i]["item_id"] == item_id and slots[i]["quantity"] < max_stack:
			var space := max_stack - slots[i]["quantity"]
			var to_add := mini(quantity, space)
			slots[i]["quantity"] += to_add
			quantity -= to_add
			if quantity <= 0:
				EventBus.inventory_changed.emit()
				return true

	for i in range(MAX_SLOTS):
		if slots[i]["item_id"] == "":
			var to_add := mini(quantity, max_stack)
			slots[i] = {"item_id": item_id, "quantity": to_add}
			quantity -= to_add
			if quantity <= 0:
				EventBus.inventory_changed.emit()
				return true

	EventBus.notification_requested.emit("Inventory full!", "warning")
	return false

func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in range(MAX_SLOTS - 1, -1, -1):
		if slots[i]["item_id"] == item_id:
			var to_remove := mini(quantity, slots[i]["quantity"])
			slots[i]["quantity"] -= to_remove
			quantity -= to_remove
			if slots[i]["quantity"] <= 0:
				slots[i] = {"item_id": "", "quantity": 0}
			if quantity <= 0:
				EventBus.inventory_changed.emit()
				return true
	return false

func has_item(item_id: String, quantity: int = 1) -> bool:
	var total := 0
	for slot in slots:
		if slot["item_id"] == item_id:
			total += slot["quantity"]
			if total >= quantity:
				return true
	return false

func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot["item_id"] == item_id:
			total += slot["quantity"]
	return total

func equip_item(slot_index: int) -> void:
	var slot := slots[slot_index]
	if slot["item_id"] == "":
		return
	var item_def := ContentDB.get_item(slot["item_id"])
	var equip_slot: String = item_def.get("equip_slot", "none")
	if equip_slot == "none":
		return

	if equipment.has(equip_slot):
		var old_item: String = equipment[equip_slot]
		add_item(old_item)

	equipment[equip_slot] = slot["item_id"]
	slots[slot_index] = {"item_id": "", "quantity": 0}

	EventBus.item_equipped.emit(slot["item_id"], equip_slot)
	EventBus.inventory_changed.emit()

func _on_item_picked_up(item_id: String, quantity: int) -> void:
	add_item(item_id, quantity)
