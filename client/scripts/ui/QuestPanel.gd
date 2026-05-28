## QuestPanel — Quest log and active quest tracker.
##
## Shows the player's active and completed quests.
## The compact tracker on the right side of the screen shows current objectives.
##
## Toggle full panel with 'J' key or EventBus.panel_toggle_requested("quests").
class_name QuestPanel
extends PanelContainer

## Quest data structure:
## { "id": int, "name": String, "description": String, "steps": Array[String],
##   "objectives": Array[{type, target, quantity}], "status": String,
##   "current_step": int, "progress": int, "rewards": Dictionary }
var active_quests: Array[Dictionary] = []
var completed_quests: Array[Dictionary] = []

var _quest_list: VBoxContainer = null
var _detail_panel: VBoxContainer = null
var _selected_quest: Dictionary = {}

## Static quest definitions (mirrors server seed data)
var quest_definitions: Dictionary = {
	1: {"id": 1, "name": "Goblin Trouble",
		"description": "Clear out goblins near the village and collect copper ore for Merchant Alice.",
		"steps": ["Defeat 3 goblins", "Collect 5 Copper Ore", "Return to Alice"],
		"objectives": [
			{"type": "kill", "target": "goblin", "quantity": 3},
			{"type": "gather", "target": 30, "quantity": 5},
			{"type": "talk", "target": "merchant_alice", "quantity": 1},
		],
		"rewards": {"xp_skill": "melee", "xp_amount": 100, "item_id": 2, "item_qty": 1}},
	2: {"id": 2, "name": "Lumberjack's Start",
		"description": "Gather oak logs to prove your woodcutting skills.",
		"steps": ["Gather 10 Oak Logs", "Return to Alice"],
		"objectives": [
			{"type": "gather", "target": 32, "quantity": 10},
			{"type": "talk", "target": "merchant_alice", "quantity": 1},
		],
		"rewards": {"xp_skill": "gathering", "xp_amount": 75, "item_id": 32, "item_qty": 5}},
	3: {"id": 3, "name": "Brew Master Apprentice",
		"description": "Learn the basics of alchemy by crafting potions.",
		"steps": ["Gather 4 Raw Fish", "Craft 3 Health Potions", "Return to Alice"],
		"objectives": [
			{"type": "gather", "target": 33, "quantity": 4},
			{"type": "craft", "target": 5, "quantity": 1},
			{"type": "talk", "target": "merchant_alice", "quantity": 1},
		],
		"rewards": {"xp_skill": "crafting", "xp_amount": 60, "item_id": 20, "item_qty": 5}},
}

func _ready() -> void:
	_build_panel()
	_connect_signals()
	visible = false

func _connect_signals() -> void:
	EventBus.panel_toggle_requested.connect(_on_panel_toggle)
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.quest_progress_updated.connect(_on_quest_progress)
	EventBus.quest_completed.connect(_on_quest_completed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			toggle()
		elif event.keycode == KEY_ESCAPE and visible:
			visible = false

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh_list()

func _build_panel() -> void:
	custom_minimum_size = Vector2(380, 340)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	style.border_color = Color(0.50, 0.45, 0.30, 0.80)
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
	title.text = "Quest Log"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
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
	scroll.custom_minimum_size = Vector2(150, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.add_child(scroll)

	_quest_list = VBoxContainer.new()
	_quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_quest_list)

	_detail_panel = VBoxContainer.new()
	_detail_panel.custom_minimum_size = Vector2(200, 0)
	_detail_panel.add_theme_constant_override("separation", 6)
	hsplit.add_child(_detail_panel)

func _refresh_list() -> void:
	for child in _quest_list.get_children():
		child.queue_free()

	if active_quests.is_empty() and completed_quests.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No quests yet.\nTalk to NPCs!"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_quest_list.add_child(empty_lbl)
		return

	if not active_quests.is_empty():
		var active_header := Label.new()
		active_header.text = "Active"
		active_header.add_theme_font_size_override("font_size", 11)
		active_header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5))
		_quest_list.add_child(active_header)

		for quest in active_quests:
			var btn := Button.new()
			btn.text = quest.name
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 11)
			btn.pressed.connect(func(): _select_quest(quest))
			_quest_list.add_child(btn)

	if not completed_quests.is_empty():
		var comp_header := Label.new()
		comp_header.text = "Completed"
		comp_header.add_theme_font_size_override("font_size", 11)
		comp_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_quest_list.add_child(comp_header)

		for quest in completed_quests:
			var btn := Button.new()
			btn.text = quest.name
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn.pressed.connect(func(): _select_quest(quest))
			_quest_list.add_child(btn)

func _select_quest(quest: Dictionary) -> void:
	_selected_quest = quest
	_refresh_detail()

func _refresh_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()

	if _selected_quest.is_empty():
		return

	var name_lbl := Label.new()
	name_lbl.text = _selected_quest.name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.60))
	_detail_panel.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = _selected_quest.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	_detail_panel.add_child(desc_lbl)

	var sep := HSeparator.new()
	_detail_panel.add_child(sep)

	var steps: Array = _selected_quest.get("steps", [])
	var current_step: int = _selected_quest.get("current_step", 0)
	var progress: int = _selected_quest.get("progress", 0)
	var status: String = _selected_quest.get("status", "active")

	for i in steps.size():
		var step_lbl := Label.new()
		var prefix := ""
		var color := Color(0.5, 0.5, 0.5)
		if status == "completed" or i < current_step:
			prefix = "[DONE] "
			color = Color(0.4, 0.7, 0.4)
		elif i == current_step:
			prefix = ">> "
			color = Color(0.9, 0.9, 0.9)
			if _selected_quest.has("objectives"):
				var obj: Dictionary = _selected_quest.objectives[i]
				step_lbl.text = prefix + steps[i] + " (%d/%d)" % [progress, obj.quantity]
			else:
				step_lbl.text = prefix + steps[i]
		else:
			prefix = "   "
		if step_lbl.text == "":
			step_lbl.text = prefix + steps[i]
		step_lbl.add_theme_font_size_override("font_size", 11)
		step_lbl.add_theme_color_override("font_color", color)
		_detail_panel.add_child(step_lbl)

func accept_quest(quest_id: int) -> void:
	if not quest_definitions.has(quest_id):
		return
	for q in active_quests:
		if q.id == quest_id:
			return
	var def: Dictionary = quest_definitions[quest_id].duplicate(true)
	def["status"] = "active"
	def["current_step"] = 0
	def["progress"] = 0
	active_quests.append(def)
	EventBus.quest_accepted.emit(quest_id)
	EventBus.notification_shown.emit("Quest accepted: %s" % def.name, "info")

func _on_quest_accepted(_quest_id: int) -> void:
	if visible:
		_refresh_list()

func _on_quest_progress(quest_id: int, new_progress: int) -> void:
	for quest in active_quests:
		if quest.id == quest_id:
			quest.progress = new_progress
			break
	if visible:
		_refresh_detail()

func _on_quest_completed(quest_id: int) -> void:
	for i in active_quests.size():
		if active_quests[i].id == quest_id:
			var quest: Dictionary = active_quests[i]
			quest.status = "completed"
			completed_quests.append(quest)
			active_quests.remove_at(i)
			EventBus.notification_shown.emit("Quest completed: %s" % quest.name, "loot")
			break
	if visible:
		_refresh_list()

func _on_panel_toggle(panel_name: String) -> void:
	if panel_name == "quests":
		toggle()
