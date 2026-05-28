## CharacterSelectScreen — Login/character creation flow.
##
## Shown when GameManager.game_state == CHARACTER_SELECT.
## In offline mode, just collects a player name and starts the game.
## In online mode, would authenticate with SpacetimeDB and load existing characters.
##
## Flow:
##   1. Player enters a name (or selects existing character in online mode)
##   2. Clicks "Enter World"
##   3. GameManager transitions to PLAYING, World spawns the player
class_name CharacterSelectScreen
extends CanvasLayer

var _panel: PanelContainer = null
var _name_input: LineEdit = null
var _play_button: Button = null
var _error_label: Label = null

func _ready() -> void:
	_build_screen()
	_connect_signals()
	layer = 20

func _connect_signals() -> void:
	GameManager.game_state_changed.connect(_on_game_state_changed) if GameManager.has_signal("game_state_changed") else null

func _build_screen() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.95)
	style.border_color = Color(0.30, 0.40, 0.60, 0.70)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "deadgenre"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.75, 0.80, 0.95))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Enter the world"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65))
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var name_label := Label.new()
	name_label.text = "Character Name"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	vbox.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "3-20 characters, letters/numbers/underscore"
	_name_input.max_length = 20
	_name_input.custom_minimum_size = Vector2(280, 36)
	_name_input.text_submitted.connect(func(_t): _on_play_pressed())
	vbox.add_child(_name_input)

	_error_label = Label.new()
	_error_label.text = ""
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_size_override("font_size", 11)
	_error_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	vbox.add_child(_error_label)

	_play_button = Button.new()
	_play_button.text = "Enter World"
	_play_button.custom_minimum_size = Vector2(200, 40)
	_play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(_play_button)

	var hint := Label.new()
	hint.text = "Offline Mode — no server required"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.40, 0.45, 0.50))
	vbox.add_child(hint)

func _on_play_pressed() -> void:
	var player_name := _name_input.text.strip_edges()

	if player_name.length() < 3:
		_error_label.text = "Name must be at least 3 characters"
		return
	if player_name.length() > 20:
		_error_label.text = "Name must be 20 characters or less"
		return
	if not _is_valid_name(player_name):
		_error_label.text = "Only letters, numbers, and underscores allowed"
		return

	_error_label.text = ""
	GameManager.settings["player_name"] = player_name
	GameManager.save_settings()

	NetworkManager.create_player(player_name)

	visible = false
	GameManager.game_state = GameManager.GameState.PLAYING

func _is_valid_name(name: String) -> bool:
	for c in name:
		if not (c.unicode_at(0) >= 65 and c.unicode_at(0) <= 90) \
			and not (c.unicode_at(0) >= 97 and c.unicode_at(0) <= 122) \
			and not (c.unicode_at(0) >= 48 and c.unicode_at(0) <= 57) \
			and c != "_":
			return false
	return true

func _on_game_state_changed(_from, to) -> void:
	visible = (to == GameManager.GameState.CHARACTER_SELECT)
