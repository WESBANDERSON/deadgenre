## Entity — Base class for all interactive world objects: NPCs, mobs, item drops.
##
## Subclass this for specific entity types. Override:
##   _on_interact()  → what happens when the player right-clicks / presses interact
##   _setup_visual() → set sprite or configure custom _draw()
##   _on_death()     → custom death behavior (drop items, play animation, etc.)
##
## All entities register themselves by entity_id so World can reference them.
class_name Entity
extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
# Server State
# ─────────────────────────────────────────────────────────────────────────────
var entity_id:   int    = -1
var entity_type: String = ""   # "mob" | "npc" | "item_drop"
var subtype:     String = ""   # e.g. "goblin", "merchant_alice"

var health:      int  = 100
var max_health:  int  = 100
var is_active:   bool = true

# ─────────────────────────────────────────────────────────────────────────────
# Visual Config — override in subclasses
# ─────────────────────────────────────────────────────────────────────────────
var body_color:    Color = Color.GRAY
var body_radius:   float = 10.0
var label_text:    String = ""
var show_healthbar: bool = true

@onready var name_label: Label = $NameLabel if has_node("NameLabel") else null
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null

func _ready() -> void:
	_setup_visual()
	_connect_signals()
	if name_label:
		name_label.text = label_text if label_text != "" else subtype.replace("_", " ").capitalize()
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

func _connect_signals() -> void:
	EventBus.entity_health_changed.connect(_on_entity_health_changed)
	EventBus.entity_died.connect(_on_entity_died_signal)

## Called by World._spawn_entity() after the node is added to the scene.
func initialize(id: int, type: String, sub: String) -> void:
	entity_id   = id
	entity_type = type
	subtype     = sub
	_on_initialized()

func _on_initialized() -> void:
	pass  # Override for subtype-specific setup

## Override to set sprite or configure _draw().
func _setup_visual() -> void:
	pass

func _draw() -> void:
	if not is_active:
		return
	# Default visual: colored circle with thin white outline
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, Color(1, 1, 1, 0.4), 1.5)

## Called when the player clicks / interacts with this entity.
## Override in subclasses.
func _on_interact() -> void:
	pass

## Called by server subscription via EventBus.
func _on_entity_health_changed(eid: int, current: int, maximum: int) -> void:
	if eid != entity_id:
		return
	health = current
	max_health = maximum
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	queue_redraw()

func _on_entity_died_signal(eid: int) -> void:
	if eid != entity_id:
		return
	is_active = false
	_on_death()

func _on_death() -> void:
	# Default: fade out and free after a moment
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func get_entity_id() -> int:
	return entity_id
