## Prop3D — Static decoration billboard (trees, rocks, pillars).
##
## Props are seeded by World3D when chunks load and do not synchronize with
## the server. They exist purely to add visual density to the Dreadmyst world.
##
## Trees and ore veins that are gatherable arrive separately as NPC3D entities
## from the server; this Prop3D variant is decoration only and is not
## interactable, ensuring no confusion with server-authoritative resources.
class_name Prop3D
extends Node3D

@onready var sprite: Sprite3D = $Sprite3D

var subtype: String = ""

func setup(sub: String) -> void:
	subtype = sub
	_setup_sprite()

func _setup_sprite() -> void:
	if sprite == null:
		return
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.pixel_size = 0.01
	sprite.shaded = true
	# Slight scale variation so the world doesn't feel stamped
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("prop:%s:%v" % [subtype, global_position])
	var s := 1.0 + (rng.randf() - 0.5) * 0.25
	var scale_base: float = 2.4 if subtype == "oak_tree" else 1.6
	sprite.scale = Vector3.ONE * scale_base * s
	# Texture: prefer generated, fall back to procedural
	var tex := SpriteFactory.try_load_generated("props", subtype)
	if tex == null:
		tex = SpriteFactory.build_billboard(subtype, "deco_%d" % rng.randi())
	sprite.texture = tex
