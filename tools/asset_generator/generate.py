#!/usr/bin/env python3
"""
deadgenre Asset Generator
——————————————————————————
Generate AI sprites for any game content category.

Usage:
  python generate.py --category items --batch "iron_sword,fire_staff"
  python generate.py --category tiles --batch "lava_floor" --biome "volcanic"
  python generate.py --category characters --batch "goblin_shaman"
  python generate.py --batch-file batches/fire_raid.json
  python generate.py --list-styles
  python generate.py --list-categories

The generated assets are placed in client/assets/generated/<category>/
and logged to client/assets/generated/manifest.json.

Every generation is reproducible: the manifest stores prompts, model,
and parameters so the same asset can be regenerated identically.

AI AGENT GUIDE:
  - To generate a batch of raid weapons: use --category items --batch with comma-separated names
  - To change the visual style: pass --style <profile_name> (see --list-styles)
  - To generate for a new biome: pass --biome "biome description"
  - The manifest.json is machine-readable; check it to avoid regenerating existing assets
"""

import argparse
import base64
import json
import os
import sys
import time
import hashlib
from pathlib import Path
from datetime import datetime, timezone

# Add parent dir to path for config import
sys.path.insert(0, str(Path(__file__).resolve().parent))

import config
from styles.base import build_prompt, build_negative_prompt
from categories import items as items_cat
from categories import characters as chars_cat
from categories import tiles as tiles_cat
from categories import props as props_cat


# ─────────────────────────────────────────────────────────────────────────────
# Manifest Management
# ─────────────────────────────────────────────────────────────────────────────

def load_manifest() -> dict:
    if config.MANIFEST_PATH.exists():
        with open(config.MANIFEST_PATH) as f:
            return json.load(f)
    return {"assets": {}}


def save_manifest(manifest: dict) -> None:
    config.MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(config.MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2)


def manifest_key(category: str, name: str, style: str) -> str:
    return f"{category}/{name}/{style}"


# ─────────────────────────────────────────────────────────────────────────────
# Prompt Building
# ─────────────────────────────────────────────────────────────────────────────

def build_asset_prompt(category: str, name: str, style_name: str,
                       biome: str = "", extra: str = "") -> tuple[str, str]:
    """Returns (positive_prompt, negative_prompt)."""
    style = config.STYLE_PROFILES[style_name]

    # Get category-specific prompt components
    if category in ("items",):
        user_prompt, context = items_cat.from_name(name)
    elif category in ("characters", "mobs", "npcs"):
        user_prompt, context = chars_cat.from_name(name)
    elif category in ("tiles",):
        user_prompt, context = tiles_cat.from_name(name, biome)
    elif category in ("props",):
        user_prompt, context = props_cat.from_name(name, biome)
    else:
        user_prompt = f"{name.replace('_', ' ')}, game asset"
        context = ""

    if extra:
        user_prompt += f", {extra}"
    if biome and category not in ("tiles",):
        context += f", {biome} environment"

    positive = build_prompt(style, user_prompt, context)
    negative = build_negative_prompt(style)
    config.validate_prompt(positive)
    return positive, negative


# ─────────────────────────────────────────────────────────────────────────────
# Image Generation Backends
# ─────────────────────────────────────────────────────────────────────────────

def generate_openai(prompt: str, style: config.StyleProfile) -> bytes:
    """Generate image via OpenAI DALL-E 3. Returns raw PNG bytes."""
    try:
        import openai
    except ImportError:
        print("  ERROR: 'openai' package not installed. Run: pip install openai")
        sys.exit(1)

    if not config.OPENAI_API_KEY:
        print("  ERROR: OPENAI_API_KEY is not set.")
        sys.exit(1)

    client = openai.OpenAI(api_key=config.OPENAI_API_KEY)
    response = client.images.generate(
        model=config.OPENAI_IMAGE_MODEL,
        prompt=prompt,
        size=f"{style.width}x{style.height}",
        quality="standard",
        response_format="b64_json",
        n=1,
    )
    return base64.b64decode(response.data[0].b64_json)


def generate_replicate(positive: str, negative: str, style: config.StyleProfile) -> bytes:
    """Generate image via Replicate (Stable Diffusion). Returns raw PNG bytes."""
    try:
        import replicate
        import requests
    except ImportError:
        print("  ERROR: 'replicate' and 'requests' packages needed. Run: pip install replicate requests")
        sys.exit(1)

    if not config.REPLICATE_API_TOKEN:
        print("  ERROR: REPLICATE_API_TOKEN is not set.")
        sys.exit(1)

    output = replicate.run(
        config.REPLICATE_MODEL,
        input={
            "prompt": positive,
            "negative_prompt": negative,
            "width": style.width,
            "height": style.height,
            "num_inference_steps": style.steps,
        }
    )
    url = output[0] if isinstance(output, list) else str(output)
    import requests
    return requests.get(url).content


def generate_manual(positive: str, negative: str, style: config.StyleProfile,
                    category: str, name: str) -> bytes:
    """Manual provider — write the prompt + target path; user fills the PNG.

    Use case: external image services like Midjourney or NovelAI where there
    is no programmatic API the user wants to wire up. This provider writes
    a placeholder transparent PNG to the canonical path AND appends a row
    to `prompts.txt` so the user can paste the prompt elsewhere and overwrite
    the placeholder file with the rendered image.
    """
    subdir = config.CATEGORY_DIRS.get(category, category)
    output_dir = config.GENERATED_OUTPUT / subdir
    output_dir.mkdir(parents=True, exist_ok=True)
    prompts_log = output_dir / "prompts.txt"
    with open(prompts_log, "a") as fp:
        fp.write(f"--- {name} [{style.name}] ---\n")
        fp.write(f"POSITIVE: {positive}\n")
        if negative:
            fp.write(f"NEGATIVE: {negative}\n")
        fp.write(f"TARGET  : {(output_dir / (name + '.png')).relative_to(config.REPO_ROOT)}\n")
        fp.write(f"SIZE    : {style.output_width}x{style.output_height}\n\n")
    # Tiny transparent PNG placeholder so the manifest path exists. The user
    # is expected to overwrite this file with a real render.
    transparent_png = bytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
    ])
    print(f"        MANUAL: prompt logged to {prompts_log.relative_to(config.REPO_ROOT)}")
    print(f"        Drop the rendered PNG at: {(output_dir / (name + '.png')).relative_to(config.REPO_ROOT)}")
    return transparent_png


def generate_image(positive: str, negative: str, style: config.StyleProfile,
                   provider: str, category: str = "", name: str = "") -> bytes:
    if provider == "openai":
        return generate_openai(positive, style)
    elif provider == "replicate":
        return generate_replicate(positive, negative, style)
    elif provider == "manual":
        return generate_manual(positive, negative, style, category, name)
    else:
        print(f"  ERROR: Unknown provider '{provider}'")
        sys.exit(1)


# ─────────────────────────────────────────────────────────────────────────────
# Image Post-Processing
# ─────────────────────────────────────────────────────────────────────────────

def postprocess(raw_bytes: bytes, style: config.StyleProfile) -> bytes:
    """
    Resize generated image to the output dimensions using nearest-neighbor
    resampling (critical for pixel art — never use bilinear/bicubic).
    """
    try:
        from PIL import Image
        import io
        img = Image.open(io.BytesIO(raw_bytes)).convert("RGBA")
        img = img.resize(
            (style.output_width, style.output_height),
            Image.Resampling.NEAREST
        )
        out = io.BytesIO()
        img.save(out, format="PNG")
        return out.getvalue()
    except ImportError:
        # Pillow not available — return raw image unchanged
        print("  WARNING: Pillow not installed; skipping resize. pip install Pillow")
        return raw_bytes


# ─────────────────────────────────────────────────────────────────────────────
# Asset Writing
# ─────────────────────────────────────────────────────────────────────────────

def write_asset(image_bytes: bytes, category: str, name: str) -> Path:
    subdir = config.CATEGORY_DIRS.get(category, category)
    output_dir = config.GENERATED_OUTPUT / subdir
    output_dir.mkdir(parents=True, exist_ok=True)
    filename = name.lower().replace(" ", "_") + ".png"
    path = output_dir / filename
    with open(path, "wb") as f:
        f.write(image_bytes)
    return path


# ─────────────────────────────────────────────────────────────────────────────
# Main Generation Flow
# ─────────────────────────────────────────────────────────────────────────────

def generate_asset(
    category: str,
    name: str,
    style_name: str,
    provider: str,
    biome: str = "",
    extra_prompt: str = "",
    dry_run: bool = False,
    skip_existing: bool = True,
) -> dict | None:
    """Generate and save a single asset. Returns the manifest entry or None on skip."""
    manifest = load_manifest()
    key = manifest_key(category, name, style_name)

    if skip_existing and key in manifest["assets"]:
        path = manifest["assets"][key]["path"]
        if Path(path).exists():
            print(f"  SKIP  {name} (already in manifest: {path})")
            return None

    print(f"  GEN   [{style_name}] {category}/{name} ...")

    style = config.STYLE_PROFILES[style_name]
    positive, negative = build_asset_prompt(category, name, style_name, biome, extra_prompt)

    if dry_run:
        print(f"        Prompt: {positive[:120]}...")
        return {"dry_run": True, "prompt": positive}

    try:
        raw = generate_image(positive, negative, style, provider, category, name)
        # Manual provider already returns a tiny placeholder; do not resize it.
        processed = raw if provider == "manual" else postprocess(raw, style)
        path = write_asset(processed, category, name)
        prompt_hash = hashlib.md5(positive.encode()).hexdigest()[:8]

        entry = {
            "category":   category,
            "name":       name,
            "style":      style_name,
            "provider":   provider,
            "path":       str(path),
            "prompt":     positive,
            "negative":   negative,
            "prompt_hash": prompt_hash,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "size":       f"{style.output_width}x{style.output_height}",
        }
        manifest["assets"][key] = entry
        save_manifest(manifest)
        print(f"  SAVED {path.relative_to(config.REPO_ROOT)}")
        return entry

    except Exception as e:
        print(f"  ERROR generating {name}: {e}")
        return None


def run_batch(
    category: str,
    names: list[str],
    style_name: str,
    provider: str,
    biome: str = "",
    extra_prompt: str = "",
    dry_run: bool = False,
    skip_existing: bool = True,
    delay: float = 1.0,
) -> list[dict]:
    """Generate a list of assets, respecting rate limits with delay between calls."""
    results = []
    total = len(names)
    for i, name in enumerate(names, 1):
        print(f"\n[{i}/{total}] {name}")
        result = generate_asset(
            category, name.strip(), style_name, provider,
            biome, extra_prompt, dry_run, skip_existing
        )
        if result:
            results.append(result)
        if not dry_run and i < total:
            time.sleep(delay)
    return results


# ─────────────────────────────────────────────────────────────────────────────
# CLI Entry Point
# ─────────────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="deadgenre AI Asset Generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage:")[1].split("AI AGENT")[0].strip(),
    )
    parser.add_argument("--category", "-c",
        choices=list(config.CATEGORY_DIRS.keys()),
        help="Asset category to generate")
    parser.add_argument("--batch", "-b",
        help="Comma-separated list of asset names (e.g. 'iron_sword,fire_staff')")
    parser.add_argument("--batch-file", "-f",
        help="Path to a JSON batch file")
    parser.add_argument("--style", "-s",
        default="pixel_art_32",
        choices=list(config.STYLE_PROFILES.keys()),
        help="Visual style profile (default: pixel_art_32)")
    parser.add_argument("--provider", "-p",
        default=config.DEFAULT_PROVIDER,
        choices=["openai", "replicate", "manual"],
        help="AI provider to use (manual logs prompts for external tools like Midjourney)")
    parser.add_argument("--biome",
        default="",
        help="Optional biome context (e.g. 'volcanic', 'arctic')")
    parser.add_argument("--extra",
        default="",
        help="Extra prompt text appended to every asset in this batch")
    parser.add_argument("--delay",
        type=float, default=1.5,
        help="Seconds between API calls (default: 1.5)")
    parser.add_argument("--dry-run",
        action="store_true",
        help="Print prompts without calling the API")
    parser.add_argument("--force",
        action="store_true",
        help="Regenerate even if asset already exists in manifest")
    parser.add_argument("--list-styles",
        action="store_true",
        help="List available style profiles and exit")
    parser.add_argument("--list-categories",
        action="store_true",
        help="List available categories and exit")
    parser.add_argument("--show-manifest",
        action="store_true",
        help="Print the generation manifest and exit")

    args = parser.parse_args()

    if args.list_styles:
        print("Available style profiles:")
        for name, profile in config.STYLE_PROFILES.items():
            print(f"  {name:20} {profile.output_width}x{profile.output_height}px output")
        return

    if args.list_categories:
        print("Available categories:")
        for cat, subdir in config.CATEGORY_DIRS.items():
            print(f"  {cat:20} → generated/{subdir}/")
        return

    if args.show_manifest:
        manifest = load_manifest()
        print(f"Manifest: {config.MANIFEST_PATH}")
        print(f"Total assets: {len(manifest['assets'])}")
        for key, entry in manifest["assets"].items():
            print(f"  {key}: {entry.get('path', '?')}")
        return

    # Batch file mode
    if args.batch_file:
        with open(args.batch_file) as f:
            batch_config = json.load(f)
        category = batch_config.get("category", args.category)
        names    = batch_config.get("items", [])
        style    = batch_config.get("style", args.style)
        context  = batch_config.get("context", args.extra)
        biome    = batch_config.get("biome", args.biome)
        print(f"\nBatch file: {args.batch_file}")
        print(f"Generating {len(names)} assets in category '{category}' with style '{style}'\n")
        run_batch(category, names, style, args.provider, biome, context,
                  args.dry_run, not args.force, args.delay)
        return

    # Direct batch mode
    if not args.category or not args.batch:
        parser.error("--category and --batch are required (or use --batch-file)")

    names = [n.strip() for n in args.batch.split(",") if n.strip()]
    print(f"\nGenerating {len(names)} assets:")
    print(f"  Category : {args.category}")
    print(f"  Style    : {args.style}")
    print(f"  Provider : {args.provider}")
    if args.biome:
        print(f"  Biome    : {args.biome}")
    if args.dry_run:
        print(f"  DRY RUN  : No API calls will be made\n")

    run_batch(args.category, names, args.style, args.provider,
              args.biome, args.extra, args.dry_run, not args.force, args.delay)
    print("\nDone.")


if __name__ == "__main__":
    main()
