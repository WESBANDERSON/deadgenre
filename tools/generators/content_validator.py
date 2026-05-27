#!/usr/bin/env python3
"""
Validates all JSON content files against their schemas.
Run this before committing new content to catch errors early.

Usage:
    python tools/generators/content_validator.py
    python tools/generators/content_validator.py --type items
"""
import json
import sys
import os
from pathlib import Path

try:
    import jsonschema
    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False

ROOT = Path(__file__).resolve().parent.parent.parent
CONTENT_DIR = ROOT / "content"
SCHEMA_DIR = CONTENT_DIR / "schema"

SCHEMA_MAP = {
    "items": "item.schema.json",
    "skills": "skill.schema.json",
    "npcs": "npc.schema.json",
    "world": "world_chunk.schema.json",
}


def load_schema(schema_name: str) -> dict:
    path = SCHEMA_DIR / schema_name
    with open(path) as f:
        return json.load(f)


def validate_file(file_path: Path, schema: dict) -> list[str]:
    errors = []
    with open(file_path) as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            return [f"{file_path}: Invalid JSON: {e}"]

    entries = data if isinstance(data, list) else [data]

    for i, entry in enumerate(entries):
        entry_id = entry.get("id", f"index_{i}")

        if not isinstance(entry, dict):
            errors.append(f"{file_path}[{i}]: Expected object, got {type(entry).__name__}")
            continue

        if "id" not in entry:
            errors.append(f"{file_path}[{i}]: Missing required field 'id'")

        if HAS_JSONSCHEMA:
            try:
                jsonschema.validate(instance=entry, schema=schema)
            except jsonschema.ValidationError as e:
                errors.append(f"{file_path} ({entry_id}): {e.message}")

    return errors


def validate_content_type(content_type: str) -> list[str]:
    schema_file = SCHEMA_MAP.get(content_type)
    if not schema_file:
        return [f"Unknown content type: {content_type}"]

    schema = load_schema(schema_file)
    content_dir = CONTENT_DIR / content_type
    errors = []

    if not content_dir.exists():
        return [f"Content directory not found: {content_dir}"]

    for json_file in sorted(content_dir.glob("*.json")):
        errors.extend(validate_file(json_file, schema))

    return errors


def main():
    content_types = sys.argv[1:] if len(sys.argv) > 1 else list(SCHEMA_MAP.keys())
    if content_types and content_types[0] == "--type":
        content_types = content_types[1:]

    all_errors = []
    total_files = 0

    for ct in content_types:
        content_dir = CONTENT_DIR / ct
        if content_dir.exists():
            files = list(content_dir.glob("*.json"))
            total_files += len(files)

        errors = validate_content_type(ct)
        all_errors.extend(errors)

    if all_errors:
        print(f"\n VALIDATION FAILED — {len(all_errors)} error(s) in {total_files} file(s):\n")
        for err in all_errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print(f"\n All {total_files} content file(s) valid.")
        sys.exit(0)


if __name__ == "__main__":
    main()
