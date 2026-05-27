## Client-side content database. Loads JSON definitions from content/ at startup
## so that the game can resolve item/NPC/skill data without server round-trips.
## The server remains authoritative; this is a read-only cache for display.
extends Node

var items: Dictionary = {}      # item_id -> Dictionary
var skills: Dictionary = {}     # skill_id -> Dictionary
var npcs: Dictionary = {}       # npc_id -> Dictionary
var world_chunks: Dictionary = {} # "x,z" -> Dictionary

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	_load_directory("res://content/items", items)
	_load_directory("res://content/skills", skills)
	_load_directory("res://content/npcs", npcs)
	_load_directory("res://content/world", world_chunks)

func _load_directory(path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_json_file(path + "/" + file_name, target)
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_json_file(file_path: String, target: Dictionary) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("ContentDB: Could not open %s" % file_path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ContentDB: Failed to parse %s" % file_path)
		return
	var data = json.data
	if data is Array:
		for entry in data:
			if entry is Dictionary and entry.has("id"):
				target[entry["id"]] = entry
	elif data is Dictionary:
		if data.has("id"):
			target[data["id"]] = data
		else:
			target.merge(data)

func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})

func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})

func get_npc(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})

func get_chunk(x: int, z: int) -> Dictionary:
	return world_chunks.get("%d,%d" % [x, z], {})
