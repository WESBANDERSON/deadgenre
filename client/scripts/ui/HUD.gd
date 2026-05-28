## HUD — Heads-Up Display controller.
##
## Layout (Albion-inspired, OSRS sensibility):
##   Top-right   → Connection status indicator
##   Bottom-left → Vital bars (HP, Mana) + level badge
##   Bottom-center → Hotbar (8 skill/item slots)
##   Right edge  → Skill panel toggle button
##   Top-left    → Notification area (temporary messages)
##   Minimap     → Procedurally-drawn minimap (top-right)
##   Right-center → Inventory panel (toggle with I)
##   Left-center  → Crafting panel (toggle with C)
##
## All layout is built in code for AI-readability and iteration speed.
## Replace with proper .tscn scene nodes once the design is locked.
class_name HUD
extends CanvasLayer

# ─────────────────────────────────────────────────────────────────────────────
# UI Element References (populated in _ready)
# ─────────────────────────────────────────────────────────────────────────────
var _hp_bar: ProgressBar = null
var _mana_bar: ProgressBar = null
var _level_label: Label = null
var _hotbar: HBoxContainer = null
var _notification_label: Label = null
var _notification_timer: float = 0.0
var _status_label: Label = null
var _minimap: Control = null
var _inventory_panel: InventoryPanel = null
var _crafting_panel: CraftingPanel = null
var _dialogue_panel: DialoguePanel = null
var _quest_panel: QuestPanel = null
var _quest_tracker: QuestTracker = null

# ─────────────────────────────────────────────────────────────────────────────
# Notification Queue
# ─────────────────────────────────────────────────────────────────────────────
var _notification_queue: Array[Dictionary] = []
const NOTIFICATION_DISPLAY_TIME := 3.0

func _ready() -> void:
	_build_hud()
	_connect_signals()

func _connect_signals() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_mana_changed.connect(_on_mana_changed)
	EventBus.player_level_changed.connect(_on_level_changed)
	EventBus.notification_shown.connect(_on_notification)
	EventBus.connected_to_server.connect(_on_connected)
	EventBus.disconnected_from_server.connect(_on_disconnected)
	EventBus.player_skill_leveled.connect(_on_skill_leveled)

func _process(delta: float) -> void:
	_update_notifications(delta)
	if _minimap:
		_minimap.queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# HUD Construction — all built programmatically for maximum AI editability
# ─────────────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_vitals_panel(root)
	_build_hotbar(root)
	_build_notification_area(root)
	_build_status_indicator(root)
	_build_minimap(root)
	_build_inventory_panel(root)
	_build_crafting_panel(root)
	_build_dialogue_panel(root)
	_build_quest_panel(root)
	_build_quest_tracker(root)

func _build_vitals_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "VitalsPanel"
	_apply_panel_style(panel, Color(0.08, 0.08, 0.12, 0.85))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left   = 10
	panel.offset_bottom = -10
	panel.offset_right  = 210
	panel.offset_top    = -100
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Level and name row
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var avatar := ColorRect.new()
	avatar.custom_minimum_size = Vector2(28, 28)
	avatar.color = Color(0.35, 0.55, 0.90)
	name_row.add_child(avatar)
	_level_label = Label.new()
	_level_label.text = "Lv.1  Adventurer"
	_level_label.add_theme_font_size_override("font_size", 12)
	name_row.add_child(_level_label)

	# HP bar
	var hp_row := HBoxContainer.new()
	vbox.add_child(hp_row)
	var hp_icon := _make_colored_rect(Color(0.85, 0.15, 0.15), Vector2(8, 18))
	hp_row.add_child(hp_icon)
	_hp_bar = _make_progress_bar(100, Color(0.85, 0.15, 0.15), Vector2(160, 18))
	hp_row.add_child(_hp_bar)

	# Mana bar
	var mana_row := HBoxContainer.new()
	vbox.add_child(mana_row)
	var mana_icon := _make_colored_rect(Color(0.20, 0.35, 0.90), Vector2(8, 18))
	mana_row.add_child(mana_icon)
	_mana_bar = _make_progress_bar(50, Color(0.20, 0.35, 0.90), Vector2(160, 18))
	mana_row.add_child(_mana_bar)

func _build_hotbar(root: Control) -> void:
	var container := HBoxContainer.new()
	container.name = "Hotbar"
	container.add_theme_constant_override("separation", 4)
	container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	container.offset_bottom = -12
	container.offset_top    = -58
	container.offset_left   = 0
	container.offset_right  = 0
	container.alignment     = BoxContainer.ALIGNMENT_CENTER
	root.add_child(container)
	_hotbar = container

	for i in 8:
		var slot := _make_hotbar_slot(i)
		container.add_child(slot)

func _make_hotbar_slot(index: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44, 44)
	btn.text = str(index + 1)
	btn.name = "Slot_%d" % index
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.90)
	style.border_color = Color(0.40, 0.40, 0.55, 0.70)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", style)
	btn.pressed.connect(func(): _on_hotbar_slot_pressed(index))
	return btn

func _build_notification_area(root: Control) -> void:
	_notification_label = Label.new()
	_notification_label.name = "Notification"
	_notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_notification_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_notification_label.offset_top    = 12
	_notification_label.offset_bottom = 60
	_notification_label.offset_left   = 100
	_notification_label.offset_right  = -100
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.modulate.a = 0.0
	_notification_label.add_theme_font_size_override("font_size", 15)
	root.add_child(_notification_label)

func _build_status_indicator(root: Control) -> void:
	_status_label = Label.new()
	_status_label.name = "StatusIndicator"
	_status_label.text = "● OFFLINE"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_label.offset_right  = -10
	_status_label.offset_top    = 10
	_status_label.offset_left   = -120
	_status_label.offset_bottom = 28
	root.add_child(_status_label)

func _build_minimap(root: Control) -> void:
	var map_size := Vector2(120, 120)
	_minimap = Control.new()
	_minimap.name = "Minimap"
	_minimap.custom_minimum_size = map_size
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_right  = -10
	_minimap.offset_top    = 34
	_minimap.offset_left   = -130
	_minimap.offset_bottom = 154
	_minimap.draw.connect(_draw_minimap.bind(_minimap))
	_minimap.clip_contents = true
	root.add_child(_minimap)

func _build_inventory_panel(root: Control) -> void:
	_inventory_panel = InventoryPanel.new()
	_inventory_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_inventory_panel.offset_right = -10
	_inventory_panel.offset_left = -270
	_inventory_panel.offset_top = -200
	_inventory_panel.offset_bottom = 200
	root.add_child(_inventory_panel)

func _build_crafting_panel(root: Control) -> void:
	_crafting_panel = CraftingPanel.new()
	_crafting_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_crafting_panel.offset_left = 10
	_crafting_panel.offset_right = 350
	_crafting_panel.offset_top = -190
	_crafting_panel.offset_bottom = 190
	root.add_child(_crafting_panel)

func _build_dialogue_panel(root: Control) -> void:
	_dialogue_panel = DialoguePanel.new()
	root.add_child(_dialogue_panel)

func _build_quest_panel(root: Control) -> void:
	_quest_panel = QuestPanel.new()
	_quest_panel.set_anchors_preset(Control.PRESET_CENTER)
	_quest_panel.offset_left = -190
	_quest_panel.offset_right = 190
	_quest_panel.offset_top = -170
	_quest_panel.offset_bottom = 170
	root.add_child(_quest_panel)

func _build_quest_tracker(root: Control) -> void:
	_quest_tracker = QuestTracker.new()
	_quest_tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest_tracker.offset_right = -10
	_quest_tracker.offset_left = -180
	_quest_tracker.offset_top = 160
	_quest_tracker.offset_bottom = 320
	_quest_tracker.set_quest_panel(_quest_panel)
	root.add_child(_quest_tracker)

func _draw_minimap(map: Control) -> void:
	var size := map.size
	# Background
	map.draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.14, 0.90))

	# Draw a simple dot for the player at center
	map.draw_circle(size * 0.5, 3.0, Color(0.35, 0.55, 0.90))

	# Border
	map.draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.35, 0.50, 0.70), false, 1.5)

	var lbl := "Minimap"
	map.draw_string(ThemeDB.fallback_font, Vector2(4, 12), lbl, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10, Color(0.6, 0.6, 0.6, 0.6))

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _make_progress_bar(max_val: int, fill_color: Color, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_val
	bar.value     = max_val
	bar.custom_minimum_size = size
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar

func _make_colored_rect(color: Color, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = size
	return r

func _apply_panel_style(panel: PanelContainer, bg: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

# ─────────────────────────────────────────────────────────────────────────────
# Notification System
# ─────────────────────────────────────────────────────────────────────────────
func _update_notifications(delta: float) -> void:
	if _notification_label == null:
		return
	if _notification_timer > 0:
		_notification_timer -= delta
		if _notification_timer <= 0.6:
			# Fade out
			_notification_label.modulate.a = max(0, _notification_label.modulate.a - delta * 2.5)
		if _notification_timer <= 0:
			_notification_label.modulate.a = 0.0
			_show_next_notification()
	elif _notification_queue.size() > 0:
		_show_next_notification()

func _show_next_notification() -> void:
	if _notification_queue.is_empty():
		return
	var entry: Dictionary = _notification_queue.pop_front()
	_notification_label.text = entry.message
	match entry.get("style", "info"):
		"error":   _notification_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
		"warn":    _notification_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.20))
		"loot":    _notification_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.10))
		_:         _notification_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	_notification_label.modulate.a = 1.0
	_notification_timer = NOTIFICATION_DISPLAY_TIME

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_health_changed(_player: Node, current: int, maximum: int) -> void:
	if _hp_bar:
		_hp_bar.max_value = maximum
		_hp_bar.value     = current

func _on_mana_changed(_player: Node, current: int, maximum: int) -> void:
	if _mana_bar:
		_mana_bar.max_value = maximum
		_mana_bar.value     = current

func _on_level_changed(new_level: int) -> void:
	if _level_label:
		var name_str: String = GameManager.settings.get("player_name", "Adventurer")
		_level_label.text = "Lv.%d  %s" % [new_level, name_str]

func _on_notification(message: String, style: String) -> void:
	_notification_queue.append({"message": message, "style": style})

func _on_connected() -> void:
	if _status_label:
		_status_label.text = "● ONLINE"
		_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))

func _on_disconnected() -> void:
	if _status_label:
		_status_label.text = "● OFFLINE"
		_status_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))

func _on_skill_leveled(skill: String, new_level: int) -> void:
	EventBus.notification_shown.emit(
		"✦ %s reached level %d!" % [skill.capitalize(), new_level], "loot")

func _on_hotbar_slot_pressed(index: int) -> void:
	print("[HUD] Hotbar slot %d pressed" % index)
