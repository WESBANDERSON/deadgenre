## Client-side skill tracking. Mirrors player_skill rows from SpacetimeDB.
## Computes levels using the same quadratic formula as the server.
extends Node

var skills: Dictionary = {}  # skill_id -> {level, xp, max_level, base_xp}

func _ready() -> void:
	_init_from_content()
	EventBus.skill_xp_gained.connect(_on_xp_gained)

func _init_from_content() -> void:
	for skill_id in ContentDB.skills:
		var def: Dictionary = ContentDB.skills[skill_id]
		skills[skill_id] = {
			"level": 1,
			"xp": 0,
			"max_level": def.get("max_level", 99),
			"base_xp": def.get("base_xp", 100),
		}

func get_level(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id]["level"]
	return 0

func get_xp(skill_id: String) -> int:
	if skills.has(skill_id):
		return skills[skill_id]["xp"]
	return 0

func get_xp_for_next_level(skill_id: String) -> int:
	if not skills.has(skill_id):
		return 0
	var s: Dictionary = skills[skill_id]
	var next_level: int = s["level"] + 1
	return s["base_xp"] * next_level * next_level

func grant_xp(skill_id: String, amount: int) -> void:
	if not skills.has(skill_id):
		return
	var s: Dictionary = skills[skill_id]
	s["xp"] += amount
	var new_level := _compute_level(s["xp"], s["base_xp"])
	if new_level > s["level"] and new_level <= s["max_level"]:
		s["level"] = new_level
		EventBus.skill_leveled_up.emit(skill_id, new_level)
	skills[skill_id] = s

func _compute_level(xp: int, base_xp: int) -> int:
	if base_xp <= 0:
		return 1
	var level := 1
	var threshold := base_xp
	while xp >= threshold:
		level += 1
		threshold = base_xp * level * level
	return level

func _on_xp_gained(skill_id: String, amount: int) -> void:
	grant_xp(skill_id, amount)
