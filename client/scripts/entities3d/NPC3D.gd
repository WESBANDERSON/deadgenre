## NPC3D — Friendly billboard NPC. Right-click / interact opens dialogue.
class_name NPC3D
extends Entity3D

var dialogue_lines: Array[String] = []
var service_type: String = ""

func _on_initialized() -> void:
	show_healthbar = false
	is_targetable = false
	_configure_from_subtype()
	_set_billboard_texture(_archetype_for_subtype(), subtype)

func _configure_from_subtype() -> void:
	match subtype:
		"merchant_alice":
			service_type = "merchant"
			label_text = "Merchant Alice"
			sprite_scale = 1.8
			dialogue_lines = [
				"Welcome to the misted hollow. Hands warm yet?",
				"The fog hides things best forgotten. Don't wander far.",
				"I've gear that won't crumble at the first wraith's touch.",
			]
		"resource_oak_tree", "oak_tree":
			service_type = "gathering"
			label_text = "Twisted Oak"
			sprite_scale = 2.4
		"resource_copper", "copper_vein":
			service_type = "gathering"
			label_text = "Copper Vein"
			sprite_scale = 1.4
		"resource_fish_spot", "fish_spot":
			service_type = "gathering"
			label_text = "Fishing Pool"
			sprite_scale = 1.2
		_:
			sprite_scale = 1.8
	if sprite:
		sprite.scale = Vector3.ONE * sprite_scale

func _archetype_for_subtype() -> String:
	if subtype.begins_with("resource_oak") or subtype == "oak_tree":
		return "oak_tree"
	if subtype.begins_with("resource_copper") or subtype == "copper_vein":
		return "copper_vein"
	if subtype.begins_with("resource_fish") or subtype == "fish_spot":
		return "fish_spot"
	if subtype == "merchant_alice":
		return "merchant_alice"
	return "npc"

func interact() -> void:
	match service_type:
		"merchant":
			EventBus.dialogue_started.emit(subtype)
		"gathering":
			NetworkManager.use_skill("gathering", entity_id)
			EventBus.notification_shown.emit(
					"You gather from the %s." % label_text, "info")
		_:
			if subtype != "":
				EventBus.dialogue_started.emit(subtype)
			elif dialogue_lines.size() > 0:
				EventBus.notification_shown.emit(
						dialogue_lines.pick_random(), "info")
