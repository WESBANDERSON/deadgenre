## Player controller: handles WASD movement, click-to-move, and rotation.
## Designed to feel smooth and responsive while staying simple enough for
## AI agents to extend (e.g. adding abilities, mounts, swimming).
extends CharacterBody3D

@export var move_speed: float = 6.0
@export var rotation_speed: float = 10.0

var _click_target: Vector3 = Vector3.INF
var _gravity: float = 20.0
var _is_moving_to_click: bool = false

@onready var _model: Node3D = $Model
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _anim_player: AnimationPlayer = $Model/AnimationPlayer if has_node("Model/AnimationPlayer") else null

func _ready() -> void:
	move_speed = Config.player_move_speed
	rotation_speed = Config.player_rotation_speed
	_gravity = Config.player_gravity
	GameManager.register_local_player(self)

func _physics_process(delta: float) -> void:
	var input_dir := _get_input_direction()

	if input_dir.length() > 0.1:
		_is_moving_to_click = false
		_click_target = Vector3.INF

	var move_dir := Vector3.ZERO

	if _is_moving_to_click:
		var to_target := _click_target - global_position
		to_target.y = 0
		if to_target.length() < Config.click_move_threshold:
			_is_moving_to_click = false
			_click_target = Vector3.INF
		else:
			move_dir = to_target.normalized()
	elif input_dir.length() > 0.1:
		var cam_basis := _get_camera_flat_basis()
		move_dir = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if move_dir.length() > 0.1:
		var target_angle := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0

	move_and_slide()

	_update_animation(move_dir.length() > 0.1)
	EventBus.player_moved.emit(global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("click_action"):
		_try_click_move(event)

func _try_click_move(event: InputEvent) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 100.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # Layer 1 = ground
	var result := space_state.intersect_ray(query)

	if result.size() > 0:
		_click_target = result["position"]
		_is_moving_to_click = true

func _get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func _get_camera_flat_basis() -> Basis:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Basis.IDENTITY
	var forward := -cam.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := cam.global_basis.x
	right.y = 0
	right = right.normalized()
	return Basis(right, Vector3.UP, forward)

func _update_animation(is_moving: bool) -> void:
	if _anim_player == null:
		return
	var target_anim := "walk" if is_moving else "idle"
	if _anim_player.has_animation(target_anim) and _anim_player.current_animation != target_anim:
		_anim_player.play(target_anim)
