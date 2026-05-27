## Global configuration singleton. Holds all tunable constants so AI agents
## and designers can adjust game feel without hunting through scripts.
extends Node

# --- Server ---
var server_uri: String = "http://127.0.0.1:3000"
var module_name: String = "deadgenre"

# --- Player movement ---
var player_move_speed: float = 6.0
var player_run_speed: float = 10.0
var player_rotation_speed: float = 10.0
var player_gravity: float = 20.0
var click_move_threshold: float = 0.5

# --- Camera ---
var camera_distance_min: float = 5.0
var camera_distance_max: float = 25.0
var camera_distance_default: float = 12.0
var camera_angle: float = -55.0  # Degrees from horizontal (OSRS-like isometric)
var camera_zoom_speed: float = 2.0
var camera_rotate_speed: float = 0.005

# --- Combat ---
var combat_tick_interval: float = 2.4  # Seconds between combat ticks (OSRS = 0.6s game tick)
var damage_popup_duration: float = 1.0
var damage_popup_rise: float = 40.0

# --- World ---
var chunk_size: float = 32.0
var view_distance_chunks: int = 3
var ground_tile_size: float = 1.0

# --- UI ---
var ui_scale: float = 1.0
var tooltip_delay: float = 0.3
var notification_duration: float = 3.0

# --- Network ---
var position_sync_interval: float = 0.1  # How often to send position updates
var reconnect_delay: float = 5.0

func _ready() -> void:
	_load_overrides()

func _load_overrides() -> void:
	var path := "user://config.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	for key in data:
		if key in self:
			set(key, data[key])

func save_overrides() -> void:
	var data := {}
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[prop.name] = get(prop.name)
	var file := FileAccess.open("user://config.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
