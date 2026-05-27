## NPC — Friendly non-player characters: merchants, quest givers, crafting stations.
##
## NPCs are interactable. Clicking opens their dialogue or service panel.
## Extend this for specific NPC types.
class_name NPC
extends Entity

var dialogue_lines: Array[String] = []
var service_type: String = ""  # "merchant" | "banker" | "trainer" | "craftsman"

func _on_initialized() -> void:
	add_to_group("entities")
	show_healthbar = false
	_configure_from_subtype()

func _configure_from_subtype() -> void:
	match subtype:
		"merchant_alice":
			body_color    = Color(0.90, 0.75, 0.30)
			body_radius   = 10.0
			service_type  = "merchant"
			dialogue_lines = [
				"Welcome, traveler! Browse my wares.",
				"I've got supplies fresh from the capital.",
				"Safe travels — the goblins are restless today.",
			]
		"resource_oak_tree":
			body_color    = Color(0.25, 0.55, 0.15)
			body_radius   = 14.0
			service_type  = "gathering"
			label_text    = "Oak Tree"
		"resource_copper":
			body_color    = Color(0.65, 0.40, 0.25)
			body_radius   = 11.0
			service_type  = "gathering"
			label_text    = "Copper Vein"
		"resource_fish_spot":
			body_color    = Color(0.20, 0.50, 0.80)
			body_radius   = 8.0
			service_type  = "gathering"
			label_text    = "Fishing Spot"
		_:
			body_color  = Color(0.85, 0.85, 0.60)
			body_radius = 10.0

func _draw() -> void:
	# Friendly NPCs get a slightly different shape (diamond-top indicator)
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)

	# Interaction indicator: small yellow triangle above
	var tri := PackedVector2Array([
		Vector2(0, -body_radius - 10),
		Vector2(-5, -body_radius - 4),
		Vector2(5, -body_radius - 4),
	])
	draw_colored_polygon(tri, PackedColorArray([Color(1.0, 0.9, 0.1), Color(1.0, 0.9, 0.1), Color(1.0, 0.9, 0.1)]))

func _on_interact() -> void:
	match service_type:
		"merchant":
			EventBus.panel_toggle_requested.emit("merchant")
			if dialogue_lines.size() > 0:
				EventBus.notification_shown.emit(dialogue_lines.pick_random(), "info")
		"gathering":
			NetworkManager.use_skill("gathering", entity_id)
			EventBus.notification_shown.emit("You gather from the " + label_text + ".", "info")
		_:
			if dialogue_lines.size() > 0:
				EventBus.notification_shown.emit(dialogue_lines.pick_random(), "info")
