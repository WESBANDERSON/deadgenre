# Item Generation Prompt Template

You are an AI content creator for **Aetheria**, an MMO inspired by Old School RuneScape, Albion Online, and Farever.

## Your Task

Generate item definitions as a JSON array. Each item MUST conform to the schema below.

## Schema Requirements

```json
{
  "id": "lowercase_snake_case_slug",
  "display_name": "Human Readable Name",
  "description": "Flavor text. Keep it short (1-2 sentences), evocative, in-universe.",
  "category": "weapon|armor|consumable|material|quest|tool",
  "subcategory": "sword|axe|helmet|potion|ore|etc",
  "asset_key": "category/id (e.g. weapons/flame_sword)",
  "rarity": 0-4,
  "max_stack": 1 for equipment, higher for consumables/materials,
  "level_requirement": 0+,
  "is_tradeable": true|false,
  "stats": { "attack": 0, "defense": 0, "speed": 0, "hp": 0 },
  "equip_slot": "none|head|body|legs|feet|main_hand|off_hand|ring|amulet",
  "base_value": gold value (integer)
}
```

## Style Guidelines

- **Names** should feel medieval-fantasy but not generic. Lean toward evocative specifics: "Ashfang Cleaver" > "Fire Sword".
- **Descriptions** are brief and atmospheric. No mechanical stats in flavor text.
- **Balance**: Follow the power curve: rarity 0 items are level 1-10, rarity 4 items are level 80+.
- **Stat scaling**: attack ~= 5 * (1 + rarity * 0.5 + level * 0.3) for weapons. Defense similarly for armor.
- **Variety**: If generating a set, ensure distinct identities — not just palette swaps.
- **IDs**: Must be globally unique, lowercase, underscores only. Prefix with a theme if part of a set (e.g. "volcanic_" for a volcanic dungeon set).

## Power Curve Reference

| Rarity | Level Range | Attack (weapon) | Defense (armor) | Base Value |
|--------|-------------|-----------------|-----------------|------------|
| 0 (Common) | 1-10 | 5-15 | 3-10 | 10-100 |
| 1 (Uncommon) | 10-25 | 12-30 | 8-20 | 80-500 |
| 2 (Rare) | 25-50 | 25-50 | 18-35 | 400-2000 |
| 3 (Epic) | 50-75 | 45-80 | 30-55 | 1500-8000 |
| 4 (Legendary) | 75-99 | 70-120 | 50-80 | 5000-50000 |

## Output Format

Return a JSON object with an "items" key containing an array:

```json
{
  "items": [
    { ... item 1 ... },
    { ... item 2 ... }
  ]
}
```
