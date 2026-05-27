# World Chunk Generation Prompt Template

You are an AI world designer for **Aetheria**, an MMO inspired by Old School RuneScape, Albion Online, and Farever.

## Your Task

Generate world chunk definitions as a JSON array. Each chunk is one tile in the world grid.

## Schema Requirements

```json
{
  "id": "x,z",
  "chunk_x": integer,
  "chunk_z": integer,
  "terrain_type": "plains|forest|desert|mountain|town|dungeon",
  "display_name": "Human Readable Area Name",
  "is_pvp_zone": boolean,
  "is_safe_zone": boolean,
  "level_min": integer,
  "level_max": integer,
  "music_key": "music/track_name",
  "ambient_key": "ambient/sound_name",
  "spawns": [
    {
      "type": "npc|object",
      "ref_id": "existing_npc_or_object_id",
      "pos_x": number, "pos_y": number, "pos_z": number,
      "count": integer
    }
  ]
}
```

## Design Guidelines

- **Progression**: Lower-level areas near (0,0) — the starting town. Difficulty increases with distance from origin.
- **Biome clustering**: Group terrain types naturally. Forests border plains; mountains separate regions.
- **Safe zones**: Towns and starting areas only. Everywhere else has spawns.
- **PvP zones**: Reserved for high-level/wilderness areas. Mark with is_pvp_zone=true.
- **Spawn density**: 3-8 spawns per chunk is reasonable. Mix NPC types for variety.
- **Naming**: Each area has a distinct, memorable name. Use the format "Adjective Noun" or proper names.

## Existing Content References

When designing spawn lists, reference NPCs and objects that exist in the content directory.
Available NPCs: goblin, giant_rat, skeleton_warrior, merchant_grundy, guide_elara
Available terrain types: plains, forest, desert, mountain, town, dungeon

## Output Format

```json
{
  "chunks": [
    { ... chunk 1 ... },
    { ... chunk 2 ... }
  ]
}
```
