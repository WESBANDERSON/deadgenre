## Main HUD overlay. Contains health/xp bars, minimap placeholder,
## and notification feed. Panels (inventory, skills) are toggled in/out.
extends CanvasLayer

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel
@onready var notification_container: VBoxContainer = %NotificationContainer
@onready var inventory_panel: Control = %InventoryPanel
@onready var skills_panel: Control = %SkillsPanel

var _player_hp: int = 100
var _player_max_hp: int = 100
var _player_level: int = 1
var _player_xp: int = 0

func _ready() -> void:
	EventBus.player_stats_changed.connect(_on_stats_changed)
	EventBus.notification_requested.connect(_on_notification)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	if inventory_panel:
		inventory_panel.visible = false
	if skills_panel:
		skills_panel.visible = false
	_update_bars()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_panel("inventory")
	elif event.is_action_pressed("toggle_skills"):
		_toggle_panel("skills")

func _toggle_panel(panel_name: String) -> void:
	match panel_name:
		"inventory":
			if inventory_panel:
				inventory_panel.visible = !inventory_panel.visible
				EventBus.ui_panel_toggled.emit("inventory", inventory_panel.visible)
		"skills":
			if skills_panel:
				skills_panel.visible = !skills_panel.visible
				EventBus.ui_panel_toggled.emit("skills", skills_panel.visible)

func _on_stats_changed(stats: Dictionary) -> void:
	_player_hp = stats.get("current_hp", _player_hp)
	_player_max_hp = stats.get("max_hp", _player_max_hp)
	_player_level = stats.get("level", _player_level)
	_player_xp = stats.get("xp", _player_xp)
	_update_bars()

func _update_bars() -> void:
	if hp_bar:
		hp_bar.max_value = _player_max_hp
		hp_bar.value = _player_hp
	if hp_label:
		hp_label.text = "%d / %d" % [_player_hp, _player_max_hp]
	if level_label:
		level_label.text = "Lv. %d" % _player_level
	if xp_bar:
		xp_bar.value = _player_xp

func _on_notification(message: String, type: String) -> void:
	if notification_container == null:
		return
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 14)
	match type:
		"combat":
			label.modulate = Color(1.0, 0.4, 0.3)
		"warning":
			label.modulate = Color(1.0, 0.85, 0.2)
		"success":
			label.modulate = Color(0.3, 1.0, 0.4)
		_:
			label.modulate = Color.WHITE
	notification_container.add_child(label)

	var tween := create_tween()
	tween.tween_interval(Config.notification_duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _on_inventory_changed() -> void:
	pass
