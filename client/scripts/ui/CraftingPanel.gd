## CraftingPanel — Toggle-able crafting recipe browser and crafter.
##
## Shows available recipes grouped by category. Player selects a recipe,
## sees required materials vs what they have, and clicks Craft.
##
## Toggle via: EventBus.panel_toggle_requested("crafting") or 'C' key.
class_name CraftingPanel
extends PanelContainer

var _recipe_list: VBoxContainer = null
var _detail_panel: VBoxContainer = null
var _craft_button: Button = null
var _selected_recipe: Dictionary = {}

## Static recipe definitions (mirrors server seed data).
## In online mode, these would be populated from a CraftingRecipe table subscription.
var recipes: Array[Dictionary] = [
	{"id": 1, "name": "Iron Sword", "desc": "Forge an iron sword from ore and wood.",
	 "result_id": 2, "result_qty": 1, "ingredients": [{item_id=31, qty=3}, {item_id=32, qty=1}],
	 "level": 5, "xp": 50, "category": "weaponsmithing"},
	{"id": 2, "name": "Oak Shortbow", "desc": "Craft a bow from oak logs.",
	 "result_id": 3, "result_qty": 1, "ingredients": [{item_id=32, qty=4}],
	 "level": 3, "xp": 35, "category": "woodworking"},
	{"id": 3, "name": "Leather Helm", "desc": "Stitch a basic leather helm.",
	 "result_id": 10, "result_qty": 1, "ingredients": [{item_id=30, qty=2}],
	 "level": 1, "xp": 20, "category": "armorcrafting"},
	{"id": 4, "name": "Leather Chest", "desc": "Assemble a leather chest piece.",
	 "result_id": 11, "result_qty": 1, "ingredients": [{item_id=30, qty=4}],
	 "level": 2, "xp": 30, "category": "armorcrafting"},
	{"id": 5, "name": "Minor Health Potion", "desc": "Brew a healing potion.",
	 "result_id": 20, "result_qty": 3, "ingredients": [{item_id=33, qty=2}, {item_id=30, qty=1}],
	 "level": 1, "xp": 15, "category": "alchemy"},
	{"id": 6, "name": "Minor Mana Potion", "desc": "Brew a mana potion.",
	 "result_id": 21, "result_qty": 3, "ingredients": [{item_id=33, qty=2}, {item_id=31, qty=1}],
	 "level": 2, "xp": 18, "category": "alchemy"},
]

var _item_names := {
	2: "Iron Sword", 3: "Oak Shortbow", 10: "Leather Helm", 11: "Leather Chest",
	20: "Minor Health Potion", 21: "Minor Mana Potion",
	30: "Copper Ore", 31: "Iron Ore", 32: "Oak Log", 33: "Raw Fish",
}

func _ready() -> void:
	_build_panel()
	_connect_signals()
	visible = false

func _connect_signals() -> void:
	EventBus.panel_toggle_requested.connect(_on_panel_toggle)
	EventBus.inventory_changed.connect(_refresh_detail)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			toggle()
		elif event.keycode == KEY_ESCAPE and visible:
			visible = false

func toggle() -> void:
	visible = not visible
	if visible:
		_populate_recipes()

func _build_panel() -> void:
	custom_minimum_size = Vector2(340, 380)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	style.border_color = Color(0.35, 0.50, 0.35, 0.80)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	var header := HBoxContainer.new()
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "Crafting"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.85))
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	var hsplit := HBoxContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(hsplit)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(140, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_list)

	_detail_panel = VBoxContainer.new()
	_detail_panel.custom_minimum_size = Vector2(180, 0)
	_detail_panel.add_theme_constant_override("separation", 4)
	hsplit.add_child(_detail_panel)

	_craft_button = Button.new()
	_craft_button.text = "Craft"
	_craft_button.custom_minimum_size = Vector2(0, 32)
	_craft_button.disabled = true
	_craft_button.pressed.connect(_on_craft_pressed)
	main_vbox.add_child(_craft_button)

func _populate_recipes() -> void:
	for child in _recipe_list.get_children():
		child.queue_free()

	var crafting_level: int = GameManager.player_skills.get("crafting", {}).get("level", 1)
	for recipe in recipes:
		var btn := Button.new()
		btn.text = recipe.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		if recipe.level > crafting_level:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn.tooltip_text = "Requires Crafting Lv.%d" % recipe.level
		btn.pressed.connect(func(): _select_recipe(recipe))
		_recipe_list.add_child(btn)

func _select_recipe(recipe: Dictionary) -> void:
	_selected_recipe = recipe
	_refresh_detail()

func _refresh_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()

	if _selected_recipe.is_empty():
		_craft_button.disabled = true
		return

	var name_label := Label.new()
	name_label.text = _selected_recipe.name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
	_detail_panel.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = _selected_recipe.desc
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	_detail_panel.add_child(desc_label)

	var sep := HSeparator.new()
	_detail_panel.add_child(sep)

	var ing_title := Label.new()
	ing_title.text = "Materials:"
	ing_title.add_theme_font_size_override("font_size", 11)
	_detail_panel.add_child(ing_title)

	var can_craft := true
	var crafting_level: int = GameManager.player_skills.get("crafting", {}).get("level", 1)
	if _selected_recipe.level > crafting_level:
		can_craft = false

	for ingredient in _selected_recipe.ingredients:
		var item_id: int = ingredient.item_id
		var needed: int = ingredient.qty
		var have: int = InventorySystem.count_item(item_id)
		var mat_name: String = _item_names.get(item_id, "Item #%d" % item_id)
		var color := Color(0.4, 0.9, 0.4) if have >= needed else Color(0.9, 0.4, 0.4)
		var lbl := Label.new()
		lbl.text = "  %s: %d / %d" % [mat_name, have, needed]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", color)
		_detail_panel.add_child(lbl)
		if have < needed:
			can_craft = false

	var result_label := Label.new()
	var result_name: String = _item_names.get(_selected_recipe.result_id, "Item")
	result_label.text = "Result: %d × %s" % [_selected_recipe.result_qty, result_name]
	result_label.add_theme_font_size_override("font_size", 11)
	result_label.add_theme_color_override("font_color", Color(0.70, 0.85, 0.95))
	_detail_panel.add_child(result_label)

	_craft_button.disabled = not can_craft

func _on_craft_pressed() -> void:
	if _selected_recipe.is_empty():
		return
	NetworkManager.craft_item(_selected_recipe.id)
	EventBus.crafting_completed.emit(_selected_recipe.id, _selected_recipe.name)

func _on_panel_toggle(panel_name: String) -> void:
	if panel_name == "crafting":
		toggle()
