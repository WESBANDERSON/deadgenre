## Player3D — Local + remote player as a billboard sprite in 2.5D world.
##
## CONTROLS:
##   WASD            → camera-relative direct movement
##   Left click      → click-to-move (legacy) or click-target
##   Right click     → context interact (attack mob, talk to NPC, gather node)
##   Tab             → cycle to next nearest hostile (acquires target)
##   Esc             → drop target
##   Enter / Space   → attack current target
##   F               → interact with closest interactable
##   1..8            → hotbar (existing)
##
## FEEL TARGETS:
##   - Instant facing change (no slow turn-rate)
##   - Linear accel/decel using lerp toward desired velocity
##   - Tab acquires within 18u radius, then cycles
##   - Click on enemy = target + auto-attack (mirrors OSRS / Dreadmyst)
##
## SERVER PROTOCOL:
##   We continue to send `move_player(x, y)` in 2D pixel coordinates so the
##   server schema is unchanged. World3D converts back when needed.
class_name Player3D
extends CharacterBody3D

const MOVE_SPEED      := 6.0   # 3D world units per second (≈ 192 px/s)
const ACCEL           := 28.0
const DECEL           := 32.0
const SYNC_RATE       := 0.1
const TAB_RANGE       := 18.0
const INTERACT_RANGE  := 3.0

var is_local_player: bool = false
var world: Node3D = null
var camera_ref: OrbitCamera3D = null

# ─────────────────────────────────────────────────────────────────────────────
# Server-synced State
# ─────────────────────────────────────────────────────────────────────────────
var player_identity: String = ""
var player_name: String = "Adventurer"
var player_class: String = "player_warrior"  # archetype for sprite selection
var health: int = 100
var max_health: int = 100
var mana: int = 50
var max_mana: int = 50
var level: int = 1

# ─────────────────────────────────────────────────────────────────────────────
# Movement
# ─────────────────────────────────────────────────────────────────────────────
var move_path: Array[Vector3] = []
var path_index: int = 0
var is_moving_along_path: bool = false
var movement_facing: Vector3 = Vector3.FORWARD
var _sync_timer: float = 0.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var name_label: Label3D = $NameLabel

func _ready() -> void:
	_setup_sprite()
	if name_label:
		name_label.text = player_name
	if not is_local_player:
		if sprite:
			sprite.modulate = Color(0.75, 0.75, 0.80)
		set_physics_process(false)
	_connect_signals()

func _setup_sprite() -> void:
	if sprite == null:
		return
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.pixel_size = 0.01
	sprite.shaded = true
	# Texture: prefer generated, else procedural
	var tex := SpriteFactory.try_load_generated("characters", player_class)
	if tex == null:
		tex = SpriteFactory.build_billboard(player_class, player_name)
	sprite.texture = tex
	sprite.scale = Vector3.ONE * 1.9

func _connect_signals() -> void:
	if is_local_player:
		EventBus.player_health_changed.connect(_on_health_changed)
		EventBus.player_mana_changed.connect(_on_mana_changed)

# ─────────────────────────────────────────────────────────────────────────────
# Input — local only
# ─────────────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:  _handle_left_click()
			MOUSE_BUTTON_RIGHT: _handle_right_click()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("target_next"):
			TabTargetingSystem.cycle_next()
		elif event.is_action("target_clear"):
			TabTargetingSystem.clear_target()
		elif event.is_action("attack_primary"):
			_attack_current_target()
		elif event.is_action("interact"):
			_interact_nearest()
		else:
			_handle_hotbar_input(event)

func _handle_hotbar_input(event: InputEventKey) -> void:
	for i in 8:
		if event.keycode == KEY_1 + i:
			EventBus.notification_shown.emit("Hotbar slot %d" % (i + 1), "info")
			break

func _handle_left_click() -> void:
	var hit := _raycast_under_cursor()
	if hit.is_empty():
		return
	if hit.has("entity"):
		var ent: Node = hit["entity"]
		# Clicking a mob = target + initiate combat; NPC = open
		if ent.has_method("get_entity_type"):
			var etype: String = ent.call("get_entity_type")
			if etype == "mob":
				TabTargetingSystem.set_target(ent)
				_attack_current_target()
				return
			elif etype == "npc":
				if ent.has_method("interact"):
					ent.call("interact")
				return
	# Otherwise: click-to-move
	if hit.has("position"):
		_request_move(hit["position"])

func _handle_right_click() -> void:
	var hit := _raycast_under_cursor()
	if hit.is_empty():
		return
	if hit.has("entity"):
		var ent: Node = hit["entity"]
		if ent.has_method("interact"):
			ent.call("interact")
		elif ent.has_method("get_entity_type") and ent.get_entity_type() == "mob":
			TabTargetingSystem.set_target(ent)
			_attack_current_target()

func _interact_nearest() -> void:
	var closest: Node = null
	var closest_d := INTERACT_RANGE
	for ent in get_tree().get_nodes_in_group("entities"):
		if not ent is Node3D:
			continue
		var d: float = global_position.distance_to(ent.global_position)
		if d < closest_d and ent.has_method("interact"):
			closest = ent
			closest_d = d
	if closest:
		closest.interact()

func _attack_current_target() -> void:
	var t := TabTargetingSystem.current_target
	if t == null or not is_instance_valid(t):
		return
	CombatSystem.request_attack(self, t)

func _raycast_under_cursor() -> Dictionary:
	var cam: Camera3D = camera_ref.get_camera() if camera_ref else null
	if cam == null:
		return {}
	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var dir  := cam.project_ray_normal(mouse_pos)

	# 1) Try to hit an entity first (entity hit-cylinders are at Y=0..2.5)
	var best_entity: Node = null
	var best_t := INF
	for ent in get_tree().get_nodes_in_group("entities"):
		if not ent is Node3D:
			continue
		var center: Vector3 = ent.global_position + Vector3.UP * 1.0
		# Ray–sphere test (sphere radius ~1.0)
		var oc := from - center
		var b := oc.dot(dir)
		var c := oc.dot(oc) - 1.0 * 1.0
		var disc := b * b - c
		if disc < 0:
			continue
		var t := -b - sqrt(disc)
		if t > 0 and t < best_t:
			best_t = t
			best_entity = ent
	if best_entity != null:
		return {"entity": best_entity, "position": from + dir * best_t}

	# 2) Hit the ground plane (Y = 0)
	if abs(dir.y) < 0.001:
		return {}
	var t_plane := -from.y / dir.y
	if t_plane <= 0:
		return {}
	return {"position": from + dir * t_plane}

# ─────────────────────────────────────────────────────────────────────────────
# Movement
# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
	var desired := _camera_relative_input()
	if desired.length_squared() > 0.01:
		# Direct WASD input cancels any active click-to-move path
		is_moving_along_path = false
		move_path.clear()
		_apply_acceleration(desired, delta)
		movement_facing = desired.normalized()
	elif is_moving_along_path:
		_advance_along_path(delta)
	else:
		_apply_acceleration(Vector3.ZERO, delta)

	move_and_slide()
	_emit_movement_signals(delta)

func _camera_relative_input() -> Vector3:
	var in_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var in_y := Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	if abs(in_x) < 0.05 and abs(in_y) < 0.05:
		return Vector3.ZERO
	var yaw := camera_ref.get_yaw() if camera_ref else 0.0
	# Forward in camera space = -Z; we project onto XZ plane.
	var forward := Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
	var right := Vector3(forward.z, 0.0, -forward.x).normalized()
	# Camera looks toward -Y, so "up" on screen (in_y < 0) is forward
	var dir := right * in_x - forward * in_y
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir * MOVE_SPEED

func _apply_acceleration(target_velocity: Vector3, delta: float) -> void:
	var rate := ACCEL if target_velocity.length() > 0.1 else DECEL
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	velocity.y = 0.0

func _advance_along_path(delta: float) -> void:
	if path_index >= move_path.size():
		is_moving_along_path = false
		_apply_acceleration(Vector3.ZERO, delta)
		return
	var target: Vector3 = move_path[path_index]
	var to_target := target - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist < 0.3:
		path_index += 1
		if path_index >= move_path.size():
			is_moving_along_path = false
			_apply_acceleration(Vector3.ZERO, delta)
			return
		target = move_path[path_index]
		to_target = target - global_position
		to_target.y = 0.0
	var dir := to_target.normalized()
	movement_facing = dir
	_apply_acceleration(dir * MOVE_SPEED, delta)

func _emit_movement_signals(delta: float) -> void:
	if velocity.length_squared() > 0.01 and world and world.has_method("world_to_pixel"):
		EventBus.player_moved.emit(world.world_to_pixel(global_position))
		_sync_timer -= delta
		if _sync_timer <= 0:
			_sync_timer = SYNC_RATE
			var p: Vector2 = world.world_to_pixel(global_position)
			NetworkManager.move_player(p.x, p.y)

func _request_move(target_world: Vector3) -> void:
	# Pathfinder operates on 2D pixel coordinates; convert and lift back.
	if world == null or not world.has_method("world_to_pixel"):
		move_path = [target_world]
		path_index = 0
		is_moving_along_path = true
		return
	var from_px: Vector2 = world.world_to_pixel(global_position)
	var to_px:   Vector2 = world.world_to_pixel(target_world)
	var px_path: Array = world.pathfinder.find_path(from_px, to_px)
	if px_path.is_empty():
		move_path = [target_world]
	else:
		move_path = []
		for px in px_path:
			move_path.append(world.pixel_to_world(px))
	path_index = 0
	is_moving_along_path = true

func cancel_movement() -> void:
	move_path.clear()
	is_moving_along_path = false
	velocity = Vector3.ZERO

# ─────────────────────────────────────────────────────────────────────────────
# Server State Application
# ─────────────────────────────────────────────────────────────────────────────
func apply_server_state(data: Dictionary) -> void:
	if data.has("health"):     health     = data.health
	if data.has("max_health"): max_health = data.max_health
	if data.has("mana"):       mana       = data.mana
	if data.has("max_mana"):   max_mana   = data.max_mana
	if data.has("level"):      level      = data.level
	if not is_local_player and data.has("pos_x") and data.has("pos_y"):
		var server_world := Vector3(
				data.pos_x / 32.0,
				0.0,
				data.pos_y / 32.0)
		global_position = global_position.lerp(server_world, 0.25)

func _on_health_changed(_player: Node, current: int, maximum: int) -> void:
	health = current
	max_health = maximum

func _on_mana_changed(_player: Node, current: int, maximum: int) -> void:
	mana = current
	max_mana = maximum

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	EventBus.player_health_changed.emit(self, health, max_health)
	if health <= 0:
		EventBus.player_died.emit(self)

# ─────────────────────────────────────────────────────────────────────────────
# Compatibility shims used by 2D-era systems
# ─────────────────────────────────────────────────────────────────────────────
## CombatSystem currently reads `global_position` as Vector2 in some legacy
## paths; expose a 2D helper for those call sites.
func get_pixel_position() -> Vector2:
	if world and world.has_method("world_to_pixel"):
		return world.world_to_pixel(global_position)
	return Vector2(global_position.x * 32.0, global_position.z * 32.0)
