//! deadgenre Game Server — SpacetimeDB 0.8 Module
//!
//! Single file containing all tables, reducers, and server logic.
//! Structured in three sections for easy navigation:
//!
//!   1. TABLES      — persistent game state (replicated to subscribed clients)
//!   2. REDUCERS    — client-callable actions + lifecycle hooks
//!   3. INTERNALS   — private helpers (world gen, XP math, validation)
//!
//! SpacetimeDB 0.8 API quick reference:
//!   - Tables:     #[spacetimedb(table)]
//!   - PK field:   #[primarykey]
//!   - Auto-inc:   #[autoinc]
//!   - 2nd index:  #[spacetimedb(index(btree, field_name))] on the struct
//!   - Reducers:   #[spacetimedb(reducer)]
//!   - Lifecycle:  #[spacetimedb(init)], #[spacetimedb(connect)], #[spacetimedb(disconnect)]
//!   - Table reads: TableName::filter_by_field(&val) or TableName::iter()
//!   - Timestamp:  ctx.timestamp.into_micros_since_epoch()
//!
//! UPGRADE PATH to SpacetimeDB 1.x (requires Rust ≥ 1.90):
//!   - #[spacetimedb(table)] → #[spacetimedb::table(name = snake_case, public)]
//!   - #[primarykey]        → #[primary_key]
//!   - Table access         → ctx.db.table().field().find(&val)
//!   - Reducers can return  Result<(), String>

use spacetimedb::{spacetimedb, Identity, ReducerContext};

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 1: TABLES
// ═════════════════════════════════════════════════════════════════════════════

/// Core player record. One row per registered account.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct Player {
    #[primarykey]
    pub identity: Identity,
    pub username: String,
    pub pos_x: f32,
    pub pos_y: f32,
    pub chunk_x: i32,
    pub chunk_y: i32,
    pub health: i32,
    pub max_health: i32,
    pub mana: i32,
    pub max_mana: i32,
    pub level: i32,
    pub experience: u64,
    pub equip_weapon: u32,
    pub equip_helm: u32,
    pub equip_chest: u32,
    pub equip_legs: u32,
    pub equip_boots: u32,
    pub equip_ring: u32,
    pub last_seen: u64,
    pub respawn_x: f32,
    pub respawn_y: f32,
}

/// Per-skill experience for each player.
/// Secondary btree index on player_identity → filter_by_player_identity() generated.
#[spacetimedb(table)]
#[spacetimedb(index(btree, player_identity))]
#[derive(Clone, Debug)]
pub struct PlayerSkill {
    #[primarykey]
    #[autoinc]
    pub id: u64,
    pub player_identity: Identity,
    pub skill_type: String,
    pub level: i32,
    pub experience: u64,
}

/// All living entities: NPCs, mobs, and item drops.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct Entity {
    #[primarykey]
    #[autoinc]
    pub id: u64,
    pub entity_type: String,
    pub subtype: String,
    pub pos_x: f32,
    pub pos_y: f32,
    pub health: i32,
    pub max_health: i32,
    pub is_active: bool,
    pub drop_item_id: u32,
    pub drop_quantity: u32,
}

/// Static item catalog. Seeded in init(), never changes at runtime.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct ItemDefinition {
    #[primarykey]
    pub id: u32,
    pub name: String,
    pub description: String,
    pub item_type: String,
    pub subtype: String,
    pub stats_json: String,
    pub stackable: bool,
    pub max_stack: u32,
    pub icon_path: String,
}

/// Player inventory slots. 28 slots per player.
#[spacetimedb(table)]
#[spacetimedb(index(btree, player_identity))]
#[derive(Clone, Debug)]
pub struct InventorySlot {
    #[primarykey]
    #[autoinc]
    pub id: u64,
    pub player_identity: Identity,
    pub slot_index: u32,
    pub item_id: u32,
    pub quantity: u32,
}

/// Terrain data per 32×32-tile chunk. tile_data is a flat Vec<u8> of 1024 bytes.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct WorldChunk {
    #[primarykey]
    pub id: u64,
    pub chunk_x: i32,
    pub chunk_y: i32,
    pub tile_data: Vec<u8>,
    pub entity_seed: u64,
    pub generated: bool,
}

/// Tracks dead mobs for respawn scheduling.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct MobRespawn {
    #[primarykey]
    #[autoinc]
    pub id: u64,
    pub subtype: String,
    pub pos_x: f32,
    pub pos_y: f32,
    pub max_health: i32,
    pub drop_item_id: u32,
    pub drop_quantity: u32,
    pub died_at: u64,
    pub respawn_after: u64,
}

/// Short-lived combat events for client animations.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct CombatEvent {
    #[primarykey]
    #[autoinc]
    pub id: u64,
    pub attacker_id: String,
    pub target_id: String,
    pub damage: i32,
    pub damage_type: String,
    pub is_critical: bool,
    pub timestamp: u64,
}

/// NPC dialogue nodes. Each NPC has a dialogue tree stored as linked nodes.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct DialogueNode {
    #[primarykey]
    pub id: u32,
    pub npc_subtype: String,
    pub text: String,
    /// Semicolon-delimited choice labels: "label1;label2;label3"
    pub choices: String,
    /// Semicolon-delimited target node IDs for each choice: "id1;id2;id3"
    /// Use "0" for end of conversation, negative for quest actions
    pub choice_targets: String,
    pub is_root: bool,
}

/// Quest definitions. Static content seeded at init.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct QuestDefinition {
    #[primarykey]
    pub id: u32,
    pub name: String,
    pub description: String,
    pub giver_npc: String,
    /// Semicolon-delimited step descriptions
    pub steps_json: String,
    /// Semicolon-delimited objectives: "type:target:quantity" per step
    /// Types: kill, gather, talk, craft
    pub objectives_json: String,
    pub reward_xp_skill: String,
    pub reward_xp_amount: u64,
    pub reward_item_id: u32,
    pub reward_item_qty: u32,
    pub required_level: i32,
}

/// Per-player quest progress. One row per active/completed quest per player.
#[spacetimedb(table)]
#[spacetimedb(index(btree, player_identity))]
#[derive(Clone, Debug)]
pub struct PlayerQuest {
    #[primarykey]
    #[autoinc]
    pub id: u64,
    pub player_identity: Identity,
    pub quest_id: u32,
    pub current_step: u32,
    /// Tracks progress on the current step's objective
    pub progress: u32,
    /// "active" | "completed" | "failed"
    pub status: String,
    pub accepted_at: u64,
    pub completed_at: u64,
}

/// Loot table definitions. Maps entity subtypes to weighted drop lists.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct LootTable {
    #[primarykey]
    pub id: u32,
    pub entity_subtype: String,
    /// Semicolon-delimited entries: "item_id:quantity:weight"
    /// Weight is relative (e.g. 80 out of 100 total = 80% chance)
    pub entries_json: String,
}

/// Spawn zone definitions. Define regions where mobs spawn with density control.
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct SpawnZone {
    #[primarykey]
    pub id: u32,
    pub name: String,
    pub center_x: f32,
    pub center_y: f32,
    pub radius: f32,
    /// Semicolon-delimited mob entries: "subtype:count:max_health"
    pub mob_list: String,
    pub max_active: u32,
    pub respawn_seconds: u32,
}

/// Crafting recipes. Seeded at init, defines what can be crafted.
/// ingredients_json format: "item_id:quantity;item_id:quantity" (simple semicolon-delimited pairs)
#[spacetimedb(table)]
#[derive(Clone, Debug)]
pub struct CraftingRecipe {
    #[primarykey]
    pub id: u32,
    pub name: String,
    pub description: String,
    pub result_item_id: u32,
    pub result_quantity: u32,
    pub ingredients_json: String,
    pub required_level: i32,
    pub xp_reward: u64,
    pub category: String,
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 2: REDUCERS
// ═════════════════════════════════════════════════════════════════════════════

/// Called once when the module is first published to SpacetimeDB.
#[spacetimedb(init)]
pub fn init() {
    log::info!("deadgenre server initializing...");
    seed_item_catalog();
    seed_crafting_recipes();
    seed_loot_tables();
    seed_spawn_zones();
    seed_dialogues();
    seed_quests();
    seed_world_entities();
    log::info!("deadgenre server ready.");
}

/// Called each time a new WebSocket client connects.
#[spacetimedb(connect)]
pub fn client_connected(_ctx: ReducerContext) {
    log::info!("Client connected.");
}

/// Called when a client disconnects. Records last_seen timestamp.
#[spacetimedb(disconnect)]
pub fn client_disconnected(ctx: ReducerContext) {
    if let Some(mut player) = Player::filter_by_identity(&ctx.sender) {
        player.last_seen = ctx.timestamp.into_micros_since_epoch();
        Player::update_by_identity(&ctx.sender, player);
    }
}

/// Register a new player account. Called once per identity.
#[spacetimedb(reducer)]
pub fn create_player(ctx: ReducerContext, username: String) {
    if let Err(msg) = validate_username(&username) {
        log::warn!("create_player rejected: {}", msg);
        return;
    }
    if Player::filter_by_identity(&ctx.sender).is_some() {
        log::warn!("create_player: player already exists");
        return;
    }

    Player::insert(Player {
        identity: ctx.sender,
        username: username.clone(),
        pos_x: 0.0, pos_y: 0.0,
        chunk_x: 0, chunk_y: 0,
        health: 100, max_health: 100,
        mana: 50, max_mana: 50,
        level: 1, experience: 0,
        equip_weapon: 0, equip_helm: 0, equip_chest: 0,
        equip_legs: 0, equip_boots: 0, equip_ring: 0,
        last_seen: ctx.timestamp.into_micros_since_epoch(),
        respawn_x: 0.0, respawn_y: 0.0,
    }).expect("Failed to insert player");

    let skills = ["melee", "ranged", "magic", "defense", "health", "crafting", "gathering", "agility"];
    for skill in skills.iter() {
        PlayerSkill::insert(PlayerSkill {
            id: 0,
            player_identity: ctx.sender,
            skill_type: skill.to_string(),
            level: 1,
            experience: 0,
        }).expect("Failed to insert skill");
    }

    log::info!("Player created: {}", username);
}

/// Update the player's authoritative position.
#[spacetimedb(reducer)]
pub fn move_player(ctx: ReducerContext, target_x: f32, target_y: f32) {
    let mut player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => { log::warn!("move_player: player not found"); return; }
    };
    let dist = euclidean_dist(player.pos_x, player.pos_y, target_x, target_y);
    if dist > 600.0 {
        log::warn!("move_player: distance {:.1} exceeds max 600", dist);
        return;
    }
    player.pos_x = target_x;
    player.pos_y = target_y;
    player.chunk_x = (target_x / 1024.0).floor() as i32;
    player.chunk_y = (target_y / 1024.0).floor() as i32;
    Player::update_by_identity(&ctx.sender, player);
}

/// Update the player's respawn location.
#[spacetimedb(reducer)]
pub fn set_respawn_point(ctx: ReducerContext, x: f32, y: f32) {
    if let Some(mut player) = Player::filter_by_identity(&ctx.sender) {
        player.respawn_x = x;
        player.respawn_y = y;
        Player::update_by_identity(&ctx.sender, player);
    }
}

/// Attack a mob entity. Validates range, computes damage, broadcasts CombatEvent.
#[spacetimedb(reducer)]
pub fn attack_entity(ctx: ReducerContext, entity_id: u64) {
    let player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => { log::warn!("attack_entity: player not found"); return; }
    };
    let mut entity = match Entity::filter_by_id(&entity_id) {
        Some(e) => e,
        None => { log::warn!("attack_entity: entity {} not found", entity_id); return; }
    };

    if !entity.is_active || entity.entity_type != "mob" {
        return;
    }
    let dist = euclidean_dist(player.pos_x, player.pos_y, entity.pos_x, entity.pos_y);
    if dist > 80.0 {
        log::warn!("attack_entity: target out of range ({:.1})", dist);
        return;
    }

    let melee_level = get_skill_level(&ctx.sender, "melee");
    let damage = compute_damage(melee_level, player.equip_weapon);
    let is_crit = damage > melee_level * 3;

    entity.health = (entity.health - damage).max(0);

    CombatEvent::insert(CombatEvent {
        id: 0,
        attacker_id: hex_identity(&ctx.sender),
        target_id: entity_id.to_string(),
        damage,
        damage_type: "physical".to_string(),
        is_critical: is_crit,
        timestamp: ctx.timestamp.into_micros_since_epoch(),
    }).expect("Failed to insert combat event");

    if entity.health <= 0 {
        entity.is_active = false;
        grant_xp(&ctx.sender, "melee", 25 + entity.max_health as u64 / 2);
        grant_xp(&ctx.sender, "health", 8 + entity.max_health as u64 / 6);

        // Roll loot table if available, else use hardcoded drop
        let drop = roll_loot_table(&entity.subtype, ctx.timestamp.into_micros_since_epoch());
        let (drop_id, drop_qty) = drop.unwrap_or((entity.drop_item_id, entity.drop_quantity));

        if drop_id > 0 {
            Entity::insert(Entity {
                id: 0,
                entity_type: "item_drop".to_string(),
                subtype: format!("drop_{}", drop_id),
                pos_x: entity.pos_x, pos_y: entity.pos_y,
                health: 1, max_health: 1,
                is_active: true,
                drop_item_id: drop_id,
                drop_quantity: drop_qty,
            }).expect("Failed to insert drop");
        }

        MobRespawn::insert(MobRespawn {
            id: 0,
            subtype: entity.subtype.clone(),
            pos_x: entity.pos_x,
            pos_y: entity.pos_y,
            max_health: entity.max_health,
            drop_item_id: entity.drop_item_id,
            drop_quantity: entity.drop_quantity,
            died_at: ctx.timestamp.into_micros_since_epoch(),
            respawn_after: 30_000_000,
        }).expect("Failed to schedule respawn");

        log::info!("Entity {} ({}) killed, respawn scheduled", entity_id, entity.subtype);
    }

    Entity::update_by_id(&entity_id, entity);
}

/// Pick up an item drop lying near the player.
#[spacetimedb(reducer)]
pub fn pick_up_item(ctx: ReducerContext, entity_id: u64) {
    let player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => return,
    };
    let mut entity = match Entity::filter_by_id(&entity_id) {
        Some(e) => e,
        None => return,
    };
    if !entity.is_active || entity.entity_type != "item_drop" {
        return;
    }
    let dist = euclidean_dist(player.pos_x, player.pos_y, entity.pos_x, entity.pos_y);
    if dist > 64.0 { return; }

    if add_to_inventory(&ctx.sender, entity.drop_item_id, entity.drop_quantity).is_ok() {
        entity.is_active = false;
        Entity::update_by_id(&entity_id, entity);
    }
}

/// Request terrain data for a chunk. Generates if not yet created.
#[spacetimedb(reducer)]
pub fn request_chunk(_ctx: ReducerContext, chunk_x: i32, chunk_y: i32) {
    let chunk_id = encode_chunk_id(chunk_x, chunk_y);
    if WorldChunk::filter_by_id(&chunk_id).is_none() {
        let seed = pcg_hash(chunk_x as u64 ^ (chunk_y as u64).wrapping_mul(2654435761));
        let tile_data = generate_chunk_tiles(chunk_x, chunk_y, seed);
        WorldChunk::insert(WorldChunk {
            id: chunk_id,
            chunk_x, chunk_y, tile_data,
            entity_seed: seed, generated: true,
        }).expect("Failed to insert chunk");
    }
}

/// Trigger a skill action (gathering from resource nodes).
#[spacetimedb(reducer)]
pub fn use_skill(ctx: ReducerContext, skill: String, target_id: u64) {
    let player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => return,
    };
    let entity = match Entity::filter_by_id(&target_id) {
        Some(e) => e,
        None => return,
    };

    let dist = euclidean_dist(player.pos_x, player.pos_y, entity.pos_x, entity.pos_y);
    if dist > 80.0 {
        log::warn!("use_skill: target out of range ({:.1})", dist);
        return;
    }

    match skill.as_str() {
        "gathering" => {
            if entity.entity_type != "npc" || !entity.subtype.starts_with("resource_") {
                return;
            }
            let qty = 1 + get_skill_level(&ctx.sender, "gathering") as u32 / 10;
            let _ = add_to_inventory(&ctx.sender, entity.drop_item_id, qty);
            grant_xp(&ctx.sender, "gathering", 15);
        }
        _ => {}
    }
}

/// Process pending mob respawns. Called periodically by any connected client.
#[spacetimedb(reducer)]
pub fn process_respawns(ctx: ReducerContext) {
    let now = ctx.timestamp.into_micros_since_epoch();
    let pending: Vec<MobRespawn> = MobRespawn::iter().collect();
    for respawn in pending {
        if now >= respawn.died_at + respawn.respawn_after {
            Entity::insert(Entity {
                id: 0,
                entity_type: "mob".to_string(),
                subtype: respawn.subtype.clone(),
                pos_x: respawn.pos_x,
                pos_y: respawn.pos_y,
                health: respawn.max_health,
                max_health: respawn.max_health,
                is_active: true,
                drop_item_id: respawn.drop_item_id,
                drop_quantity: respawn.drop_quantity,
            }).expect("Failed to respawn mob");
            let rid = respawn.id;
            MobRespawn::delete_by_id(&rid);
            log::info!("Mob {} respawned at ({}, {})", respawn.subtype, respawn.pos_x, respawn.pos_y);
        }
    }
}

/// Tick spawn zones: ensure each zone has its target mob count.
/// Called periodically by connected clients (every ~5s is fine).
#[spacetimedb(reducer)]
pub fn tick_spawn_zones(ctx: ReducerContext) {
    let timestamp = ctx.timestamp.into_micros_since_epoch();
    let zones: Vec<SpawnZone> = SpawnZone::iter().collect();

    for zone in zones {
        let mobs_in_zone: usize = Entity::iter()
            .filter(|e| e.entity_type == "mob" && e.is_active
                && euclidean_dist(e.pos_x, e.pos_y, zone.center_x, zone.center_y) <= zone.radius)
            .count();

        if mobs_in_zone >= zone.max_active as usize {
            continue;
        }

        let entries: Vec<(&str, u32, i32)> = zone.mob_list.split(';')
            .filter_map(|entry| {
                let parts: Vec<&str> = entry.split(':').collect();
                if parts.len() == 3 {
                    Some((parts[0], parts[1].parse().ok()?, parts[2].parse().ok()?))
                } else {
                    None
                }
            })
            .collect();

        let needed = zone.max_active as usize - mobs_in_zone;
        let mut spawned = 0;
        for (subtype, _target_count, max_hp) in &entries {
            if spawned >= needed { break; }
            let angle_seed = pcg_hash(timestamp.wrapping_add(spawned as u64 * 7919));
            let angle = (angle_seed % 360) as f32 * std::f32::consts::PI / 180.0;
            let dist_seed = pcg_hash(angle_seed);
            let dist = (dist_seed % (zone.radius as u64).max(1)) as f32 * 0.7;
            let spawn_x = zone.center_x + angle.cos() * dist;
            let spawn_y = zone.center_y + angle.sin() * dist;

            Entity::insert(Entity {
                id: 0,
                entity_type: "mob".to_string(),
                subtype: subtype.to_string(),
                pos_x: spawn_x,
                pos_y: spawn_y,
                health: *max_hp,
                max_health: *max_hp,
                is_active: true,
                drop_item_id: 0,
                drop_quantity: 0,
            }).expect("Failed to spawn zone mob");
            spawned += 1;
        }
    }
}

/// Equip an item from the player's inventory into the appropriate slot.
#[spacetimedb(reducer)]
pub fn equip_item(ctx: ReducerContext, slot_index: u32) {
    let mut player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => { log::warn!("equip_item: player not found"); return; }
    };

    let inv_slot = match InventorySlot::filter_by_player_identity(&ctx.sender)
        .find(|s| s.slot_index == slot_index) {
        Some(s) => s,
        None => { log::warn!("equip_item: slot {} empty", slot_index); return; }
    };

    let item = match ItemDefinition::filter_by_id(&inv_slot.item_id) {
        Some(i) => i,
        None => return,
    };

    let equip_slot = match item.item_type.as_str() {
        "weapon" => "weapon",
        "armor" => item.subtype.as_str(),
        _ => { log::warn!("equip_item: item {} is not equippable", item.name); return; }
    };

    let previously_equipped = match equip_slot {
        "weapon" | "melee_1h" | "ranged_bow" | "magic_staff" => player.equip_weapon,
        "helm" => player.equip_helm,
        "chest" => player.equip_chest,
        "legs" => player.equip_legs,
        "boots" => player.equip_boots,
        "ring" => player.equip_ring,
        _ => { log::warn!("equip_item: unknown slot {}", equip_slot); return; }
    };

    match equip_slot {
        "weapon" | "melee_1h" | "ranged_bow" | "magic_staff" => player.equip_weapon = inv_slot.item_id,
        "helm" => player.equip_helm = inv_slot.item_id,
        "chest" => player.equip_chest = inv_slot.item_id,
        "legs" => player.equip_legs = inv_slot.item_id,
        "boots" => player.equip_boots = inv_slot.item_id,
        "ring" => player.equip_ring = inv_slot.item_id,
        _ => return,
    }

    let sid = inv_slot.id;
    InventorySlot::delete_by_id(&sid);

    if previously_equipped > 0 {
        let _ = add_to_inventory(&ctx.sender, previously_equipped, 1);
    }

    Player::update_by_identity(&ctx.sender, player);
    log::info!("Player equipped {} in slot {}", item.name, equip_slot);
}

/// Unequip an item from an equipment slot back into the inventory.
#[spacetimedb(reducer)]
pub fn unequip_item(ctx: ReducerContext, equip_slot: String) {
    let mut player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => { log::warn!("unequip_item: player not found"); return; }
    };

    let item_id = match equip_slot.as_str() {
        "weapon" => player.equip_weapon,
        "helm" => player.equip_helm,
        "chest" => player.equip_chest,
        "legs" => player.equip_legs,
        "boots" => player.equip_boots,
        "ring" => player.equip_ring,
        _ => { log::warn!("unequip_item: unknown slot {}", equip_slot); return; }
    };

    if item_id == 0 {
        log::warn!("unequip_item: slot {} is empty", equip_slot);
        return;
    }

    if add_to_inventory(&ctx.sender, item_id, 1).is_err() {
        log::warn!("unequip_item: inventory full");
        return;
    }

    match equip_slot.as_str() {
        "weapon" => player.equip_weapon = 0,
        "helm" => player.equip_helm = 0,
        "chest" => player.equip_chest = 0,
        "legs" => player.equip_legs = 0,
        "boots" => player.equip_boots = 0,
        "ring" => player.equip_ring = 0,
        _ => return,
    }

    Player::update_by_identity(&ctx.sender, player);
    log::info!("Player unequipped from slot {}", equip_slot);
}

/// Handle player death: drop percentage of resources, respawn at bound point.
#[spacetimedb(reducer)]
pub fn player_died(ctx: ReducerContext) {
    let mut player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => return,
    };

    if player.health > 0 {
        return;
    }

    let death_pos_x = player.pos_x;
    let death_pos_y = player.pos_y;

    let inventory_slots: Vec<InventorySlot> = InventorySlot::filter_by_player_identity(&ctx.sender).collect();
    for slot in inventory_slots {
        let item = match ItemDefinition::filter_by_id(&slot.item_id) {
            Some(i) => i,
            None => continue,
        };
        if item.item_type == "material" && slot.quantity > 0 {
            let drop_qty = (slot.quantity as f32 * 0.10).ceil() as u32;
            if drop_qty > 0 {
                Entity::insert(Entity {
                    id: 0,
                    entity_type: "item_drop".to_string(),
                    subtype: format!("drop_{}", slot.item_id),
                    pos_x: death_pos_x + (slot.slot_index as f32 * 4.0 - 56.0),
                    pos_y: death_pos_y,
                    health: 1,
                    max_health: 1,
                    is_active: true,
                    drop_item_id: slot.item_id,
                    drop_quantity: drop_qty,
                }).expect("Failed to drop item on death");

                let remaining = slot.quantity - drop_qty;
                if remaining > 0 {
                    let mut updated_slot = slot.clone();
                    updated_slot.quantity = remaining;
                    let sid = updated_slot.id;
                    InventorySlot::update_by_id(&sid, updated_slot);
                } else {
                    let sid = slot.id;
                    InventorySlot::delete_by_id(&sid);
                }
            }
        }
    }

    player.health = player.max_health;
    player.mana = player.max_mana;
    player.pos_x = player.respawn_x;
    player.pos_y = player.respawn_y;
    player.chunk_x = (player.respawn_x / 1024.0).floor() as i32;
    player.chunk_y = (player.respawn_y / 1024.0).floor() as i32;
    Player::update_by_identity(&ctx.sender, player);
    log::info!("Player died and respawned");
}

/// Start crafting an item using a recipe. Consumes materials immediately.
#[spacetimedb(reducer)]
pub fn craft_item(ctx: ReducerContext, recipe_id: u32) {
    if Player::filter_by_identity(&ctx.sender).is_none() {
        return;
    }

    let recipe = match CraftingRecipe::filter_by_id(&recipe_id) {
        Some(r) => r,
        None => { log::warn!("craft_item: unknown recipe {}", recipe_id); return; }
    };

    let crafting_level = get_skill_level(&ctx.sender, "crafting");
    if crafting_level < recipe.required_level {
        log::warn!("craft_item: level {} < required {}", crafting_level, recipe.required_level);
        return;
    }

    let ingredients: Vec<(u32, u32)> = recipe.ingredients_json
        .split(';')
        .filter_map(|pair| {
            let parts: Vec<&str> = pair.split(':').collect();
            if parts.len() == 2 {
                Some((parts[0].parse().ok()?, parts[1].parse().ok()?))
            } else {
                None
            }
        })
        .collect();

    let inventory: Vec<InventorySlot> = InventorySlot::filter_by_player_identity(&ctx.sender).collect();
    for (item_id, qty_needed) in &ingredients {
        let have: u32 = inventory.iter()
            .filter(|s| s.item_id == *item_id)
            .map(|s| s.quantity)
            .sum();
        if have < *qty_needed {
            log::warn!("craft_item: insufficient material {} (have {}, need {})", item_id, have, qty_needed);
            return;
        }
    }

    for (item_id, mut qty_needed) in ingredients {
        let slots: Vec<InventorySlot> = InventorySlot::filter_by_player_identity(&ctx.sender)
            .filter(|s| s.item_id == item_id)
            .collect();
        for slot in slots {
            if qty_needed == 0 { break; }
            if slot.quantity <= qty_needed {
                qty_needed -= slot.quantity;
                let sid = slot.id;
                InventorySlot::delete_by_id(&sid);
            } else {
                let mut updated = slot.clone();
                updated.quantity -= qty_needed;
                qty_needed = 0;
                let sid = updated.id;
                InventorySlot::update_by_id(&sid, updated);
            }
        }
    }

    let _ = add_to_inventory(&ctx.sender, recipe.result_item_id, recipe.result_quantity);
    grant_xp(&ctx.sender, "crafting", recipe.xp_reward);
    log::info!("Player crafted recipe {}", recipe_id);
}

/// Drop an item from the player's inventory onto the ground.
#[spacetimedb(reducer)]
pub fn drop_item(ctx: ReducerContext, slot_index: u32, quantity: u32) {
    let player = match Player::filter_by_identity(&ctx.sender) {
        Some(p) => p,
        None => return,
    };

    let slot = match InventorySlot::filter_by_player_identity(&ctx.sender)
        .find(|s| s.slot_index == slot_index) {
        Some(s) => s,
        None => return,
    };

    if quantity == 0 || quantity > slot.quantity {
        return;
    }

    Entity::insert(Entity {
        id: 0,
        entity_type: "item_drop".to_string(),
        subtype: format!("drop_{}", slot.item_id),
        pos_x: player.pos_x,
        pos_y: player.pos_y + 20.0,
        health: 1,
        max_health: 1,
        is_active: true,
        drop_item_id: slot.item_id,
        drop_quantity: quantity,
    }).expect("Failed to drop item");

    if slot.quantity <= quantity {
        let sid = slot.id;
        InventorySlot::delete_by_id(&sid);
    } else {
        let mut updated = slot.clone();
        updated.quantity -= quantity;
        let sid = updated.id;
        InventorySlot::update_by_id(&sid, updated);
    }
}

/// Accept a quest from an NPC.
#[spacetimedb(reducer)]
pub fn accept_quest(ctx: ReducerContext, quest_id: u32) {
    if Player::filter_by_identity(&ctx.sender).is_none() {
        return;
    }
    let quest = match QuestDefinition::filter_by_id(&quest_id) {
        Some(q) => q,
        None => { log::warn!("accept_quest: unknown quest {}", quest_id); return; }
    };

    // Check if already accepted or completed
    let existing = PlayerQuest::filter_by_player_identity(&ctx.sender)
        .find(|pq| pq.quest_id == quest_id);
    if let Some(pq) = existing {
        if pq.status == "active" || pq.status == "completed" {
            log::warn!("accept_quest: quest {} already {}", quest_id, pq.status);
            return;
        }
    }

    let player_level = Player::filter_by_identity(&ctx.sender)
        .map(|p| p.level).unwrap_or(1);
    if player_level < quest.required_level {
        log::warn!("accept_quest: level {} < required {}", player_level, quest.required_level);
        return;
    }

    PlayerQuest::insert(PlayerQuest {
        id: 0,
        player_identity: ctx.sender,
        quest_id,
        current_step: 0,
        progress: 0,
        status: "active".to_string(),
        accepted_at: ctx.timestamp.into_micros_since_epoch(),
        completed_at: 0,
    }).expect("Failed to insert quest");
    log::info!("Player accepted quest: {}", quest.name);
}

/// Report progress on a quest objective. Called after kills, gathers, etc.
#[spacetimedb(reducer)]
pub fn report_quest_progress(ctx: ReducerContext, quest_id: u32, progress_amount: u32) {
    if Player::filter_by_identity(&ctx.sender).is_none() {
        return;
    }

    let mut pq = match PlayerQuest::filter_by_player_identity(&ctx.sender)
        .find(|pq| pq.quest_id == quest_id && pq.status == "active") {
        Some(pq) => pq,
        None => return,
    };

    let quest = match QuestDefinition::filter_by_id(&quest_id) {
        Some(q) => q,
        None => return,
    };

    pq.progress += progress_amount;

    // Parse objectives to find current step target
    let objectives: Vec<&str> = quest.objectives_json.split(';').collect();
    if let Some(obj) = objectives.get(pq.current_step as usize) {
        let parts: Vec<&str> = obj.split(':').collect();
        let target_qty: u32 = parts.get(2).and_then(|s| s.parse().ok()).unwrap_or(1);

        if pq.progress >= target_qty {
            pq.progress = 0;
            pq.current_step += 1;

            let total_steps = objectives.len() as u32;
            if pq.current_step >= total_steps {
                pq.status = "completed".to_string();
                pq.completed_at = ctx.timestamp.into_micros_since_epoch();

                // Grant rewards
                if !quest.reward_xp_skill.is_empty() && quest.reward_xp_amount > 0 {
                    grant_xp(&ctx.sender, &quest.reward_xp_skill, quest.reward_xp_amount);
                }
                if quest.reward_item_id > 0 {
                    let _ = add_to_inventory(&ctx.sender, quest.reward_item_id, quest.reward_item_qty);
                }
                log::info!("Player completed quest: {}", quest.name);
            }
        }
    }

    let pid = pq.id;
    PlayerQuest::update_by_id(&pid, pq);
}

/// Get the starting dialogue node for an NPC interaction.
#[spacetimedb(reducer)]
pub fn start_dialogue(_ctx: ReducerContext, _npc_subtype: String) {
    // Dialogue is read-only from client subscription to DialogueNode table.
    // This reducer exists as a placeholder for future dialogue state tracking.
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION 3: INTERNALS
// ═════════════════════════════════════════════════════════════════════════════

fn encode_chunk_id(chunk_x: i32, chunk_y: i32) -> u64 {
    ((chunk_x as u64) << 32) | ((chunk_y as u32) as u64)
}

fn pcg_hash(input: u64) -> u64 {
    let state = input.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    let word = ((state >> 22) ^ state) >> (((state >> 61) + 22) as u32);
    word.wrapping_mul(2685821657736338717)
}

fn generate_chunk_tiles(chunk_x: i32, chunk_y: i32, seed: u64) -> Vec<u8> {
    const CHUNK_SIZE: usize = 32;
    let mut tiles = vec![0u8; CHUNK_SIZE * CHUNK_SIZE];
    for y in 0..CHUNK_SIZE {
        for x in 0..CHUNK_SIZE {
            let wx = chunk_x * CHUNK_SIZE as i32 + x as i32;
            let wy = chunk_y * CHUNK_SIZE as i32 + y as i32;
            let h1 = pcg_hash(seed ^ pcg_hash(wx as u64));
            let h2 = pcg_hash(h1 ^ pcg_hash(wy as u64));
            let h3 = pcg_hash(h2 ^ seed.wrapping_add(7919));
            let n = (h3 & 0xFFFF) as f32 / 65535.0;
            let dist = ((wx * wx + wy * wy) as f32).sqrt() / 256.0;
            tiles[y * CHUNK_SIZE + x] = match (n, dist) {
                (v, _) if v < 0.08                          => 3, // WATER
                (v, d) if v < 0.20 && d < 1.5               => 1, // FOREST
                (v, _) if v < 0.22                          => 5, // DIRT
                (_, d) if d > 4.0 && pcg_hash(h2) % 4 == 0 => 6, // SNOW
                (_, d) if d > 3.0 && pcg_hash(h3) % 5 == 0 => 2, // STONE
                (v, _) if v > 0.88                          => 4, // SAND
                _                                           => 0, // GRASS
            };
        }
    }
    tiles
}

fn xp_to_level(xp: u64) -> i32 {
    (1.0 + (xp as f64 / 50.0).sqrt()).floor() as i32
}

fn get_skill_level(identity: &Identity, skill: &str) -> i32 {
    PlayerSkill::filter_by_player_identity(identity)
        .find(|s| s.skill_type == skill)
        .map(|s| s.level)
        .unwrap_or(1)
}

fn grant_xp(identity: &Identity, skill: &str, amount: u64) {
    let existing = PlayerSkill::filter_by_player_identity(identity)
        .find(|s| s.skill_type == skill);
    if let Some(mut record) = existing {
        let old_level = record.level;
        record.experience = record.experience.saturating_add(amount);
        record.level = xp_to_level(record.experience);
        if record.level > old_level {
            log::info!("Player leveled {} to {}", skill, record.level);
            if skill == "health" {
                if let Some(mut player) = Player::filter_by_identity(identity) {
                    player.max_health = 100 + (record.level - 1) * 10;
                    player.health = player.max_health;
                    Player::update_by_identity(identity, player);
                }
            }
        }
        let rid = record.id;
        PlayerSkill::update_by_id(&rid, record);
    }
}

fn compute_damage(skill_level: i32, weapon_id: u32) -> i32 {
    let base = 3 + skill_level;
    let weapon_bonus = if weapon_id > 0 { (weapon_id as i32 % 10) * 2 } else { 0 };
    (base + weapon_bonus).max(1)
}

fn euclidean_dist(x1: f32, y1: f32, x2: f32, y2: f32) -> f32 {
    ((x2 - x1).powi(2) + (y2 - y1).powi(2)).sqrt()
}

/// Roll a loot table for a given mob subtype. Returns (item_id, quantity) or None for no drop.
fn roll_loot_table(mob_subtype: &str, timestamp_seed: u64) -> Option<(u32, u32)> {
    let loot = LootTable::iter().find(|lt| lt.entity_subtype == mob_subtype)?;
    let entries: Vec<(u32, u32, u32)> = loot.entries_json
        .split(';')
        .filter_map(|entry| {
            let parts: Vec<&str> = entry.split(':').collect();
            if parts.len() == 3 {
                Some((parts[0].parse().ok()?, parts[1].parse().ok()?, parts[2].parse().ok()?))
            } else {
                None
            }
        })
        .collect();

    if entries.is_empty() {
        return None;
    }

    let total_weight: u32 = entries.iter().map(|e| e.2).sum();
    let roll = (pcg_hash(timestamp_seed) % total_weight as u64) as u32;

    let mut cumulative = 0u32;
    for (item_id, quantity, weight) in &entries {
        cumulative += weight;
        if roll < cumulative {
            return Some((*item_id, *quantity));
        }
    }
    // "Nothing" drop if total_weight < 100 and roll lands beyond entries
    None
}

fn validate_username(username: &str) -> Result<(), String> {
    if username.len() < 3 || username.len() > 20 {
        return Err("Username must be 3–20 characters".into());
    }
    if !username.chars().all(|c| c.is_alphanumeric() || c == '_') {
        return Err("Username may only contain letters, numbers, and underscores".into());
    }
    Ok(())
}

fn hex_identity(id: &Identity) -> String {
    let bytes = id.to_vec();
    bytes.iter().take(4).map(|b| format!("{:02x}", b)).collect::<Vec<_>>().join("")
}

fn add_to_inventory(identity: &Identity, item_id: u32, quantity: u32) -> Result<(), String> {
    if item_id == 0 || quantity == 0 { return Ok(()); }
    let item_def = ItemDefinition::filter_by_id(&item_id)
        .ok_or_else(|| format!("Unknown item id {}", item_id))?;

    if item_def.stackable {
        let existing = InventorySlot::filter_by_player_identity(identity)
            .find(|s| s.item_id == item_id);
        if let Some(mut slot) = existing {
            slot.quantity += quantity;
            let sid = slot.id;
            InventorySlot::update_by_id(&sid, slot);
            return Ok(());
        }
    }

    let used: std::collections::HashSet<u32> = InventorySlot::filter_by_player_identity(identity)
        .map(|s| s.slot_index)
        .collect();
    let empty_slot = (0..28u32).find(|i| !used.contains(i))
        .ok_or("Inventory is full")?;

    InventorySlot::insert(InventorySlot {
        id: 0,
        player_identity: *identity,
        slot_index: empty_slot,
        item_id, quantity,
    }).expect("Failed to insert inventory slot");
    Ok(())
}

fn seed_item_catalog() {
    macro_rules! item {
        ($id:expr, $name:expr, $desc:expr, $type:expr, $sub:expr, $stats:expr, $stack:expr, $max:expr) => {
            if ItemDefinition::filter_by_id(&$id).is_none() {
                ItemDefinition::insert(ItemDefinition {
                    id: $id, name: $name.into(), description: $desc.into(),
                    item_type: $type.into(), subtype: $sub.into(),
                    stats_json: $stats.into(), stackable: $stack, max_stack: $max,
                    icon_path: "".into(),
                }).expect("item insert failed");
            }
        };
    }
    item!(1,  "Worn Sword",          "A battered blade.",           "weapon",     "melee_1h",    r#"{"attack":3}"#,   false, 1);
    item!(2,  "Iron Sword",          "Solid iron, reliable edge.",  "weapon",     "melee_1h",    r#"{"attack":8}"#,   false, 1);
    item!(3,  "Oak Shortbow",        "Quick at range.",             "weapon",     "ranged_bow",  r#"{"attack":6}"#,   false, 1);
    item!(4,  "Apprentice Staff",    "Channels raw mana.",          "weapon",     "magic_staff", r#"{"attack":5}"#,   false, 1);
    item!(10, "Leather Helm",        "Scraped hide cap.",           "armor",      "helm",        r#"{"defense":2}"#,  false, 1);
    item!(11, "Leather Chest",       "Covers the torso.",           "armor",      "chest",       r#"{"defense":4}"#,  false, 1);
    item!(20, "Minor Health Potion", "Restores 30 HP.",             "consumable", "potion_hp",   r#"{"heal_hp":30}"#, true,  30);
    item!(21, "Minor Mana Potion",   "Restores 20 mana.",           "consumable", "potion_mana", r#"{"heal_mana":20}"#,true, 30);
    item!(30, "Copper Ore",          "Raw copper.",                 "material",   "ore",         r#"{"tier":1}"#,     true,  1000);
    item!(31, "Iron Ore",            "Dense iron ore.",             "material",   "ore",         r#"{"tier":2}"#,     true,  1000);
    item!(32, "Oak Log",             "Sturdy oak log.",             "material",   "wood",        r#"{"tier":1}"#,     true,  1000);
    item!(33, "Raw Fish",            "Needs cooking.",              "material",   "fish",        r#"{"tier":1}"#,     true,  500);
}

fn seed_crafting_recipes() {
    macro_rules! recipe {
        ($id:expr, $name:expr, $desc:expr, $result_id:expr, $result_qty:expr, $ingredients:expr, $level:expr, $xp:expr, $cat:expr) => {
            if CraftingRecipe::filter_by_id(&$id).is_none() {
                CraftingRecipe::insert(CraftingRecipe {
                    id: $id, name: $name.into(), description: $desc.into(),
                    result_item_id: $result_id, result_quantity: $result_qty,
                    ingredients_json: $ingredients.into(),
                    required_level: $level, xp_reward: $xp, category: $cat.into(),
                }).expect("recipe insert failed");
            }
        };
    }
    recipe!(1, "Iron Sword",   "Forge an iron sword from ore and wood.",  2, 1, "31:3;32:1", 5, 50, "weaponsmithing");
    recipe!(2, "Oak Shortbow", "Craft a bow from oak logs.",              3, 1, "32:4",      3, 35, "woodworking");
    recipe!(3, "Leather Helm", "Stitch a basic leather helm.",           10, 1, "30:2",      1, 20, "armorcrafting");
    recipe!(4, "Leather Chest","Assemble a leather chest piece.",        11, 1, "30:4",      2, 30, "armorcrafting");
    recipe!(5, "Minor Health Potion", "Brew a healing potion.",          20, 3, "33:2;30:1", 1, 15, "alchemy");
    recipe!(6, "Minor Mana Potion",   "Brew a mana potion.",            21, 3, "33:2;31:1", 2, 18, "alchemy");
}

fn seed_spawn_zones() {
    macro_rules! zone {
        ($id:expr, $name:expr, $cx:expr, $cy:expr, $r:expr, $mobs:expr, $max:expr, $respawn:expr) => {
            if SpawnZone::filter_by_id(&$id).is_none() {
                SpawnZone::insert(SpawnZone {
                    id: $id, name: $name.into(),
                    center_x: $cx, center_y: $cy, radius: $r,
                    mob_list: $mobs.into(), max_active: $max, respawn_seconds: $respawn,
                }).expect("zone insert failed");
            }
        };
    }
    zone!(1, "Goblin Camp",    200.0,  150.0, 180.0, "goblin:4:40;goblin_shaman:1:60", 5, 30);
    zone!(2, "Eastern Woods",  350.0, -100.0, 150.0, "goblin:3:40;wolf:2:30",          4, 25);
    zone!(3, "Southern Ruins", -180.0, -200.0, 200.0, "skeleton:3:50;goblin:2:40",      5, 35);
}

fn seed_loot_tables() {
    macro_rules! loot {
        ($id:expr, $subtype:expr, $entries:expr) => {
            if LootTable::filter_by_id(&$id).is_none() {
                LootTable::insert(LootTable {
                    id: $id, entity_subtype: $subtype.into(), entries_json: $entries.into(),
                }).expect("loot table insert failed");
            }
        };
    }
    // entries format: "item_id:quantity:weight" (weight out of 100)
    loot!(1, "goblin",         "30:1:60;20:1:15;1:1:5");    // copper ore 60%, health pot 15%, worn sword 5%, nothing 20%
    loot!(2, "goblin_shaman",  "31:1:50;21:1:20;4:1:8");    // iron ore, mana pot, staff
    loot!(3, "skeleton",       "31:2:45;2:1:10;10:1:12");   // iron ore, iron sword, leather helm
    loot!(4, "wolf",           "33:2:70;30:1:20");           // raw fish (meat), copper ore (bone)
}

fn seed_dialogues() {
    macro_rules! dialogue {
        ($id:expr, $npc:expr, $text:expr, $choices:expr, $targets:expr, $root:expr) => {
            if DialogueNode::filter_by_id(&$id).is_none() {
                DialogueNode::insert(DialogueNode {
                    id: $id, npc_subtype: $npc.into(), text: $text.into(),
                    choices: $choices.into(), choice_targets: $targets.into(), is_root: $root,
                }).expect("dialogue insert failed");
            }
        };
    }
    // Merchant Alice dialogue tree
    dialogue!(1, "merchant_alice", "Welcome, traveler! I'm Alice. How can I help you today?",
              "Tell me about this area;Do you have any work for me?;Goodbye", "2;3;0", true);
    dialogue!(2, "merchant_alice", "This is the Starter Meadows. Goblins lurk in the forests, and there are copper veins in the hills to the south. Careful out there!",
              "Anything else?;Thanks, goodbye", "1;0", false);
    dialogue!(3, "merchant_alice", "Actually, yes! The goblins have been stealing copper from my shipments. If you could clear out a few and bring me some ore, I'd reward you handsomely.",
              "I'll help! (Accept quest);Maybe later", "4;0", false);
    dialogue!(4, "merchant_alice", "Wonderful! Bring me 5 Copper Ore after defeating some goblins. Good luck out there, adventurer!",
              "On my way!", "0", false);

    // Resource node "dialogues" (simple interaction text)
    dialogue!(10, "resource_oak_tree", "A sturdy oak tree. You could chop some logs here.",
              "Chop wood;Leave", "0;0", true);
    dialogue!(11, "resource_copper", "A vein of copper ore glints in the rock face.",
              "Mine copper;Leave", "0;0", true);
    dialogue!(12, "resource_fish_spot", "Fish swirl lazily beneath the water's surface.",
              "Cast line;Leave", "0;0", true);
}

fn seed_quests() {
    macro_rules! quest {
        ($id:expr, $name:expr, $desc:expr, $giver:expr, $steps:expr, $obj:expr, $xp_skill:expr, $xp_amt:expr, $item:expr, $qty:expr, $level:expr) => {
            if QuestDefinition::filter_by_id(&$id).is_none() {
                QuestDefinition::insert(QuestDefinition {
                    id: $id, name: $name.into(), description: $desc.into(),
                    giver_npc: $giver.into(), steps_json: $steps.into(),
                    objectives_json: $obj.into(),
                    reward_xp_skill: $xp_skill.into(), reward_xp_amount: $xp_amt,
                    reward_item_id: $item, reward_item_qty: $qty, required_level: $level,
                }).expect("quest insert failed");
            }
        };
    }
    quest!(1, "Goblin Trouble",
           "Clear out goblins near the village and collect copper ore for Merchant Alice.",
           "merchant_alice",
           "Defeat 3 goblins;Collect 5 Copper Ore;Return to Alice",
           "kill:goblin:3;gather:30:5;talk:merchant_alice:1",
           "melee", 100, 2, 1, 1);

    quest!(2, "Lumberjack's Start",
           "Gather oak logs to prove your woodcutting skills.",
           "merchant_alice",
           "Gather 10 Oak Logs;Return to Alice",
           "gather:32:10;talk:merchant_alice:1",
           "gathering", 75, 32, 5, 1);

    quest!(3, "Brew Master Apprentice",
           "Learn the basics of alchemy by crafting potions.",
           "merchant_alice",
           "Gather 4 Raw Fish;Craft 3 Health Potions;Return to Alice",
           "gather:33:4;craft:5:1;talk:merchant_alice:1",
           "crafting", 60, 20, 5, 1);
}

fn seed_world_entities() {
    let goblins: &[(f32, f32)] = &[
        (160.0, 96.0), (256.0, 160.0), (-128.0, 192.0),
        (320.0, -96.0), (-192.0, -160.0), (96.0, 320.0),
    ];
    for (x, y) in goblins.iter() {
        Entity::insert(Entity {
            id: 0, entity_type: "mob".into(), subtype: "goblin".into(),
            pos_x: *x, pos_y: *y, health: 40, max_health: 40,
            is_active: true, drop_item_id: 30, drop_quantity: 1,
        }).expect("goblin insert failed");
    }

    Entity::insert(Entity {
        id: 0, entity_type: "npc".into(), subtype: "merchant_alice".into(),
        pos_x: 64.0, pos_y: 32.0, health: 100, max_health: 100,
        is_active: true, drop_item_id: 0, drop_quantity: 0,
    }).expect("merchant insert failed");

    let resources: &[(&str, f32, f32, u32)] = &[
        ("resource_oak_tree",  200.0,  50.0, 32),
        ("resource_oak_tree", -150.0,  80.0, 32),
        ("resource_copper",    180.0,-120.0, 30),
        ("resource_copper",   -200.0, -80.0, 30),
        ("resource_fish_spot",   0.0, 250.0, 33),
    ];
    for (subtype, x, y, item_id) in resources.iter() {
        Entity::insert(Entity {
            id: 0, entity_type: "npc".into(), subtype: subtype.to_string(),
            pos_x: *x, pos_y: *y, health: 1, max_health: 1,
            is_active: true, drop_item_id: *item_id, drop_quantity: 1,
        }).expect("resource insert failed");
    }
}
