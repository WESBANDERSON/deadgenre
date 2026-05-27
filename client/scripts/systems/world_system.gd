## Manages chunk loading/unloading and world object placement.
## The world is a grid of chunks; only chunks near the player are active.
extends Node

var loaded_chunks: Dictionary = {}  # "x,z" -> Node3D
var current_chunk: Vector2i = Vector2i.ZERO

func _ready() -> void:
	EventBus.player_moved.connect(_on_player_moved)

func _on_player_moved(pos: Vector3) -> void:
	var chunk_x := floori(pos.x / Config.chunk_size)
	var chunk_z := floori(pos.z / Config.chunk_size)
	var new_chunk := Vector2i(chunk_x, chunk_z)

	if new_chunk != current_chunk:
		current_chunk = new_chunk
		_update_loaded_chunks()
		var chunk_def := ContentDB.get_chunk(chunk_x, chunk_z)
		var terrain: String = chunk_def.get("terrain_type", "plains")
		EventBus.chunk_entered.emit(chunk_x, chunk_z, terrain)

func _update_loaded_chunks() -> void:
	var needed: Array[String] = []
	var vd := Config.view_distance_chunks
	for dx in range(-vd, vd + 1):
		for dz in range(-vd, vd + 1):
			var key := "%d,%d" % [current_chunk.x + dx, current_chunk.y + dz]
			needed.append(key)

	for key in loaded_chunks.keys():
		if key not in needed:
			_unload_chunk(key)

	for key in needed:
		if key not in loaded_chunks:
			_load_chunk(key)

func _load_chunk(key: String) -> void:
	var parts := key.split(",")
	var cx := int(parts[0])
	var cz := int(parts[1])

	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%s" % key

	var ground := _create_ground_plane(cx, cz)
	chunk_node.add_child(ground)

	get_tree().current_scene.add_child(chunk_node)
	loaded_chunks[key] = chunk_node

func _unload_chunk(key: String) -> void:
	if loaded_chunks.has(key):
		loaded_chunks[key].queue_free()
		loaded_chunks.erase(key)

func _create_ground_plane(cx: int, cz: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1  # ground layer

	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Config.chunk_size, Config.chunk_size)
	mesh_instance.mesh = plane

	var material := StandardMaterial3D.new()
	var chunk_def := ContentDB.get_chunk(cx, cz)
	var terrain: String = chunk_def.get("terrain_type", "plains")

	match terrain:
		"forest":
			material.albedo_color = Color(0.2, 0.45, 0.15)
		"desert":
			material.albedo_color = Color(0.76, 0.65, 0.35)
		"mountain":
			material.albedo_color = Color(0.5, 0.48, 0.45)
		"town":
			material.albedo_color = Color(0.55, 0.5, 0.4)
		"dungeon":
			material.albedo_color = Color(0.25, 0.22, 0.2)
		_:
			material.albedo_color = Color(0.3, 0.55, 0.2)

	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(Config.chunk_size, 0.1, Config.chunk_size)
	collision.shape = shape
	collision.position.y = -0.05
	body.add_child(collision)

	body.position = Vector3(
		cx * Config.chunk_size + Config.chunk_size / 2.0,
		0,
		cz * Config.chunk_size + Config.chunk_size / 2.0
	)
	return body
