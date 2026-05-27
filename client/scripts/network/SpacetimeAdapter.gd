## SpacetimeAdapter — Thin adapter isolating all SpacetimeDB SDK calls.
##
## When the SpacetimeDB Godot SDK addon is installed:
##   1. Install com.clockworklabs.spacetimedbsdk to client/addons/spacetimedb/
##   2. Enable the addon in Project Settings → Plugins
##   3. Uncomment the SDK calls below and delete the stub bodies.
##
## This adapter exists so that every SDK interaction is in one place,
## making it trivial to update when the SDK version changes.
##
## SDK Reference: https://github.com/clockworklabs/com.clockworklabs.spacetimedbsdk
class_name SpacetimeAdapter
extends RefCounted

var _client = null  # SpacetimeDBClient when SDK is installed

signal on_connect(identity: String, token: String)
signal on_disconnect
signal on_row_update(table: String, old_row, new_row, is_insert: bool)
signal on_reducer_call_error(reducer: String, message: String)

func connect_db(host: String, db_name: String, ssl: bool) -> void:
	# SDK: _client = SpacetimeDBClient.new()
	# SDK: _client.on_connect.connect(_on_sdk_connect)
	# SDK: _client.on_disconnect.connect(_on_sdk_disconnect)
	# SDK: _client.on_row_update.connect(_on_sdk_row_update)
	# SDK: _client.connect_db(host, db_name, ssl)
	push_warning("[SpacetimeAdapter] SDK not installed. Running in offline mode.")
	_ = host; _ = db_name; _ = ssl

func subscribe(queries: Array) -> void:
	# SDK: _client.subscribe(queries)
	_ = queries

func call_reducer(name: String, args: Array) -> void:
	# SDK: _client.call_reducer(name, args)
	_ = name; _ = args

func get_identity() -> String:
	# SDK: return _client.identity
	return ""

# ─────────────────────────────────────────────────────────────────────────────
# Internal SDK Callbacks (uncomment when SDK is installed)
# ─────────────────────────────────────────────────────────────────────────────
# func _on_sdk_connect(identity: String, token: String) -> void:
#     on_connect.emit(identity, token)
#
# func _on_sdk_disconnect() -> void:
#     on_disconnect.emit()
#
# func _on_sdk_row_update(table: String, old_row, new_row, is_insert: bool) -> void:
#     on_row_update.emit(table, old_row, new_row, is_insert)
