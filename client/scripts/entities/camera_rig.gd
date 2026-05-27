## Isometric-style camera rig that follows the player.
## Supports zoom (scroll wheel), rotation (middle-mouse drag), and smooth following.
## Attach this as a child of the player or as a standalone node that tracks a target.
extends Node3D

@export var target_path: NodePath = ""
@export var follow_speed: float = 8.0

var _distance: float = 12.0
var _angle_y: float = 0.0  # Horizontal orbit angle
var _is_rotating: bool = false

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_distance = Config.camera_distance_default
	_update_camera_transform()

func _process(delta: float) -> void:
	var target := _get_target()
	if target:
		global_position = global_position.lerp(target.global_position, follow_speed * delta)
	_update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_distance = clampf(_distance - Config.camera_zoom_speed, Config.camera_distance_min, Config.camera_distance_max)
	elif event.is_action_pressed("camera_zoom_out"):
		_distance = clampf(_distance + Config.camera_zoom_speed, Config.camera_distance_min, Config.camera_distance_max)

	if event.is_action_pressed("camera_rotate"):
		_is_rotating = true
	elif event.is_action_released("camera_rotate"):
		_is_rotating = false

	if event is InputEventMouseMotion and _is_rotating:
		_angle_y -= event.relative.x * Config.camera_rotate_speed

func _update_camera_transform() -> void:
	if _camera == null:
		return
	var pitch := deg_to_rad(Config.camera_angle)
	var offset := Vector3(
		sin(_angle_y) * cos(pitch) * _distance,
		-sin(pitch) * _distance,
		cos(_angle_y) * cos(pitch) * _distance
	)
	_camera.position = offset
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _get_target() -> Node3D:
	if target_path != NodePath(""):
		return get_node_or_null(target_path) as Node3D
	return GameManager.local_player
