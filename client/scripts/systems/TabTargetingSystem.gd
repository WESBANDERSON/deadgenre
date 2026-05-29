## TabTargetingSystem — Server-agnostic tab-target manager.
##
## RESPONSIBILITY:
##   - Track the local player's currently selected target
##   - Cycle through "in-range, hostile, alive" entities sorted by distance
##   - Apply the visual "targeted" state on the previous and new target nodes
##   - Emit EventBus signals so UI/combat can react
##
## TIER 0 (this file):
##   - Hostiles only (entity_type == "mob")
##   - Within MAX_RANGE world units of the local player
##   - Tab key cycles; Esc clears
##
## TIER 1 EXPANSION:
##   - Friendly targeting (party / heals)
##   - "Smart target" priority (lowest health, last attacker, etc.)
##   - Soft target previews on hover
extends Node

const MAX_RANGE := 25.0

signal target_changed(new_target: Node, previous: Node)

var current_target: Node = null
var _last_cycle_index: int = -1

func _ready() -> void:
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.local_player_respawned.connect(func(_p): clear_target())

func set_target(node: Node) -> void:
	if node == current_target:
		return
	var prev := current_target
	if prev and is_instance_valid(prev) and prev.has_method("set_targeted"):
		prev.set_targeted(false)
	current_target = node
	if current_target and current_target.has_method("set_targeted"):
		current_target.set_targeted(true)
	target_changed.emit(current_target, prev)
	if current_target and current_target.has_method("get_entity_id"):
		EventBus.combat_entered.emit(current_target)

func clear_target() -> void:
	if current_target == null:
		return
	var prev := current_target
	if prev and is_instance_valid(prev) and prev.has_method("set_targeted"):
		prev.set_targeted(false)
	current_target = null
	target_changed.emit(null, prev)
	EventBus.combat_exited.emit()

## Cycle to the next valid hostile target ordered by distance.
func cycle_next() -> void:
	var player := GameManager.local_player
	if player == null:
		return
	var candidates := _gather_candidates(player)
	if candidates.is_empty():
		clear_target()
		return

	# Find current index, advance by one
	var idx := -1
	for i in candidates.size():
		if candidates[i] == current_target:
			idx = i
			break
	idx = (idx + 1) % candidates.size()
	set_target(candidates[idx])

func _gather_candidates(player: Node) -> Array:
	var result: Array = []
	for ent in get_tree().get_nodes_in_group("entities"):
		if ent == null or not is_instance_valid(ent):
			continue
		if not ent.has_method("get_entity_type"):
			continue
		if ent.get_entity_type() != "mob":
			continue
		if "is_active" in ent and not ent.is_active:
			continue
		var d: float = player.global_position.distance_to(ent.global_position)
		if d > MAX_RANGE:
			continue
		result.append({"node": ent, "dist": d})
	result.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var nodes: Array = []
	for r in result:
		nodes.append(r["node"])
	return nodes

func _on_entity_died(entity_id: int) -> void:
	if current_target and current_target.has_method("get_entity_id"):
		if current_target.get_entity_id() == entity_id:
			clear_target()
