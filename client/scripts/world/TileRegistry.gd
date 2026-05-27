## TileRegistry — Defines all tile types and builds the TileSet programmatically.
##
## This is the single source of truth for tile visuals and properties on the client.
## Tile IDs MUST match the server's `tile::*` constants in lib.rs.
##
## ADDING A NEW TILE:
##   1. Add an entry to TILE_TYPES with a matching ID.
##   2. Update the server's tile module in lib.rs.
##   3. Set sprite_path once a real asset is available (color used while empty).
##
## UPGRADING VISUALS:
##   Set sprite_path to "res://assets/sprites/tiles/your_tile.png"
##   The registry will use it automatically — no other changes needed.
class_name TileRegistry
extends RefCounted

const TILE_SIZE := 32  # pixels per tile; changing this requires a full rebuild

## Tile type definitions. Array index == source atlas column for the TileSet.
## Keep in ID order — the TileSet atlas is built from this array sequentially.
const TILE_TYPES: Array[Dictionary] = [
	{
		"id": 0, "name": "grass",
		"color": Color(0.35, 0.60, 0.25),
		"sprite_path": "",
		"walkable": true, "swim": false, "movement_cost": 1.0,
	},
	{
		"id": 1, "name": "forest",
		"color": Color(0.13, 0.37, 0.13),
		"sprite_path": "",
		"walkable": false, "swim": false, "movement_cost": 0.0,
	},
	{
		"id": 2, "name": "stone",
		"color": Color(0.55, 0.55, 0.55),
		"sprite_path": "",
		"walkable": true, "swim": false, "movement_cost": 1.0,
	},
	{
		"id": 3, "name": "water",
		"color": Color(0.18, 0.42, 0.78),
		"sprite_path": "",
		"walkable": false, "swim": true, "movement_cost": 0.0,
	},
	{
		"id": 4, "name": "sand",
		"color": Color(0.85, 0.78, 0.45),
		"sprite_path": "",
		"walkable": true, "swim": false, "movement_cost": 1.2,
	},
	{
		"id": 5, "name": "dirt",
		"color": Color(0.55, 0.38, 0.22),
		"sprite_path": "",
		"walkable": true, "swim": false, "movement_cost": 1.0,
	},
	{
		"id": 6, "name": "snow",
		"color": Color(0.88, 0.92, 0.96),
		"sprite_path": "",
		"walkable": true, "swim": false, "movement_cost": 1.4,
	},
	{
		"id": 7, "name": "swamp",
		"color": Color(0.28, 0.38, 0.20),
		"sprite_path": "",
		"walkable": true, "swim": false, "movement_cost": 1.8,
	},
	{
		"id": 8, "name": "lava",
		"color": Color(0.90, 0.25, 0.05),
		"sprite_path": "",
		"walkable": false, "swim": false, "movement_cost": 0.0,
	},
]

var _tile_by_id: Dictionary = {}

func _init() -> void:
	for tile_def in TILE_TYPES:
		_tile_by_id[tile_def.id] = tile_def

## Build and assign a TileSet to the given TileMap.
## Called once by World._ready(). Safe to call again if the registry changes.
func build_tileset(tile_map: TileMap) -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var source := TileSetAtlasSource.new()

	# Create the atlas image: one row, one column per tile type
	var atlas_width  := TILE_SIZE * TILE_TYPES.size()
	var atlas_height := TILE_SIZE
	var img := Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)

	for i in TILE_TYPES.size():
		var tile_def: Dictionary = TILE_TYPES[i]

		if tile_def.sprite_path != "" and ResourceLoader.exists(tile_def.sprite_path):
			# Load the real sprite and blit it into the atlas
			var sprite_img: Image = load(tile_def.sprite_path).get_image()
			if sprite_img.get_width() != TILE_SIZE or sprite_img.get_height() != TILE_SIZE:
				sprite_img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
			img.blit_rect(sprite_img, Rect2i(0, 0, TILE_SIZE, TILE_SIZE),
				Vector2i(i * TILE_SIZE, 0))
		else:
			# Draw a solid color block — good-looking placeholder
			img.fill_rect(
				Rect2i(i * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE),
				tile_def.color)
			# Add subtle 1px dark border for grid readability
			_draw_tile_border(img, i * TILE_SIZE, 0, TILE_SIZE)

	var texture := ImageTexture.create_from_image(img)
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for i in TILE_TYPES.size():
		source.create_tile(Vector2i(i, 0))

	tileset.add_source(source, 0)
	tile_map.tile_set = tileset

## Returns true if the tile at the given ID can be walked on.
func is_walkable(tile_id: int) -> bool:
	return _tile_by_id.get(tile_id, {}).get("walkable", false)

## Returns the movement cost weight for this tile (higher = slower path).
func movement_cost(tile_id: int) -> float:
	return _tile_by_id.get(tile_id, {}).get("movement_cost", 1.0)

func get_tile_name(tile_id: int) -> String:
	return _tile_by_id.get(tile_id, {}).get("name", "unknown")

func _draw_tile_border(img: Image, ox: int, oy: int, size: int) -> void:
	var border := Color(0, 0, 0, 0.15)
	for px in size:
		img.set_pixel(ox + px, oy, border)
		img.set_pixel(ox + px, oy + size - 1, border)
		img.set_pixel(ox, oy + px, border)
		img.set_pixel(ox + size - 1, oy + px, border)
