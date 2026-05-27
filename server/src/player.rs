use spacetimedb::{ReducerContext, Table, Timestamp};

/// Core player identity and state. Every connected client has exactly one row here.
/// Position is stored as world-space coordinates; the client interpolates visually.
#[spacetimedb::table(name = player, public)]
pub struct Player {
    #[primary_key]
    pub identity: spacetimedb::Identity,
    pub username: String,
    pub pos_x: f32,
    pub pos_y: f32,
    pub pos_z: f32,
    pub rot_y: f32,

    pub max_hp: i32,
    pub current_hp: i32,
    pub attack: i32,
    pub defense: i32,
    pub speed: i32,
    pub level: i32,
    pub xp: i64,

    pub created_at: Timestamp,
    pub last_seen: Timestamp,
    pub is_online: bool,
}

#[spacetimedb::reducer]
pub fn create_player(ctx: &ReducerContext, username: String) {
    let now = Timestamp::now();
    if ctx.db.player().identity().find(ctx.sender).is_some() {
        log::warn!("Player already exists for {:?}", ctx.sender);
        return;
    }
    ctx.db.player().insert(Player {
        identity: ctx.sender,
        username,
        pos_x: 0.0,
        pos_y: 0.0,
        pos_z: 0.0,
        rot_y: 0.0,
        max_hp: 100,
        current_hp: 100,
        attack: 10,
        defense: 10,
        speed: 5,
        level: 1,
        xp: 0,
        created_at: now,
        last_seen: now,
        is_online: true,
    });
}

#[spacetimedb::reducer]
pub fn update_player_position(ctx: &ReducerContext, x: f32, y: f32, z: f32, rot_y: f32) {
    if let Some(mut player) = ctx.db.player().identity().find(ctx.sender) {
        player.pos_x = x;
        player.pos_y = y;
        player.pos_z = z;
        player.rot_y = rot_y;
        player.last_seen = Timestamp::now();
        ctx.db.player().identity().update(player);
    }
}

#[spacetimedb::reducer]
pub fn set_online_status(ctx: &ReducerContext, online: bool) {
    if let Some(mut player) = ctx.db.player().identity().find(ctx.sender) {
        player.is_online = online;
        player.last_seen = Timestamp::now();
        ctx.db.player().identity().update(player);
    }
}
