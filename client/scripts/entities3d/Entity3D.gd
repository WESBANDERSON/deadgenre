## Entity3D — Base class for all in-world billboarded entities.
##
## ROLE:
##   Visible enemy / NPC / prop in the 2.5D Dreadmyst world. Renders as a
##   Sprite3D billboard with a Y-billboard mode (always faces the camera on
##   the horizontal plane) and an attached ground reticle slot used by the
##   tab-targeting system.
##
## HOW THIS REPLACES Entity.gd:
##   The 2D base class uses Node2D + draw(); this one uses Node3D + Sprite3D.
##   Both speak the same EventBus protocol so combat / damage / death code
##   works without modification.
class_name Entity3D
extends Node3D

# ─────────────────────────────────────────────────────────────────────────────
# Server State
# ─────────────────────────────────────────────────────────────────────────────
var entity_id:   int    = -1
var entity_type: String = ""
var subtype:     String = ""

var health:      int  = 100
var max_health:  int  = 100
var is_active:   bool = true

# ─────────────────────────────────────────────────────────────────────────────
# Visual Config — override in subclasses
# ─────────────────────────────────────────────────────────────────────────────
var sprite_scale: float = 2.0
var sprite_y_offset: float = 0.0   # billboard root height
var label_text: String = ""
var show_healthbar: bool = true
var is_targetable: bool = false

@onready var sprite: Sprite3D = $Sprite3D
@onready var hover_label: Label3D = $HoverLabel
@onready var health_bar: MeshInstance3D = $HealthBar if has_node("HealthBar") else null

var _current_target_ring: MeshInstance3D = null

func _ready() -> void:
	_setup_sprite()
	_connect_signals()
	if hover_label:
		hover_label.text = label_text if label_text != "" else subtype.replace("_", " ").capitalize()
	if health_bar:
		_update_health_bar_visual()

func _connect_signals() -> void:
	EventBus.entity_health_changed.connect(_on_entity_health_changed)
	EventBus.entity_died.connect(_on_entity_died_signal)

func initialize(id: int, type: String, sub: String) -> void:
	entity_id   = id
	entity_type = type
	subtype     = sub
	_on_initialized()
	# Add to global "entities" group so picker/targeting can find us
	add_to_group("entities")

func _on_initialized() -> void:
	pass

## Override or extend to swap textures per subtype.
func _setup_sprite() -> void:
	if sprite == null:
		return
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.fixed_size = false
	sprite.no_depth_test = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.pixel_size = 0.01
	sprite.shaded = true

func _set_billboard_texture(archetype: String, sub: String = "") -> void:
	# Prefer AI-generated asset, else fallback to procedural sprite
	var category := "characters"
	if archetype.begins_with("oak_tree") or archetype.begins_with("stone_pillar") \
			or archetype.begins_with("copper_vein") or archetype.begins_with("fish_spot"):
		category = "props"
	var tex := SpriteFactory.try_load_generated(category, sub if sub != "" else archetype)
	if tex == null:
		tex = SpriteFactory.build_billboard(archetype, sub)
	sprite.texture = tex

func _on_entity_health_changed(eid: int, current: int, maximum: int) -> void:
	if eid != entity_id:
		return
	health = current
	max_health = maximum
	_update_health_bar_visual()

func _on_entity_died_signal(eid: int) -> void:
	if eid != entity_id:
		return
	is_active = false
	_on_death()

func _on_death() -> void:
	# Fade out and free
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(scale.x, 0.05, scale.z), 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _update_health_bar_visual() -> void:
	if health_bar == null or not show_healthbar:
		return
	var ratio: float = float(health) / float(max(1, max_health))
	health_bar.visible = ratio > 0.0 and ratio < 1.0
	if health_bar.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = health_bar.material_override
		mat.albedo_color = Color(0.9, 0.15, 0.15).lerp(Color(0.15, 0.85, 0.20), ratio)
	health_bar.scale.x = max(0.05, ratio)

# ─────────────────────────────────────────────────────────────────────────────
# Targeting Integration
# ─────────────────────────────────────────────────────────────────────────────
func set_targeted(on: bool) -> void:
	if on and _current_target_ring == null:
		_current_target_ring = _make_target_ring()
		add_child(_current_target_ring)
	elif not on and _current_target_ring:
		_current_target_ring.queue_free()
		_current_target_ring = null

func _make_target_ring() -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.2, 2.2)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform.origin = Vector3(0.0, 0.05, 0.0)
	mi.rotate_x(-PI / 2.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = SpriteFactory.build_reticle()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.no_depth_test = false
	mi.material_override = mat
	return mi

# ─────────────────────────────────────────────────────────────────────────────
# Accessors expected by combat/inventory systems
# ─────────────────────────────────────────────────────────────────────────────
func get_entity_id() -> int:
	return entity_id

func get_entity_type() -> String:
	return entity_type

func get_subtype() -> String:
	return subtype
