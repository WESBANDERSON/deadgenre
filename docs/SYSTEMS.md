# deadgenre Systems Reference

Detailed specification for each gameplay system. This is the design contract between server logic and client implementation.

---

## Skills

Eight skills cover all player progression:

| Skill | XP Actions | Benefits |
|-------|-----------|---------|
| `melee` | Fighting with melee weapons | Attack damage, weapon unlock |
| `ranged` | Fighting with bows/crossbows | Attack damage, ranged weapon unlock |
| `magic` | Casting spells | Spell damage, spell unlock |
| `defense` | Taking damage in combat | Armor class, damage reduction |
| `health` | Any combat (passive) | Maximum HP |
| `crafting` | Making items at workbenches | Crafting tier unlock |
| `gathering` | Mining, woodcutting, fishing | Resource yield, node access |
| `agility` | Traversing obstacles | Movement speed boost, shortcut access |

**XP Formula**: `level = floor(1 + sqrt(xp / 50))`  
Level 1 = 0 XP · Level 10 = ~4500 XP · Level 50 = ~122500 XP · Level 99 = ~490050 XP

---

## Combat

Real-time with cooldowns (Albion-style feel, OSRS-style tick foundation).

**Attack cycle**:
1. Player right-clicks or hotkeys an enemy → `CombatSystem.initiate_combat(player, target)`
2. Client validates range (2 tiles for melee, 7 tiles for ranged/magic)
3. Client validates cooldown (2s base, reduced by level)
4. Sends `attack_entity` reducer to server
5. Server computes: `damage = base_damage + (skill_level * 2) + weapon_bonus - target_defense`
6. Server updates entity health; if ≤0, marks inactive, schedules loot drop
7. Client subscription fires → visual hit feedback → HUD update

**Damage types**: `physical, fire, ice, lightning, poison` — all resolved server-side.

---

## Inventory

28 slots (OSRS homage). Stack size unlimited for resources, 1 for equipment.

**Slot structure** (mirrors `player_inventory` table):
- `slot_index`: 0–27
- `item_id`: references `item_definition`
- `quantity`: stack count

**Equipment** is a separate concept tracked in `player` row as `equip_*` fields (to be expanded).

---

## World & Chunks

- Chunk size: 32×32 tiles
- Tile size: 32×32 pixels
- World origin: chunk (0,0), tile (0,0)
- Coordinate system: positive X = East, positive Y = South (Godot default)

**Tile IDs** (must match between server and `TileRegistry`):
```
0 = GRASS      walkable, movement_cost=1.0
1 = FOREST     not walkable (trees, impassable)
2 = STONE      walkable, movement_cost=1.0
3 = WATER      not walkable (add BOAT skill later)
4 = SAND       walkable, movement_cost=1.2
5 = DIRT       walkable, movement_cost=1.0
6 = SNOW       walkable, movement_cost=1.4
7 = SWAMP      walkable, movement_cost=1.8
8 = LAVA       not walkable (fire resistance items later)
```

---

## Equipment

Equipment slots on the Player table: `weapon`, `helm`, `chest`, `legs`, `boots`, `ring`.

**Equip flow**:
1. Player left-clicks or right-clicks an equippable item in inventory → calls `equip_item(slot_index)` reducer
2. Server validates item exists in inventory and is equippable
3. Server puts the item_id in the correct equip field; if something was already equipped, it moves to inventory
4. Server deletes the inventory slot holding the newly equipped item
5. Client receives player row update + inventory update via subscription

**Unequip flow**:
1. Player clicks equipped item → calls `unequip_item(equip_slot_name)` reducer
2. Server validates inventory has space
3. Server moves item from equip field to inventory; zeroes the equip field

**Equippable item types**:
- `weapon` (any subtype: melee_1h, ranged_bow, magic_staff) → `equip_weapon`
- `armor` with subtype `helm` → `equip_helm`
- `armor` with subtype `chest` → `equip_chest`
- `armor` with subtype `legs` → `equip_legs`
- `armor` with subtype `boots` → `equip_boots`
- `armor` with subtype `ring` → `equip_ring`

---

## Crafting

Recipe-driven system. Recipes are seeded at server init in the `CraftingRecipe` table.

**Recipe structure**:
- `id`: unique recipe identifier
- `name`, `description`: display text
- `result_item_id`, `result_quantity`: what you get
- `ingredients_json`: semicolon-delimited `item_id:quantity` pairs (e.g. `"31:3;32:1"`)
- `required_level`: minimum crafting skill level
- `xp_reward`: crafting XP granted on success
- `category`: recipe category for UI grouping

**Craft flow**:
1. Player selects recipe in crafting panel → calls `craft_item(recipe_id)` reducer
2. Server validates crafting level >= required
3. Server checks all ingredients exist in inventory in sufficient quantities
4. Server consumes ingredients (deletes/decrements inventory slots)
5. Server grants result item + crafting XP

**Client panel** (toggle with `C` key):
- Left side: recipe list with level-gated coloring
- Right side: ingredient list with have/need counts, craft button

**Starter recipes** (Tier 0):
| ID | Name | Ingredients | Level | Category |
|----|------|-------------|-------|----------|
| 1 | Iron Sword | 3 Iron Ore + 1 Oak Log | 5 | Weaponsmithing |
| 2 | Oak Shortbow | 4 Oak Log | 3 | Woodworking |
| 3 | Leather Helm | 2 Copper Ore | 1 | Armorcrafting |
| 4 | Leather Chest | 4 Copper Ore | 2 | Armorcrafting |
| 5 | Minor Health Potion ×3 | 2 Raw Fish + 1 Copper Ore | 1 | Alchemy |
| 6 | Minor Mana Potion ×3 | 2 Raw Fish + 1 Iron Ore | 2 | Alchemy |

---

## Economy (Planned)

Player-driven, Albion-inspired:
- No NPC buy/sell shops for high-value items
- Player-to-player trading via Trade Post buildings
- Resource nodes are contested and finite (respawn on timer)
- Crafting degrades equipment, creating constant demand

---

## Respawn

**Implemented** in `player_died` reducer and client `DeathScreen`.

On death:
- Player respawns at last bound location (default: world spawn at 0,0)
- Drops 10% of carried resources (not equipment)
- Retains all skills and levels
- 3-second respawn delay (client-enforced button cooldown)

**Client flow**:
1. Player health reaches 0 → `EventBus.player_died` fires
2. `GameManager.game_state` transitions to `DEAD`
3. `DeathScreen` overlay appears with respawn timer
4. After 3s, player clicks "Respawn" → calls `player_died_reducer()`
5. Server restores HP/mana, moves player to respawn point, drops 10% resources
6. Client receives position update, hides death screen

---

## Gathering

**Implemented** in `use_skill("gathering", target_id)` reducer.

**Interaction flow**:
1. Player right-clicks a resource node (NPC entity with `resource_*` subtype)
2. Client walks toward node if out of range
3. Client calls `NetworkManager.use_skill("gathering", entity_id)`
4. Server validates range, grants items based on `gathering` level, awards XP
5. Offline mode: simulated immediately with item pickup notification

**Resource nodes** (seeded):
- `resource_oak_tree` → drops Oak Log (id 32)
- `resource_copper` → drops Copper Ore (id 30)
- `resource_fish_spot` → drops Raw Fish (id 33)

---

## Chat (Planned)

Channels: `All, Local (32-tile range), Guild, Party, Trade`

Chat is stored server-side in a `chat_message` table (ephemeral, 24h TTL). Client subscribes to messages in the player's current channels.
