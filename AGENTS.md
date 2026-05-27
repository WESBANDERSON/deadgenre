# AI Contributor Guide

This repository is meant to be extended by both humans and AI agents. Optimize for clarity, explicitness, and safe incremental growth.

## Core rules

1. **Prefer addition over hidden mutation**
   Add new systems in clearly named modules. Avoid changing behavior in surprising places.

2. **Keep systems data-driven**
   If a designer might want to adjust it later, it should probably live in structured data instead of one-off code.

3. **Start at Tier 0**
   New features should first land as the smallest playable version that proves the loop.

4. **Document architectural changes**
   If a major decision changes the structure of the game, update docs and ADRs in the same change.

5. **Separate simulation from presentation**
   Server-authoritative rules should not be buried inside client visuals or UI flows.

## Preferred repo habits

- small files
- explicit names
- one clear purpose per module
- minimal magic
- stable schemas
- low nesting depth

## When adding a new gameplay system

Define these pieces separately:

- player-facing purpose
- server authority rules
- content definitions
- client presentation mapping
- analytics or validation needs
- future Tier 1 and Tier 2 expansion path

## Content conventions

Generated content should be treated as draft input until it is:

- validated
- reviewed when necessary
- mapped into structured game definitions

Avoid creating content that only exists in prompts or images without a corresponding data definition.

## Architecture conventions

- client handles feel
- server handles truth
- tools handle generation and validation
- shared schemas define contracts

If a feature crosses those boundaries, state the contract explicitly.

## Documentation expectations

When adding or changing major systems, update at least one of:

- `README.md`
- `docs/game-vision.md`
- `docs/technical-architecture.md`
- a relevant ADR or system doc

Future AI agents should be able to understand not only **what** changed, but **why** it changed.
