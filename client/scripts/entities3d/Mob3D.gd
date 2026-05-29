## Mob3D — Hostile entity rendered as a Dreadmyst-styled billboard.
##
## Extends Entity3D. Configures stats and visuals by `subtype`. Right-click
## or Tab-target → Enter triggers an auto-attack via CombatSystem.
class_name Mob3D
extends Entity3D

func _on_initialized() -> void:
	is_targetable = true
	_configure_from_subtype()
	_set_billboard_texture(_archetype_for_subtype(), subtype)

func _configure_from_subtype() -> void:
	match subtype:
		"goblin":
			max_health = 40
			sprite_scale = 1.6
		"goblin_shaman":
			max_health = 60
			sprite_scale = 1.7
		"skeleton":
			max_health = 50
			sprite_scale = 1.8
		"wolf":
			max_health = 30
			sprite_scale = 1.4
		"dread_wraith":
			max_health = 80
			sprite_scale = 2.0
		_:
			max_health = 50
			sprite_scale = 1.8
	health = max_health
	if sprite:
		sprite.scale = Vector3.ONE * sprite_scale

func _archetype_for_subtype() -> String:
	if subtype in ["goblin", "goblin_shaman", "skeleton", "wolf", "dread_wraith"]:
		return subtype
	return "goblin"

func interact() -> void:
	if not is_active:
		return
	EventBus.combat_entered.emit(self)
	CombatSystem.request_attack(GameManager.local_player, self)
