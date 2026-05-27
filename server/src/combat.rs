use spacetimedb::{ReducerContext, Table, Timestamp};

/// Active combat encounters. Each row is a fight between two entities.
/// Combat uses a tick-based system inspired by OSRS: every N seconds a
/// combat tick resolves, damage is calculated, and the row is updated.
///
/// For v1, combat is PvE only (player vs npc_instance_id). PvP follows the
/// same shape — swap target fields as needed.
#[spacetimedb::table(name = combat_state, public)]
pub struct CombatState {
    #[primary_key]
    #[auto_inc]
    pub combat_id: u64,
    pub attacker: spacetimedb::Identity,
    pub target_npc_id: u64,
    pub started_at: Timestamp,
    pub last_tick: Timestamp,
    pub attacker_hp: i32,
    pub target_hp: i32,
    pub is_active: bool,
}

/// Combat log for UI display and post-fight analysis.
#[spacetimedb::table(name = combat_log, public)]
pub struct CombatLog {
    #[primary_key]
    #[auto_inc]
    pub log_id: u64,
    pub combat_id: u64,
    pub tick: u32,
    pub source_is_player: bool,
    pub damage: i32,
    pub timestamp: Timestamp,
}

#[spacetimedb::reducer]
pub fn start_combat(ctx: &ReducerContext, target_npc_id: u64) {
    let player = match ctx.db.player().identity().find(ctx.sender) {
        Some(p) => p,
        None => return,
    };

    let npc = match ctx.db.npc_instance().instance_id().find(target_npc_id) {
        Some(n) => n,
        None => {
            log::warn!("NPC instance {} not found", target_npc_id);
            return;
        }
    };

    let now = Timestamp::now();
    ctx.db.combat_state().insert(CombatState {
        combat_id: 0,
        attacker: ctx.sender,
        target_npc_id,
        started_at: now,
        last_tick: now,
        attacker_hp: player.current_hp,
        target_hp: npc.current_hp,
        is_active: true,
    });
}

/// Called periodically (by client or scheduled reducer) to advance combat by one tick.
/// Damage formula: max(1, attacker_stat - defender_stat/2) with some variance.
#[spacetimedb::reducer]
pub fn combat_tick(ctx: &ReducerContext, combat_id: u64) {
    let mut combat = match ctx.db.combat_state().combat_id().find(combat_id) {
        Some(c) => c,
        None => return,
    };

    if !combat.is_active {
        return;
    }

    let player = match ctx.db.player().identity().find(combat.attacker) {
        Some(p) => p,
        None => return,
    };

    let npc = match ctx.db.npc_instance().instance_id().find(combat.target_npc_id) {
        Some(n) => n,
        None => return,
    };

    let npc_def = match ctx.db.npc_def().npc_id().find(&npc.npc_id) {
        Some(d) => d,
        None => return,
    };

    let now = Timestamp::now();

    let tick_count = ctx
        .db
        .combat_log()
        .iter()
        .filter(|l| l.combat_id == combat_id)
        .count() as u32;

    let player_damage = (player.attack - npc_def.defense / 2).max(1);
    combat.target_hp -= player_damage;

    ctx.db.combat_log().insert(CombatLog {
        log_id: 0,
        combat_id,
        tick: tick_count + 1,
        source_is_player: true,
        damage: player_damage,
        timestamp: now,
    });

    let npc_damage = (npc_def.attack - player.defense / 2).max(1);
    combat.attacker_hp -= npc_damage;

    ctx.db.combat_log().insert(CombatLog {
        log_id: 0,
        combat_id,
        tick: tick_count + 1,
        source_is_player: false,
        damage: npc_damage,
        timestamp: now,
    });

    if combat.target_hp <= 0 {
        combat.is_active = false;
        let mut p = player;
        let xp_reward = npc_def.xp_reward as i64;
        p.xp += xp_reward;
        ctx.db.player().identity().update(p);

        let mut dead_npc = npc;
        dead_npc.current_hp = 0;
        dead_npc.is_alive = false;
        ctx.db.npc_instance().instance_id().update(dead_npc);
    }

    if combat.attacker_hp <= 0 {
        combat.is_active = false;
        let mut p = player;
        p.current_hp = p.max_hp;
        p.pos_x = 0.0;
        p.pos_y = 0.0;
        p.pos_z = 0.0;
        ctx.db.player().identity().update(p);
    }

    combat.last_tick = now;
    ctx.db.combat_state().combat_id().update(combat);
}

#[spacetimedb::reducer]
pub fn flee_combat(ctx: &ReducerContext, combat_id: u64) {
    if let Some(mut combat) = ctx.db.combat_state().combat_id().find(combat_id) {
        if combat.attacker == ctx.sender && combat.is_active {
            combat.is_active = false;
            ctx.db.combat_state().combat_id().update(combat);
        }
    }
}
