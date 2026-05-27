## Client-side combat system. Manages the tick timer, visual feedback, and
## communicates with the server via SpacetimeDB reducers.
## For offline/dev mode it runs a local simulation.
extends Node

var is_in_combat: bool = false
var combat_id: int = -1
var current_target: Node3D = null
var _tick_timer: float = 0.0

func _ready() -> void:
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)

func _process(delta: float) -> void:
	if not is_in_combat:
		return
	_tick_timer += delta
	if _tick_timer >= Config.combat_tick_interval:
		_tick_timer -= Config.combat_tick_interval
		_process_tick()

func _on_combat_started(target_name: String) -> void:
	is_in_combat = true
	_tick_timer = 0.0
	EventBus.notification_requested.emit("Combat with " + target_name + "!", "combat")

func _on_combat_ended(victory: bool) -> void:
	is_in_combat = false
	combat_id = -1
	current_target = null
	if victory:
		EventBus.notification_requested.emit("Victory!", "combat")
	else:
		EventBus.notification_requested.emit("You were defeated.", "combat")

func _process_tick() -> void:
	# In connected mode, this calls the combat_tick reducer on SpacetimeDB.
	# For local dev, simulate damage exchange.
	var damage_dealt := randi_range(1, 15)
	var damage_received := randi_range(0, 10)

	if current_target and current_target.has_method("take_damage"):
		current_target.take_damage(damage_dealt)

	EventBus.combat_tick.emit(damage_dealt, damage_received)

	if current_target and current_target is Node3D:
		EventBus.damage_popup_requested.emit(
			current_target.global_position + Vector3.UP * 2,
			damage_dealt, false
		)
	if GameManager.local_player:
		EventBus.damage_popup_requested.emit(
			GameManager.local_player.global_position + Vector3.UP * 2,
			damage_received, true
		)

func flee() -> void:
	if is_in_combat:
		EventBus.combat_ended.emit(false)
