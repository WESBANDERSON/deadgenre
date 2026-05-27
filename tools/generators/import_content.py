#!/usr/bin/env python3
"""
Imports JSON content definitions into a running SpacetimeDB instance.
Reads content files and calls the appropriate register_* reducers.

Usage:
    python tools/generators/import_content.py --type items
    python tools/generators/import_content.py --type all
    python tools/generators/import_content.py --type items --file content/items/starter_weapons.json

Requires: spacetime CLI installed and a running SpacetimeDB instance.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CONTENT_DIR = ROOT / "content"

DEFAULT_MODULE = "deadgenre"


def spacetime_call(reducer: str, args: list[str], module: str = DEFAULT_MODULE):
    cmd = ["spacetime", "call", reducer] + args
    print(f"  > {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"    ERROR: {result.stderr.strip()}")
    return result.returncode == 0


def import_items(file_path: Path) -> int:
    with open(file_path) as f:
        data = json.load(f)
    entries = data if isinstance(data, list) else [data]
    count = 0

    for item in entries:
        stats = item.get("stats", {})
        args = [
            item["id"],
            item["display_name"],
            item.get("description", ""),
            item["category"],
            item.get("subcategory", ""),
            item.get("asset_key", ""),
            str(item.get("rarity", 0)),
            str(item.get("max_stack", 1)),
            str(item.get("level_requirement", 0)),
            str(item.get("is_tradeable", True)).lower(),
            str(stats.get("attack", 0)),
            str(stats.get("defense", 0)),
            str(stats.get("speed", 0)),
            str(stats.get("hp", 0)),
            item.get("equip_slot", "none"),
            str(item.get("base_value", 0)),
        ]
        if spacetime_call("register_item", args):
            count += 1

    return count


def import_skills(file_path: Path) -> int:
    with open(file_path) as f:
        data = json.load(f)
    entries = data if isinstance(data, list) else [data]
    count = 0

    for skill in entries:
        args = [
            skill["id"],
            skill["display_name"],
            skill.get("description", ""),
            str(skill.get("max_level", 99)),
            str(skill.get("base_xp", 100)),
            skill.get("icon_key", ""),
        ]
        if spacetime_call("register_skill", args):
            count += 1

    return count


def import_npcs(file_path: Path) -> int:
    with open(file_path) as f:
        data = json.load(f)
    entries = data if isinstance(data, list) else [data]
    count = 0

    for npc in entries:
        loot = npc.get("loot_table", [])
        loot_str = ",".join(
            f"{e['item_id']}:{e['weight']}:{e.get('min_qty',1)}:{e.get('max_qty',1)}"
            for e in loot
        )
        args = [
            npc["id"],
            npc["display_name"],
            npc.get("description", ""),
            npc["npc_type"],
            npc.get("asset_key", ""),
            str(npc.get("max_hp", 50)),
            str(npc.get("attack", 5)),
            str(npc.get("defense", 5)),
            str(npc.get("speed", 3)),
            str(npc.get("level", 1)),
            str(npc.get("xp_reward", 10)),
            loot_str,
            npc.get("dialogue_key", ""),
        ]
        if spacetime_call("register_npc", args):
            count += 1

    return count


def import_world(file_path: Path) -> int:
    with open(file_path) as f:
        data = json.load(f)
    entries = data if isinstance(data, list) else [data]
    count = 0

    for chunk in entries:
        metadata = {
            k: chunk[k]
            for k in ("music_key", "ambient_key", "spawns")
            if k in chunk
        }
        args = [
            str(chunk["chunk_x"]),
            str(chunk["chunk_z"]),
            chunk["terrain_type"],
            chunk.get("display_name", ""),
            str(chunk.get("is_pvp_zone", False)).lower(),
            str(chunk.get("is_safe_zone", False)).lower(),
            str(chunk.get("level_min", 1)),
            str(chunk.get("level_max", 5)),
            json.dumps(metadata),
        ]
        if spacetime_call("register_chunk", args):
            count += 1

    return count


IMPORTERS = {
    "items": import_items,
    "skills": import_skills,
    "npcs": import_npcs,
    "world": import_world,
}


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Import content into SpacetimeDB")
    parser.add_argument("--type", required=True, help="Content type or 'all'")
    parser.add_argument("--file", help="Specific file to import")
    parser.add_argument("--module", default=DEFAULT_MODULE, help="SpacetimeDB module name")
    args = parser.parse_args()

    global DEFAULT_MODULE
    DEFAULT_MODULE = args.module

    types = list(IMPORTERS.keys()) if args.type == "all" else [args.type]

    total = 0
    for ct in types:
        importer = IMPORTERS.get(ct)
        if not importer:
            print(f"Unknown content type: {ct}")
            continue

        if args.file:
            files = [Path(args.file)]
        else:
            content_dir = CONTENT_DIR / ct
            files = sorted(content_dir.glob("*.json"))

        for f in files:
            print(f"\nImporting {ct} from {f.name}...")
            count = importer(f)
            total += count
            print(f"  Imported {count} entries.")

    print(f"\nTotal imported: {total}")


if __name__ == "__main__":
    main()
