use spacetimedb::{ReducerContext, Table};

/// World is divided into chunks. Each chunk has a type, metadata, and can be
/// loaded/unloaded by the client based on proximity. Chunk coordinates use
/// an integer grid; the client translates to world-space.
#[spacetimedb::table(name = world_chunk, public)]
pub struct WorldChunk {
    #[primary_key]
    #[auto_inc]
    pub chunk_id: u64,
    pub chunk_x: i32,
    pub chunk_z: i32,
    /// Biome/terrain type: "plains", "forest", "desert", "mountain", "town", "dungeon"
    pub terrain_type: String,
    pub display_name: String,
    /// Whether players can PvP in this chunk
    pub is_pvp_zone: bool,
    /// Whether this chunk is safe (no monsters)
    pub is_safe_zone: bool,
    /// Level range for spawns: min
    pub level_min: i32,
    /// Level range for spawns: max
    pub level_max: i32,
    /// JSON blob for extra chunk-specific data (ambient sound, music key, etc.)
    pub metadata_json: String,
}

/// Interactable world objects: trees, rocks, chests, doors, etc.
#[spacetimedb::table(name = world_object, public)]
pub struct WorldObject {
    #[primary_key]
    #[auto_inc]
    pub object_id: u64,
    pub chunk_id: u64,
    /// Object type slug: "tree_oak", "rock_iron", "chest_common", etc.
    pub object_type: String,
    pub pos_x: f32,
    pub pos_y: f32,
    pub pos_z: f32,
    /// Whether this object can currently be interacted with
    pub is_active: bool,
    /// Respawn time in seconds (0 = no respawn)
    pub respawn_seconds: u32,
    /// Skill required to interact: "" if none
    pub required_skill: String,
    pub required_skill_level: i32,
}

#[spacetimedb::reducer]
pub fn register_chunk(
    ctx: &ReducerContext,
    chunk_x: i32,
    chunk_z: i32,
    terrain_type: String,
    display_name: String,
    is_pvp_zone: bool,
    is_safe_zone: bool,
    level_min: i32,
    level_max: i32,
    metadata_json: String,
) {
    ctx.db.world_chunk().insert(WorldChunk {
        chunk_id: 0,
        chunk_x,
        chunk_z,
        terrain_type,
        display_name,
        is_pvp_zone,
        is_safe_zone,
        level_min,
        level_max,
        metadata_json,
    });
}

#[spacetimedb::reducer]
pub fn place_world_object(
    ctx: &ReducerContext,
    chunk_id: u64,
    object_type: String,
    pos_x: f32,
    pos_y: f32,
    pos_z: f32,
    respawn_seconds: u32,
    required_skill: String,
    required_skill_level: i32,
) {
    ctx.db.world_object().insert(WorldObject {
        object_id: 0,
        chunk_id,
        object_type,
        pos_x,
        pos_y,
        pos_z,
        is_active: true,
        respawn_seconds,
        required_skill,
        required_skill_level,
    });
}

#[spacetimedb::reducer]
pub fn interact_with_object(ctx: &ReducerContext, object_id: u64) {
    if let Some(mut obj) = ctx.db.world_object().object_id().find(object_id) {
        if !obj.is_active {
            log::warn!("Object {} is not active", object_id);
            return;
        }
        obj.is_active = false;
        ctx.db.world_object().object_id().update(obj);
    }
}
