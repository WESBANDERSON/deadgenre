## DeathScreen — Displayed when the player dies.
##
## Shows a "You Died" message with a respawn button.
## On respawn, calls the server reducer and teleports the player to their
## bound respawn point. 3 second immunity is tracked client-side.
class_name DeathScreen
extends CanvasLayer

var _panel: PanelContainer = null
var _respawn_button: Button = null
var _respawn_timer: float = 0.0
const RESPAWN_DELAY := 3.0

func _ready() -> void:
	_build_screen()
	_connect_signals()
	visible = false
	layer = 10

func _connect_signals() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.local_player_respawned.connect(_on_respawned)

func _process(delta: float) -> void:
	if not visible:
		return
	if _respawn_timer > 0:
		_respawn_timer -= delta
		_respawn_button.text = "Respawn (%.1f)" % maxf(0, _respawn_timer)
		if _respawn_timer <= 0:
			_respawn_button.text = "Respawn"
			_respawn_button.disabled = false

func _build_screen() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -140
	_panel.offset_right = 140
	_panel.offset_top = -80
	_panel.offset_bottom = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.02, 0.02, 0.95)
	style.border_color = Color(0.6, 0.1, 0.1, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "10% of carried resources were dropped."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 12)
	msg.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg)

	_respawn_button = Button.new()
	_respawn_button.text = "Respawn"
	_respawn_button.custom_minimum_size = Vector2(120, 36)
	_respawn_button.disabled = true
	_respawn_button.pressed.connect(_on_respawn_pressed)
	vbox.add_child(_respawn_button)

func _on_player_died(_player: Node) -> void:
	visible = true
	_respawn_timer = RESPAWN_DELAY
	_respawn_button.disabled = true

func _on_respawn_pressed() -> void:
	NetworkManager.player_died_reducer()
	visible = false
	GameManager.game_state = GameManager.GameState.PLAYING

func _on_respawned(_position: Vector2) -> void:
	visible = false
