# deadgenre

AI-native MMO foundation for a lightweight, expandable online RPG.

## Vision

This project starts with a small but polished shared-world RPG and grows into a deeper MMO over time. The guiding idea is that the game's architecture should parallel the gameplay:

- start simple
- feel good immediately
- keep every system readable by humans and future AI agents
- scale fidelity, content, and infrastructure only when they are justified

The intended design space is:

- **progression DNA:** Old School RuneScape
- **shared-world clarity:** Albion Online
- **stylized low-friction presentation:** Farever

## Recommended foundation

The current recommended stack is:

- **Client:** Godot 4 + GDScript
- **Authoritative game state:** SpacetimeDB module in Rust
- **Content/admin tooling:** TypeScript
- **Data format:** mostly text-first content definitions, versioned in-repo

Why this stack:

- Godot scenes, resources, and scripts are text-forward and AI-readable.
- GDScript is concise, easy to diff, and easy for AI to extend safely.
- Rust is a strong fit for authoritative simulation, performance, and explicit system boundaries.
- SpacetimeDB gives a direct path to real-time state sync without building a large custom backend first.
- TypeScript is a practical layer for content pipelines, validation, and lightweight internal tools.

## Project principles

1. **Simple first, depth later**  
   Every system needs a low-scope version that is fun before it gains complexity.

2. **Data-driven over hard-coded**  
   Items, NPCs, drops, encounters, and progression should be defined in data whenever possible.

3. **AI-readable by default**  
   Prefer small files, explicit naming, predictable folder structure, and decision records.

4. **Human art direction still matters**  
   AI can generate volume, but curated style packs, material libraries, and approvals define the world's identity.

5. **Scale by replacing seams, not rewriting the game**  
   Start lightweight, then upgrade rendering, simulation, pipelines, and hosting behind stable interfaces.

## Core documents

- [Game vision](docs/game-vision.md)
- [Technical architecture](docs/technical-architecture.md)
- [AI content pipeline](docs/ai-content-pipeline.md)
- [AI contributor guide](AGENTS.md)

## Initial target

Build a vertical slice that proves the product loop before chasing "full MMO" scope:

- one town
- one surrounding wilderness
- one dungeon or raid entrance
- one combat style
- three gatherable resources
- two craftable gear paths
- persistent characters
- visible other players
- smooth movement, combat feel, and progression rewards

If that slice feels good, the rest of the MMO can grow from the same patterns.

## Near-term next steps

1. Create the first architecture skeleton for:
   - `client/godot`
   - `server/spacetimedb`
   - `tools/content`
2. Define canonical schemas for:
   - items
   - NPCs
   - resource nodes
   - encounters
3. Build the vertical slice loop:
   - move
   - gather
   - fight
   - loot
   - craft
   - bank
4. Establish an art style bible and prompt packs before generating content at volume.
