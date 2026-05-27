## GameManager — Central game state registry.
##
## This is NOT a logic processor. It holds references and state that multiple
## systems need to read, but it does not own update loops for those systems.
##
## Access pattern:
##   GameManager.local_player      → the current player's Node
##   GameManager.game_state        → current GameState enum value
##   GameManager.session_identity  → SpacetimeDB identity string
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# State Machine
# ─────────────────────────────────────────────────────────────────────────────
enum GameState {
	LOADING,       # Initial load, connecting to server
	CHARACTER_SELECT,
	PLAYING,
	DEAD,
	PAUSED,
}

var game_state: GameState = GameState.LOADING:
	set(value):
		var prev = game_state
		game_state = value
		_on_state_changed(prev, value)

# ─────────────────────────────────────────────────────────────────────────────
# Global References
# ─────────────────────────────────────────────────────────────────────────────
var local_player: Node = null       # Set by World when player spawns
var world: Node = null              # Set by World on _ready
var session_identity: String = ""   # Set by NetworkManager on connect

# ─────────────────────────────────────────────────────────────────────────────
# Player State Cache (mirrors server values for quick read access)
# ─────────────────────────────────────────────────────────────────────────────
var player_health: int = 100
var player_max_health: int = 100
var player_mana: int = 50
var player_max_mana: int = 50
var player_level: int = 1
var player_skills: Dictionary = {}  # skill_name -> {level, experience}

# ─────────────────────────────────────────────────────────────────────────────
# Settings (persisted to user://settings.cfg)
# ─────────────────────────────────────────────────────────────────────────────
var settings: Dictionary = {
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"show_damage_numbers": true,
	"camera_zoom": 2.0,
	"player_name": "",
}

func _ready() -> void:
	_load_settings()
	_connect_signals()

func _connect_signals() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_mana_changed.connect(_on_player_mana_changed)
	EventBus.player_skill_leveled.connect(_on_skill_leveled)
	EventBus.player_xp_gained.connect(_on_xp_gained)
	EventBus.local_player_spawned.connect(_on_local_player_spawned)
	EventBus.player_died.connect(_on_player_died)
	EventBus.connected_to_server.connect(_on_connected)
	EventBus.disconnected_from_server.connect(_on_disconnected)

# ─────────────────────────────────────────────────────────────────────────────
# Signal Handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_state_changed(from: GameState, to: GameState) -> void:
	print("[GameManager] State: %s → %s" % [GameState.keys()[from], GameState.keys()[to]])

func _on_player_health_changed(player: Node, current: int, maximum: int) -> void:
	if player == local_player:
		player_health = current
		player_max_health = maximum

func _on_player_mana_changed(player: Node, current: int, maximum: int) -> void:
	if player == local_player:
		player_mana = current
		player_max_mana = maximum

func _on_skill_leveled(skill: String, new_level: int) -> void:
	if not player_skills.has(skill):
		player_skills[skill] = {}
	player_skills[skill]["level"] = new_level

func _on_xp_gained(skill: String, _amount: int, new_total: int) -> void:
	if not player_skills.has(skill):
		player_skills[skill] = {}
	player_skills[skill]["experience"] = new_total

func _on_local_player_spawned(player: Node) -> void:
	local_player = player
	game_state = GameState.PLAYING

func _on_player_died(_player: Node) -> void:
	game_state = GameState.DEAD

func _on_connected() -> void:
	print("[GameManager] Connected to server.")

func _on_disconnected() -> void:
	print("[GameManager] Disconnected from server.")
	if game_state == GameState.PLAYING:
		EventBus.notification_shown.emit("Disconnected from server", "error")

# ─────────────────────────────────────────────────────────────────────────────
# Settings Persistence
# ─────────────────────────────────────────────────────────────────────────────
func save_settings() -> void:
	var cfg = ConfigFile.new()
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save("user://settings.cfg")

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		for key in settings:
			if cfg.has_section_key("settings", key):
				settings[key] = cfg.get_value("settings", key)
