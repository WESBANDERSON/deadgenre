## Pathfinder — AStarGrid2D-based tile pathfinding.
##
## Owned by the World node and queried by Player for click-to-move.
## Updated incrementally as chunks are received from the server.
##
## Usage:
##   var path: Array[Vector2] = world.pathfinder.find_path(from_world, to_world)
##   # Returns world-space waypoints (centers of walkable tiles).
##   # Returns [] if no path exists or start == end.
class_name Pathfinder
extends RefCounted

const TILE_SIZE      := 32
const CHUNK_SIZE     := 32
const GRID_HALF_SIZE := 256  # tiles from origin in each direction (512×512 grid total)

var _astar: AStarGrid2D

func _init() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(-GRID_HALF_SIZE, -GRID_HALF_SIZE, GRID_HALF_SIZE * 2, GRID_HALF_SIZE * 2)
	_astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()

	# Default: all tiles solid until chunk data arrives
	for y in range(-GRID_HALF_SIZE, GRID_HALF_SIZE):
		for x in range(-GRID_HALF_SIZE, GRID_HALF_SIZE):
			_astar.set_point_solid(Vector2i(x, y), true)

## Update walkability for an entire chunk when tile data arrives.
## tile_data is a flat PackedByteArray of CHUNK_SIZE*CHUNK_SIZE bytes.
## chunk_origin_tile is the top-left tile coordinate of the chunk.
func update_chunk(chunk_origin_tile: Vector2i, tile_data: PackedByteArray, tile_registry: TileRegistry) -> void:
	for y in CHUNK_SIZE:
		for x in CHUNK_SIZE:
			var tile_pos := chunk_origin_tile + Vector2i(x, y)
			if not _astar.is_in_boundsv(tile_pos):
				continue
			var tile_id: int = tile_data[y * CHUNK_SIZE + x]
			var walkable: bool = tile_registry.is_walkable(tile_id)
			var cost: float = tile_registry.movement_cost(tile_id)
			_astar.set_point_solid(tile_pos, not walkable)
			if walkable:
				_astar.set_point_weight_scale(tile_pos, cost)

## Find a path between two world-space positions.
## Returns an array of world-space Vector2 waypoints, empty if unreachable.
func find_path(from_world: Vector2, to_world: Vector2) -> Array[Vector2]:
	var from_tile := world_to_tile(from_world)
	var to_tile   := world_to_tile(to_world)

	if from_tile == to_tile:
		return []

	# Clamp destination to grid bounds
	to_tile = to_tile.clamp(
		Vector2i(-GRID_HALF_SIZE, -GRID_HALF_SIZE),
		Vector2i(GRID_HALF_SIZE - 1, GRID_HALF_SIZE - 1))

	# If target is solid, find nearest walkable neighbor
	if _astar.is_point_solid(to_tile):
		to_tile = _find_nearest_walkable(to_tile, from_tile)

	if to_tile == from_tile:
		return []

	var tile_path := _astar.get_id_path(from_tile, to_tile)
	var world_path: Array[Vector2] = []
	for tp in tile_path:
		world_path.append(tile_to_world_center(tp))

	return world_path

## Mark a single tile as walkable or solid (used for dynamic obstacles).
func set_tile_walkable(tile_pos: Vector2i, walkable: bool, cost: float = 1.0) -> void:
	if _astar.is_in_boundsv(tile_pos):
		_astar.set_point_solid(tile_pos, not walkable)
		if walkable:
			_astar.set_point_weight_scale(tile_pos, cost)

# ─────────────────────────────────────────────────────────────────────────────
# Coordinate Utilities
# ─────────────────────────────────────────────────────────────────────────────
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))

func tile_to_world_center(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE + TILE_SIZE * 0.5,
	               tile_pos.y * TILE_SIZE + TILE_SIZE * 0.5)

func _find_nearest_walkable(start: Vector2i, prefer_toward: Vector2i) -> Vector2i:
	# BFS outward from start to find the closest walkable tile
	var visited: Dictionary = {}
	var queue: Array = [start]
	var max_search := 10

	for _step in max_search:
		if queue.is_empty():
			break
		var current: Vector2i = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true

		if _astar.is_in_boundsv(current) and not _astar.is_point_solid(current):
			return current

		var neighbors := [
			current + Vector2i(1, 0), current + Vector2i(-1, 0),
			current + Vector2i(0, 1), current + Vector2i(0, -1),
		]
		# Sort neighbors toward the preferred direction for faster convergence
		neighbors.sort_custom(func(a, b):
			return a.distance_squared_to(prefer_toward) < b.distance_squared_to(prefer_toward))
		queue.append_array(neighbors)

	return start
