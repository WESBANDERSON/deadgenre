# ADR-002: 2.5D Billboard World ("Dreadmyst meets Megabonk")

**Status:** Accepted (Tier 0 implemented)
**Date:** 2026-05-29
**Affects:** Client rendering, scene graph, camera, input, asset pipeline
**Supersedes:** Defers the open question in [ADR-001](001-2.5d-camera-and-wasd-movement.md) ("Visual Approach Options") with a concrete choice.

---

## Context

Tier-0 playtesting of the pure 2D top-down build left the game feeling flat:
the world read as a tile grid instead of a place, and the player character was
literally invisible (a colored circle drawn at runtime). NPC dialogue and
quest systems were being elaborated on top of that foundation while the core
"see your character in a world" loop wasn't yet enjoyable.

The product direction asks for:

- a **Dreadmyst** look-and-feel — moody, foggy, painterly dark fantasy where
  silhouettes carry the mood
- a **Megabonk** sense of motion — snappy WASD movement, instantly readable
  enemies, top-down camera that keeps the character center-frame
- **tab targeting** as the combat selection model
- a path that scales from cheap 2D billboards today to full 3D later, without
  invalidating server schemas, content data, or AI-generated assets

## Decision

The client renders the world in **2.5D**: a true 3D scene where characters
and props are billboard Sprite3D nodes. We adopt Godot's `Forward+` 3D
renderer, depth-tested billboards with `BILLBOARD_FIXED_Y`, and a stylized
WorldEnvironment that defines the Dreadmyst aesthetic in a single place.

### Coordinate contract

| Layer            | Unit           | Notes |
|------------------|----------------|-------|
| Server           | "world pixels" | 32 px == 1 tile. Unchanged. |
| 2D World (old)   | pixels         | 1 tile == 32 px. Still functional, kept as fallback. |
| 2.5D World3D     | world units    | 1 tile == 1 unit. XZ plane. Y is up. |

`World3D.pixel_to_world` and `World3D.world_to_pixel` are the only seam
between server pixel coordinates and 3D world units. The server schema is
unchanged.

### New modules (addition, not mutation)

```
client/scripts/world3d/
  ├── World3D.gd          # owns terrain, fog, lights, entity spawning
  ├── TerrainBuilder.gd   # builds a MeshInstance3D per chunk from tile data
  ├── OrbitCamera3D.gd    # Megabonk-style top-down orbit follow camera
  └── SpriteFactory.gd    # procedural fallback billboards in Dreadmyst palette

client/scripts/entities3d/
  ├── Entity3D.gd         # base for billboard entities
  ├── Player3D.gd         # WASD + click-to-move + tab-target
  ├── Mob3D.gd            # hostile billboard
  ├── NPC3D.gd            # friendly billboard
  └── Prop3D.gd           # static decoration billboard (trees / pillars)

client/scripts/systems/
  └── TabTargetingSystem.gd  # autoload; cycles hostiles within range
```

The 2D modules under `client/scripts/world/` and `client/scripts/entities/`
remain on disk so we can A/B compare without losing the existing implementation
or breaking systems that still reference them. The active `run/main_scene` is
`Main3D.tscn`.

### Input model

- **WASD** — camera-relative directional movement (snappy: accel 28 u/s²,
  decel 32 u/s², top speed 6 u/s ≈ 192 px/s)
- **Left click** — context: click an enemy to target+attack, click an NPC
  to talk, click ground to path
- **Right click** — context interact (gather node, talk, attack)
- **Tab** — cycle nearest hostile within 25 units; **Esc** clears target
- **Space / Enter** — attack current target
- **Q / E** — rotate orbit camera yaw
- **Mouse wheel** — zoom (clamped)
- **F** — interact with closest entity (resource / NPC)
- **1..8** — hotbar slots (existing)

### Visual language ("Dreadmyst meets Megabonk")

- Background sky: near-black navy
- Volumetric fog: cold gray-blue, dense at distance, low height fog at knees
- Moonlight directional light, low energy, slight blue tint
- Saturation 0.85, contrast 1.10, filmic tonemap, light bloom
- Terrain: per-vertex colored quads from `TileRegistry`, darkened ~40% for
  dusk mood; forest and stone tiles get a small Y bump for relief
- Characters & props: tall billboard sprites with strong silhouette and an
  ember/witchfire rim color in the eyes
- Tab target highlight: ember ground ring under the targeted enemy

## Asset pipeline

The `tools/asset_generator` pipeline now ships three new style profiles
aligned with this aesthetic:

- `dreadmyst_billboard` — 512×768 character/NPC billboards
- `dreadmyst_prop`      — 512×512 environment props
- `dreadmyst_tile`      — 256×256 seamless ground textures

A third provider, **`--provider manual`**, lets users plug in external tools
like **Midjourney** without writing a Python integration: the generator
writes the exact prompt to `client/assets/generated/<cat>/prompts.txt` and
drops a placeholder PNG at the canonical destination path. The user simply
renders the prompt elsewhere and overwrites the placeholder file. The client
auto-detects real renders vs placeholders by size, so the game keeps using
the procedural fallback until a real asset lands.

Starter batches live under `tools/asset_generator/batches/dreadmyst_*.json`.

### Procedural fallback

`SpriteFactory.gd` produces a Dreadmyst-styled billboard for every
character/prop archetype directly from code. The fallback is good enough that
the game looks coherent on first run without any AI assets generated. Real
generated assets are preferred when present (over `MIN_GENERATED_DIMENSION`).

## Tier ladder

- **Tier 0 (this ADR)** — Billboard sprites, vertex-color terrain, orbit
  camera, tab target, WASD, procedural fallback art.
- **Tier 1** — Wire generated `dreadmyst_*` assets as drop-in replacements;
  add per-direction billboard frames so characters change pose by facing;
  texture the terrain with `dreadmyst_tile` textures via a triplanar shader.
- **Tier 2** — Replace key characters and bosses with low-poly 3D models
  using the same skeleton. Server, content data, and gameplay systems do
  not change. The camera and input model are already 3D-correct.

## Consequences

- The client now requires the Forward+ renderer; GL Compatibility is no
  longer adequate. Older GPUs may need to opt into the mobile renderer
  (`renderer/rendering_method.mobile="mobile"`).
- Combat ranges are now expressed in tiles (`MELEE_RANGE_TILES`) and the
  CombatSystem converts to the active world's units. Reducer logic and
  server tables are unchanged.
- The 2D `Player`, `Mob`, `NPC`, `World` scripts are retained but no longer
  on the main scene; future cleanup may remove them once the 2.5D path is
  proven in production.
- Equipment-on-character visibility (the open question in ADR-001) becomes a
  straight content task: swap or layer character billboards based on the
  `equipment_changed` signal.

## When to revisit

Revisit if Godot deprecates Forward+ on a target platform, or if billboard
artifacts (popping, depth fighting) become a content blocker. The path to
full 3D models is described in Tier 2 above and is non-breaking.
