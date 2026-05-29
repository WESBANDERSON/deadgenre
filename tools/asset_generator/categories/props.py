"""
Prop asset generation prompts (2.5D billboard environment objects).

Props are tall, ground-rooted billboards used in the Dreadmyst 2.5D world
(trees, rocks, ore veins, fishing pools, ruined pillars, etc.). They render
on Sprite3D nodes with billboard mode set so they always face the camera.

AI AGENT NOTE:
  - Keep prompts consistent with `dreadmyst_prop` style profile.
  - Always describe transparent background and a centered ground-rooted base.
  - Use names that match SpriteFactory archetype keys so generated PNGs
    drop into the right `client/assets/generated/props/<name>.png` path
    and override the procedural fallback automatically.
"""

WORLD_CONTEXT = (
    "deadgenre, Dreadmyst-style dark fantasy, painterly stylized 2.5D, "
    "moody fog, muted cold palette, eerie atmosphere"
)

PROP_DESCRIPTIONS: dict[str, str] = {
    "oak_tree":      "gnarled twisted oak tree, dark mossy bark, sparse withered leaves, faint pair of glowing eyes in the hollow",
    "dead_pine":     "tall dead pine tree, bare branches like claws, peeling grey bark",
    "stone_pillar":  "broken stone pillar with carved runes, lichen and moss patches, weathered slate texture",
    "copper_vein":   "rough boulder shot through with bright copper ore veins, faint orange glow in cracks",
    "iron_vein":     "rough boulder with dark iron ore veins, dull metallic sheen in cracks",
    "fish_spot":     "small pool of dark misty water with reeds at the edge, faint white ripples on the surface",
    "ruined_arch":   "ruined gothic arch of dark stone, half-collapsed, vines climbing it",
    "altar":         "weathered ritual altar of black stone, drips of dried wax, faint witch-green glow",
    "lantern_post":  "iron lantern post with cracked glass, warm ember flame inside, faint halo of fog",
    "tombstone":     "leaning moss-covered tombstone, illegible carvings, small white flowers at base",
    "mushroom_cluster": "cluster of glowing pale mushrooms with witch-green caps and slender stems",
}


def prop(name: str, biome: str = "") -> tuple[str, str]:
    desc = PROP_DESCRIPTIONS.get(
        name, f"{name.replace('_', ' ')} environment prop, ground-rooted, single object")
    biome_str = f"{biome} biome, " if biome else ""
    prompt = (
        f"{biome_str}{desc}, single centered object, "
        "transparent PNG background, feet rooted at bottom of frame, "
        "viewed from 3/4 top-down camera"
    )
    context = WORLD_CONTEXT
    if biome:
        context += f", {biome} biome aesthetic"
    return prompt, context


def from_name(name: str, biome: str = "") -> tuple[str, str]:
    return prop(name, biome)
