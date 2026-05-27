"""
Character and mob asset generation prompts.

AI AGENT NOTE:
  Add new mob/NPC types here. Keep the visual language consistent by
  including the WORLD_CONTEXT in every character prompt.
"""

WORLD_CONTEXT = (
    "deadgenre, medieval fantasy, celtic and norse aesthetic, "
    "earthy tones, top-down RPG view"
)

MOB_DESCRIPTIONS: dict[str, str] = {
    "goblin":          "small green-skinned goblin creature, pointy ears, wielding a crude club or knife",
    "goblin_shaman":   "goblin shaman in tattered robes, glowing staff, ritual markings on face",
    "wolf":            "grey timber wolf, snarling, slightly larger than a dog",
    "skeleton":        "animated skeleton warrior, wearing rusted armor, holding a bone sword",
    "dark_knight":     "imposing dark knight in black plate armor, glowing red eyes visible through visor",
    "giant_spider":    "large dark spider, hairy legs, red hourglass marking",
    "cave_troll":      "hunched cave troll, grey rocky skin, tiny eyes, heavy stone club",
    "fire_elemental":  "swirling fire elemental creature, glowing orange core, flame body",
    "undead_mage":     "undead mage in decayed robes, skull face, casting purple energy",
}

NPC_DESCRIPTIONS: dict[str, str] = {
    "merchant":        "friendly human merchant in practical travel clothes, holding a coin purse, warm expression",
    "blacksmith":      "stout dwarf blacksmith with leather apron, sooty face, hammer in hand",
    "innkeeper":       "cheerful human innkeeper in simple clothes, holding a tankard, welcoming smile",
    "guard":           "town guard in standard steel armor, spear at ready, neutral expression",
    "healer":          "elven healer in white and green robes, glowing hands, gentle expression",
    "quest_giver":     "cloaked mysterious figure with hood down, map in hand, determined look",
}


def mob(name: str) -> tuple[str, str]:
    desc = MOB_DESCRIPTIONS.get(name, f"{name.replace('_', ' ')} creature, hostile mob, menacing appearance")
    prompt = f"character sprite of {desc}, top-down view, single entity centered, game asset"
    return prompt, WORLD_CONTEXT


def npc(name: str) -> tuple[str, str]:
    desc = NPC_DESCRIPTIONS.get(name, f"{name.replace('_', ' ')} NPC character, friendly, top-down view")
    prompt = f"character sprite of {desc}, top-down view, single entity centered, game asset"
    return prompt, WORLD_CONTEXT


def from_name(name: str) -> tuple[str, str]:
    if name in MOB_DESCRIPTIONS:
        return mob(name)
    if name in NPC_DESCRIPTIONS:
        return npc(name)
    prompt = f"character sprite of {name.replace('_', ' ')}, top-down RPG game asset"
    return prompt, WORLD_CONTEXT
