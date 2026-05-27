## Generic NPC entity. Resolves its appearance and behavior from ContentDB
## using npc_id. Hostile NPCs can be attacked; friendly ones show dialogue.
extends CharacterBody3D

@export var npc_id: String = ""
@export var instance_id: int = 0

var display_name: String = ""
var npc_type: String = "neutral"
var current_hp: int = 100
var max_hp: int = 100
var is_alive: bool = true

@onready var _nameplate: Label3D = $Nameplate if has_node("Nameplate") else null
@onready var _hp_bar: Node = $HPBar if has_node("HPBar") else null

func _ready() -> void:
	_load_definition()

func _load_definition() -> void:
	var def := ContentDB.get_npc(npc_id)
	if def.is_empty():
		return
	display_name = def.get("display_name", npc_id)
	npc_type = def.get("npc_type", "neutral")
	max_hp = def.get("max_hp", 100)
	current_hp = max_hp

	if _nameplate:
		_nameplate.text = display_name
		match npc_type:
			"hostile":
				_nameplate.modulate = Color.RED
			"friendly", "merchant", "quest_giver":
				_nameplate.modulate = Color.GREEN
			_:
				_nameplate.modulate = Color.WHITE

func interact() -> void:
	match npc_type:
		"hostile":
			EventBus.combat_started.emit(display_name)
		"merchant":
			EventBus.notification_requested.emit("Shop coming soon!", "info")
		"quest_giver":
			var def := ContentDB.get_npc(npc_id)
			var dialogue_key: String = def.get("dialogue_key", "")
			EventBus.npc_dialogue_started.emit(display_name, dialogue_key)
		_:
			EventBus.notification_requested.emit(display_name + " has nothing to say.", "info")

func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	EventBus.damage_popup_requested.emit(global_position + Vector3.UP * 2, amount, false)
	if current_hp <= 0:
		is_alive = false

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event.is_action_pressed("click_action"):
		interact()
