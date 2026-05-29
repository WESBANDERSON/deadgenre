## OrbitCamera3D — Tight follow-orbit camera for the 2.5D Dreadmyst view.
##
## DESIGN:
##   Camera sits on a spring arm anchored to the player. Pitch is fixed-ish
##   (around 55°) which gives a Dreadmyst/Megabonk top-down-but-readable feel.
##   Yaw can be rotated with Q/E (or right-mouse drag) so players can inspect
##   their character from any angle once equipment-on-body becomes visible.
##
## TIER 0 SCOPE:
##   - Follows player position
##   - Q/E yaw rotation
##   - Mouse wheel zoom within bounds
##
## TIER 1 EXPANSION:
##   - Right-mouse drag yaw (game cursor capture)
##   - Cinematic pitch tweens for hub locations
##   - Screen-space "shake" for combat impacts
class_name OrbitCamera3D
extends Node3D

@export var follow_target: Node3D
@export var yaw_speed: float = 1.8         # radians per second
@export var pitch_deg: float = 55.0
@export var min_distance: float = 6.0
@export var max_distance: float = 18.0
@export var default_distance: float = 11.0
@export var zoom_speed: float = 1.5
@export var follow_lerp: float = 12.0

var _yaw: float = 0.0
var _distance: float = 11.0
var _camera: Camera3D

func _ready() -> void:
	_distance = default_distance
	_build_camera()

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.fov = 55.0
	_camera.near = 0.1
	_camera.far = 240.0
	add_child(_camera)
	_apply_camera_transform()

func _process(delta: float) -> void:
	if follow_target:
		var target_pos: Vector3 = follow_target.global_position
		global_position = global_position.lerp(target_pos, clampf(delta * follow_lerp, 0.0, 1.0))

	if Input.is_action_pressed("camera_rotate_left"):
		_yaw -= yaw_speed * delta
	if Input.is_action_pressed("camera_rotate_right"):
		_yaw += yaw_speed * delta

	_apply_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - zoom_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + zoom_speed, min_distance, max_distance)

func _apply_camera_transform() -> void:
	if _camera == null:
		return
	var pitch_rad := deg_to_rad(pitch_deg)
	var offset := Vector3(
		sin(_yaw) * cos(pitch_rad) * _distance,
		sin(pitch_rad) * _distance,
		cos(_yaw) * cos(pitch_rad) * _distance)
	_camera.transform.origin = offset
	_camera.look_at(global_position, Vector3.UP)

## Returns the camera's current yaw (radians) so movement can be made
## camera-relative.
func get_yaw() -> float:
	return _yaw

func get_camera() -> Camera3D:
	return _camera
