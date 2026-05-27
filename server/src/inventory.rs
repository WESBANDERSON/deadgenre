use spacetimedb::{ReducerContext, Table};

/// Each row is one inventory slot for a player. Slot index determines bag position.
/// Equipment is tracked separately via `equip_slot` on the item definition +
/// the `PlayerEquipment` table.
#[spacetimedb::table(name = player_inventory, public)]
pub struct PlayerInventory {
    #[primary_key]
    #[auto_inc]
    pub row_id: u64,
    pub owner: spacetimedb::Identity,
    pub item_id: String,
    pub quantity: u32,
    pub slot_index: u32,
}

#[spacetimedb::table(name = player_equipment, public)]
pub struct PlayerEquipment {
    #[primary_key]
    #[auto_inc]
    pub row_id: u64,
    pub owner: spacetimedb::Identity,
    pub item_id: String,
    /// Mirrors ItemDef.equip_slot: "head", "body", "main_hand", etc.
    pub slot: String,
}

#[spacetimedb::reducer]
pub fn add_item_to_inventory(ctx: &ReducerContext, item_id: String, quantity: u32) {
    let owner = ctx.sender;

    if ctx.db.item_def().item_id().find(&item_id).is_none() {
        log::warn!("Unknown item_id '{}'", item_id);
        return;
    }

    for inv in ctx.db.player_inventory().iter() {
        if inv.owner == owner && inv.item_id == item_id {
            let mut updated = inv;
            updated.quantity += quantity;
            ctx.db.player_inventory().row_id().update(updated);
            return;
        }
    }

    let next_slot = ctx
        .db
        .player_inventory()
        .iter()
        .filter(|i| i.owner == owner)
        .map(|i| i.slot_index)
        .max()
        .unwrap_or(0)
        + 1;

    ctx.db.player_inventory().insert(PlayerInventory {
        row_id: 0,
        owner,
        item_id,
        quantity,
        slot_index: next_slot,
    });
}

#[spacetimedb::reducer]
pub fn equip_item(ctx: &ReducerContext, item_id: String) {
    let owner = ctx.sender;

    let item_def = match ctx.db.item_def().item_id().find(&item_id) {
        Some(def) => def,
        None => {
            log::warn!("Unknown item '{}'", item_id);
            return;
        }
    };

    if item_def.equip_slot == "none" {
        log::warn!("Item '{}' is not equippable", item_id);
        return;
    }

    let has_item = ctx
        .db
        .player_inventory()
        .iter()
        .any(|i| i.owner == owner && i.item_id == item_id && i.quantity > 0);

    if !has_item {
        log::warn!("Player does not have item '{}'", item_id);
        return;
    }

    for eq in ctx.db.player_equipment().iter() {
        if eq.owner == owner && eq.slot == item_def.equip_slot {
            ctx.db.player_equipment().row_id().delete(eq.row_id);
            break;
        }
    }

    ctx.db.player_equipment().insert(PlayerEquipment {
        row_id: 0,
        owner,
        item_id,
        slot: item_def.equip_slot.clone(),
    });
}
