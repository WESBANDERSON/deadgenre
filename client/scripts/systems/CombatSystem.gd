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
const MELEE_RANGE    := 80.0   # pixels (~2.5 tiles)
const RANGED_RANGE   := 224.0  # pixels (~7 tiles)
const MAGIC_RANGE    := 192.0  # pixels (~6 tiles)

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
	if not target.is_active if target.has_meta("is_active") else false:
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
	match _attack_type:
		"ranged": return RANGED_RANGE
		"magic":  return MAGIC_RANGE
		_:        return MELEE_RANGE

func _get_cooldown() -> float:
	match _attack_type:
		"ranged": return RANGED_COOLDOWN
		"magic":  return MAGIC_COOLDOWN
		_:        return MELEE_COOLDOWN

func _play_attack_visual(target: Node) -> void:
	# Brief red flash on the target
	if target.has_method("modulate"):
		return
	var tween := target.create_tween()
	tween.tween_property(target, "modulate", Color(2, 0.5, 0.5), 0.05)
	tween.tween_property(target, "modulate", Color.WHITE, 0.15)

func _spawn_damage_number(position: Vector2, damage: int, is_crit: bool) -> void:
	# Damage numbers float upward and fade — implemented as a simple Label3D/Label
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
		_spawn_damage_number(target_node.global_position, damage, is_critical)
		var tween := target_node.create_tween()
		tween.tween_property(target_node, "modulate", Color(2, 0.6, 0.6), 0.05)
		tween.tween_property(target_node, "modulate", Color.WHITE, 0.2)

func _on_combat_entered(target: Node) -> void:
	_current_target = target

func _on_combat_exited() -> void:
	_current_target = null
	_auto_attack_active = false

func _on_entity_died(entity_id: int) -> void:
	if _current_target and _current_target.has_method("get_entity_id"):
		if _current_target.get_entity_id() == entity_id:
			stop_combat()
