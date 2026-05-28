## InventoryPanel — Toggle-able 28-slot grid overlay.
##
## Shows the player's inventory in a 4-column, 7-row grid.
## Each slot displays item icon placeholder, name, and quantity.
## Right-click a slot to show context actions (equip, drop).
##
## Toggle via: EventBus.panel_toggle_requested("inventory") or 'I' key.
class_name InventoryPanel
extends PanelContainer

const COLS := 4
const ROWS := 7
const SLOT_SIZE := Vector2(56, 56)
const SLOT_MARGIN := 4

var _grid: GridContainer = null
var _slot_buttons: Array[Button] = []
var _context_menu: PopupMenu = null
var _context_slot_index: int = -1

func _ready() -> void:
	_build_panel()
	_connect_signals()
	visible = false

func _connect_signals() -> void:
	EventBus.inventory_changed.connect(_refresh_slots)
	EventBus.panel_toggle_requested.connect(_on_panel_toggle)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			toggle()
		elif event.keycode == KEY_ESCAPE and visible:
			visible = false

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_slots()

func _build_panel() -> void:
	custom_minimum_size = Vector2(
		COLS * (SLOT_SIZE.x + SLOT_MARGIN) + 24,
		ROWS * (SLOT_SIZE.y + SLOT_MARGIN) + 60
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	style.border_color = Color(0.35, 0.35, 0.50, 0.80)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", SLOT_MARGIN)
	_grid.add_theme_constant_override("v_separation", SLOT_MARGIN)
	vbox.add_child(_grid)

	for i in InventorySystem.MAX_SLOTS:
		var btn := _make_slot_button(i)
		_grid.add_child(btn)
		_slot_buttons.append(btn)

	_context_menu = PopupMenu.new()
	_context_menu.add_item("Equip", 0)
	_context_menu.add_item("Drop", 1)
	_context_menu.add_item("Drop All", 2)
	_context_menu.id_pressed.connect(_on_context_action)
	add_child(_context_menu)

func _make_slot_button(index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = SLOT_SIZE
	btn.clip_text = true
	btn.text = ""
	btn.tooltip_text = "Empty"

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.15, 0.85)
	style.border_color = Color(0.30, 0.30, 0.40, 0.60)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 10)

	btn.gui_input.connect(func(event: InputEvent): _on_slot_input(event, index))
	return btn

func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_slot_left_click(index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_slot_right_click(index, event.global_position)

func _on_slot_left_click(index: int) -> void:
	var slot := InventorySystem.get_slot(index)
	if slot.item_id == 0:
		return
	var item_type := InventorySystem.get_item_type(slot.item_id)
	if item_type in ["weapon", "armor"]:
		NetworkManager.equip_item(index)

func _on_slot_right_click(index: int, pos: Vector2) -> void:
	var slot := InventorySystem.get_slot(index)
	if slot.item_id == 0:
		return
	_context_slot_index = index
	_context_menu.position = Vector2i(int(pos.x), int(pos.y))
	_context_menu.popup()

func _on_context_action(id: int) -> void:
	if _context_slot_index < 0:
		return
	var slot := InventorySystem.get_slot(_context_slot_index)
	if slot.item_id == 0:
		return
	match id:
		0:  # Equip
			NetworkManager.equip_item(_context_slot_index)
		1:  # Drop 1
			NetworkManager.drop_item(_context_slot_index, 1)
		2:  # Drop All
			NetworkManager.drop_item(_context_slot_index, slot.quantity)
	_context_slot_index = -1

func _refresh_slots() -> void:
	for i in _slot_buttons.size():
		var slot := InventorySystem.get_slot(i)
		var btn: Button = _slot_buttons[i]
		if slot.item_id == 0:
			btn.text = ""
			btn.tooltip_text = "Empty"
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.border_color = Color(0.30, 0.30, 0.40, 0.60)
		else:
			var qty_str := "" if slot.quantity <= 1 else " x%d" % slot.quantity
			btn.text = slot.item_name.substr(0, 7) + qty_str
			btn.tooltip_text = "%s (%d)" % [slot.item_name, slot.quantity]
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.border_color = Color(0.50, 0.50, 0.65, 0.80)

func _on_panel_toggle(panel_name: String) -> void:
	if panel_name == "inventory":
		toggle()
