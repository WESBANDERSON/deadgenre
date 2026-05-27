# AI Content Pipeline

## Goal

Use AI to accelerate content creation without letting generated content define the game's identity by accident.

AI should help with:

- volume
- variants
- draft ideation
- structured data generation
- naming and flavor text
- first-pass visual assets

Humans should retain authority over:

- style direction
- acceptance thresholds
- flagship assets
- encounter identity
- key world landmarks
- monetization-sensitive content

## Principle: style packs before content packs

Do not ask an agent to generate "a series of weapons for the new raid" until the project has:

- a style bible
- approved shape language
- material rules
- rarity language
- naming patterns
- output constraints

Without those, AI produces content volume but not world coherence.

## Asset tiers

### Tier A: Human-authored hero assets

Use for:

- key bosses
- town center landmarks
- faction iconography
- premium cosmetics
- UI branding

### Tier B: AI-generated, human-approved production assets

Use for:

- weapon sets
- armor variants
- props
- clutter
- minor NPC variants

### Tier C: Purely generated draft assets

Use for:

- prototypes
- placeholder icons
- internal concept passes
- rapid event content experiments

## Pipeline shape

```text
prompt pack
  -> generate drafts
  -> validate against style constraints
  -> human review where required
  -> convert to engine-ready formats
  -> register in content definitions
  -> test in-game
```

## Prompt pack structure

Every generation workflow should be versioned.

Suggested prompt pack fields:

- style family
- item family
- silhouette rules
- material rules
- palette constraints
- prohibited motifs
- output size / format
- naming conventions
- lore tags

Example:

```yaml
id: raid_ashen_king_weapons_v1
style_family: worn-fantasy-clean-silhouette
item_family: two-handed-weapons
palette:
  primary: charcoal
  accent: ember-orange
  trim: pale-steel
materials:
  - forged_iron
  - ash_wood
  - ember_crystal
prohibited_motifs:
  - sci-fi edges
  - glowing neon
  - ornate filigree overload
```

## Generated content should land in structured data

Agents should not directly create final game behavior in ad hoc code when they are producing content. They should populate structured definitions such as:

- item stats
- rarity
- drop source
- icon path
- mesh path
- sound family
- crafting recipe
- tags

This allows future AI agents to rebalance or reskin content without reverse-engineering custom logic.

## Validation gates

Before generated content enters the game, validate:

- file naming
- schema correctness
- stat bounds
- rarity budget
- asset dimension constraints
- palette compliance where possible
- missing references

If possible, make these validations scriptable so agents can run them automatically.

## Human touch rules

Some content should always require manual sign-off:

- faction leaders
- signature bosses
- first impression screens
- core UI icons
- biome-defining landmarks
- monetized cosmetics

The goal is not to remove human taste. It is to spend human taste where it compounds the most.

## Example agent task

Good agent brief:

"Generate 12 weapons for the Ashen King raid using prompt pack `raid_ashen_king_weapons_v1`. Output structured item definitions, draft names, icon prompts, and stat ranges consistent with tier-3 raid rewards. Do not exceed the current DPS budget or introduce new keywords."

Why this works:

- it references a style pack
- it references balance constraints
- it specifies expected outputs
- it prevents uncontrolled system drift

## Technical recommendation

Treat generated content as an import pipeline, not as direct source-of-truth editing. That means:

- keep raw generations in staging folders
- keep approved assets in production folders
- keep definitions in versioned text
- log which prompt pack and model produced each batch

This will matter later when you need to regenerate a family of assets coherently.
