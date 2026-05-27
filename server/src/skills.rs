use spacetimedb::{ReducerContext, Table};

/// Skill definitions. Skills are data-driven: each skill has an id, name, and
/// XP curve parameters. New skills can be added without code changes.
#[spacetimedb::table(name = skill_def, public)]
pub struct SkillDef {
    #[primary_key]
    pub skill_id: String,
    pub display_name: String,
    pub description: String,
    pub max_level: i32,
    /// XP multiplier for the standard quadratic curve: xp_for_level = base_xp * level^2
    pub base_xp: i64,
    pub icon_key: String,
}

/// Per-player skill progress.
#[spacetimedb::table(name = player_skill, public)]
pub struct PlayerSkill {
    #[primary_key]
    #[auto_inc]
    pub row_id: u64,
    pub owner: spacetimedb::Identity,
    pub skill_id: String,
    pub level: i32,
    pub xp: i64,
}

#[spacetimedb::reducer]
pub fn register_skill(
    ctx: &ReducerContext,
    skill_id: String,
    display_name: String,
    description: String,
    max_level: i32,
    base_xp: i64,
    icon_key: String,
) {
    if ctx.db.skill_def().skill_id().find(&skill_id).is_some() {
        log::warn!("Skill '{}' already registered", skill_id);
        return;
    }
    ctx.db.skill_def().insert(SkillDef {
        skill_id,
        display_name,
        description,
        max_level,
        base_xp,
        icon_key,
    });
}

#[spacetimedb::reducer]
pub fn grant_skill_xp(ctx: &ReducerContext, skill_id: String, amount: i64) {
    let owner = ctx.sender;

    let skill_def = match ctx.db.skill_def().skill_id().find(&skill_id) {
        Some(d) => d,
        None => {
            log::warn!("Unknown skill '{}'", skill_id);
            return;
        }
    };

    for ps in ctx.db.player_skill().iter() {
        if ps.owner == owner && ps.skill_id == skill_id {
            let mut updated = ps;
            updated.xp += amount;
            let new_level = compute_level(updated.xp, skill_def.base_xp);
            if new_level <= skill_def.max_level {
                updated.level = new_level;
            }
            ctx.db.player_skill().row_id().update(updated);
            return;
        }
    }

    let initial_level = compute_level(amount, skill_def.base_xp).min(skill_def.max_level);
    ctx.db.player_skill().insert(PlayerSkill {
        row_id: 0,
        owner,
        skill_id,
        level: initial_level,
        xp: amount,
    });
}

fn compute_level(xp: i64, base_xp: i64) -> i32 {
    if base_xp <= 0 {
        return 1;
    }
    let mut level = 1i32;
    let mut threshold = base_xp;
    while xp >= threshold {
        level += 1;
        threshold = base_xp * (level as i64) * (level as i64);
    }
    level
}
