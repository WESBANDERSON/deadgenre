# Combat System

## Overview

deadgenre uses a **tick-based combat system** inspired by Old School RuneScape. Combat resolves in discrete intervals rather than real-time, making it predictable, fair, and easy to extend.

## Current Implementation (V1)

### Parameters

| Parameter | Value | Config Key |
|-----------|-------|-----------|
| Tick interval | 2.4 seconds | `Config.combat_tick_interval` |
| Damage formula | `max(1, attacker_attack - defender_defense / 2)` | `server/src/combat.rs` |
| Death behavior | Respawn at (0,0,0), full HP | `server/src/combat.rs` |

### Server Side (`server/src/combat.rs`)

- `CombatState` table tracks active encounters
- `CombatLog` table records per-tick damage for history/analysis
- `start_combat` reducer initiates a fight
- `combat_tick` reducer resolves one round of damage exchange
- `flee_combat` reducer ends combat without resolution

### Client Side (`client/scripts/systems/combat_system.gd`)

- Maintains a tick timer synchronized with Config
- In offline/dev mode, simulates random damage
- Emits `EventBus.combat_tick` and `EventBus.combat_ended` signals
- HUD responds with damage popups and notifications

### Flow

1. Player clicks hostile NPC → `interact()` → `EventBus.combat_started`
2. `CombatSystem` starts tick timer
3. Every tick: calls `combat_tick` reducer (or simulates locally)
4. Server computes bidirectional damage, updates HP
5. Client displays damage popups via `damage_popup_requested` signal
6. On death: `combat_ended` signal, respawn or loot

## Enhancement Roadmap

### V2: Abilities and Status Effects
- Add `AbilityDef` table: cooldown, damage multiplier, effects
- Add `StatusEffect` table: buff/debuff tracking per entity
- Modify `combat_tick` to apply active abilities and status effects

### V3: PvP
- Allow `CombatState.target` to be another player Identity
- Add PvP zone checks from `WorldChunk.is_pvp_zone`
- Implement death penalties (item drop, XP loss)
