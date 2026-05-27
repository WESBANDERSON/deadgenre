## SkillSystem — Client-side skill tracking and level-up display.
##
## The server is authoritative on all XP values.
## This system:
##   - Caches current skill levels from server subscription
##   - Computes derived values (level, xp-to-next) for UI
##   - Triggers level-up visual effects
##
## ADDING A NEW SKILL:
##   1. Add it to SKILL_NAMES (must match server skill name exactly)
##   2. Add an icon path in SKILL_ICONS (leave "" until generated)
##   3. Server handles XP grant in reducers — no client change needed for XP logic
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Skill Definitions — must match server skill names exactly
# ─────────────────────────────────────────────────────────────────────────────
const SKILL_NAMES: Array[String] = [
	"melee", "ranged", "magic", "defense",
	"health", "crafting", "gathering", "agility"
]

const SKILL_ICONS: Dictionary = {
	"melee":     "res://assets/sprites/ui/skill_melee.png",
	"ranged":    "res://assets/sprites/ui/skill_ranged.png",
	"magic":     "res://assets/sprites/ui/skill_magic.png",
	"defense":   "res://assets/sprites/ui/skill_defense.png",
	"health":    "res://assets/sprites/ui/skill_health.png",
	"crafting":  "res://assets/sprites/ui/skill_crafting.png",
	"gathering": "res://assets/sprites/ui/skill_gathering.png",
	"agility":   "res://assets/sprites/ui/skill_agility.png",
}

const SKILL_COLORS: Dictionary = {
	"melee":     Color(0.85, 0.25, 0.25),
	"ranged":    Color(0.25, 0.75, 0.35),
	"magic":     Color(0.40, 0.40, 0.95),
	"defense":   Color(0.75, 0.65, 0.20),
	"health":    Color(0.90, 0.30, 0.40),
	"crafting":  Color(0.70, 0.50, 0.25),
	"gathering": Color(0.45, 0.70, 0.30),
	"agility":   Color(0.30, 0.80, 0.80),
}

# ─────────────────────────────────────────────────────────────────────────────
# State
# ─────────────────────────────────────────────────────────────────────────────
## skill_name -> { "level": int, "experience": int }
var skills: Dictionary = {}

func _ready() -> void:
	# Initialize all skills at level 1 / 0 XP
	for skill in SKILL_NAMES:
		skills[skill] = {"level": 1, "experience": 0}
	EventBus.player_skill_leveled.connect(_on_skill_leveled)
	EventBus.player_xp_gained.connect(_on_xp_gained)

# ─────────────────────────────────────────────────────────────────────────────
# XP Math — mirrors server formula exactly: level = floor(1 + sqrt(xp / 50))
# ─────────────────────────────────────────────────────────────────────────────
static func xp_for_level(level: int) -> int:
	return int(pow(level - 1, 2) * 50)

static func xp_to_level(xp: int) -> int:
	return int(1.0 + sqrt(float(xp) / 50.0))

## XP needed to reach the next level from current total XP.
static func xp_to_next(current_xp: int) -> int:
	var current_level := xp_to_level(current_xp)
	return xp_for_level(current_level + 1) - current_xp

## 0.0–1.0 progress toward the next level.
static func level_progress(current_xp: int) -> float:
	var current_level := xp_to_level(current_xp)
	var xp_this_level := current_xp - xp_for_level(current_level)
	var xp_span       := xp_for_level(current_level + 1) - xp_for_level(current_level)
	if xp_span <= 0:
		return 1.0
	return float(xp_this_level) / float(xp_span)

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────
func get_level(skill: String) -> int:
	return skills.get(skill, {}).get("level", 1)

func get_xp(skill: String) -> int:
	return skills.get(skill, {}).get("experience", 0)

func get_progress(skill: String) -> float:
	return level_progress(get_xp(skill))

func get_icon(skill: String) -> Texture2D:
	var path: String = SKILL_ICONS.get(skill, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null  # HUD draws a fallback colored square

func get_color(skill: String) -> Color:
	return SKILL_COLORS.get(skill, Color.GRAY)

# ─────────────────────────────────────────────────────────────────────────────
# Event Handlers
# ─────────────────────────────────────────────────────────────────────────────
func _on_xp_gained(skill: String, _amount: int, new_total: int) -> void:
	if not skills.has(skill):
		skills[skill] = {}
	skills[skill]["experience"] = new_total
	skills[skill]["level"] = xp_to_level(new_total)
	GameManager.player_skills[skill] = skills[skill].duplicate()

func _on_skill_leveled(skill: String, new_level: int) -> void:
	if not skills.has(skill):
		skills[skill] = {}
	var old_level: int = skills[skill].get("level", 1)
	skills[skill]["level"] = new_level

	if new_level > old_level:
		_play_levelup_effect(skill, new_level)

func _play_levelup_effect(skill: String, new_level: int) -> void:
	var msg := "%s level up! Now level %d." % [skill.capitalize(), new_level]
	EventBus.notification_shown.emit(msg, "info")
	# The HUD will briefly show a level-up banner; it listens for player_skill_leveled
