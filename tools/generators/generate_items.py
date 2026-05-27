#!/usr/bin/env python3
"""
AI-driven item generation scaffold. This script provides the structure for
generating new item definitions using an LLM API. It produces valid JSON
files conforming to the item schema.

Usage:
    python tools/generators/generate_items.py --prompt "Create 5 rare fire-themed weapons for a volcanic dungeon"
    python tools/generators/generate_items.py --prompt "Generate a set of fishing equipment" --category tool

This is a scaffold: it generates items from templates and heuristics.
To enable full AI generation, set OPENAI_API_KEY (or your preferred LLM API key)
and uncomment the API call section.
"""
import json
import sys
import os
import random
import string
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CONTENT_DIR = ROOT / "content" / "items"
SCHEMA_PATH = ROOT / "content" / "schema" / "item.schema.json"
TEMPLATES_DIR = ROOT / "tools" / "templates"

RARITY_NAMES = ["common", "uncommon", "rare", "epic", "legendary"]
CATEGORIES = ["weapon", "armor", "consumable", "material", "tool"]
WEAPON_SUBS = ["sword", "axe", "mace", "bow", "staff", "dagger", "spear"]
ARMOR_SUBS = ["helmet", "body", "legs", "boots", "shield", "gloves"]
EQUIP_SLOTS = {
    "sword": "main_hand", "axe": "main_hand", "mace": "main_hand",
    "bow": "main_hand", "staff": "main_hand", "dagger": "main_hand",
    "spear": "main_hand", "shield": "off_hand",
    "helmet": "head", "body": "body", "legs": "legs",
    "boots": "feet", "gloves": "body",
}


def generate_id(name: str) -> str:
    slug = name.lower().replace(" ", "_").replace("'", "")
    return "".join(c for c in slug if c.isalnum() or c == "_")


def generate_from_template(
    name: str,
    category: str = "weapon",
    subcategory: str = "sword",
    rarity: int = 0,
    level: int = 1,
    description: str = "",
) -> dict:
    item_id = generate_id(name)
    stat_mult = 1 + rarity * 0.5 + level * 0.3

    stats = {"attack": 0, "defense": 0, "speed": 0, "hp": 0}
    if category == "weapon":
        stats["attack"] = int(5 * stat_mult)
    elif category == "armor":
        stats["defense"] = int(4 * stat_mult)
        stats["hp"] = int(2 * stat_mult)

    return {
        "id": item_id,
        "display_name": name,
        "description": description or f"A {RARITY_NAMES[rarity]} {subcategory}.",
        "category": category,
        "subcategory": subcategory,
        "asset_key": f"{category}s/{item_id}",
        "rarity": rarity,
        "max_stack": 1 if category in ("weapon", "armor") else 20,
        "level_requirement": level,
        "is_tradeable": True,
        "stats": stats,
        "equip_slot": EQUIP_SLOTS.get(subcategory, "none"),
        "base_value": int(10 * stat_mult * (1 + rarity)),
    }


def generate_batch_from_prompt(prompt: str, count: int = 5, category: str = "weapon") -> list[dict]:
    """
    Scaffold: generates items using templates and randomization.
    Replace this function body with an LLM API call for true AI generation.
    """
    # --- LLM integration point ---
    # To enable:
    #   1. pip install openai
    #   2. Set OPENAI_API_KEY environment variable
    #   3. Uncomment the block below and comment out the template fallback
    #
    # import openai
    # client = openai.OpenAI()
    # schema = json.loads(SCHEMA_PATH.read_text())
    # system_prompt = (TEMPLATES_DIR / "item_generation.md").read_text()
    # response = client.chat.completions.create(
    #     model="gpt-4o",
    #     messages=[
    #         {"role": "system", "content": system_prompt},
    #         {"role": "user", "content": f"Generate {count} items. Context: {prompt}. Category: {category}. Output valid JSON array."},
    #     ],
    #     response_format={"type": "json_object"},
    # )
    # return json.loads(response.choices[0].message.content)["items"]

    prefixes = ["Flame", "Shadow", "Crystal", "Ancient", "Storm", "Void", "Iron", "Golden"]
    items = []
    sub = random.choice(WEAPON_SUBS if category == "weapon" else ARMOR_SUBS)

    for i in range(count):
        rarity = min(i, 4)
        level = 1 + i * 10
        prefix = random.choice(prefixes)
        name = f"{prefix} {sub.title()}"
        item = generate_from_template(
            name=name,
            category=category,
            subcategory=sub,
            rarity=rarity,
            level=level,
            description=f"Generated from prompt: {prompt[:50]}...",
        )
        items.append(item)

    return items


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Generate item definitions")
    parser.add_argument("--prompt", required=True, help="Description of items to generate")
    parser.add_argument("--count", type=int, default=5, help="Number of items")
    parser.add_argument("--category", default="weapon", choices=CATEGORIES)
    parser.add_argument("--output", help="Output file (default: auto-named in content/items/)")
    args = parser.parse_args()

    items = generate_batch_from_prompt(args.prompt, args.count, args.category)

    if args.output:
        output_path = Path(args.output)
    else:
        slug = generate_id(args.prompt[:30])
        output_path = CONTENT_DIR / f"generated_{slug}.json"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(items, f, indent=2)

    print(f"Generated {len(items)} items -> {output_path}")
    for item in items:
        print(f"  [{RARITY_NAMES[item['rarity']]}] {item['display_name']} (Lv.{item['level_requirement']})")


if __name__ == "__main__":
    main()
