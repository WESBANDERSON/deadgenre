use spacetimedb::{ReducerContext, Table};

/// NPC archetype definitions. Like items, these are data-driven: AI or human
/// authors create entries and the server/client resolve them at runtime.
#[spacetimedb::table(name = npc_def, public)]
pub struct NpcDef {
    #[primary_key]
    pub npc_id: String,
    pub display_name: String,
    pub description: String,
    /// "hostile", "friendly", "neutral", "merchant", "quest_giver"
    pub npc_type: String,
    pub asset_key: String,
    pub max_hp: i32,
    pub attack: i32,
    pub defense: i32,
    pub speed: i32,
    pub level: i32,
    pub xp_reward: i32,
    /// Comma-separated loot table entries: "item_id:weight:min_qty:max_qty"
    pub loot_table: String,
    /// Dialogue key for non-hostile NPCs
    pub dialogue_key: String,
}

/// Live NPC instances in the world. Multiple instances can share one NpcDef.
#[spacetimedb::table(name = npc_instance, public)]
pub struct NpcInstance {
    #[primary_key]
    #[auto_inc]
    pub instance_id: u64,
    pub npc_id: String,
    pub chunk_id: u64,
    pub pos_x: f32,
    pub pos_y: f32,
    pub pos_z: f32,
    pub current_hp: i32,
    pub is_alive: bool,
}

#[spacetimedb::reducer]
pub fn register_npc(
    ctx: &ReducerContext,
    npc_id: String,
    display_name: String,
    description: String,
    npc_type: String,
    asset_key: String,
    max_hp: i32,
    attack: i32,
    defense: i32,
    speed: i32,
    level: i32,
    xp_reward: i32,
    loot_table: String,
    dialogue_key: String,
) {
    if ctx.db.npc_def().npc_id().find(&npc_id).is_some() {
        log::warn!("NPC '{}' already registered", npc_id);
        return;
    }
    ctx.db.npc_def().insert(NpcDef {
        npc_id,
        display_name,
        description,
        npc_type,
        asset_key,
        max_hp,
        attack,
        defense,
        speed,
        level,
        xp_reward,
        loot_table,
        dialogue_key,
    });
}

#[spacetimedb::reducer]
pub fn spawn_npc(
    ctx: &ReducerContext,
    npc_id: String,
    chunk_id: u64,
    pos_x: f32,
    pos_y: f32,
    pos_z: f32,
) {
    let npc_def = match ctx.db.npc_def().npc_id().find(&npc_id) {
        Some(d) => d,
        None => {
            log::warn!("Unknown NPC '{}'", npc_id);
            return;
        }
    };

    ctx.db.npc_instance().insert(NpcInstance {
        instance_id: 0,
        npc_id,
        chunk_id,
        pos_x,
        pos_y,
        pos_z,
        current_hp: npc_def.max_hp,
        is_alive: true,
    });
}

#[spacetimedb::reducer]
pub fn respawn_npc(ctx: &ReducerContext, instance_id: u64) {
    if let Some(mut npc) = ctx.db.npc_instance().instance_id().find(instance_id) {
        let npc_def = match ctx.db.npc_def().npc_id().find(&npc.npc_id) {
            Some(d) => d,
            None => return,
        };
        npc.current_hp = npc_def.max_hp;
        npc.is_alive = true;
        ctx.db.npc_instance().instance_id().update(npc);
    }
}
