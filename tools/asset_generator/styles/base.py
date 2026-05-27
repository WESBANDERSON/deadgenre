"""
Style helpers — functions that build final prompts from a style profile + user prompt.

AI AGENT NOTE:
  To change how prompts are assembled (e.g. add world lore context),
  edit build_prompt(). The style prefix and user prompt are the two inputs.
"""

from __future__ import annotations
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from config import StyleProfile


def build_prompt(style: "StyleProfile", user_prompt: str, context: str = "") -> str:
    """Assemble the final prompt from a style profile and user description."""
    parts = [style.prompt_prefix]
    if context:
        parts.append(f"game world context: {context}")
    parts.append(user_prompt)
    return ", ".join(parts)


def build_negative_prompt(style: "StyleProfile", extra_negative: str = "") -> str:
    parts = [style.negative_prompt]
    if extra_negative:
        parts.append(extra_negative)
    return ", ".join(parts)
