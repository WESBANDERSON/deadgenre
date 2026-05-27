## Mob — Base class for hostile entities (goblins, creatures, bosses).
##
## Mobs are clickable for combat. Extend this for specific mob types,
## overriding _setup_visual() and any custom behavior.
##
## ADDING A NEW MOB:
##   1. Create YourMob.gd extending Mob
##   2. Override body_color and any stats
##   3. Override _on_interact() if the mob has special mechanics
##   4. Register in World._preload_entity_scenes() with its subtype key
class_name Mob
extends Entity

func _on_initialized() -> void:
	add_to_group("entities")
	_configure_from_subtype()

func _configure_from_subtype() -> void:
	match subtype:
		"goblin":
			body_color  = Color(0.25, 0.65, 0.25)
			body_radius = 9.0
			max_health  = 40
			health      = 40
		"goblin_shaman":
			body_color  = Color(0.20, 0.50, 0.20)
			body_radius = 9.0
			max_health  = 60
			health      = 60
		_:
			body_color  = Color(0.70, 0.20, 0.20)
			body_radius = 10.0

func _draw() -> void:
	if not is_active:
		return
	# Body
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 1.5)

	# Health bar drawn above the mob
	if show_healthbar and max_health > 0:
		var bar_w  := body_radius * 2.2
		var bar_h  := 3.0
		var bar_y  := -body_radius - 7.0
		var ratio  := float(health) / float(max_health)
		var bg_color   := Color(0.2, 0.2, 0.2, 0.8)
		var fill_color := Color(0.9, 0.15, 0.15).lerp(Color(0.1, 0.9, 0.1), ratio)
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), bg_color)
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * ratio, bar_h), fill_color)

func _on_interact() -> void:
	if not is_active:
		return
	EventBus.combat_entered.emit(self)
	CombatSystem.request_attack(GameManager.local_player, self)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_interact()

func _on_entity_health_changed(eid: int, current: int, maximum: int) -> void:
	super._on_entity_health_changed(eid, current, maximum)
	if eid == entity_id:
		queue_redraw()
