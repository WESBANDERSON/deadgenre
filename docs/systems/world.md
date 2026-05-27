# World System

## Overview

The world is a flat grid of chunks. Each chunk is 32x32 units and has a terrain type, spawn list, and metadata. The client loads/unloads chunks based on player proximity.

## Current Implementation (V1)

### Chunk Properties

| Property | Type | Description |
|----------|------|-------------|
| `chunk_x`, `chunk_z` | int | Grid coordinates |
| `terrain_type` | string | "plains", "forest", "desert", "mountain", "town", "dungeon" |
| `display_name` | string | Human-readable area name |
| `is_pvp_zone` | bool | PvP allowed here? |
| `is_safe_zone` | bool | No monster spawns? |
| `level_min`, `level_max` | int | Spawn level range |
| `spawns` | array | NPCs and objects to place |

### Client Rendering

`WorldSystem` creates ground planes with color-coded materials per terrain type:
- Plains: green
- Forest: dark green
- Desert: sandy yellow
- Mountain: gray
- Town: brown
- Dungeon: dark gray

### View Distance

Controlled by `Config.view_distance_chunks` (default: 3). A 7x7 grid of chunks is loaded around the player at all times.

## Enhancement Roadmap

### V2: Height Maps and Biome Blending
- Add `height_data` field to chunks (array of height values)
- Blend terrain colors at chunk boundaries
- Add simple vegetation (grass, trees) based on terrain type

### V3: Full 3D Terrain
- Replace PlaneMesh with sculpted terrain meshes
- Add water planes, caves, vertical structures
- Dynamic weather and time-of-day lighting

## World Layout (Starter Area)

```
         [-1,1]           [0,1]            [1,1]
                      Whispering       Eastern
                       Woods           Fields
         [-1,0]          [0,0]            [1,0]
       Ironridge       deadgenre        Greenfield
       Foothills      Town Square       Meadow
```

The town at (0,0) is the safe starting point. Difficulty increases with distance from origin.
