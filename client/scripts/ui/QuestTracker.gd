## QuestTracker — Compact on-screen quest objective display.
##
## Shows the current step of active quests on the right side of the screen.
## Always visible during gameplay (unlike the full QuestPanel which toggles).
class_name QuestTracker
extends VBoxContainer

var _quest_panel: QuestPanel = null

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	EventBus.quest_accepted.connect(_refresh)
	EventBus.quest_progress_updated.connect(func(_id, _p): _refresh())
	EventBus.quest_completed.connect(func(_id): _refresh())

func set_quest_panel(panel: QuestPanel) -> void:
	_quest_panel = panel
	_refresh()

func _refresh(_arg = null) -> void:
	for child in get_children():
		child.queue_free()

	if _quest_panel == null:
		return

	for quest in _quest_panel.active_quests:
		var entry := _build_entry(quest)
		add_child(entry)

func _build_entry(quest: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(160, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = quest.name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.45))
	vbox.add_child(name_lbl)

	var steps: Array = quest.get("steps", [])
	var current_step: int = quest.get("current_step", 0)
	var progress: int = quest.get("progress", 0)

	if current_step < steps.size():
		var step_lbl := Label.new()
		var obj_text: String = steps[current_step]
		if quest.has("objectives") and current_step < quest.objectives.size():
			var obj: Dictionary = quest.objectives[current_step]
			obj_text += " (%d/%d)" % [progress, obj.quantity]
		step_lbl.text = obj_text
		step_lbl.add_theme_font_size_override("font_size", 9)
		step_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
		vbox.add_child(step_lbl)

	return panel
