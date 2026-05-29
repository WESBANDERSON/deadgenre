## TerrainBuilder — Builds the 2.5D world ground mesh from tile-chunk data.
##
## CONTRACT WITH SERVER:
##   Chunks arrive as flat tile_id arrays sized CHUNK_SIZE×CHUNK_SIZE.
##   tile_id maps to TileRegistry.TILE_TYPES; visuals here are derived from
##   that registry, so tile palette stays the single source of truth.
##
## COORDINATE SPACE:
##   World plane is XZ in 3D space; Y is up.
##   1 tile == TILE_UNITS world units.  Player and entities live on Y ≈ 0.
##
## VISUAL STYLE:
##   Flat shaded quads per tile with per-vertex color noise. Forest / stone
##   tiles get a small Y bump (~0.25u) so terrain has subtle relief without
##   needing a true heightmap.
##
## EXTENSION POINTS:
##   - Replace `build_chunk_mesh()` with a true heightmap when the world model
##     adds elevation data.
##   - Add a shader material that samples per-tile textures instead of vertex
##     colors once generated tile sprites land in `assets/generated/tiles/`.
class_name TerrainBuilder
extends RefCounted

const TILE_UNITS  := 1.0
const CHUNK_SIZE  := 32
const RELIEF_FOREST := 0.35
const RELIEF_STONE  := 0.18

var _tile_registry: TileRegistry
var _shared_material: StandardMaterial3D = null

func _init(tile_registry: TileRegistry) -> void:
	_tile_registry = tile_registry
	_shared_material = StandardMaterial3D.new()
	_shared_material.vertex_color_use_as_albedo = true
	_shared_material.roughness = 0.95
	_shared_material.metallic = 0.0
	_shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

## Build a MeshInstance3D for a single chunk. The mesh is positioned in its
## own local space; the caller is expected to place it in the world by
## setting `mesh_instance.transform.origin`.
func build_chunk_mesh(tile_data: PackedByteArray) -> MeshInstance3D:
	assert(tile_data.size() == CHUNK_SIZE * CHUNK_SIZE,
			"Tile data must be exactly chunk size")

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ty in CHUNK_SIZE:
		for tx in CHUNK_SIZE:
			var tile_id: int = tile_data[ty * CHUNK_SIZE + tx]
			_emit_tile_quad(st, tx, ty, tile_id)

	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _shared_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _emit_tile_quad(st: SurfaceTool, tx: int, ty: int, tile_id: int) -> void:
	var base_color: Color = _tile_color_for(tile_id)
	var relief: float = _tile_relief_for(tile_id)

	var x0 := tx * TILE_UNITS
	var z0 := ty * TILE_UNITS
	var x1 := x0 + TILE_UNITS
	var z1 := z0 + TILE_UNITS

	# Subtle per-tile color jitter so the ground isn't a solid block of color.
	var seed_h := hash("%d_%d_%d" % [tx, ty, tile_id])
	var jitter := ((seed_h & 0xFF) / 255.0 - 0.5) * 0.06
	var color := Color(
		clampf(base_color.r + jitter, 0.0, 1.0),
		clampf(base_color.g + jitter * 0.8, 0.0, 1.0),
		clampf(base_color.b + jitter * 0.6, 0.0, 1.0),
		1.0)

	# 4 corners; relief lifts the centre slightly via per-corner Y to fake bumps.
	var y_c := relief * 0.5
	var v00 := Vector3(x0, y_c, z0)
	var v10 := Vector3(x1, y_c, z0)
	var v01 := Vector3(x0, y_c, z1)
	var v11 := Vector3(x1, y_c, z1)

	# Triangle 1
	st.set_color(color)
	st.add_vertex(v00)
	st.set_color(color)
	st.add_vertex(v10)
	st.set_color(color)
	st.add_vertex(v11)

	# Triangle 2
	st.set_color(color)
	st.add_vertex(v00)
	st.set_color(color)
	st.add_vertex(v11)
	st.set_color(color)
	st.add_vertex(v01)

func _tile_color_for(tile_id: int) -> Color:
	var base: Color = _tile_registry._tile_by_id.get(tile_id, {}).get(
			"color", Color(0.30, 0.30, 0.30))
	# Darken for Dreadmyst mood — terrain reads as overcast / dusk
	return Color(base.r * 0.55, base.g * 0.60, base.b * 0.62)

func _tile_relief_for(tile_id: int) -> float:
	var name: String = _tile_registry.get_tile_name(tile_id)
	if name == "forest":
		return RELIEF_FOREST
	if name == "stone":
		return RELIEF_STONE
	if name == "snow":
		return 0.08
	if name == "water" or name == "lava" or name == "swamp":
		return -0.10
	return 0.0
