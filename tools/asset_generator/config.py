"""
Asset Generator Configuration
——————————————————————————————
Central configuration for all asset generation. Edit this file to:
  - Switch AI providers (openai / replicate / local)
  - Add new style profiles
  - Adjust output paths
  - Set API keys (or use environment variables — preferred)

AI AGENT NOTE:
  To change the visual style of all generated assets, edit the relevant
  StyleProfile in STYLE_PROFILES. The prefix string is prepended to every
  prompt before it's sent to the model.
"""

import os
from dataclasses import dataclass, field
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────────────────────────────────
REPO_ROOT        = Path(__file__).resolve().parent.parent.parent
CLIENT_ASSETS    = REPO_ROOT / "client" / "assets"
GENERATED_OUTPUT = CLIENT_ASSETS / "generated"
STAGING_OUTPUT   = Path(__file__).resolve().parent / "output"
MANIFEST_PATH    = GENERATED_OUTPUT / "manifest.json"

# ─────────────────────────────────────────────────────────────────────────────
# API Configuration
# ─────────────────────────────────────────────────────────────────────────────
# Supported providers: "openai" | "replicate" | "manual"
# - "openai":    DALL-E 3 (requires OPENAI_API_KEY)
# - "replicate": SDXL / Stable Diffusion (requires REPLICATE_API_TOKEN)
# - "manual":    Print prompts + destination paths and write a prompts.json.
#                Use this when generating in Midjourney, Krea, NovelAI, etc.
#                and then dropping the resulting PNGs into the printed paths.
DEFAULT_PROVIDER = os.environ.get("ASSET_PROVIDER", "openai")

OPENAI_API_KEY    = os.environ.get("OPENAI_API_KEY", "")
OPENAI_IMAGE_MODEL = "dall-e-3"

REPLICATE_API_TOKEN = os.environ.get("REPLICATE_API_TOKEN", "")
# Stable Diffusion XL on Replicate — consistent pixel art quality
REPLICATE_MODEL   = "stability-ai/sdxl:39ed52f2319f9b43c82ba3beeff3e47571b03ef20a6f1be5c9ec97a93cde1cac"

# ─────────────────────────────────────────────────────────────────────────────
# Style Profiles
# ─────────────────────────────────────────────────────────────────────────────
@dataclass
class StyleProfile:
    name: str
    # Prepended to every prompt — defines the visual language
    prompt_prefix: str
    # Negative prompt for Stable Diffusion (ignored by DALL-E)
    negative_prompt: str
    # Native generation size
    width: int
    height: int
    # Output is upscaled to this before saving (nearest neighbor for pixel art)
    output_width: int
    output_height: int
    # Number of inference steps (Replicate / local only)
    steps: int = 20

STYLE_PROFILES: dict[str, StyleProfile] = {
    # ─────────────────────────────────────────────────────────────────────
    # Dreadmyst-flavoured 2.5D billboard sprites
    # These are the active style for the new 2.5D client. Sprites are tall
    # full-body characters/props with transparent backgrounds, designed to
    # billboard onto Sprite3D nodes in the 3D world. Color and mood match
    # the in-engine procedural fallback in SpriteFactory.gd so AI-generated
    # assets slot in seamlessly.
    # ─────────────────────────────────────────────────────────────────────
    "dreadmyst_billboard": StyleProfile(
        name="dreadmyst_billboard",
        prompt_prefix=(
            "full-body character billboard for a 2.5D dark fantasy RPG, "
            "Dreadmyst inspired, painterly stylized illustration with crisp edges, "
            "moody color palette of deep navy, cold teal, ember orange and witch-green, "
            "soft volumetric fog rim light, eerie atmospheric lighting, "
            "facing camera in neutral pose, "
            "transparent PNG background, centered figure, single subject, "
            "clean silhouette readable from a 3/4 top-down camera angle, "
            "tall portrait composition with feet at bottom edge"
        ),
        negative_prompt=(
            "photo, realistic skin pores, 3d render, low quality, blurry, "
            "anti-aliased halos, watermark, text, logo, multiple characters, "
            "tiled, repeating pattern, ground shadow box"
        ),
        width=1024, height=1536,
        output_width=512, output_height=768,
        steps=30,
    ),
    "dreadmyst_prop": StyleProfile(
        name="dreadmyst_prop",
        prompt_prefix=(
            "dark fantasy environment prop billboard for a 2.5D RPG, "
            "Dreadmyst inspired, painterly stylized illustration, "
            "muted earthy palette, mossy slate stone, gnarled wood, "
            "soft fog rim light, eerie ambient mood, "
            "transparent PNG background, single object centered, "
            "ground-rooted base, viewed from 3/4 top-down angle, "
            "no characters, no creatures"
        ),
        negative_prompt=(
            "photo, realistic, 3d render, watermark, text, "
            "person, character, multiple props, tiled, repeating"
        ),
        width=1024, height=1024,
        output_width=512, output_height=512,
        steps=28,
    ),
    "dreadmyst_tile": StyleProfile(
        name="dreadmyst_tile",
        prompt_prefix=(
            "seamlessly tileable ground texture for a dark fantasy 2.5D RPG, "
            "Dreadmyst aesthetic, top-down orthographic view, "
            "moody overcast lighting, desaturated cold palette, "
            "no objects, no entities, ground material only, "
            "subtle painterly brushwork, even seam edges"
        ),
        negative_prompt=(
            "person, creature, object, prop, tree, rock, watermark, text, "
            "3d render, photo, shadow, sky"
        ),
        width=1024, height=1024,
        output_width=256, output_height=256,
        steps=30,
    ),
    # ─────────────────────────────────────────────────────────────────────
    # Legacy top-down pixel art profiles (kept for compatibility)
    # ─────────────────────────────────────────────────────────────────────
    "pixel_art_32": StyleProfile(
        name="pixel_art_32",
        prompt_prefix=(
            "32x32 pixel art sprite, OSRS-inspired palette, "
            "black 1-pixel outline, flat cel shading, no anti-aliasing, "
            "transparent PNG background, top-down RPG game asset, "
            "crisp clean pixels, limited color palette of 16-32 colors"
        ),
        negative_prompt=(
            "realistic, 3d render, photo, blurry, smooth gradients, "
            "anti-aliased, watermark, text, logo, noise, dithering"
        ),
        width=1024, height=1024,      # DALL-E 3 minimum; we downscale to 32x32
        output_width=128, output_height=128,  # 4x upscale for crisp HiDPI display
        steps=25,
    ),
    "pixel_art_64": StyleProfile(
        name="pixel_art_64",
        prompt_prefix=(
            "64x64 pixel art sprite, OSRS/Albion Online inspired, "
            "black outline, flat shading, transparent PNG background, "
            "top-down RPG game art, detailed but clean pixel work"
        ),
        negative_prompt=(
            "realistic, photo, blurry, anti-aliased, watermark, 3d"
        ),
        width=1024, height=1024,
        output_width=256, output_height=256,
        steps=30,
    ),
    "icon_32": StyleProfile(
        name="icon_32",
        prompt_prefix=(
            "32x32 UI icon, game HUD skill icon, flat vector style, "
            "bold silhouette, single color palette, transparent background, "
            "clean lines, instantly recognizable symbol"
        ),
        negative_prompt="realistic, photo, text, complex detail, gradient",
        width=1024, height=1024,
        output_width=128, output_height=128,
        steps=20,
    ),
    "portrait_128": StyleProfile(
        name="portrait_128",
        prompt_prefix=(
            "128x128 pixel art character portrait, RPG game UI portrait, "
            "OSRS chat head style, visible face and shoulders, "
            "expressive character, flat shading with highlight, transparent background"
        ),
        negative_prompt="realistic, photo, blurry, full body",
        width=1024, height=1024,
        output_width=256, output_height=256,
        steps=30,
    ),
}

# ─────────────────────────────────────────────────────────────────────────────
# Category → Output Subdirectory Mapping
# ─────────────────────────────────────────────────────────────────────────────
CATEGORY_DIRS: dict[str, str] = {
    "tiles":      "tiles",
    "characters": "characters",
    "items":      "items",
    "effects":    "effects",
    "ui":         "ui",
    "portraits":  "portraits",
    "props":      "props",         # 2.5D billboard props (trees, rocks, etc.)
    "mobs":       "characters",    # mobs go in characters/
    "npcs":       "characters",
}

# ─────────────────────────────────────────────────────────────────────────────
# Prompt Validation
# ─────────────────────────────────────────────────────────────────────────────
# Reject any prompt that OpenAI's safety system is likely to flag.
BLOCKED_KEYWORDS = ["gore", "explicit", "nude", "nsfw", "violence"]

def validate_prompt(prompt: str) -> None:
    lower = prompt.lower()
    for word in BLOCKED_KEYWORDS:
        if word in lower:
            raise ValueError(f"Prompt contains blocked keyword: '{word}'")
