"""
Character and mob asset generation prompts.

AI AGENT NOTE:
  Add new mob/NPC types here. Keep the visual language consistent by
  including the WORLD_CONTEXT in every character prompt.
"""

WORLD_CONTEXT = (
    "deadgenre, Dreadmyst-style dark fantasy, painterly stylized 2.5D, "
    "moody fog, muted cold palette pierced by warm ember accents, "
    "eerie haunted atmosphere"
)

PLAYER_DESCRIPTIONS: dict[str, str] = {
    "player_warrior":  "human warrior in dark slate plate armor, tattered cloak, glowing ember eyes visible under hood, longsword in hand",
    "player_ranger":   "human ranger in deep moss leathers and hood, witch-green glowing eyes, longbow slung across back, dagger at hip",
    "player_mage":     "human mage in midnight robes embroidered with silver runes, ghost-blue glowing eyes, gnarled staff with floating ember",
}

MOB_DESCRIPTIONS: dict[str, str] = {
    "goblin":          "small hunched goblin with sickly green skin, oversized pointed ears, snaggle teeth, rusted dagger, tattered brown loincloth",
    "goblin_shaman":   "goblin shaman in dark stitched robes, bone fetishes, gnarled staff topped with a witch-green glowing orb",
    "wolf":            "lean grey timber wolf with matted fur, snarling muzzle, faint ember glow in eyes",
    "skeleton":        "animated skeleton warrior in rusted half-plate, glowing witch-green pinpoints in eye sockets, notched bone sword",
    "dread_wraith":    "tall tattered wraith of black mist, skeletal face with witch-green eyes, ragged cloak dissolving into fog at the ground",
    "dark_knight":     "imposing dark knight in obsidian plate, ember-red eyes through visor, two-handed greatsword",
    "giant_spider":    "large dark spider with bristled legs, faint witch-green markings on abdomen",
    "cave_troll":      "hunched cave troll with cracked grey hide, tiny ember eyes, massive stone club",
    "fire_elemental":  "swirling elemental of dark cinders and ember flame, glowing molten core, drifting smoke trails",
    "undead_mage":     "undead mage in decayed slate robes, skull face with witch-green eye flames, hands wreathed in purple aether",
}

NPC_DESCRIPTIONS: dict[str, str] = {
    "merchant_alice":  "human merchant Alice in warm ochre wool cloak over slate tunic, lantern in one hand, kind weathered face, friendly smile",
    "merchant":        "human merchant in practical travel clothes, holding a coin purse, lantern at belt, warm expression",
    "blacksmith":      "stout dwarf blacksmith with soot-darkened leather apron, ember-glow forge marks on hands, heavy hammer",
    "innkeeper":       "cheerful human innkeeper in simple clothes, holding a tankard, warm expression in a foggy doorway",
    "guard":           "town guard in dull steel plate, spear at ready, lantern hanging from belt",
    "healer":          "elven healer in pale slate and witch-green robes, glowing hands, gentle expression",
    "quest_giver":     "cloaked figure with hood down, holding a worn map, weathered face, determined eyes",
}


def _wrap(desc: str) -> str:
    # All character billboards share the same framing rules so they slot
    # consistently into the 2.5D Sprite3D nodes.
    return (
        f"{desc}, "
        "single centered figure, facing camera, neutral idle pose, "
        "feet rooted at bottom of frame, transparent PNG background, "
        "tall portrait composition"
    )


def player(name: str) -> tuple[str, str]:
    desc = PLAYER_DESCRIPTIONS.get(
        name, f"player adventurer {name.replace('_', ' ')}, dark fantasy")
    return _wrap(desc), WORLD_CONTEXT


def mob(name: str) -> tuple[str, str]:
    desc = MOB_DESCRIPTIONS.get(
        name, f"{name.replace('_', ' ')} creature, hostile, menacing appearance")
    return _wrap(desc), WORLD_CONTEXT


def npc(name: str) -> tuple[str, str]:
    desc = NPC_DESCRIPTIONS.get(
        name, f"{name.replace('_', ' ')} NPC character, friendly")
    return _wrap(desc), WORLD_CONTEXT


def from_name(name: str) -> tuple[str, str]:
    if name in PLAYER_DESCRIPTIONS or name.startswith("player_"):
        return player(name)
    if name in MOB_DESCRIPTIONS:
        return mob(name)
    if name in NPC_DESCRIPTIONS:
        return npc(name)
    return _wrap(f"{name.replace('_', ' ')} character"), WORLD_CONTEXT
