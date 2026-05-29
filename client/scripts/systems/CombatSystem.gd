## CombatSystem — Client-side combat orchestration.
##
## Validates range and cooldown on the client before sending to the server.
## Server revalidates everything and is authoritative on damage.
## Client shows optimistic feedback (hit flash, damage numbers) immediately.
##
## Usage:
##   CombatSystem.request_attack(player_node, target_entity_node)
##
## ADDING NEW ATTACK TYPES:
##   Add a new method following the pattern of request_attack.
##   Each attack type may have different range, cooldown, and visual feedback.
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────
# Ranges are expressed in TILES. The world adapter converts to its own units
# (1 px == 1/32 tile in the 2D world, 1 unit == 1 tile in the 2.5D World3D).
const MELEE_RANGE_TILES  := 2.5
const RANGED_RANGE_TILES := 7.0
const MAGIC_RANGE_TILES  := 6.0

const MELEE_COOLDOWN  := 2.0   # seconds
const RANGED_COOLDOWN := 1.8
const MAGIC_COOLDOWN  := 2.5

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
var _last_attack_time: float = -999.0
var _attack_type: String = "melee"  # "melee" | "ranged" | "magic"
var _current_target: Node = null
var _auto_attack_active: bool = false

## Floating damage number scene (instantiated per hit)
var _damage_label_scene: PackedScene = null

func _ready() -> void:
	EventBus.combat_hit.connect(_on_combat_hit)
	EventBus.combat_entered.connect(_on_combat_entered)
	EventBus.combat_exited.connect(_on_combat_exited)
	EventBus.entity_died.connect(_on_entity_died)

func _process(delta: float) -> void:
	# Auto-attack: keep attacking the current target until it dies or moves out of range
	if not _auto_attack_active or _current_target == null:
		return
	var player := GameManager.local_player
	if player == null:
		return
	var dist := player.global_position.distance_to(_current_target.global_position)
	if dist > _get_range():
		return  # Player must move closer; movement is handled by Player.gd
	var cooldown := _get_cooldown()
	if Time.get_ticks_msec() / 1000.0 - _last_attack_time >= cooldown:
		_send_attack(_current_target)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Initiate combat with an entity. Begins the auto-attack loop.
func request_attack(player: Node, target: Node) -> void:
	if not target.has_method("get_entity_id"):
		return
	if "is_active" in target and not target.is_active:
		return
	_current_target = target
	_auto_attack_active = true
	# Immediate first attack if off cooldown
	var dist := player.global_position.distance_to(target.global_position)
	if dist <= _get_range():
		_send_attack(target)

## Stop auto-attacking.
func stop_combat() -> void:
	_auto_attack_active = false
	_current_target = null
	EventBus.combat_exited.emit()

## Set the active attack style (determines range and cooldown).
func set_attack_type(type: String) -> void:
	assert(type in ["melee", "ranged", "magic"], "Unknown attack type: " + type)
	_attack_type = type

# ─────────────────────────────────────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────────────────────────────────────
func _send_attack(target: Node) -> void:
	_last_attack_time = Time.get_ticks_msec() / 1000.0
	NetworkManager.attack_entity(target.get_entity_id())
	_play_attack_visual(target)

func _get_range() -> float:
	# Return range in the active world's distance units.
	#   2D World      → 1 tile == 32 px, so multiply tiles by 32.
	#   2.5D World3D  → 1 tile == 1 unit, so use tiles directly.
	var upt := 32.0
	if GameManager.world and GameManager.world.has_method("units_per_tile"):
		upt = GameManager.world.units_per_tile()
	match _attack_type:
		"ranged": return RANGED_RANGE_TILES * upt
		"magic":  return MAGIC_RANGE_TILES  * upt
		_:        return MELEE_RANGE_TILES  * upt

func _get_cooldown() -> float:
	match _attack_type:
		"ranged": return RANGED_COOLDOWN
		"magic":  return MAGIC_COOLDOWN
		_:        return MELEE_COOLDOWN

func _play_attack_visual(target: Node) -> void:
	# Brief red flash on the target — works for Sprite2D/Sprite3D children alike
	if target == null:
		return
	var flash_target: Object = target
	if target is Node3D and target.has_node("Sprite3D"):
		flash_target = target.get_node("Sprite3D")
	if not "modulate" in flash_target:
		return
	var tween := target.create_tween()
	tween.tween_property(flash_target, "modulate", Color(2, 0.5, 0.5), 0.05)
	tween.tween_property(flash_target, "modulate", Color.WHITE, 0.15)

func _spawn_damage_number_2d(position: Vector2, damage: int, is_crit: bool) -> void:
	var label := Label.new()
	label.text = ("CRIT! " if is_crit else "") + str(damage)
	label.add_theme_color_override("font_color", Color.ORANGE_RED if not is_crit else Color.YELLOW)
	label.add_theme_font_size_override("font_size", 16 if not is_crit else 22)
	label.global_position = position + Vector2(-15, -20)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y - 50, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)

func _spawn_damage_number_3d(parent: Node3D, damage: int, is_crit: bool) -> void:
	var label := Label3D.new()
	label.text = ("CRIT! " if is_crit else "") + str(damage)
	label.modulate = Color.YELLOW if is_crit else Color.ORANGE_RED
	label.font_size = 64 if is_crit else 48
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 2.4, 0)
	label.pixel_size = 0.006
	get_tree().current_scene.add_child(label)
	label.global_position = parent.global_position + Vector3(0, 2.4, 0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y",
			label.global_position.y + 1.6, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)

func _spawn_damage_number(target_node: Node, damage: int, is_crit: bool) -> void:
	if target_node is Node3D:
		_spawn_damage_number_3d(target_node, damage, is_crit)
	elif target_node is Node2D:
		_spawn_damage_number_2d(target_node.global_position, damage, is_crit)

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_combat_hit(attacker_id: String, target_id: String, damage: int, is_critical: bool) -> void:
	if not GameManager.settings.get("show_damage_numbers", true):
		return
	# Find the target node and spawn the damage float
	var world := GameManager.world
	if world == null:
		return
	var target_node: Node = null
	if attacker_id == "local_player" or attacker_id == GameManager.session_identity:
		var tid := int(target_id)
		if world.entity_nodes.has(tid):
			target_node = world.entity_nodes[tid]
	if target_node:
		_spawn_damage_number(target_node, damage, is_critical)
		# Hit-flash works for either 2D (modulate) or 3D entities (sprite modulate)
		var flash_target: Object = target_node
		if target_node is Node3D and target_node.has_node("Sprite3D"):
			flash_target = target_node.get_node("Sprite3D")
		if "modulate" in flash_target:
			var tween := target_node.create_tween()
			tween.tween_property(flash_target, "modulate", Color(2, 0.6, 0.6), 0.05)
			tween.tween_property(flash_target, "modulate", Color.WHITE, 0.2)

func _on_combat_entered(target: Node) -> void:
	_current_target = target

func _on_combat_exited() -> void:
	_current_target = null
	_auto_attack_active = false

func _on_entity_died(entity_id: int) -> void:
	if _current_target and _current_target.has_method("get_entity_id"):
		if _current_target.get_entity_id() == entity_id:
			stop_combat()
