## Global event bus for decoupled communication between systems.
## Any system can emit or listen to signals here without direct references.
## To add a new event: declare a signal below and document its parameters.
extends Node

# --- Player events ---
signal player_spawned(player_node: Node3D)
signal player_moved(position: Vector3)
signal player_stats_changed(stats: Dictionary)
signal player_died()
signal player_respawned()

# --- Combat events ---
signal combat_started(target_name: String)
signal combat_tick(damage_dealt: int, damage_received: int)
signal combat_ended(victory: bool)
signal damage_popup_requested(position: Vector3, amount: int, is_player: bool)

# --- Inventory events ---
signal inventory_changed()
signal item_picked_up(item_id: String, quantity: int)
signal item_equipped(item_id: String, slot: String)
signal item_unequipped(slot: String)

# --- UI events ---
signal ui_panel_toggled(panel_name: String, is_open: bool)
signal notification_requested(message: String, type: String)
signal tooltip_requested(data: Dictionary, screen_pos: Vector2)
signal tooltip_hidden()

# --- World events ---
signal chunk_entered(chunk_x: int, chunk_z: int, terrain: String)
signal world_object_interacted(object_id: int)

# --- Network events ---
signal connected_to_server()
signal disconnected_from_server()
signal connection_error(message: String)

# --- Skill events ---
signal skill_xp_gained(skill_id: String, amount: int)
signal skill_leveled_up(skill_id: String, new_level: int)

# --- NPC events ---
signal npc_dialogue_started(npc_name: String, dialogue_key: String)
signal npc_dialogue_ended()
