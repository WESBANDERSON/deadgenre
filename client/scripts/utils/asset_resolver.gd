## Resolves asset_key strings to actual resource paths. This indirection lets
## content definitions reference assets by key while the actual files can live
## anywhere and be swapped out (e.g. placeholder -> AI-generated -> hand-crafted).
##
## Resolution order:
##   1. Exact path if it starts with "res://"
##   2. Lookup in the asset manifest (res://assets/manifest.json)
##   3. Convention-based: "items/{key}.png", "models/{key}.glb", etc.
##   4. Fallback placeholder
class_name AssetResolver

const ASSET_BASE := "res://assets/"
const PLACEHOLDER_TEXTURE := "res://assets/textures/placeholder.png"
const PLACEHOLDER_MODEL := "res://assets/models/placeholder.glb"

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false

static func resolve_texture(asset_key: String) -> String:
	if asset_key.begins_with("res://"):
		return asset_key
	_ensure_manifest()
	if _manifest.has(asset_key):
		return _manifest[asset_key]
	var conventional := ASSET_BASE + "textures/" + asset_key + ".png"
	if ResourceLoader.exists(conventional):
		return conventional
	return PLACEHOLDER_TEXTURE

static func resolve_model(asset_key: String) -> String:
	if asset_key.begins_with("res://"):
		return asset_key
	_ensure_manifest()
	if _manifest.has(asset_key):
		return _manifest[asset_key]
	var conventional := ASSET_BASE + "models/" + asset_key + ".glb"
	if ResourceLoader.exists(conventional):
		return conventional
	return PLACEHOLDER_MODEL

static func _ensure_manifest() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	var path := ASSET_BASE + "manifest.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_manifest = json.data
