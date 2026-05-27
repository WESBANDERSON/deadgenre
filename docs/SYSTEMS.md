# Aethermoor Systems Reference

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

## Economy (Planned)

Player-driven, Albion-inspired:
- No NPC buy/sell shops for high-value items
- Player-to-player trading via Trade Post buildings
- Resource nodes are contested and finite (respawn on timer)
- Crafting degrades equipment, creating constant demand

---

## Respawn

On death:
- Player respawns at last bound location (default: world spawn at 0,0)
- Drops 10% of carried resources (not equipment)
- Retains all skills and levels
- 3-second immunity after respawn

---

## Chat

Channels: `All, Local (32-tile range), Guild, Party, Trade`

Chat is stored server-side in a `chat_message` table (ephemeral, 24h TTL). Client subscribes to messages in the player's current channels.
