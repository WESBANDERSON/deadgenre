## EventBus — Global signal hub for all cross-system communication.
##
## Every signal that crosses a system boundary is declared here.
## Systems emit and connect through EventBus — never directly to each other.
##
## HOW TO ADD A SIGNAL:
##   1. Declare it below with a descriptive name and typed parameters.
##   2. Emit from the source:   EventBus.your_signal.emit(data)
##   3. Connect in subscriber:  EventBus.your_signal.connect(_on_your_signal)
##
## Signal naming convention:  noun_verb (e.g. player_died, chunk_loaded)
extends Node

# ─────────────────────────────────────────────────────────────────────────────
# Network / Session
# ─────────────────────────────────────────────────────────────────────────────
signal connected_to_server
signal disconnected_from_server
signal connection_failed(reason: String)

# ─────────────────────────────────────────────────────────────────────────────
# Player Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
signal local_player_spawned(player: Node)
signal local_player_respawned(position: Vector2)
signal player_died(player: Node)
signal player_level_changed(new_level: int)

# ─────────────────────────────────────────────────────────────────────────────
# Player State (synced from server)
# ─────────────────────────────────────────────────────────────────────────────
signal player_health_changed(player: Node, current: int, maximum: int)
signal player_mana_changed(player: Node, current: int, maximum: int)
signal player_xp_gained(skill: String, amount: int, new_total: int)
signal player_skill_leveled(skill: String, new_level: int)
signal player_moved(world_position: Vector2)

# ─────────────────────────────────────────────────────────────────────────────
# World / Terrain
# ─────────────────────────────────────────────────────────────────────────────
signal chunk_needed(chunk_x: int, chunk_y: int)
signal chunk_loaded(chunk_x: int, chunk_y: int)
signal tiles_updated(tile_positions: Array)

# ─────────────────────────────────────────────────────────────────────────────
# Entities
# ─────────────────────────────────────────────────────────────────────────────
signal entity_spawned(entity_id: int, entity_type: String, subtype: String, pos: Vector2)
signal entity_despawned(entity_id: int)
signal entity_health_changed(entity_id: int, current: int, maximum: int)
signal entity_died(entity_id: int)
signal entity_clicked(entity_id: int, entity_node: Node)

# ─────────────────────────────────────────────────────────────────────────────
# Combat
# ─────────────────────────────────────────────────────────────────────────────
signal combat_hit(attacker_id: String, target_id: String, damage: int, is_critical: bool)
signal combat_miss(attacker_id: String, target_id: String)
signal combat_entered(target: Node)
signal combat_exited

# ─────────────────────────────────────────────────────────────────────────────
# Inventory
# ─────────────────────────────────────────────────────────────────────────────
signal inventory_changed
signal item_picked_up(item_name: String, quantity: int)
signal inventory_full

# ─────────────────────────────────────────────────────────────────────────────
# UI
# ─────────────────────────────────────────────────────────────────────────────
signal notification_shown(message: String, style: String)  # style: "info"|"warn"|"error"|"loot"
signal chat_message_received(channel: String, sender: String, message: String)
signal panel_toggle_requested(panel_name: String)          # "inventory"|"skills"|"map"|"menu"
