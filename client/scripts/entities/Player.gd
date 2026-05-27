## Player — Handles both the local player and remote players in the same node.
##
## is_local_player = true   → processes mouse input, runs pathfinding, syncs to server
## is_local_player = false  → receives server state, interpolates position visually
##
## CLICK-TO-MOVE FLOW:
##   Left click  → move to world position (A* pathfinding via World.pathfinder)
##   Right click → interact with entity under cursor (context-sensitive)
##
## VISUAL UPGRADE PATH:
##   Replace _draw() with an AnimatedSprite2D node pointing to a generated sprite
##   sheet. The movement_direction and is_moving variables drive animation state.
##
## EXTENSION POINTS:
##   _handle_hotbar_input() → abilities, spells, item use
##   apply_server_state()   → extend when new fields are added to the player table
class_name Player
extends CharacterBody2D

const TILE_SIZE   := 32
const MOVE_SPEED  := 160.0
const SYNC_RATE   := 0.1   # seconds between position syncs to server

## Set by World when spawning this node.
var is_local_player: bool = false
var world: Node = null      # Reference to the World node (for pathfinder access)

# ─────────────────────────────────────────────────────────────────────────────
# Server-synced State
# ─────────────────────────────────────────────────────────────────────────────
var player_identity: String = ""
var player_name: String = "Adventurer"
var health: int = 100
var max_health: int = 100
var mana: int = 50
var max_mana: int = 50
var level: int = 1

# ─────────────────────────────────────────────────────────────────────────────
# Movement State
# ─────────────────────────────────────────────────────────────────────────────
var move_path: Array[Vector2] = []
var path_index: int = 0
var is_moving: bool = false
var movement_direction: Vector2 = Vector2.DOWN  # used for sprite facing
var _sync_timer: float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Visual
# ─────────────────────────────────────────────────────────────────────────────
var body_color: Color = Color(0.35, 0.55, 0.90)  # Local player: blue. Overridden for remotes.
var _move_indicator: Vector2 = Vector2.ZERO       # Click destination dot

@onready var name_label: Label = $NameLabel

func _ready() -> void:
	name_label.text = player_name
	# Remote players get a desaturated color so the local player stands out
	if not is_local_player:
		body_color = Color(0.55, 0.55, 0.55)
	_connect_signals()

func _connect_signals() -> void:
	if is_local_player:
		EventBus.player_health_changed.connect(_on_health_changed)
		EventBus.player_mana_changed.connect(_on_mana_changed)

# ─────────────────────────────────────────────────────────────────────────────
# Input — local player only
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not is_local_player:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_handle_left_click(get_global_mouse_position())
			MOUSE_BUTTON_RIGHT:
				_handle_right_click(get_global_mouse_position())

	if event is InputEventKey and event.pressed and not event.echo:
		_handle_hotbar_input(event)

func _handle_left_click(world_pos: Vector2) -> void:
	# Check if clicking on an entity first (interaction)
	var entities := get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if entity.has_method("get_entity_id"):
			var dist := global_position.distance_to(entity.global_position)
			if dist < 20.0:  # 20px hit radius
				EventBus.entity_clicked.emit(entity.get_entity_id(), entity)
				return

	# Otherwise: move to clicked position
	_request_move(world_pos)

func _handle_right_click(_world_pos: Vector2) -> void:
	pass  # Context menu or secondary action — extend here

func _handle_hotbar_input(event: InputEventKey) -> void:
	# Map number keys 1–8 to hotbar slots
	for i in 8:
		if event.keycode == KEY_1 + i:
			EventBus.notification_shown.emit("Hotbar slot %d" % (i + 1), "info")
			break

# ─────────────────────────────────────────────────────────────────────────────
# Movement
# ─────────────────────────────────────────────────────────────────────────────
func _request_move(target_world: Vector2) -> void:
	if world == null or not world.has_method("world_to_tile"):
		# Fallback: direct movement without pathfinding
		move_path = [target_world]
		path_index = 0
		is_moving = true
		_move_indicator = target_world
		queue_redraw()
		return

	var path := world.pathfinder.find_path(global_position, target_world)
	if path.is_empty():
		# Target tile might be solid; try moving toward it anyway
		path = [target_world]

	move_path  = path
	path_index = 0
	is_moving  = true
	_move_indicator = target_world
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_local_player:
		_process_movement(delta)
		_process_position_sync(delta)
	else:
		# Remote players are smoothly interpolated, not physics-driven
		pass

func _process_movement(delta: float) -> void:
	if not is_moving or path_index >= move_path.size():
		is_moving = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target := move_path[path_index]
	var dist   := global_position.distance_to(target)

	if dist < 4.0:
		path_index += 1
		if path_index >= move_path.size():
			is_moving = false
			velocity = Vector2.ZERO
			global_position = target
			EventBus.player_moved.emit(global_position)
			queue_redraw()
			return
		target = move_path[path_index]

	var dir    := global_position.direction_to(target)
	velocity    = dir * MOVE_SPEED
	movement_direction = dir
	move_and_slide()
	EventBus.player_moved.emit(global_position)
	queue_redraw()

func _process_position_sync(delta: float) -> void:
	_sync_timer -= delta
	if _sync_timer <= 0 and is_moving:
		_sync_timer = SYNC_RATE
		NetworkManager.move_player(global_position.x, global_position.y)

# ─────────────────────────────────────────────────────────────────────────────
# Visual — Programmatic placeholder; replace with AnimatedSprite2D when ready
# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	# Body circle
	draw_circle(Vector2.ZERO, 11.0, body_color)
	# Outline
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.5)

	# Direction nub — shows facing direction
	if is_moving:
		var nub_pos := movement_direction.normalized() * 13.0
		draw_circle(nub_pos, 3.5, Color.WHITE * 0.9)

	# Level indicator badge
	if is_local_player:
		draw_circle(Vector2(11, -9), 5.0, Color(1.0, 0.85, 0.0))

	# Move indicator — small pulsing dot at click destination
	if is_local_player and is_moving:
		var local_target := _move_indicator - global_position
		draw_circle(local_target, 3.0, Color(1, 1, 0, 0.6))
		draw_arc(local_target, 5.0, 0.0, TAU, 12, Color(1, 1, 0, 0.3), 1.0)

# ─────────────────────────────────────────────────────────────────────────────
# Server State Application
# ─────────────────────────────────────────────────────────────────────────────

## Called by NetworkManager when the server updates this player's row.
func apply_server_state(data: Dictionary) -> void:
	if data.has("health"):     health     = data.health
	if data.has("max_health"): max_health = data.max_health
	if data.has("mana"):       mana       = data.mana
	if data.has("max_mana"):   max_mana   = data.max_mana
	if data.has("level"):      level      = data.level

	if not is_local_player and data.has("pos_x") and data.has("pos_y"):
		var server_pos := Vector2(data.pos_x, data.pos_y)
		global_position = global_position.lerp(server_pos, 0.25)

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
