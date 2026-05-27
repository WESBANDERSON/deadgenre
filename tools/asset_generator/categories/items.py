"""
Item asset generation — prompts and context for weapons, armor, consumables, materials.

Each function returns a (prompt_suffix, context) tuple for use with styles/base.py.

AI AGENT NOTE:
  Add new item subtypes here. The prompt_suffix describes the specific item;
  the context string provides world lore that anchors the visual style.
"""

WORLD_CONTEXT = (
    "Aethermoor, a medieval fantasy world with celtic and northern european aesthetic, "
    "earthy tones, worn craftsmanship, nature-infused magic"
)


def weapon(name: str, subtype: str = "melee") -> tuple[str, str]:
    """Generate a prompt for a weapon item sprite."""
    subtype_hints = {
        "melee_1h":    "single-handed sword, axe, or mace",
        "melee_2h":    "two-handed weapon, greatsword or battleaxe",
        "ranged_bow":  "shortbow or longbow",
        "magic_staff": "wooden or metal staff with glowing crystal",
        "dagger":      "small blade, lightweight",
    }
    hint = subtype_hints.get(subtype, "weapon")
    prompt = f"item sprite of {name}, {hint}, on transparent background, game inventory icon"
    return prompt, WORLD_CONTEXT


def armor(name: str, slot: str = "chest") -> tuple[str, str]:
    """Generate a prompt for an armor piece sprite."""
    prompt = f"item sprite of {name}, {slot} armor piece, worn but sturdy, game inventory icon"
    return prompt, WORLD_CONTEXT


def consumable(name: str) -> tuple[str, str]:
    """Generate a prompt for a consumable item sprite (potions, food, scrolls)."""
    prompt = f"item sprite of {name}, small consumable game item, potion bottle or scroll, game inventory icon"
    return prompt, WORLD_CONTEXT


def material(name: str, tier: int = 1) -> tuple[str, str]:
    """Generate a prompt for a crafting material sprite."""
    tier_desc = ["common", "uncommon", "rare", "epic"][min(tier - 1, 3)]
    prompt = f"item sprite of {name}, {tier_desc} crafting material, ore or wood or resource, game inventory icon"
    return prompt, WORLD_CONTEXT


def from_name(name: str) -> tuple[str, str]:
    """Infer item type from name and generate an appropriate prompt."""
    name_lower = name.lower()
    if any(w in name_lower for w in ["sword", "axe", "bow", "staff", "dagger", "blade", "mace"]):
        return weapon(name)
    if any(w in name_lower for w in ["helm", "chest", "legs", "boots", "shield", "ring", "amulet"]):
        return armor(name)
    if any(w in name_lower for w in ["potion", "scroll", "food", "fish", "bread", "cooked"]):
        return consumable(name)
    return material(name)
