"""The app's own light and dark themes: neutral greys with one indigo accent."""

from __future__ import annotations

from textual.app import App
from textual.color import Color
from textual.theme import Theme

LIGHT = Theme(
    name="all-configs-light",
    dark=False,
    primary="#4B4FC4",
    secondary="#6E6F7A",
    accent="#4B4FC4",
    success="#1E7F4F",
    warning="#A15C00",
    error="#C4303A",
    foreground="#1D1F24",
    background="#F6F6F4",
    surface="#FFFFFF",
    panel="#ECECE9",
    variables={
        "border": "#4B4FC4",
        "border-blurred": "#D9D9D4",
        "block-cursor-background": "#E4E5FA",
        "block-cursor-foreground": "#1D1F24",
        "block-cursor-text-style": "none",
        "button-focus-text-style": "bold underline",
        "block-cursor-blurred-background": "#EEEEF3",
        "block-cursor-blurred-foreground": "#1D1F24",
        "block-cursor-blurred-text-style": "none",
        "footer-background": "#ECECE9",
        "footer-key-foreground": "#4B4FC4",
        "footer-description-foreground": "#5C5E66",
        "input-cursor-background": "#4B4FC4",
        "input-selection-background": "#4B4FC4 25%",
        "scrollbar": "#D9D9D4",
        "scrollbar-hover": "#BDBDB6",
        "scrollbar-active": "#4B4FC4",
        "scrollbar-background": "#FFFFFF",
    },
)

DARK = Theme(
    name="all-configs-dark",
    dark=True,
    primary="#8F93F5",
    secondary="#9A9CA8",
    accent="#8F93F5",
    success="#4CC38A",
    warning="#E8B04B",
    error="#F0646C",
    foreground="#E3E4E8",
    background="#111216",
    surface="#17181D",
    panel="#202127",
    variables={
        "border": "#8F93F5",
        "border-blurred": "#2C2E35",
        "block-cursor-background": "#2A2C4A",
        "block-cursor-foreground": "#E3E4E8",
        "block-cursor-text-style": "none",
        "button-focus-text-style": "bold underline",
        "block-cursor-blurred-background": "#22232B",
        "block-cursor-blurred-foreground": "#E3E4E8",
        "block-cursor-blurred-text-style": "none",
        "footer-background": "#17181D",
        "footer-key-foreground": "#8F93F5",
        "footer-description-foreground": "#9A9CA8",
        "input-cursor-background": "#8F93F5",
        "input-selection-background": "#8F93F5 30%",
        "scrollbar": "#2C2E35",
        "scrollbar-hover": "#3A3C45",
        "scrollbar-active": "#8F93F5",
        "scrollbar-background": "#17181D",
    },
)

THEMES = (LIGHT, DARK)


def tones(app: App) -> dict[str, str]:
    """Resolved theme colours for Rich Text, which cannot read $variables."""
    v = app.get_css_variables()
    return {
        "accent": v["primary"],
        "ok": v["success"],
        "warn": v["warning"],
        "err": v["error"],
        "muted": Color.parse(v["foreground"]).blend(Color.parse(v["surface"]), 0.42).hex,
    }
