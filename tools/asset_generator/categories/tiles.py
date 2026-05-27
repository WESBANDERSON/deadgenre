"""
Tile asset generation prompts.

Generated tiles are 32x32 sprites used in the TileMap.
Each tile type should look good tiled seamlessly.

AI AGENT NOTE:
  When generating tiles, always include "seamlessly tileable" in the prompt.
  The `biome` parameter sets additional context for a themed tile set.
"""

WORLD_CONTEXT = "Aethermoor, top-down 2D RPG tileset, medieval fantasy"

TILE_DESCRIPTIONS: dict[str, str] = {
    "grass":    "flat green grass tile, subtle variation in shade, no objects, ground only",
    "forest":   "dense tree canopy tile, dark green leaves, solid, no walkthrough",
    "stone":    "grey stone cobble tile, worn texture, flat ground surface",
    "water":    "blue water tile, gentle ripples, flat animated-style",
    "sand":     "tan sandy ground tile, slight grain texture, flat",
    "dirt":     "brown dirt/mud tile, earthy, slightly worn path",
    "snow":     "white snow tile, soft texture, slightly sparkled",
    "swamp":    "murky swamp tile, dark green-brown muddy water with reeds",
    "lava":     "bright orange-red lava tile, glowing cracks in dark rock",
    # Transition/decoration tiles (extend as needed)
    "grass_path": "grassy dirt path tile, worn center, grass edges",
    "stone_floor": "polished interior stone floor tile, square pattern",
    "dungeon_floor": "dark dungeon stone floor, aged, slight moss",
}


def tile(name: str, biome: str = "") -> tuple[str, str]:
    desc = TILE_DESCRIPTIONS.get(name, f"{name.replace('_', ' ')} ground tile, flat surface")
    biome_str = f"{biome} biome, " if biome else ""
    prompt = f"top-down game tile sprite, {biome_str}{desc}, seamlessly tileable, no entities"
    context = WORLD_CONTEXT
    if biome:
        context += f", {biome} biome aesthetic"
    return prompt, context


def from_name(name: str, biome: str = "") -> tuple[str, str]:
    return tile(name, biome)
