use spacetimedb::{ReducerContext, Table};

/// Static item definitions. These are data-driven: content authors (human or AI)
/// populate them via reducers or bulk import. The client reads these to know what
/// items look like and do without hardcoding anything.
///
/// `item_id` is a human-readable slug (e.g. "bronze_sword") so that content files,
/// asset filenames, and database rows all share a single namespace.
#[spacetimedb::table(name = item_def, public)]
pub struct ItemDef {
    #[primary_key]
    pub item_id: String,
    pub display_name: String,
    pub description: String,
    /// Categories: "weapon", "armor", "consumable", "material", "quest", "tool"
    pub category: String,
    /// Subcategory for finer grouping: "sword", "helmet", "potion", etc.
    pub subcategory: String,
    /// Visual asset key — the client resolves this to a texture/model path.
    pub asset_key: String,
    /// Rarity tier: 0 = common, 1 = uncommon, 2 = rare, 3 = epic, 4 = legendary
    pub rarity: u8,
    pub max_stack: u32,
    pub level_requirement: i32,
    pub is_tradeable: bool,

    pub stat_attack: i32,
    pub stat_defense: i32,
    pub stat_speed: i32,
    pub stat_hp: i32,
    /// Equipment slot: "none", "head", "body", "legs", "feet", "main_hand", "off_hand", "ring", "amulet"
    pub equip_slot: String,
    /// Buy/sell base value in gold
    pub base_value: i64,
}

#[spacetimedb::reducer]
pub fn register_item(
    ctx: &ReducerContext,
    item_id: String,
    display_name: String,
    description: String,
    category: String,
    subcategory: String,
    asset_key: String,
    rarity: u8,
    max_stack: u32,
    level_requirement: i32,
    is_tradeable: bool,
    stat_attack: i32,
    stat_defense: i32,
    stat_speed: i32,
    stat_hp: i32,
    equip_slot: String,
    base_value: i64,
) {
    if ctx.db.item_def().item_id().find(&item_id).is_some() {
        log::warn!("Item '{}' already registered", item_id);
        return;
    }
    ctx.db.item_def().insert(ItemDef {
        item_id,
        display_name,
        description,
        category,
        subcategory,
        asset_key,
        rarity,
        max_stack,
        level_requirement,
        is_tradeable,
        stat_attack,
        stat_defense,
        stat_speed,
        stat_hp,
        equip_slot,
        base_value,
    });
}
