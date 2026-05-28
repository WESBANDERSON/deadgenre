## DialoguePanel — NPC dialogue interaction window.
##
## Shows dialogue text with clickable choice buttons.
## Data-driven: dialogue trees defined as linked nodes (mirrors server DialogueNode table).
##
## Flow:
##   1. Player interacts with NPC → EventBus.dialogue_started emits
##   2. Panel shows root node text with choices
##   3. Player clicks a choice → advances to target node
##   4. Node with target "0" ends the conversation
class_name DialoguePanel
extends PanelContainer

var _npc_name_label: Label = null
var _text_label: Label = null
var _choices_container: VBoxContainer = null
var _current_npc: String = ""
var _current_node_id: int = -1

## Dialogue data cache: npc_subtype -> Array of node dicts
## In online mode, populated from server subscription. In offline, seeded locally.
var dialogue_trees: Dictionary = {}

func _ready() -> void:
	_build_panel()
	_connect_signals()
	visible = false
	_seed_offline_dialogues()

func _connect_signals() -> void:
	EventBus.dialogue_started.connect(_on_dialogue_started)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and visible:
			_close()

func _build_panel() -> void:
	custom_minimum_size = Vector2(420, 180)
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 100
	offset_right = -100
	offset_bottom = -20
	offset_top = -200

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.09, 0.94)
	style.border_color = Color(0.45, 0.40, 0.25, 0.80)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_npc_name_label = Label.new()
	_npc_name_label.text = "NPC"
	_npc_name_label.add_theme_font_size_override("font_size", 14)
	_npc_name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.50))
	vbox.add_child(_npc_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_label.add_theme_font_size_override("font_size", 12)
	_text_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_text_label.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(_text_label)

	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_choices_container)

func _on_dialogue_started(npc_subtype: String) -> void:
	_current_npc = npc_subtype
	var tree: Array = dialogue_trees.get(npc_subtype, [])
	if tree.is_empty():
		return

	var root = null
	for node in tree:
		if node.is_root:
			root = node
			break
	if root == null:
		root = tree[0]

	_show_node(root)
	visible = true

func _show_node(node: Dictionary) -> void:
	_current_node_id = node.id
	_npc_name_label.text = _current_npc.replace("_", " ").capitalize()
	_text_label.text = node.text

	for child in _choices_container.get_children():
		child.queue_free()

	var choices: Array = node.get("choices", [])
	var targets: Array = node.get("targets", [])

	for i in choices.size():
		var btn := Button.new()
		btn.text = "> " + choices[i]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.70, 0.85, 0.70))
		var target_id: int = targets[i] if i < targets.size() else 0
		btn.pressed.connect(func(): _on_choice_selected(target_id))
		_choices_container.add_child(btn)

func _on_choice_selected(target_id: int) -> void:
	if target_id <= 0:
		_close()
		if target_id < 0:
			EventBus.quest_action_triggered.emit(_current_npc, abs(target_id))
		return

	var tree: Array = dialogue_trees.get(_current_npc, [])
	for node in tree:
		if node.id == target_id:
			_show_node(node)
			return

	_close()

func _close() -> void:
	visible = false
	_current_npc = ""
	EventBus.dialogue_ended.emit()

func _seed_offline_dialogues() -> void:
	dialogue_trees["merchant_alice"] = [
		{"id": 1, "is_root": true,
		 "text": "Welcome, traveler! I'm Alice. How can I help you today?",
		 "choices": ["Tell me about this area", "Do you have any work for me?", "Goodbye"],
		 "targets": [2, 3, 0]},
		{"id": 2, "is_root": false,
		 "text": "This is the Starter Meadows. Goblins lurk in the forests, and there are copper veins in the hills to the south. Careful out there!",
		 "choices": ["Anything else?", "Thanks, goodbye"],
		 "targets": [1, 0]},
		{"id": 3, "is_root": false,
		 "text": "Actually, yes! The goblins have been stealing copper from my shipments. If you could clear out a few and bring me some ore, I'd reward you handsomely.",
		 "choices": ["I'll help! (Accept quest)", "Maybe later"],
		 "targets": [4, 0]},
		{"id": 4, "is_root": false,
		 "text": "Wonderful! Bring me 5 Copper Ore after defeating some goblins. Good luck out there, adventurer!",
		 "choices": ["On my way!"],
		 "targets": [0]},
	]
	dialogue_trees["resource_oak_tree"] = [
		{"id": 10, "is_root": true,
		 "text": "A sturdy oak tree. You could chop some logs here.",
		 "choices": ["Chop wood", "Leave"],
		 "targets": [0, 0]},
	]
	dialogue_trees["resource_copper"] = [
		{"id": 11, "is_root": true,
		 "text": "A vein of copper ore glints in the rock face.",
		 "choices": ["Mine copper", "Leave"],
		 "targets": [0, 0]},
	]
	dialogue_trees["resource_fish_spot"] = [
		{"id": 12, "is_root": true,
		 "text": "Fish swirl lazily beneath the water's surface.",
		 "choices": ["Cast line", "Leave"],
		 "targets": [0, 0]},
	]
