#!/usr/bin/env python3
"""Draws the UI skin: 9-slice textures for panels, edge-to-edge docks (the
battle's top bar and bottom menu), card slots, buttons, progress bars,
portrait frames and the bottom navigation, in the game's flat, muted look:
dark warm charcoal surfaces, thin ink lines, small corner radii, stone-grey buttons with a short lip, copper accents for what you own
or should press, and a faint grain so nothing looks plastic.

Pure Python 3 (uses doodle.py next to this file). Run from anywhere:

    python3 Assets/Art/Source/ui_skin.py [--sheet preview.png]

Output: PNGs in Assets/Art/UI/. The theme (Assets/Themes/main_theme.tres)
and a few scenes use them as 9-slice textures with the margins in SLICES.
One design unit is one pixel here.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from doodle import Canvas, box, circle, half_plane, ring  # noqa: E402

UI_DIR = Path(__file__).resolve().parents[1] / "UI"
INK = "#121010"
COPPER = "#d0743c"
COPPER_DARK = "#8a4522"

BUTTON_COLORS = {
    # name: (top, bottom, lip)
    "blue": ("#5f8ba3", "#4a7187", "#2d4655"),
    "green": ("#86a35a", "#6b8644", "#43552b"),
    "red": ("#bd5c4d", "#9c4437", "#63291f"),
    "grey": ("#6c665f", "#57524c", "#37332f"),
    "gold": ("#de9150", "#c27333", "#7b4419"),
    "disabled": ("#45413d", "#3a3734", "#282523"),
}
BAR_COLORS = {
    "blue": "#4f87a9",
    "red": "#b8473a",
    "green": "#6f9a45",
    "gold": "#d2913b",
    "purple": "#8e64b8",
}
# Texture margins (left, top, right, bottom) for 9-slicing.
SLICES = {
    "panel": (18, 18, 18, 18),
    "card": (12, 12, 12, 12),
    "stat_cell": (10, 10, 10, 10),
    "pill": (16, 16, 16, 16),
    "button": (14, 12, 14, 18),
    "bar": (6, 6, 6, 6),
    "portrait_frame": (12, 12, 12, 12),
    "nav_tile": (14, 16, 14, 16),
    "dock_top": (4, 4, 4, 12),
    "dock_bottom": (4, 12, 4, 4),
}


def rounded(width, height, inset, radius, offset_y=0.0):
    return box(width / 2.0, height / 2.0 + offset_y, width / 2.0 - inset, height / 2.0 - inset, radius)


def top_rim(shape, thickness):
    return shape - shape.moved(0, thickness)


def new_canvas(width, height, seed):
    return Canvas(width, height, design_width=width, seed=seed, outline_px=0.0, wobble_px=0.0)


def finish(canvas, grain=0.05):
    canvas.add_grain(grain)
    return canvas


def panel():
    c = new_canvas(64, 64, "panel")
    c.flat(rounded(64, 64, 0, 10), INK)
    c.gradient(rounded(64, 64, 3, 8), "#2f2c29", "#232120")
    c.flat(rounded(64, 64, 5, 6) - rounded(64, 64, 6, 5), "#3e3935")
    c.flat(top_rim(rounded(64, 64, 3, 8), 1.5), "#56504a", alpha=0.6)
    return finish(c)


def dock(edge_at_top):
    """A full-width bar that runs off the screen edges: square, no side
    borders, one ink edge (with a light rim) toward the battlefield."""
    c = new_canvas(48, 48, "dock")
    c.gradient(box(24, 24, 24, 24), "#2f2c29", "#232120")
    if edge_at_top:
        c.flat(box(24, 1.5, 24, 1.5), INK)
        c.flat(box(24, 3.75, 24, 0.75), "#56504a", alpha=0.7)
        c.flat(box(24, 7.25, 24, 0.75), "#3e3935", alpha=0.8)
    else:
        c.flat(box(24, 46.5, 24, 1.5), INK)
        c.flat(box(24, 40.75, 24, 0.75), "#3e3935", alpha=0.8)
    return finish(c)


def slot(border=None, fill_top="#26231f", fill_bottom="#1d1b19", seed="slot"):
    """A dark card slot; [border] adds a colored line (owned / featured)."""
    c = new_canvas(48, 48, seed)
    c.flat(rounded(48, 48, 0, 6), INK)
    inset = 2.0
    if border:
        c.flat(rounded(48, 48, inset, 5), border)
        inset += 2.0
    c.gradient(rounded(48, 48, inset, 4), fill_top, fill_bottom)
    c.flat(rounded(48, 48, inset + 1, 3) - rounded(48, 48, inset + 2, 2), "#36312c", alpha=0.8)
    return finish(c)


def stat_cell():
    c = new_canvas(40, 40, "cell")
    c.flat(rounded(40, 40, 0, 6), INK)
    c.flat(rounded(40, 40, 2, 5), "#36312c")
    c.gradient(rounded(40, 40, 3, 4), "#1a1817", "#211f1d")
    return finish(c)


def pill():
    c = new_canvas(48, 40, "pill")
    c.flat(rounded(48, 40, 0, 18), INK, alpha=0.9)
    c.flat(rounded(48, 40, 2, 16), "#3c3732")
    c.gradient(rounded(48, 40, 3, 15), "#1b1918", "#222020")
    return finish(c)


def button(colors, pressed=False):
    top, bottom, lip = colors
    c = new_canvas(48, 48, "button")
    c.flat(rounded(48, 48, 0, 8), INK)
    lip_depth = 2.0 if pressed else 5.0
    c.flat(rounded(48, 48, 2, 6), lip)
    body = box(24, 24 - lip_depth / 2.0 + (1.0 if pressed else 0.0), 22, 22 - lip_depth / 2.0, 6)
    c.gradient(body, top, bottom)
    if colors != BUTTON_COLORS["disabled"]:
        c.flat(top_rim(body, 1.5), "#ffffff", alpha=0.22 if pressed else 0.3)
    return finish(c, 0.06)


def bar_background():
    c = new_canvas(24, 20, "bar")
    c.flat(rounded(24, 20, 0, 5), INK)
    c.flat(rounded(24, 20, 1.5, 4), "#34302c")
    c.flat(rounded(24, 20, 2.5, 3), "#131110")
    return c


def bar_fill(color):
    c = new_canvas(24, 20, "fill")
    fill = rounded(24, 20, 2.5, 3)
    c.flat(fill, color)
    c.flat(top_rim(fill, 1.5), "#ffffff", alpha=0.28)
    c.flat(fill & half_plane(0, -1, -14), "#000000", alpha=0.15)
    return finish(c, 0.05)


def portrait_frame():
    """Light frame, transparent inside; tinted by rarity in the game."""
    c = new_canvas(40, 40, "frame")
    c.flat(rounded(40, 40, 0, 6) - rounded(40, 40, 5, 3), INK)
    c.flat(rounded(40, 40, 1.5, 5) - rounded(40, 40, 3.5, 3.5), "#ece6dc")
    return c


def nav_tile(selected):
    c = new_canvas(56, 64, "nav")
    c.flat(rounded(56, 64, 0, 7), INK)
    c.flat(rounded(56, 64, 2, 6), "#2f2b28")
    body = box(28, 30, 26, 28, 5)
    if selected:
        c.gradient(body, "#77706a", "#615b55")
        c.flat(box(28, 5, 22, 2, 1), COPPER)
    else:
        c.gradient(body, "#5b5651", "#4a4642")
    c.flat(top_rim(body, 1.5), "#ffffff", alpha=0.18)
    return finish(c, 0.06)


def nav_center(pressed):
    """Round medallion for the hero chest in the middle of the nav bar."""
    size = 160
    c = new_canvas(size, size, "medallion")
    middle = size / 2.0
    c.flat(circle(middle, middle, 78), INK)
    c.gradient(circle(middle, middle, 74), COPPER, COPPER_DARK)
    c.flat(circle(middle, middle, 66), INK)
    c.gradient(circle(middle, middle, 63), "#4c4642" if not pressed else "#3d3834", "#2c2927")
    c.flat(ring(middle, middle, 58, 1.5), "#5e5751", alpha=0.8)
    for angle in range(0, 360, 45):
        rivet_x = middle + math.cos(math.radians(angle)) * 70
        rivet_y = middle + math.sin(math.radians(angle)) * 70
        c.flat(circle(rivet_x, rivet_y, 2.6), "#f0b27a", alpha=0.8)
    return finish(c, 0.05)


def build():
    images = {
        "panel": panel(),
        "dock_top": dock(False),
        "dock_bottom": dock(True),
        "card": slot(),
        "card_owned": slot(COPPER, seed="owned"),
        "feature_card": slot(COPPER, "#33281d", "#211b15", seed="feature"),
        "stat_cell": stat_cell(),
        "pill": pill(),
        "bar_background": bar_background(),
        "portrait_frame": portrait_frame(),
        "nav_tile": nav_tile(False),
        "nav_tile_selected": nav_tile(True),
        "nav_center": nav_center(False),
        "nav_center_pressed": nav_center(True),
    }
    for name, colors in BUTTON_COLORS.items():
        images["button_%s" % name] = button(colors)
        if name != "disabled":
            images["button_%s_pressed" % name] = button(colors, pressed=True)
    for name, color in BAR_COLORS.items():
        images["bar_%s" % name] = bar_fill(color)
    return images


def main(arguments):
    images = build()
    for name, canvas in images.items():
        canvas.save(UI_DIR / (name + ".png"))
        print("ui", name)
    if "--sheet" in arguments:
        from generate_art import write_sheet
        write_sheet(arguments[arguments.index("--sheet") + 1], list(images.values()))


if __name__ == "__main__":
    main(sys.argv[1:])
