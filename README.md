# deadgenre

MMO Starter Blueprint v1 for a scalable, systems-driven MMORPG.

This blueprint is designed for:
- Small, smooth MVP first
- Low hosting and content costs early
- Clean expansion path for fidelity and feature depth
- Strong readability so future contributors can safely extend systems

---

## 1) Guiding Principles

1. **Simple systems, deep interactions**
   - Start with a tiny world and a few mechanics that combine well.
2. **Data-first content**
   - Items, mobs, abilities, quests, and recipes are authored as schema data, not hardcoded logic.
3. **Authoritative simulation**
   - Server owns truth; client is responsive but never authoritative on gameplay outcomes.
4. **Pipeline-accelerated, human-directed**
   - Content production is structured to scale while preserving artistic direction.
5. **Progressive fidelity**
   - Visual/animation/audio quality can be upgraded over time without rewriting core systems.

---

## 2) Tech Stack (v1)

### Runtime
- **Client:** Godot 4.x
- **Server/world state:** SpacetimeDB
- **Backend/system logic:** Rust modules in SpacetimeDB reducers + helper services
- **Tooling and automation:** Python (asset/gen pipelines, linting, batch jobs)

### Data and content
- **Schema format:** JSON (or JSON5) with strict JSON Schema validation
- **Asset format:** GLB/GLTF + PNG/WebP textures + OGG audio
- **Versioning:** Git + semantic content versions (e.g. `weapon.v3`)

### Observability
- Structured logs, event metrics, and replay-friendly gameplay event traces from day one.

---

## 3) Repository and Module Structure (starter)

```text
/
  README.md
  docs/
    architecture.md
    adr/
      ADR-001-authoritative-server.md
      ADR-002-data-first-content.md
  game-client/
    project.godot
    scenes/
      world/
      ui/
      entities/
    scripts/
      net/
      combat/
      inventory/
      movement/
  game-server/
    spacetime/
      src/
        modules/
          world.rs
          entities.rs
          combat.rs
          inventory.rs
          economy.rs
      schema/
        tables.rs
    services/
      content-validator/
      content-importer/
      content-jobs/
  content/
    schemas/
      item.schema.json
      weapon.schema.json
      armor.schema.json
      npc.schema.json
      monster.schema.json
      ability.schema.json
      recipe.schema.json
      loot-table.schema.json
      quest.schema.json
      zone.schema.json
    data/
      items/
      weapons/
      armors/
      npcs/
      monsters/
      abilities/
      recipes/
      loot-tables/
      quests/
      zones/
    manifests/
      import-manifest.json
  tools/
    policies/
      asset_quality_policy.md
      lore_consistency_policy.md
```

---

## 4) First 10 Schemas (MVP contracts)

All schemas include:
- `id` (string, immutable key)
- `version` (integer)
- `tags` (string[])
- `author` (`internal`)
- `status` (`draft`, `playtest`, `approved`, `deprecated`)

### 1. `zone`
Defines world partitions and environmental parameters.
- Fields: `biome`, `danger_level`, `spawn_rules`, `resource_nodes`, `music_profile`

### 2. `npc`
Non-combat and service characters.
- Fields: `role` (vendor/trainer/questgiver), `dialogue_tree_id`, `shop_table_id`, `faction`

### 3. `monster`
Combat enemies and behavior packages.
- Fields: `stats`, `ability_ids`, `aggro_profile`, `loot_table_id`, `respawn_seconds`

### 4. `ability`
Combat and utility actions.
- Fields: `cooldown_ms`, `cast_ms`, `costs`, `target_rules`, `effects[]`

### 5. `item`
Base inventory objects.
- Fields: `stack_size`, `weight`, `value_soft`, `bind_rule`, `icon_asset_id`

### 6. `weapon`
Equipable offensive item specialization.
- Fields: `weapon_type`, `attack_speed`, `damage_profile`, `ability_overrides`

### 7. `armor`
Equipable defensive item specialization.
- Fields: `slot`, `resist_profile`, `set_bonus_id`, `move_penalty`

### 8. `recipe`
Crafting transformations.
- Fields: `inputs[]`, `outputs[]`, `station_type`, `skill_requirement`, `craft_time_ms`

### 9. `loot-table`
Weighted reward definitions.
- Fields: `entries[] { item_id, weight, min, max }`, `roll_count`, `luck_scaling_rule`

### 10. `quest`
Task graphs for progression.
- Fields: `prereqs`, `steps[]`, `completion_rules`, `rewards`, `repeatable`

---

## 5) SpacetimeDB World Model (MVP)

### Core tables
1. `players`
   - identity, account linkage, progression summary
2. `characters`
   - player-owned character state, zone position, vital stats
3. `inventories`
   - slot and stack state
4. `equipment`
   - equipped item IDs by slot
5. `zones`
   - online zone metadata, capacity, shard info
6. `entities`
   - spawned NPC/monster/resource-node instances
7. `combat_states`
   - active combat, threat, cooldown timers
8. `market_orders`
   - buy/sell orders and status
9. `craft_jobs`
   - in-progress crafting
10. `world_events`
   - scheduled and active event timeline

### Reducers (authoritative actions)
- `move_character`
- `use_ability`
- `apply_damage`
- `loot_entity`
- `equip_item`
- `unequip_item`
- `start_craft`
- `complete_craft`
- `post_market_order`
- `resolve_market_trade`
- `accept_quest`
- `complete_quest_step`

### Design notes
- Reducers are deterministic and schema-driven.
- Client sends intents; server validates all constraints.
- Event stream emits compact gameplay events for replay/debug/analytics.

---

## 6) Content Production Pipeline (weapons example)

### Pipeline stages
1. **Spec drafting**
   - A content pipeline step reads the raid design brief and outputs weapon family specs.
2. **Input synthesis**
   - Convert specs into production-ready input packages.
3. **Asset production**
   - Generate concept sheets, then 3D meshes/textures.
4. **Validation gates**
   - Poly budget, texture budget, style similarity, lore checks.
5. **Auto-rig/preview**
   - Validate animation attach points and silhouette readability.
6. **Import manifest**
   - Emit machine-readable import file for client/server content sync.
7. **Human approval**
   - Approve/reject per asset tier and world zone rules.

### Quality policy highlights (`tools/policies/asset_quality_policy.md`)
- Hard fail if:
  - Triangles exceed per-tier budget
  - Texture resolution exceeds profile
  - Visual style distance from anchor exceeds threshold
  - Socket alignment or grip position is invalid
- Soft warn if:
  - Contrast/readability is weak in low-light zones
  - Rarity differentiation is unclear

### Human override policy
- Protected asset classes: bosses, story artifacts, major town landmarks, UI icons.
- Draft variants may be proposed automatically, but final publish requires human approval for protected classes.

---

## 7) “Simple but Smooth” MVP Scope

### World slice
- 1 town hub
- 2 gathering zones
- 1 combat wilderness
- 1 mini raid/dungeon

### Skills and loops
- Gathering: woodcutting, mining, harvesting
- Crafting: smithing, alchemy
- Combat: melee, ranged, magic baseline with shared ability framework

### Economy
- Player trade + simple market board
- Local prices with optional expansion to region-linked markets later

### Social
- Partying, chat, basic friends list
- Guilds/clans later

---

## 8) Progressive Fidelity Plan (no rewrites)

Build low-cost defaults, then upgrade by profile:

- `fidelity_profile = low | medium | high | cinematic`

Upgrade vectors over time:
- LOD and shader complexity
- Higher quality animation sets
- Better VFX/audio layers
- Denser environment set dressing

Rule: gameplay logic and content IDs stay stable while presentation assets evolve.

---

## 9) First Content Workflows

### Workflow A: “Generate raid weapon pack”
Input:
- Raid design brief
- Allowed motifs/materials
- Budget profile

Output:
- 12-20 candidate weapons with metadata
- Validation report
- Import manifest
- 3 recommended finalists per family

### Workflow B: “Quest expansion pass”
Input:
- Current world state + lore constraints

Output:
- 10 side quests using existing zones/NPCs
- Reward balancing against economy constraints
- Conflict report for lore continuity

### Workflow C: “Economy sanity audit”
Input:
- Trade/crafting logs and drop rates

Output:
- Inflation pressure signals
- Crafting bottleneck report
- Suggested drop/recipe weight adjustments

---

## 10) Implementation Milestones Checklist

### Milestone 0: Foundations
- [ ] Repository structure in place
- [ ] Content schema validation CLI
- [ ] ADRs for core architecture decisions
- [ ] Basic CI checks (format, lint, schema-validate)

### Milestone 1: Playable vertical slice
- [ ] Login + character spawn
- [ ] Movement replication with interpolation
- [ ] Basic combat loop (1-2 abilities per style)
- [ ] Inventory/equipment loop
- [ ] One gather -> craft -> equip chain

### Milestone 2: Living world basics
- [ ] NPC services (vendor/trainer/questgiver)
- [ ] Monster spawns + loot tables
- [ ] Quest chain with branching step(s)
- [ ] Market board and simple trade settlement

### Milestone 3: Content pipeline loop
- [ ] Weapon content pipeline online
- [ ] Validation gates integrated in CI/content import
- [ ] Human approval queue and publish toggle
- [ ] Hotload approved assets into non-critical content paths

### Milestone 4: First raid + social depth
- [ ] Raid prototype with gear progression targets
- [ ] Group finder/party polish
- [ ] Event telemetry and replay dashboards
- [ ] Balance cadence process (weekly tuning window)

---

## 11) Definition of Done (for each new system)

A new system is considered production-ready only when it has:
- Data schema + examples
- Authoritative server reducer coverage
- Client UX implementation
- Telemetry events
- Tests (unit + integration path)
- Extension notes (what can be safely modified and where approval is required)

This keeps the project legible to future developers and maintainers.
