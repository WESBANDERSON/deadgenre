## Visual inventory grid. Renders the 28-slot backpack and responds to
## clicks for equipping/using items. Gets data from the InventorySystem node.
extends PanelContainer

const SLOT_SIZE := Vector2(48, 48)
const GRID_COLUMNS := 4

@onready var grid: GridContainer = %InventoryGrid
@onready var title_label: Label = %InventoryTitle

var _inventory_system: Node = null

func _ready() -> void:
	EventBus.inventory_changed.connect(_refresh)
	_find_inventory_system()
	_refresh()

func _find_inventory_system() -> void:
	_inventory_system = get_tree().current_scene.find_child("InventorySystem", true, false)

func _refresh() -> void:
	if grid == null or _inventory_system == null:
		return
	for child in grid.get_children():
		child.queue_free()

	for i in range(_inventory_system.MAX_SLOTS):
		var slot_data: Dictionary = _inventory_system.slots[i]
		var slot_button := Button.new()
		slot_button.custom_minimum_size = SLOT_SIZE

		if slot_data["item_id"] != "":
			var item_def := ContentDB.get_item(slot_data["item_id"])
			var display := item_def.get("display_name", slot_data["item_id"])
			slot_button.text = display.substr(0, 3)
			slot_button.tooltip_text = "%s (x%d)" % [display, slot_data["quantity"]]
		else:
			slot_button.text = ""
			slot_button.tooltip_text = "Empty"

		var idx := i
		slot_button.pressed.connect(func(): _on_slot_clicked(idx))
		grid.add_child(slot_button)

func _on_slot_clicked(index: int) -> void:
	if _inventory_system == null:
		return
	_inventory_system.equip_item(index)
