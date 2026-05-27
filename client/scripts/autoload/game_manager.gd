## Top-level game state manager. Handles scene transitions, pause state,
## and orchestrates the connection between client systems and the server.
extends Node

enum GameState { LOADING, MENU, CONNECTING, PLAYING, DISCONNECTED }

var current_state: GameState = GameState.LOADING
var local_player: Node3D = null
var is_paused: bool = false

func _ready() -> void:
	_transition_to(GameState.MENU)

func _transition_to(new_state: GameState) -> void:
	current_state = new_state
	match new_state:
		GameState.MENU:
			_show_main_menu()
		GameState.CONNECTING:
			pass
		GameState.PLAYING:
			EventBus.connected_to_server.emit()
		GameState.DISCONNECTED:
			EventBus.disconnected_from_server.emit()

func _show_main_menu() -> void:
	pass

func start_game(username: String) -> void:
	_transition_to(GameState.CONNECTING)
	# SpacetimeDB connection will be initiated here once the SDK is wired up.
	# For now, go straight to playing for local development.
	_transition_to(GameState.PLAYING)

func register_local_player(node: Node3D) -> void:
	local_player = node
	EventBus.player_spawned.emit(node)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if current_state == GameState.PLAYING:
			is_paused = !is_paused
			get_tree().paused = is_paused
