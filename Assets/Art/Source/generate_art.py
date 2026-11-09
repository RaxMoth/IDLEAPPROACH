#!/usr/bin/env python3
"""Draws the game's original art: heroes, monsters, bases, backdrop props,
the hero chest and UI icons, in a painted look: chibi proportions, one
dusty palette (doodle.muted), shaded volumes with cool shadows and warm
lights, thin inner lines, one brush-like ink outline around each
silhouette, warm glows and a faint grain.

Pure Python 3 (uses doodle.py next to this file). Run from anywhere:

    python3 Assets/Art/Source/generate_art.py                 # everything
    python3 Assets/Art/Source/generate_art.py Heroes Icons    # some folders
    python3 Assets/Art/Source/generate_art.py --sheet out.png # + preview sheet

Output: PNGs under Assets/Art/<Folder>/. Heroes face right, monsters face
left. Character art is drawn in a 100 x 100 design box with the feet near
y = 92, which the game uses to line sprites up with their shadows.
Replace any PNG with real art of the same name.
"""

import math
import multiprocessing
import random
import sys
from functools import partial
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from doodle import (INK, Canvas, box, capsule, circle, ellipse, half_plane, heart,  # noqa: E402
                    lighter, mix, muted, polygon, ring, rgb, star, teardrop, zigzag)

ART_DIR = Path(__file__).resolve().parents[1]
CHARACTER_SIZE = 128
BOSS_SIZE = 160
ICON_SIZE = 96
# Drawn at this multiple of the output size, then averaged down (smooth edges).
SUPERSAMPLE = 2
WHITE = (1.0, 1.0, 1.0)

SKIN = "#f1c7a0"
ELF_SKIN = "#efd3b4"
BOOT = "#4b3a33"
STEEL = "#aeb5c0"
STEEL_LIGHT = "#d9dee6"
WOOD = "#8b5b37"
LEATHER = "#76502f"
GOLD = "#e6b649"
EMBER = "#ff9a3c"


# ============================================
# HERO PARTS (facing right)
# ============================================
# A chibi figure in a 100-unit box, feet near y = 92: legs and boots, a back
# arm, the torso, the head with an ear and a face, then a front arm. Heroes
# assemble these in drawing order and add their gear in between.

LINE = "#2a2026"


def darker(color, amount=0.3):
    return mix(rgb(color), (0.0, 0.0, 0.0), amount)


def legs(c, pants="#4d4038", boots=BOOT, spread=0.0):
    c.draw(capsule(46 - spread, 78, 44 - spread, 88, 4.4), darker(pants, 0.12))
    c.draw(box(44.5 - spread, 90.6, 6.0, 3.4, 2.6) | ellipse(48 - spread, 91.2, 4.4, 2.8), darker(boots, 0.1))
    c.draw(capsule(55 + spread, 78, 57 + spread, 88, 4.6), pants)
    c.draw(box(58.5 + spread, 90.6, 6.4, 3.6, 2.8) | ellipse(62.5 + spread, 91.3, 4.6, 2.9), boots)
    c.draw(box(57.5 + spread, 86.4, 5.6, 1.6, 1.0), lighter(boots, 0.15), outline_px=0.8)
    c.line([(53.5 + spread, 93.6), (66 + spread, 93.6)], 0.5, LINE, 0.5)


def arm(c, shoulder, hand_at, sleeve, skin=SKIN, glove=None, cuff=None):
    (sx, sy), (hx, hy) = shoulder, hand_at
    c.draw(capsule(sx, sy, hx, hy, 3.9, 3.2), sleeve)
    dx, dy = hx - sx, hy - sy
    length = math.hypot(dx, dy) or 1.0
    cx, cy = hx - dx / length * 3.4, hy - dy / length * 3.4
    c.draw(capsule(cx - dx / length * 1.2, cy - dy / length * 1.2, cx, cy, 3.6), cuff or darker(sleeve, 0.18), outline_px=0.8)
    c.draw(circle(hx, hy, 3.5), glove or skin)
    c.flat(circle(hx + 1.2, hy - 1.6, 1.4), lighter(glove or skin, 0.25), alpha=0.6)


def tunic(c, color, trim=None, belt=LEATHER, buckle=GOLD, length=86.0, flare=2.5):
    shape = box(50, 70.5, 12.5, 9.5, 6).blend(polygon([(37.5, 72), (62.5, 72), (62.5 + flare, length), (37.5 - flare, length)]), 3)
    c.draw(shape, color)
    if trim:
        c.flat(shape & half_plane(0, -1, -(length - 2.6)), trim)
        c.flat(ellipse(52, 61.2, 7.5, 2.6), trim)
    for (x1, y1), (x2, y2) in (((44, 79), (42.5, length - 1)), ((50, 80), (50.5, length - 1)), ((56, 79), (58, length - 1))):
        c.line([(x1, y1), (x2, y2)], 0.45, LINE, 0.35)
    if belt:
        c.draw(box(50, 75.5, 13.3, 2.1, 1.0), belt, outline_px=0.8)
        c.draw(box(55, 75.5, 2.4, 2.4, 0.8), buckle, outline_px=0.8, shine=0.6)
        c.flat(box(55, 75.5, 1.0, 1.0, 0.3), darker(belt, 0.4))


def head(c, skin=SKIN, cx=50.0, cy=44.0, radius=20.0, ear=True, pointy_ear=False):
    if pointy_ear:
        c.draw(polygon([(cx - radius * 0.7, cy - 1), (cx - radius * 1.38, cy - 9), (cx - radius * 0.72, cy + 7)]), skin)
    elif ear:
        c.draw(ellipse(cx - radius * 0.86, cy + 3, 3.6, 4.6), skin)
    c.draw(circle(cx, cy, radius), skin)
    if ear and not pointy_ear:
        c.flat(ellipse(cx - radius * 0.86, cy + 3, 1.6, 2.4), darker(skin, 0.2), alpha=0.7)


def face(c, cx=50.0, cy=44.0, radius=20.0, skin=SKIN, brows=True, mouth=True, nose=True, blush=True, eye_size=2.8):
    eyes = [(cx + radius * 0.3, cy + 3.5), (cx + radius * 0.72, cy + 3.5)]
    for ex, ey in eyes:
        c.flat(ellipse(ex, ey, eye_size * 0.7, eye_size), "#1c1418")
        c.flat(circle(ex + eye_size * 0.22, ey - eye_size * 0.38, eye_size * 0.3), (1.0, 1.0, 1.0))
        if brows:
            c.line([(ex - 2.0, ey - eye_size - 2.6), (ex + 2.2, ey - eye_size - 3.1)], 0.6, LINE, 0.8)
    if nose:
        c.draw(ellipse(cx + radius * 0.98, cy + 7.2, 2.2, 1.9), skin, outline_px=0.8)
    if mouth:
        c.line([(cx + radius * 0.4, cy + 11.8), (cx + radius * 0.56, cy + 12.5), (cx + radius * 0.7, cy + 11.9)], 0.5, LINE, 0.75)
    if blush:
        c.flat(ellipse(cx + radius * 0.22, cy + 9.6, 3.0, 1.7), "#e08a78", alpha=0.35)


def hood(c, color, cx=50.0, cy=44.0, radius=22.5, tip=None):
    shape = circle(cx, cy, radius) - ellipse(cx + 8.5, cy + 4, 14.5, 15.5)
    if tip:
        shape = shape.blend(polygon([(cx - radius * 0.6, cy - radius * 0.4), tip, (cx - radius * 0.2, cy - radius * 0.85)]), 3)
    c.draw(shape, color)
    c.flat(ellipse(cx + 8.5, cy + 4, 15.2, 16.2) - ellipse(cx + 8.5, cy + 4, 14.3, 15.3), darker(color, 0.45), alpha=0.7)


def hero_sword(c, grip, tip, blade=STEEL_LIGHT, guard=GOLD, width=3.0):
    (gx, gy), (tx, ty) = grip, tip
    dx, dy = tx - gx, ty - gy
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    base_x, base_y = gx + ux * 4.5, gy + uy * 4.5
    c.draw(capsule(base_x, base_y, tx, ty, width, 0.8), blade, shine=0.8)
    c.line([(base_x + ux * 2, base_y + uy * 2), (tx - ux * 5, ty - uy * 5)], 0.5, darker(blade, 0.35), 0.6)
    c.draw(capsule(base_x - uy * 6, base_y + ux * 6, base_x + uy * 6, base_y - ux * 6, 1.6), guard, outline_px=0.9, shine=0.5)
    c.draw(capsule(gx - ux * 3, gy - uy * 3, base_x, base_y, 1.7), LEATHER, outline_px=0.8)
    c.draw(circle(gx - ux * 4.5, gy - uy * 4.5, 2.1), guard, outline_px=0.8, shine=0.5)


def feet(c, color=BOOT, spread=8.0, y=91.0):
    c.draw(ellipse(50 - spread, y, 7, 4.6), darker(color, 0.1))
    c.draw(ellipse(51 + spread, y, 7.5, 4.6), color)


def torso(c, color, cx=50.0, cy=74.0, half_width=15.0, half_height=14.0):
    c.draw(box(cx, cy, half_width, half_height, 9), color)


def hand(c, x, y, color=SKIN):
    c.draw(circle(x, y, 4.2), color, outline_px=1.0)


def feathered_wing(c, root, start_angle, end_angle, length, color, rows=3, count=6, width=3.6):
    """A fan of layered feathers from [root] (angles in degrees, 0 = right,
    -90 = up): back rows longer and darker, front rows shorter and lighter."""
    rx, ry = root
    for row in range(rows):
        row_length = length * (1.0 - row * 0.24)
        tone = darker(color, 0.16 * (rows - 1 - row)) if row < rows - 1 else color
        for index in range(count):
            angle = math.radians(start_angle + (end_angle - start_angle) * index / max(1, count - 1))
            mid_x = rx + math.cos(angle) * row_length * 0.55
            mid_y = ry + math.sin(angle) * row_length * 0.55
            feather = ellipse(mid_x, mid_y, row_length * 0.5, width * (1.0 - row * 0.12), angle=math.degrees(angle))
            c.draw(feather, tone, outline_px=0.8)
            c.line([(rx + math.cos(angle) * row_length * 0.2, ry + math.sin(angle) * row_length * 0.2),
                    (rx + math.cos(angle) * row_length * 0.9, ry + math.sin(angle) * row_length * 0.9)], 0.3, darker(color, 0.4), 0.5)


def rivets(c, points, radius=0.9, color="#e8e2d6"):
    for rx, ry in points:
        c.flat(circle(rx, ry, radius), color, alpha=0.9)


def hero_squire(c):
    legs(c, "#4b4038")
    arm(c, (44, 64), (36, 73), "#3e6299")
    c.draw(circle(32, 73, 11.5), WOOD)
    for plank_x in (27.5, 32, 36.5):
        c.flat(box(plank_x, 73, 0.4, 10.5) & circle(32, 73, 10.5), darker(WOOD, 0.35), alpha=0.7)
    c.draw(ring(32, 73, 10.6, 2.2), STEEL, outline_px=0.8, shine=0.4)
    c.draw(circle(32, 73, 3.6), STEEL_LIGHT, outline_px=0.8, shine=0.8)
    rivets(c, [(32, 63.6), (41.4, 73), (32, 82.4), (22.6, 73)])
    tunic(c, "#4f7dc2", "#c9a24a")
    head(c)
    face(c)
    helmet = circle(50, 44, 21.4) & half_plane(0, 1, 38.5)
    c.draw(helmet, STEEL, shine=0.9)
    c.draw(ellipse(50, 38.6, 23, 2.8), darker(STEEL, 0.1), outline_px=0.9, shine=0.5)
    c.draw(box(63.5, 43.5, 1.7, 5.6, 0.8), STEEL, outline_px=0.8, shine=0.6)
    rivets(c, [(34, 36.5), (42, 35.6), (50, 35.4), (58, 35.6)], 0.8)
    hero_sword(c, (67, 69), (84, 37))
    arm(c, (56, 64), (66, 69), "#4f7dc2")


def hero_archer(c):
    c.draw(polygon([(40, 58), (24, 86), (40, 88), (46, 66)]), "#2f4a2a")
    c.draw(box(33, 60, 5.5, 13, 2.5, angle=-18), LEATHER)
    for offset in (-3.2, 0.0, 3.2):
        c.draw(polygon([(27.5 + offset, 48.5), (30 + offset, 41), (32.5 + offset, 48.5)]), "#efe6d0", outline_px=0.8)
    legs(c, "#5a4a32", "#5b4030")
    arm(c, (44, 64), (39, 72), "#5d7d40", ELF_SKIN)
    tunic(c, "#6b8f4a", "#3f5a2a", length=85)
    c.line([(40, 62), (60, 78)], 0.9, LEATHER, 0.9)
    head(c, ELF_SKIN, pointy_ear=True)
    face(c, skin=ELF_SKIN)
    hood(c, "#3f6b34", tip=(20, 24))
    c.draw(ring(64, 66, 21, 3.0) & half_plane(-1, 0, -71.5), WOOD, outline_px=0.9)
    c.draw(box(77.5, 66, 1.9, 3.6, 1.0), LEATHER, outline_px=0.8)
    c.line([(73.5, 46.5), (73.5, 85.5)], 0.35, "#efe6d0", 0.9)
    arm(c, (56, 64), (77, 66), "#6b8f4a", ELF_SKIN)


def hero_banner_knight(c):
    c.draw(capsule(22, 94, 22, 4, 1.9), WOOD)
    flag = polygon([(23, 6), (40, 8), (47, 7), (43, 14), (48, 21), (40, 20), (23, 21)])
    c.draw(flag, "#3f6fb5")
    c.flat(flag & half_plane(0, -1, -18.6), GOLD)
    c.draw(circle(32, 13.5, 3.4), GOLD, outline_px=0.8, shine=0.5)
    legs(c, STEEL, "#5d636e")
    arm(c, (44, 64), (23, 66), STEEL, glove="#5d636e")
    c.draw(ellipse(42, 62.5, 6.5, 4.8), STEEL, shine=0.8)
    tunic(c, "#36598f", GOLD)
    c.flat(box(50, 72, 2.2, 10), GOLD)
    c.draw(ellipse(35, 22, 6, 12, angle=-40), "#c9493d")
    for offset in (-2.5, 0.0, 2.5):
        c.line([(31 + offset, 14), (38 + offset, 28)], 0.4, darker("#c9493d", 0.4), 0.6)
    helm = box(50, 44, 19.5, 20.5, 9)
    c.draw(helm, STEEL, shine=0.9)
    c.flat(box(61, 46, 12, 1.5, 0.7), "#1c1820")
    c.flat(circle(58, 46, 0.8) | circle(66, 46, 0.8), "#f4ead8")
    for hole_y in (52, 55):
        for hole_x in (60, 64, 68):
            c.flat(circle(hole_x, hole_y, 0.7), "#141016")
    c.line([(50, 24.5), (50, 63)], 0.5, darker(STEEL, 0.35), 0.6)
    rivets(c, [(34, 33), (34, 55), (66, 33)], 0.8)
    arm(c, (57, 64), (63, 75), STEEL, glove="#5d636e")
    c.draw(ellipse(57.5, 62.5, 6.5, 4.8), STEEL, shine=0.8)


def hero_cannoneer(c):
    legs(c, "#4a3d33", BOOT, spread=1.5)
    arm(c, (43, 64), (40, 74), "#7a5236")
    tunic(c, "#8b5b3c", None, LEATHER, STEEL, length=85, flare=3.5)
    c.draw(box(50, 79, 9, 6.5, 2.5), "#6e4a2c")
    c.draw(box(42, 79.5, 3.2, 3.6, 1.2), LEATHER, outline_px=0.8)
    head(c)
    face(c, mouth=False, blush=False)
    beard = ellipse(56, 57, 15, 10.5).blend(polygon([(44, 58), (68, 58), (58, 72)]), 3)
    c.draw(beard, "#b9692f")
    for strand in range(5):
        x = 48 + strand * 4
        c.line([(x, 56), (x + 1.5, 64 - abs(strand - 2))], 0.4, darker("#b9692f", 0.4), 0.6)
    c.draw(ellipse(62, 53, 8.5, 2.8, angle=-8), "#a55a26", outline_px=0.8)
    cap = circle(50, 44, 21.2) & half_plane(0, 1, 34)
    c.draw(cap, "#5b4a3b")
    c.draw(ellipse(52, 33.6, 21, 2.6), darker("#5b4a3b", 0.15), outline_px=0.8)
    for goggle_x in (53, 65):
        c.draw(circle(goggle_x, 31.5, 5.0), "#c9a24a", outline_px=0.9, shine=0.6)
        c.draw(circle(goggle_x, 31.5, 3.1), "#7fc8e8", outline_px=0.6, shine=0.9)
    c.draw(circle(71, 83, 8.5), WOOD)
    for angle in range(0, 180, 45):
        rad = math.radians(angle)
        c.line([(71 - math.cos(rad) * 7, 83 - math.sin(rad) * 7), (71 + math.cos(rad) * 7, 83 + math.sin(rad) * 7)], 0.6, darker(WOOD, 0.4), 0.8)
    c.draw(circle(71, 83, 2.4), STEEL, outline_px=0.8, shine=0.6)
    barrel = box(78, 70, 13.5, 6.2, 3, angle=-15)
    c.draw(barrel, "#3b3f49", shine=0.7)
    for band_x, band_y in ((70.5, 72.2), (80.5, 69.4)):
        c.draw(box(band_x, band_y, 1.4, 6.8, 0.6, angle=-15), "#8a8f99", outline_px=0.7, shine=0.6)
    c.draw(circle(91, 66.5, 6.4), "#2c2f37", shine=0.5)
    c.flat(circle(91, 66.5, 3.4), "#0e0d10")
    arm(c, (57, 64), (68, 70), "#8b5b3c")


def hero_cleric(c):
    c.draw(capsule(64, 86, 79, 40, 2.2), WOOD)
    c.line([(66, 80), (68, 74), (70, 68)], 0.5, darker(WOOD, 0.4), 0.7)
    c.draw(box(81, 35, 10.5, 6.5, 2, angle=-20), STEEL, shine=0.8)
    c.flat(box(81, 35, 10.5, 1.2, 0.6, angle=-20), darker(STEEL, 0.3), alpha=0.6)
    legs(c, "#d9d2c0", "#6e5a48")
    arm(c, (44, 64), (39, 74), "#ddd5c2")
    tunic(c, "#e9e1cc", GOLD, belt=None, length=89, flare=4)
    c.line([(40, 75), (60, 75)], 1.0, "#b08f4a", 0.9)
    c.draw(circle(57, 77, 1.8), "#b08f4a", outline_px=0.6)
    c.flat(box(50, 81, 2.2, 6.5), GOLD)
    c.flat(box(50, 79, 5, 1.6), GOLD)
    head(c)
    face(c, mouth=False, blush=False)
    beard = ellipse(56, 59, 14, 9.5).blend(polygon([(45, 60), (67, 60), (57, 74)]), 3)
    c.draw(beard, "#dad5cd")
    for strand in range(4):
        c.line([(50 + strand * 4, 58), (51 + strand * 4, 67)], 0.4, "#9e9890", 0.6)
    hood(c, "#e9e1cc")
    arm(c, (57, 64), (67, 77), "#e9e1cc")


def hero_druid(c):
    c.glow(81, 25, 17, "#9cf06b", 0.55)
    c.draw(capsule(77, 93, 79, 55, 2.5) | capsule(79, 55, 82, 32, 2.2), WOOD)
    c.draw(capsule(82, 32, 76, 24, 1.6) | capsule(82, 32, 88, 26, 1.6), WOOD, outline_px=0.8)
    c.draw(circle(81, 25.5, 5.6), "#a6e872", shine=0.9)
    legs(c, "#5a4128", "#4a3424")
    arm(c, (44, 64), (39, 74), "#6a4d32", ELF_SKIN)
    tunic(c, "#7a5a3a", "#4f7a3a", belt="#4f7a3a", buckle="#a6e872", length=88, flare=3.5)
    for leaf_x, leaf_y, angle in ((42, 84, 30), (58, 84, -30)):
        c.draw(ellipse(leaf_x, leaf_y, 2.6, 4.2, angle=angle), "#6fb04e", outline_px=0.7)
    head(c, ELF_SKIN, pointy_ear=True)
    face(c, skin=ELF_SKIN)
    hood(c, "#5a4128")
    for leaf_x, leaf_y, angle in ((36, 25, -50), (44, 20, -20), (53, 19, 10), (61, 22, 40)):
        leaf = ellipse(leaf_x, leaf_y, 3.6, 6.8, angle=angle)
        c.draw(leaf, "#6fb04e", outline_px=0.8)
        c.line([(leaf_x - math.sin(math.radians(angle)) * 5, leaf_y + math.cos(math.radians(angle)) * 5), (leaf_x + math.sin(math.radians(angle)) * 5, leaf_y - math.cos(math.radians(angle)) * 5)], 0.35, "#3c6a2a", 0.7)
    arm(c, (57, 64), (77, 60), "#7a5a3a", ELF_SKIN)


def hero_ember_mage(c):
    legs(c, "#5a2a28", "#3e2422")
    arm(c, (44, 64), (40, 75), "#9c3530")
    tunic(c, "#b6423a", GOLD, belt="#5a2a28", buckle=GOLD, length=89, flare=4)
    for rune_x in (43, 50, 57):
        c.flat(star(rune_x, 85.5, 1.4, 0.6, 4), GOLD, alpha=0.8)
    head(c)
    c.draw(polygon([(33, 40), (40, 36), (38, 52), (32, 48)]), "#5a3a2a")
    face(c, cy=46)
    hat = polygon([(32, 32), (68, 32), (52, 10), (44, 2), (40, 6), (46, 12)])
    c.draw(hat, "#a7352f")
    c.draw(ellipse(50, 33, 29, 5.6), "#8e2e2a")
    c.draw(box(50, 29, 14.5, 2.6, 1.0) & hat.grown(1), GOLD, outline_px=0.8)
    c.draw(box(56, 29, 2.4, 2.6, 0.6), "#e8c64a", outline_px=0.6, shine=0.6)
    c.glow(79, 58, 20, "#ffb347", 0.75)
    c.draw(teardrop(79, 64, 7, 78, 46), "#ff8a3c")
    c.draw(teardrop(79, 65, 4.8, 80, 52), "#ffcd57", outline=None)
    c.flat(teardrop(79, 66, 2.4, 79, 59), "#fff1b8")
    arm(c, (57, 64), (77, 70), "#b6423a")


def hero_griffin_knight(c):
    fur, feather, talon = "#c99a5a", "#ece7dc", "#e6a33b"
    feathered_wing(c, (46, 58), -170, -112, 30, feather, rows=3, count=5, width=3.4)
    c.draw(capsule(32, 66, 20, 60, 1.8, 1.2), fur, outline_px=0.8)
    c.draw(teardrop(17, 58, 3.4, 12, 54), darker(fur, 0.2), outline_px=0.8)
    c.draw(capsule(38, 74, 35, 87, 3.2), darker(fur, 0.12))
    c.draw(ellipse(36, 89, 4.4, 2.6), darker(fur, 0.12), outline_px=0.8)
    c.draw(ellipse(38, 70, 9, 9.5), fur)
    c.draw(ellipse(52, 67, 20, 12.5), fur)
    for tuft_x in (42, 48, 54):
        c.line([(tuft_x, 76), (tuft_x + 1.5, 79)], 0.4, darker(fur, 0.4), 0.6)
    c.draw(ellipse(66, 63, 8.5, 10), feather)
    for leg_x in (59, 65):
        c.draw(capsule(leg_x, 72, leg_x + 1, 86, 2.2), talon)
        for toe in (-2.4, 0.0, 2.4):
            c.draw(capsule(leg_x + 1, 87, leg_x + 3 + toe, 90, 0.8), talon, outline_px=0.6)
    c.draw(circle(73, 52, 9.5), feather)
    c.draw(polygon([(66, 45), (62, 38), (70, 43)]) | polygon([(64, 49), (57, 45), (65, 47)]), feather, outline_px=0.8)
    c.draw(polygon([(80, 48), (91, 52), (88, 57), (80, 57)]), "#e6b649", shine=0.4)
    c.line([(82, 53.4), (88.5, 54.2)], 0.4, LINE, 0.6)
    c.eyes([(76, 50)], 2.2)
    c.draw(box(47, 47, 7.5, 7, 4), "#3f6fb5")
    c.flat(box(47, 51, 7.5, 1.3), GOLD)
    head(c, cx=47, cy=32, radius=11)
    face(c, cx=47, cy=32, radius=11, eye_size=1.8, brows=False, blush=False)
    c.draw(circle(47, 32, 11.8) & half_plane(0, 1, 29.5), STEEL, shine=0.9)
    c.draw(ellipse(41, 19, 3.2, 6.5, angle=-40), "#c9493d", outline_px=0.8)
    c.draw(capsule(38, 52, 95, 25, 1.5, 0.9), STEEL_LIGHT, shine=0.6)
    c.draw(polygon([(85, 31), (93, 29), (89, 34)]), "#c9493d", outline_px=0.7)
    arm(c, (51, 45), (57, 48), "#3f6fb5")


def hero_paladin(c):
    legs(c, STEEL, "#5d636e")
    arm(c, (44, 64), (39, 74), STEEL, glove="#5d636e")
    c.draw(ellipse(41.5, 62.5, 7, 5), "#d9a63e", shine=0.8)
    tunic(c, "#d9a63e", "#f1cf73", belt="#7a5236", length=86)
    c.flat(box(50, 69, 8, 6, 3), "#f1cf73", alpha=0.6)
    c.line([(43, 66), (57, 66)], 0.5, darker("#d9a63e", 0.4), 0.6)
    helm = box(50, 43, 20, 21, 7.5)
    c.draw(helm, STEEL_LIGHT, shine=0.95)
    c.flat(box(61, 43, 12, 1.5, 0.7) | box(57.5, 48.5, 1.5, 5.5, 0.6), "#1c1820")
    c.flat(circle(55, 43, 0.8) | circle(65, 43, 0.8), "#f4ead8")
    c.draw(box(50, 23.5, 20, 2.4, 1.0), GOLD, outline_px=0.8, shine=0.6)
    c.draw(capsule(50, 20, 50, 12, 2.4), GOLD, outline_px=0.8, shine=0.6)
    rivets(c, [(33, 30), (33, 56), (67, 30), (67, 56)], 0.8, "#f1cf73")
    shield = polygon([(64, 56), (89, 56), (89, 72), (76.5, 91), (64, 72)])
    c.draw(shield, "#ebe7dc")
    c.draw(polygon([(66, 58), (87, 58), (87, 71), (76.5, 88), (66, 71)]) - polygon([(68, 60), (85, 60), (85, 70), (76.5, 85), (68, 70)]), GOLD, outline_px=0.6, shine=0.4)
    c.draw(box(76.5, 70, 2.2, 10, 0.6) | box(76.5, 66, 7, 2.2, 0.6), GOLD, outline_px=0.7, shine=0.5)
    c.draw(ellipse(58.5, 62.5, 7, 5), "#d9a63e", shine=0.8)


def hero_ranger(c):
    c.draw(polygon([(40, 58), (14, 50), (20, 57), (12, 62), (38, 64)]), "#c79a3a")
    c.line([(16, 55), (36, 60)], 0.4, darker("#c79a3a", 0.4), 0.6)
    legs(c, "#3d4a46", "#4a3a2c")
    arm(c, (44, 64), (40, 73), "#3e7e79", ELF_SKIN, cuff=LEATHER)
    tunic(c, "#3e7e79", "#28524f", length=85)
    c.draw(box(50, 69, 9, 6.5, 3), LEATHER)
    c.line([(46, 64), (46, 75)], 0.4, darker(LEATHER, 0.4), 0.6)
    head(c, ELF_SKIN, pointy_ear=True)
    face(c, skin=ELF_SKIN)
    hood(c, "#2e6762", tip=(24, 30))
    c.draw(box(50, 61.5, 12, 2.6, 1.3), "#c79a3a", outline_px=0.8)
    c.draw(circle(39, 62, 2.6), "#c79a3a", outline_px=0.8)
    c.draw(box(73, 68, 12, 2.8, 1.2), WOOD)
    c.draw(ring(84, 68, 11, 2.8) & half_plane(-1, 0, -84), "#5b4a3b", outline_px=0.8)
    c.draw(box(84, 68, 1.6, 2.2, 0.6), STEEL, outline_px=0.6, shine=0.6)
    c.line([(84.5, 57.5), (84.5, 78.5)], 0.3, "#efe6d0", 0.9)
    c.draw(capsule(70, 66, 92, 66, 0.8), STEEL_LIGHT, outline_px=0.5, shine=0.5)
    arm(c, (56, 64), (68, 69), "#3e7e79", ELF_SKIN, cuff=LEATHER)


def hero_seraph(c):
    feathered_wing(c, (44, 60), -165, -120, 34, "#f6f1e6", rows=3, count=6, width=3.8)
    c.glow(50, 15, 18, "#ffe27a", 0.45)
    c.draw(ring(50, 15, 11.5, 3.0), "#f4d35e", outline_px=0.8, shine=0.8)
    robe = box(50, 72, 13.5, 13, 7).blend(polygon([(36, 76), (64, 76), (67, 92), (50, 89), (33, 92)]), 3)
    c.draw(robe, "#f3e8c8")
    c.flat(robe & half_plane(0, -1, -88), "#e2c26a")
    c.line([(44, 78), (42, 90)], 0.4, LINE, 0.3)
    c.line([(56, 78), (58, 90)], 0.4, LINE, 0.3)
    c.draw(box(50, 74, 13.8, 1.8, 0.8), "#e2c26a", outline_px=0.7, shine=0.4)
    arm(c, (44, 64), (40, 74), "#f3e8c8")
    head(c)
    hair = (circle(50, 44, 21.6) & half_plane(0, 1, 38)).blend(polygon([(30, 38), (36, 38), (32, 56), (28, 50)]), 2)
    c.draw(hair, "#f0c14b")
    for strand_x in (40, 46, 52, 58):
        c.line([(strand_x, 26), (strand_x - 2, 37)], 0.4, darker("#f0c14b", 0.35), 0.6)
    face(c)
    c.glow(76, 62, 18, "#ffe27a", 0.35)
    c.draw(ring(66, 62, 18, 2.8) & half_plane(-1, 0, -75), "#f4d35e", outline_px=0.8, shine=0.7)
    c.line([(77.5, 46), (77.5, 78)], 0.3, "#fff1b8", 0.9)
    arm(c, (56, 64), (77, 62), "#f3e8c8")


def hero_storm_fairy(c):
    for wing in (ellipse(32, 36, 15, 22, angle=-28), ellipse(32, 62, 10, 14, angle=24)):
        c.draw(wing, "#a9d8f5", alpha=0.8)
    c.line([(44, 50), (26, 24)], 0.4, "#5f8fb0", 0.7)
    c.line([(44, 52), (24, 44)], 0.4, "#5f8fb0", 0.7)
    c.line([(44, 56), (28, 70)], 0.4, "#5f8fb0", 0.7)
    for spot_x, spot_y in ((28, 30), (24, 40), (30, 66)):
        c.flat(circle(spot_x, spot_y, 2.2), "#ffffff", alpha=0.6)
    c.draw(capsule(49, 84, 47, 92, 1.8) | capsule(56, 84, 58, 92, 1.8), "#e8c8a8")
    c.draw(ellipse(46.5, 92.5, 2.8, 1.8) | ellipse(58.5, 92.5, 2.8, 1.8), "#6a5acd", outline_px=0.7)
    dress = box(52, 74, 10, 9, 6).blend(polygon([(41, 78), (63, 78), (66, 87), (38, 87)]), 2.5)
    c.draw(dress, "#6a5acd")
    c.flat(dress & half_plane(0, -1, -85), "#b8a8f0")
    arm(c, (47, 66), (42, 74), "#6a5acd", cuff="#b8a8f0")
    head(c, cx=52, cy=46, radius=21)
    hair = (circle(52, 46, 22.2) & half_plane(0, 1, 40)).blend(circle(36, 30, 7) | circle(60, 26, 6), 3)
    c.draw(hair, "#7b5cc9")
    for strand_x in (44, 50, 56, 62):
        c.line([(strand_x, 27), (strand_x - 1.5, 39)], 0.4, darker("#7b5cc9", 0.4), 0.6)
    face(c, cx=52, cy=47, radius=21)
    c.glow(82, 48, 14, "#ffe066", 0.65)
    c.draw(capsule(70, 70, 80, 53, 1.5), "#d8c08a", outline_px=0.8)
    c.draw(star(82, 49, 7, 3.2, 5), "#ffe066", shine=0.6)
    c.line([(88, 44), (91, 40), (89, 39), (93, 34)], 0.5, "#fff1b8", 0.9)
    arm(c, (58, 66), (71, 71), "#6a5acd", cuff="#b8a8f0")


HEROES = {
    "squire": hero_squire, "archer": hero_archer, "banner_knight": hero_banner_knight,
    "cannoneer": hero_cannoneer, "cleric": hero_cleric, "druid": hero_druid,
    "ember_mage": hero_ember_mage, "griffin_knight": hero_griffin_knight, "paladin": hero_paladin,
    "ranger": hero_ranger, "seraph": hero_seraph, "storm_fairy": hero_storm_fairy,
}


# ============================================
# MONSTERS (facing left)
# ============================================

def mean_eyes(c, positions, size=2.8, color="#1c1418", glow=None, angry=True):
    """Eyes with a glint and slanted brows (facing left)."""
    for ex, ey in positions:
        if glow:
            c.glow(ex, ey, size * 3.2, glow, 0.55)
        c.flat(ellipse(ex, ey, size * 0.75, size), color)
        c.flat(circle(ex - size * 0.22, ey - size * 0.38, size * 0.3), (1.0, 1.0, 1.0))
        if angry:
            c.line([(ex - 2.4, ey - size - 3.2), (ex + 2.2, ey - size - 1.8)], 0.7, LINE, 0.85)


def teeth(c, x0, x1, y, count, size=1.6, color="#f1ead8"):
    step = (x1 - x0) / count
    for index in range(count):
        tx = x0 + step * (index + 0.5)
        c.flat(polygon([(tx - size * 0.6, y), (tx, y + size * 1.4), (tx + size * 0.6, y)]), color)


def jointed_leg(c, hip, knee, foot, radius, color):
    c.draw(capsule(hip[0], hip[1], knee[0], knee[1], radius) | capsule(knee[0], knee[1], foot[0], foot[1], radius, radius * 0.6), color, outline_px=0.9)


def leaf_cluster(c, center, radius, color, seed):
    rng = random.Random(seed)
    cx, cy = center
    c.draw(circle(cx, cy, radius), darker(color, 0.15))
    for index in range(int(radius * 1.2)):
        angle = rng.uniform(0, math.tau)
        distance = rng.uniform(0.2, 0.85) * radius
        lx, ly = cx + math.cos(angle) * distance, cy + math.sin(angle) * distance
        c.draw(ellipse(lx, ly, 2.6, 4.4, angle=rng.uniform(0, 180)), lighter(color, rng.uniform(0.0, 0.18)), outline_px=0.6)


def slime(c, color, crown=False):
    body = (ellipse(50, 68, 33, 26) & half_plane(0, 1, 91)).blend(circle(52, 52, 17), 9)
    body = body.blend(ellipse(70, 90, 5, 4), 3)
    c.draw(body, color, shine=0.8)
    for bx, by, br in ((62, 74, 3.2), (40, 80, 2.2), (68, 62, 1.8), (48, 84, 1.4)):
        c.flat(circle(bx, by, br), lighter(color, 0.3), alpha=0.45)
        c.flat(circle(bx - br * 0.3, by - br * 0.3, br * 0.35), (1.0, 1.0, 1.0), alpha=0.5)
    c.flat(ellipse(64, 50, 7, 3.8, angle=30), (1.0, 1.0, 1.0), alpha=0.45)
    mean_eyes(c, [(36, 64), (47, 64)], 3.6, angry=crown)
    c.flat(ellipse(41, 75, 4.2, 2.6), "#2a1a1e")
    teeth(c, 38, 44, 73.2, 2, 1.2)
    if crown:
        crown_shape = polygon([(34, 40), (34, 22), (41, 30), (50, 17), (59, 30), (66, 22), (66, 40)])
        c.draw(crown_shape, GOLD, shine=0.7)
        c.draw(box(50, 38, 16, 2.4, 1.0), darker(GOLD, 0.15), outline_px=0.8, shine=0.5)
        for jewel_x, jewel_color in ((42, "#3a8ee0"), (50, "#e0484e"), (58, "#3a8ee0")):
            c.draw(circle(jewel_x, 33, 2.4), jewel_color, outline_px=0.7, shine=0.9)


def monster_slime(c):
    slime(c, "#7fbf4d")


def monster_slime_king(c):
    slime(c, "#5fae3e", crown=True)


def monster_beetle(c):
    for hip_x, knee_x, foot_x in ((40, 34, 28), (52, 50, 48), (64, 70, 74)):
        jointed_leg(c, (hip_x, 76), (knee_x, 82), (foot_x, 91), 1.7, "#2f2622")
    shell = ellipse(56, 64, 30, 21) & half_plane(0, 1, 82)
    c.draw(shell, "#7a5536", shine=0.6)
    c.line([(58, 44), (60, 81)], 0.7, "#2a1c14", 0.9)
    for ridge in range(3):
        c.line([(40 + ridge * 6, 54 + ridge * 2), (46 + ridge * 6, 78)], 0.4, "#2a1c14", 0.4)
        c.line([(66 + ridge * 6, 52 + ridge * 3), (70 + ridge * 5, 78)], 0.4, "#2a1c14", 0.4)
    for spot_x, spot_y in ((48, 58), (68, 60), (74, 70)):
        c.flat(circle(spot_x, spot_y, 2.4), darker("#7a5536", 0.35), alpha=0.6)
    c.draw(ellipse(30, 68, 10, 9), "#3b2f2a")
    c.draw(polygon([(23, 63), (8, 44), (12, 43), (26, 58)]), "#d9c8a0", shine=0.5)
    for ring_y in (52, 56):
        c.line([(14, ring_y - 4), (18, ring_y - 5)], 0.4, darker("#d9c8a0", 0.4), 0.7)
    c.draw(capsule(22, 72, 15, 76, 1.3) | capsule(22, 74, 16, 79, 1.2), "#2f2622", outline_px=0.7)
    c.line([(30, 60), (26, 50), (22, 48)], 0.5, "#2f2622", 0.9)
    mean_eyes(c, [(25, 67)], 2.2, "#f2e6c8")


def goblin(c, skin, vest, hat=None, weapon="dagger", band=None):
    legs(c, "#4a3b2c", "#3d3029")
    arm(c, (56, 66), (64, 76), vest, skin)
    tunic(c, vest, None, belt=LEATHER, buckle=STEEL, length=86, flare=3)
    c.draw(box(43, 82, 3, 3, 0.8), lighter(vest, 0.2), outline_px=0.6)
    c.line([(41, 80), (45, 84)], 0.3, LINE, 0.6)
    c.draw(polygon([(66, 40), (88, 28), (84, 36), (66, 52)]), skin)
    c.flat(polygon([(70, 41), (83, 33), (70, 48)]), darker(skin, 0.25), alpha=0.6)
    c.draw(circle(50, 46, 21), skin)
    c.draw(polygon([(34, 42), (10, 30), (16, 38), (34, 52)]), skin)
    c.flat(polygon([(31, 42), (16, 34), (31, 48)]), darker(skin, 0.25), alpha=0.6)
    mean_eyes(c, [(36, 46), (46, 46)], 2.8)
    c.draw(ellipse(29, 53, 4.2, 3.0), skin, outline_px=0.8)
    c.flat(circle(27, 51, 0.8), darker(skin, 0.35))
    c.line([(32, 59), (37, 61), (44, 60)], 0.6, LINE, 0.85)
    teeth(c, 35, 41, 60.2, 2, 1.4)
    if band:
        c.draw(box(50, 33, 21, 2.6, 1.2) & circle(50, 46, 22), band, outline_px=0.8)
        c.draw(capsule(68, 34, 76, 40, 1.4) | capsule(68, 34, 75, 30, 1.4), band, outline_px=0.7)
    if hat == "fur":
        c.draw(circle(50, 44, 22.5) & half_plane(0, 1, 32), "#f1f3f6")
        for tuft_x in (34, 42, 50, 58, 66):
            c.flat(circle(tuft_x, 26 + abs(tuft_x - 50) * 0.18, 2.2), "#ffffff", alpha=0.7)
        c.draw(box(50, 33, 22.5, 3.2, 1.6), "#7a5236")
        c.draw(box(50, 64, 12, 2.6, 1.3), "#c9493d", outline_px=0.8)
    if weapon == "dagger":
        hero_sword(c, (26, 74), (12, 57), blade="#b9bec6", guard=LEATHER, width=2.0)
        hand(c, 26, 74, skin)
    elif weapon == "sling":
        c.line([(27, 73), (20, 56), (17, 47)], 0.6, LEATHER, 0.95)
        c.draw(circle(17, 45, 3.6), "#8e8a86", outline_px=0.8)
        hand(c, 27, 74, skin)
    else:
        arm(c, (44, 66), (30, 74), vest, skin)


def monster_goblin_scout(c):
    goblin(c, "#7fae52", "#6b4a2e")


def monster_goblin_slinger(c):
    goblin(c, "#72a24a", "#5b6b3a", weapon="sling", band="#c9493d")


def monster_frost_goblin(c):
    goblin(c, "#8db4c8", "#4f6b86", hat="fur")


def monster_hornet(c):
    for wing in (ellipse(58, 32, 9, 16, angle=22), ellipse(68, 34, 7, 12, angle=38)):
        c.draw(wing, "#e4f3ff", alpha=0.6)
    c.line([(54, 46), (60, 20)], 0.3, "#8aa0b0", 0.6)
    c.line([(64, 46), (72, 24)], 0.3, "#8aa0b0", 0.6)
    abdomen = ellipse(62, 60, 22, 14, angle=8)
    c.draw(abdomen, "#f2c230", shine=0.5)
    for stripe_x in (56, 65, 74):
        c.flat(abdomen & box(stripe_x, 60, 2.8, 20, angle=8), "#2a2330")
    c.draw(polygon([(82, 62), (95, 68), (82, 67)]), "#2a2330")
    c.draw(ellipse(41, 56, 9, 8), "#3a3040")
    for fuzz in range(6):
        c.line([(36 + fuzz * 2, 49), (35 + fuzz * 2, 47)], 0.3, "#6a5a70", 0.7)
    for leg_x in (36, 42, 48):
        jointed_leg(c, (leg_x, 62), (leg_x - 2, 68), (leg_x + 2, 73), 0.9, "#2a2330")
    c.draw(circle(28, 54, 10.5), "#2a2330")
    c.draw(ellipse(24, 52, 5.2, 6), "#7a2a2a", shine=0.9)
    c.line([(28, 44), (22, 34), (18, 32)], 0.5, "#2a2330", 0.95)
    c.line([(31, 45), (30, 34), (26, 30)], 0.5, "#2a2330", 0.95)
    c.draw(capsule(20, 62, 16, 66, 1.0) | capsule(24, 63, 21, 67, 1.0), "#2a2330", outline_px=0.6)


def monster_cave_spider(c):
    for index, (hip_x, knee_x, knee_y, foot_x) in enumerate(((40, 30, 44, 22), (48, 42, 40, 38), (58, 62, 40, 64), (66, 78, 44, 82))):
        jointed_leg(c, (hip_x, 62), (knee_x, knee_y), (foot_x, 90), 1.9, "#3d2a52")
        c.line([(knee_x - 1, knee_y + 3), (knee_x + 1, knee_y + 6)], 0.3, "#8a7aa0", 0.6)
    abdomen = ellipse(64, 58, 23, 17)
    c.draw(abdomen, "#6a4a8e", shine=0.4)
    c.flat(polygon([(62, 48), (70, 50), (72, 58), (66, 66), (60, 58)]), "#c45a5a", alpha=0.75)
    c.flat(circle(64, 54, 1.6) | circle(68, 54, 1.6), "#2a1a30")
    for hair in range(7):
        c.line([(46 + hair * 5, 42 + abs(hair - 3) * 1.6), (45 + hair * 5, 39 + abs(hair - 3) * 1.6)], 0.35, "#3d2a52", 0.8)
    c.draw(circle(38, 66, 12), "#5a3c7a")
    for ex, ey, size in ((30, 61, 2.2), (35, 59, 2.6), (30, 68, 1.7), (36, 67, 1.9)):
        c.glow(ex, ey, size * 2.4, "#ff5c5c", 0.35)
        c.flat(circle(ex, ey, size), "#ff6a5c")
        c.flat(circle(ex - size * 0.3, ey - size * 0.3, size * 0.32), (1.0, 1.0, 1.0))
    c.draw(polygon([(28, 74), (24, 82), (30, 77)]) | polygon([(34, 76), (32, 84), (36, 78)]), "#f2ead8", outline_px=0.7)
    for leg_index, (hip_x, knee_x, foot_x) in enumerate(((44, 36, 30), (52, 50, 50), (60, 66, 70), (68, 80, 86))):
        jointed_leg(c, (hip_x, 66), (knee_x, 50 + leg_index), (foot_x, 92), 2.0, "#4a3363")


def treant(c, bark, leaves, eye_color, elder=False):
    for root_x, end_x in ((36, 24), (46, 42), (56, 60), (64, 78)):
        c.draw(capsule(root_x, 84, end_x, 92, 4.2, 2.2), darker(bark, 0.08))
    for cluster_index, (cx, cy, radius) in enumerate(((30, 30, 13), (50, 20, 15), (70, 28, 13), (40, 36, 11), (62, 36, 11))):
        leaf_cluster(c, (cx, cy), radius, leaves, cluster_index + (10 if elder else 0))
    if elder:
        leaf_cluster(c, (20, 42), 9, leaves, 20)
        leaf_cluster(c, (80, 42), 9, leaves, 21)
    trunk = box(50, 64, 21, 27, 11)
    c.draw(trunk, bark)
    rng = random.Random(7 if elder else 3)
    for index in range(7):
        x = 34 + index * 5 + rng.uniform(-1, 1)
        c.line([(x, 42 + rng.uniform(0, 6)), (x + rng.uniform(-2, 2), 62), (x + rng.uniform(-1, 1), 88)], 0.45, darker(bark, 0.45), 0.55)
    c.draw(ellipse(62, 74, 3.4, 4.6), darker(bark, 0.15), outline_px=0.7)
    c.flat(ellipse(62, 74, 1.4, 2.2), darker(bark, 0.5))
    c.draw(capsule(30, 56, 12, 44, 3.6, 2.2) | capsule(18, 48, 12, 38, 1.6), bark)
    c.draw(capsule(70, 60, 86, 50, 3.6, 2.2) | capsule(80, 54, 88, 58, 1.5), bark)
    leaf_cluster(c, (11, 40), 4.5, leaves, 30)
    c.glow(40, 58, 10, eye_color, 0.5)
    c.glow(54, 58, 10, eye_color, 0.5)
    for eye_x in (40, 54):
        c.flat(ellipse(eye_x, 58, 4.0, 5.0), "#120c0a")
        c.flat(circle(eye_x, 58, 1.8), eye_color)
    c.line([(35, 51), (44, 53)], 0.8, darker(bark, 0.5), 0.9)
    c.line([(50, 53), (59, 51)], 0.8, darker(bark, 0.5), 0.9)
    c.flat(ellipse(46, 72, 6, 3.4) - ellipse(46, 69.5, 6.5, 3), "#120c0a")
    if elder:
        c.draw(polygon([(38, 76), (56, 76), (52, 92), (47, 86), (42, 92)]), "#7cb357")
        c.draw(ellipse(62, 44, 10, 4.5), "#7cb357", outline_px=0.8)


def monster_treant(c):
    treant(c, "#7a5a3a", "#5d8f45", "#ffd35a")


def monster_elder_treant(c):
    treant(c, "#5e4630", "#4b7a3a", "#9cf06b", elder=True)


def bat_wing(c, shoulder, tip, lower, color):
    sx, sy = shoulder
    membrane = polygon([shoulder, tip, (tip[0] + (lower[0] - tip[0]) * 0.3, tip[1] + 8), (lower[0] + (tip[0] - lower[0]) * 0.45, lower[1] - 2), lower, (sx, sy + 8)])
    c.draw(membrane, color)
    for finger in (0.3, 0.6):
        fx = tip[0] + (lower[0] - tip[0]) * finger
        fy = tip[1] + (lower[1] - tip[1]) * finger + 4
        c.line([(sx, sy + 2), (fx, fy)], 0.6, darker(color, 0.4), 0.8)
    c.line([(sx, sy), tip], 0.9, darker(color, 0.35), 0.9)


def monster_bat(c):
    bat_wing(c, (56, 50), (95, 30), (74, 66), "#3b3246")
    bat_wing(c, (44, 50), (5, 30), (26, 66), "#4a3f55")
    body = circle(50, 56, 14)
    c.draw(body, "#4a3f55")
    for tuft in range(5):
        c.line([(42 + tuft * 4, 66), (43 + tuft * 4, 70)], 0.4, "#2a2230", 0.7)
    c.draw(polygon([(39, 46), (35, 30), (47, 41)]) | polygon([(53, 41), (63, 30), (61, 46)]), "#4a3f55")
    c.flat(polygon([(40, 43), (38, 34), (44, 41)]), "#a06070", alpha=0.6)
    mean_eyes(c, [(44, 53), (54, 53)], 2.6, "#ff6b6b", glow="#ff5050")
    c.flat(ellipse(49, 61, 4, 2.2), "#2a1a1e")
    teeth(c, 46, 52, 60.6, 2, 1.8)


def monster_scorpion(c):
    color = "#d29a4c"
    for leg_x in (46, 54, 62, 70):
        jointed_leg(c, (leg_x, 78), (leg_x + 4, 84), (leg_x + 2, 91), 1.4, darker(color, 0.25))
    for index, (tx, ty, radius) in enumerate(((76, 70, 7.5), (82, 58, 7), (80, 46, 6.5), (72, 37, 6), (62, 34, 5.5))):
        c.draw(circle(tx, ty, radius), color, shine=0.3)
        c.line([(tx - radius * 0.6, ty - radius * 0.2), (tx + radius * 0.6, ty + radius * 0.2)], 0.35, darker(color, 0.45), 0.6)
    c.draw(teardrop(56, 36, 4.2, 47, 43), "#3a2a20", shine=0.6)
    body = ellipse(58, 76, 22, 11)
    c.draw(body, color, shine=0.4)
    for plate_x in (50, 58, 66):
        c.line([(plate_x, 66), (plate_x + 1, 86)], 0.4, darker(color, 0.45), 0.6)
    c.draw(capsule(40, 76, 26, 72, 2.6) | capsule(26, 72, 22, 66, 2.2), color)
    c.draw(circle(17, 64, 6.2) - ellipse(11, 63, 5, 2.0), color, shine=0.4)
    c.draw(circle(30, 82, 4.5) - ellipse(26, 83, 4, 1.5), darker(color, 0.12))
    mean_eyes(c, [(38, 71), (44, 70)], 1.8)


def monster_mummy(c):
    wrap = "#ddd3b8"
    legs(c, "#c4b896", "#a8996f")
    arm(c, (44, 64), (20, 60), wrap, wrap)
    tunic(c, wrap, None, belt=None, length=88, flare=1.5)
    head(c, wrap, cy=42, radius=19, ear=False)
    for y1, y2, x0, x1 in ((30, 33, 32, 68), (38, 36, 31, 69), (48, 46, 32, 68), (66, 63, 37, 63), (74, 77, 36, 64), (82, 80, 37, 63)):
        c.line([(x0, y1), (x1, y2)], 0.9, "#b4a785", 0.8)
        c.line([(x0, y1 - 1.4), (x1, y2 - 1.4)], 0.35, "#f4eedc", 0.6)
    c.flat(ellipse(46, 42, 8, 3.2), "#2a2220")
    c.glow(42, 42, 9, "#9cf06b", 0.6)
    c.flat(circle(42, 42, 2.2), "#c9ff8a")
    c.draw(polygon([(60, 84), (66, 92), (62, 93)]), "#c9bea0", outline_px=0.7)
    arm(c, (56, 64), (22, 56), wrap, wrap)
    c.line([(30, 56), (32, 62)], 0.4, "#b4a785", 0.8)


def monster_sand_wyrm(c):
    c.draw(ellipse(58, 90, 34, 7), "#c9a66b")
    for dust_x in (30, 44, 74, 86):
        c.flat(circle(dust_x, 85, 1.6), "#e0c48a", alpha=0.7)
    for index, (sx, sy, radius) in enumerate(((70, 84, 12), (68, 70, 12), (60, 58, 11.5), (50, 48, 11), (40, 40, 12))):
        c.draw(circle(sx, sy, radius), "#b88a52")
        c.flat(ellipse(sx + 4, sy - 2, radius * 0.45, radius * 0.6), "#d6ae74", alpha=0.6)
        c.draw(polygon([(sx + radius * 0.4, sy - radius * 0.85), (sx + radius * 0.9, sy - radius * 1.25), (sx + radius * 0.85, sy - radius * 0.45)]), "#8e6436", outline_px=0.7)
    c.draw(circle(32, 38, 14), "#c49660")
    c.flat(polygon([(14, 32), (30, 40), (15, 50)]), "#1a1012")
    teeth(c, 15, 27, 33.5, 4, 1.5)
    c.flat(polygon([(16, 48), (20, 45), (24, 48), (28, 45)]), "#f1ead8")
    mean_eyes(c, [(34, 30)], 2.4)


def monster_bone_vulture(c):
    feathered_wing(c, (60, 52), -60, -10, 34, "#3a2e2e", rows=3, count=5, width=3.4)
    c.draw(ellipse(58, 60, 20, 14), "#4a3a3a")
    for row in range(3):
        c.line([(50 + row * 6, 54), (54 + row * 6, 68)], 0.4, "#2a2020", 0.6)
    c.draw(polygon([(74, 62), (93, 68), (78, 70)]), "#3a2e2e")
    for talon_x in (54, 62):
        c.draw(capsule(talon_x, 72, talon_x - 1, 82, 1.4), "#8a6e5e", outline_px=0.7)
        c.draw(capsule(talon_x - 1, 83, talon_x - 4, 85, 0.7) | capsule(talon_x - 1, 83, talon_x + 2, 85, 0.7), "#e0d8c4", outline_px=0.5)
    c.draw(ellipse(42, 52, 8, 6), "#e8dcc8")
    for ruff in range(5):
        c.line([(36 + ruff * 3, 48), (37 + ruff * 3, 56)], 0.35, "#a89880", 0.6)
    c.draw(capsule(40, 52, 32, 46, 3.4), "#8a6e5e")
    c.draw(circle(28, 43, 10.5), "#ece6d6")
    c.draw(polygon([(20, 45), (6, 54), (12, 55), (22, 51)]), "#d8cdb2", shine=0.3)
    c.flat(circle(25, 41, 3.2), "#1a1012")
    c.flat(circle(24, 41, 1.1), "#ff7a3a")
    c.line([(31, 34), (33, 39), (31, 42)], 0.4, "#8a7a60", 0.8)


def golem(c, stone, crack=None, eye="#ffb347", moss=None):
    c.draw(box(36, 84, 8, 9, 3) | box(64, 84, 8, 9, 3), darker(stone, 0.08))
    c.draw(box(50, 62, 26, 20, 7), stone)
    for chip_x, chip_y in ((30, 46), (70, 50), (40, 78)):
        c.flat(polygon([(chip_x, chip_y), (chip_x + 4, chip_y + 1), (chip_x + 1, chip_y + 3)]), darker(stone, 0.3), alpha=0.7)
    c.line([(28, 58), (72, 60)], 0.5, darker(stone, 0.4), 0.5)
    c.draw(box(20, 64, 8, 15, 4, angle=8) | box(18, 80, 7, 4, 2), stone)
    c.draw(box(80, 64, 8, 15, 4, angle=-8) | box(82, 80, 7, 4, 2), stone)
    c.draw(box(48, 34, 14, 12, 5), stone)
    c.flat(box(48, 34, 11, 3.2, 1.2), "#141012")
    c.glow(43, 34, 8, eye, 0.6)
    c.glow(54, 34, 8, eye, 0.6)
    c.flat(box(43, 34, 3.2, 1.8, 0.8) | box(54, 34, 3.2, 1.8, 0.8), eye)
    if crack:
        c.glow(50, 62, 22, crack, 0.3)
        c.line([(40, 48), (47, 56), (43, 64), (53, 74)], 1.3, crack, 0.95)
        c.line([(62, 46), (58, 56), (66, 64)], 1.1, crack, 0.95)
        c.line([(20, 58), (22, 66)], 0.9, crack, 0.9)
    else:
        c.line([(40, 54), (46, 60), (50, 59)], 0.6, darker(stone, 0.5), 0.6)
        c.line([(58, 66), (64, 72)], 0.6, darker(stone, 0.5), 0.6)
        c.flat(circle(50, 62, 4) - circle(50, 62, 2.6), "#6fc8e8", alpha=0.7)
    if moss:
        for moss_x, moss_y in ((32, 44), (38, 43), (64, 44), (46, 23)):
            c.draw(ellipse(moss_x, moss_y, 4, 2.2), moss, outline_px=0.6)


def monster_sand_colossus(c):
    golem(c, "#c79a5a", eye="#ffb347", moss="#7c9a4a")


def monster_magma_golem(c):
    golem(c, "#4b3636", crack="#ff8a3a", eye="#ffd35a")


def imp(c, skin, horn="#2a2330", held="ice"):
    bat_wing(c, (56, 62), (80, 46), (70, 70), darker(skin, 0.3))
    c.draw(capsule(62, 80, 82, 70, 1.6) | capsule(82, 70, 86, 62, 1.6), skin, outline_px=0.8)
    c.draw(polygon([(86, 56), (90, 63), (82, 63)]), skin, outline_px=0.8)
    legs(c, darker(skin, 0.1), "#3a2a30")
    c.draw(ellipse(52, 73, 12, 10), skin)
    c.flat(ellipse(50, 76, 7, 5), lighter(skin, 0.2), alpha=0.6)
    for horn_points in (((34, 36), (24, 18), (40, 32)), ((56, 32), (62, 16), (62, 36))):
        c.draw(polygon(list(horn_points)), horn, shine=0.5)
    c.draw(polygon([(32, 48), (14, 42), (32, 56)]), skin)
    head(c, skin, cx=48, cy=48, radius=18, ear=False)
    mean_eyes(c, [(39, 48), (48, 48)], 2.8, "#2a1a1a")
    c.line([(36, 58), (42, 60), (48, 58)], 0.6, LINE, 0.85)
    teeth(c, 38, 46, 59, 3, 1.2)
    if held == "ice":
        c.glow(22, 70, 12, "#bfe9ff", 0.6)
        crystal = polygon([(22, 56), (28, 70), (22, 84), (16, 70)])
        c.draw(crystal, "#d3f1ff", shine=0.9)
        c.flat(polygon([(22, 58), (26, 70), (22, 70)]), "#ffffff", alpha=0.5)
    else:
        c.glow(22, 68, 14, "#ffb347", 0.75)
        c.draw(teardrop(22, 72, 6, 22, 56), "#ff8a3c")
        c.draw(teardrop(22, 73, 3.8, 23, 62), "#ffcd57", outline=None)
    arm(c, (44, 66), (26, 74), skin, skin)


def monster_ice_imp(c):
    imp(c, "#79b8e0", "#eef6ff", "ice")


def monster_fire_imp(c):
    imp(c, "#e0553a", "#2a2330", "fire")


def monster_yeti(c):
    fur = "#eef2f7"
    legs(c, "#c9d3df", "#8fa6c2", spread=3)
    body = circle(50, 64, 27)
    for angle in range(0, 360, 24):
        body = body | circle(50 + math.cos(math.radians(angle)) * 26, 64 + math.sin(math.radians(angle)) * 26, 5.2)
    c.draw(body, fur)
    rng = random.Random(5)
    for clump in range(14):
        cx, cy = 34 + rng.uniform(0, 32), 46 + rng.uniform(0, 34)
        c.line([(cx, cy), (cx + rng.uniform(-1.5, 1.5), cy + 4)], 0.4, "#b8c4d4", 0.7)
    c.draw(polygon([(34, 40), (28, 24), (40, 34)]) | polygon([(62, 34), (70, 22), (68, 40)]), "#b8c4d4", shine=0.4)
    c.draw(ellipse(42, 56, 15, 12), "#8fa6c2")
    mean_eyes(c, [(35, 53), (46, 53)], 2.8)
    c.flat(ellipse(41, 64, 7, 3), "#2a1a22")
    teeth(c, 35, 47, 62.2, 3, 1.8)
    c.draw(capsule(26, 66, 14, 80, 5.2), fur)
    for claw in (-2.4, 0.0, 2.4):
        c.draw(polygon([(12 + claw, 82), (10 + claw, 87), (14 + claw, 84)]), "#d8d0c0", outline_px=0.6)


def monster_frost_wisp(c):
    c.glow(50, 52, 42, "#9fd6ff", 0.7)
    points = [(50 + math.cos(math.radians(-90 + index * 30)) * (30 if index % 2 == 0 else 16), 52 + math.sin(math.radians(-90 + index * 30)) * (30 if index % 2 == 0 else 16)) for index in range(12)]
    for index in range(12):
        facet = polygon([(50, 52), points[index], points[(index + 1) % 12]])
        c.draw(facet, "#bfe3ff" if index % 3 == 0 else ("#dff1ff" if index % 3 == 1 else "#9fcff0"), outline_px=0.6)
    c.draw(star(50, 52, 14, 9, 6, angle=-60), "#eaf7ff", outline_px=1.2, shine=0.9)
    mean_eyes(c, [(44, 52), (54, 52)], 3.0, angry=False)
    for shard_x, shard_y in ((20, 30), (82, 36), (78, 76), (24, 74)):
        c.draw(polygon([(shard_x, shard_y - 5), (shard_x + 3, shard_y), (shard_x, shard_y + 5), (shard_x - 3, shard_y)]), "#e4f5ff", outline_px=1.0, shine=0.8)


def monster_frost_giant(c):
    skin = "#7fa6d6"
    legs(c, "#3f4f66", "#2e3a4c", spread=4)
    arm(c, (40, 62), (28, 74), "#4f6b86", skin)
    torso_shape = box(50, 68, 21, 16, 8)
    c.draw(torso_shape, "#4f6b86")
    c.draw(box(50, 56, 22, 5, 3), "#e4ecf4")
    for tuft_x in (32, 38, 44, 50, 56, 62, 68):
        c.flat(circle(tuft_x, 52, 2.4), "#ffffff", alpha=0.6)
    c.draw(box(50, 76, 21.5, 2.4, 1.0), LEATHER, outline_px=0.8)
    c.draw(polygon([(74, 70), (86, 26), (96, 30), (82, 72)]), "#cfeaff", shine=0.9)
    c.line([(80, 64), (90, 32)], 0.5, "#8fbfe0", 0.8)
    head(c, skin, cy=36, radius=18, ear=False)
    beard = polygon([(32, 44), (68, 44), (64, 58), (58, 51), (53, 63), (47, 52), (41, 60), (36, 52)])
    c.draw(beard, "#e4f5ff", shine=0.6)
    mean_eyes(c, [(39, 35), (50, 35)], 2.6)
    helm = circle(50, 36, 19) & half_plane(0, 1, 28)
    c.draw(helm, "#8a96a6", shine=0.8)
    c.draw(polygon([(32, 26), (22, 12), (36, 22)]) | polygon([(68, 26), (78, 12), (64, 22)]), "#f2ead8", shine=0.4)
    hand(c, 78, 66, skin)


def monster_salamander(c):
    color = "#e8743a"
    c.draw(capsule(64, 72, 82, 64, 6, 3) | capsule(82, 64, 94, 70, 3, 1.4), color)
    for leg_x, toe_dir in ((38, -1), (62, 1)):
        jointed_leg(c, (leg_x, 74), (leg_x + toe_dir * 4, 82), (leg_x - 2, 90), 2.6, darker(color, 0.1))
        for toe in (-2.0, 0.0, 2.0):
            c.draw(capsule(leg_x - 2, 90, leg_x - 4 + toe, 92, 0.8), darker(color, 0.1), outline_px=0.5)
    body = ellipse(52, 72, 22, 11.5)
    c.draw(body, color, shine=0.4)
    c.flat(body & half_plane(0, -1, -76), "#f2c27a")
    for spot_x, spot_y, radius in ((44, 66, 2.6), (54, 64, 3.0), (64, 66, 2.4), (72, 66, 1.8)):
        c.flat(circle(spot_x, spot_y, radius), "#ffd35a")
    c.draw(ellipse(28, 64, 15, 9.5), color)
    c.flat(ellipse(28, 69, 12, 3.6), "#f2c27a", alpha=0.8)
    mean_eyes(c, [(22, 58), (31, 58)], 2.6, angry=False)
    c.line([(14, 67), (24, 69), (32, 67)], 0.6, LINE, 0.85)


def monster_ash_wraith(c):
    color = "#6d6464"
    c.glow(50, 50, 32, "#ff7a3a", 0.18)
    cloak = teardrop(50, 46, 22, 66, 90) | circle(36, 62, 10) | circle(50, 66, 9)
    c.draw(cloak, color)
    for tatter_x, tatter_y in ((34, 72), (44, 76), (56, 80)):
        c.draw(polygon([(tatter_x - 4, tatter_y - 2), (tatter_x, tatter_y + 8), (tatter_x + 4, tatter_y - 2)]), darker(color, 0.15), outline_px=0.7)
    hood_shape = circle(46, 42, 16) - ellipse(42, 46, 10, 11)
    c.draw(hood_shape, darker(color, 0.12))
    c.flat(ellipse(42, 46, 10, 11), "#1a1416")
    c.glow(38, 45, 8, "#ff8a3a", 0.7)
    c.glow(48, 45, 8, "#ff8a3a", 0.7)
    c.flat(ellipse(38, 45, 2.6, 3.6) | ellipse(48, 45, 2.6, 3.6), "#ffcf6a")
    c.draw(capsule(30, 56, 16, 62, 3.0, 1.8), color)
    for claw in (-1.6, 0.0, 1.6):
        c.draw(capsule(16, 62, 11, 61 + claw * 2, 0.6), "#2a2224", outline_px=0.5)
    for wisp_x, wisp_y in ((70, 34), (76, 46), (66, 22)):
        c.flat(circle(wisp_x, wisp_y, 3.5), "#8a8484", alpha=0.35)
    for ember_x, ember_y in ((72, 30), (80, 50), (22, 30), (26, 80)):
        c.flat(circle(ember_x, ember_y, 1.5), EMBER)


def monster_inferno_drake(c):
    body = "#c8402e"
    bat_wing(c, (54, 48), (78, 4), (88, 46), "#7e2422")
    c.draw(capsule(68, 72, 92, 82, 6, 1.8), body)
    c.draw(polygon([(92, 80), (99, 76), (97, 86)]), "#7e2422", outline_px=0.7)
    for spike_x in (60, 68, 76):
        c.draw(polygon([(spike_x - 3, 58), (spike_x, 52), (spike_x + 3, 58)]), "#f2e6c8", outline_px=0.6)
    for leg_x in (46, 66):
        jointed_leg(c, (leg_x, 74), (leg_x + 3, 82), (leg_x - 1, 90), 3.4, darker(body, 0.12))
        for claw in (-2.4, 0.0, 2.4):
            c.draw(polygon([(leg_x - 1 + claw, 91), (leg_x - 3 + claw, 94), (leg_x + claw, 93)]), "#f2e6c8", outline_px=0.5)
    torso_shape = ellipse(58, 66, 22, 14)
    c.draw(torso_shape, body, shine=0.3)
    c.flat(torso_shape & half_plane(0, -1, -68), "#f2b34a")
    for plate_x in (48, 54, 60, 66):
        c.line([(plate_x, 70), (plate_x + 1, 79)], 0.4, darker("#f2b34a", 0.4), 0.7)
    c.draw(capsule(44, 58, 32, 42, 6, 5), body)
    c.draw(ellipse(24, 40, 14, 10), body)
    c.draw(polygon([(28, 31), (36, 16), (36, 33)]) | polygon([(20, 31), (22, 18), (26, 32)]), "#f2e6c8", shine=0.4)
    c.flat(polygon([(10, 42), (22, 44), (12, 48)]), "#1a0e0c")
    teeth(c, 11, 19, 42.4, 3, 1.2)
    c.glow(7, 45, 12, "#ffb347", 0.75)
    mean_eyes(c, [(22, 36)], 2.4, "#ffd35a")
    bat_wing(c, (48, 50), (62, 14), (72, 50), "#9e2e28")


MONSTERS = {
    "slime": monster_slime, "beetle": monster_beetle, "goblin_scout": monster_goblin_scout,
    "hornet": monster_hornet, "slime_king": monster_slime_king, "goblin_slinger": monster_goblin_slinger,
    "cave_spider": monster_cave_spider, "treant": monster_treant, "bat": monster_bat,
    "elder_treant": monster_elder_treant, "scorpion": monster_scorpion, "mummy": monster_mummy,
    "sand_wyrm": monster_sand_wyrm, "bone_vulture": monster_bone_vulture, "sand_colossus": monster_sand_colossus,
    "ice_imp": monster_ice_imp, "yeti": monster_yeti, "frost_goblin": monster_frost_goblin,
    "frost_wisp": monster_frost_wisp, "frost_giant": monster_frost_giant, "fire_imp": monster_fire_imp,
    "magma_golem": monster_magma_golem, "salamander": monster_salamander, "ash_wraith": monster_ash_wraith,
    "inferno_drake": monster_inferno_drake,
}
BOSSES = {"slime_king", "elder_treant", "sand_colossus", "frost_giant", "inferno_drake"}


# ============================================
# BASES (160 x 256 design units, feet at y = 252)
# ============================================

def brick_wall(c, left, top, right, bottom, color, row_height=11.0, brick_width=17.0, seed=1):
    """Courses of slightly uneven stones filling a rectangle."""
    rng = random.Random(seed)
    c.draw(box((left + right) / 2.0, (top + bottom) / 2.0, (right - left) / 2.0, (bottom - top) / 2.0, 2.0), darker(color, 0.35))
    row = 0
    y = top + 1.0
    while y < bottom - 2.0:
        height = min(row_height, bottom - 1.0 - y)
        x = left + 1.0 - (brick_width * 0.5 if row % 2 else 0.0)
        while x < right - 1.0:
            width = brick_width * rng.uniform(0.8, 1.15)
            x_from, x_to = max(left + 1.0, x + 0.6), min(right - 1.0, x + width - 0.6)
            if x_to - x_from > 2.5:
                tone = lighter(color, rng.uniform(-0.04, 0.12)) if rng.random() > 0.15 else darker(color, 0.08)
                c.draw(box((x_from + x_to) / 2.0, y + height / 2.0, (x_to - x_from) / 2.0, height / 2.0 - 0.6, 1.6), tone, outline_px=0.9)
            x += width
        y += height
        row += 1


def shingles(c, apex, base_left, base_right, color, rows=6):
    """A cone roof built from rows of scalloped tiles."""
    ax, ay = apex
    c.draw(polygon([apex, base_left, base_right]), darker(color, 0.2))
    for row in range(rows):
        t = (row + 1) / float(rows)
        y = ay + (base_left[1] - ay) * t
        half = (base_right[0] - base_left[0]) / 2.0 * t
        count = max(2, int(half * 2 / 9.0))
        tile = half * 2.0 / count
        for index in range(count):
            tx = ax - half + tile * (index + 0.5)
            scale_shape = (circle(tx, y - tile * 0.15, tile * 0.62) & half_plane(0, -1, -(y + 0.6))) & polygon([apex, (base_left[0] - 2, base_left[1] + 1), (base_right[0] + 2, base_right[1] + 1)])
            c.draw(scale_shape, lighter(color, 0.06 * ((index + row) % 2)), outline_px=0.8)


def torch(c, x, y, flame="#ffcd57", core="#fff1b8", glow_color=EMBER):
    c.glow(x, y - 14, 30, glow_color, 0.5)
    c.draw(capsule(x, y + 18, x, y, 2.4), WOOD)
    c.draw(box(x, y, 4.5, 3, 1.2), "#4a4448", shine=0.4)
    c.draw(teardrop(x, y - 7, 5.5, x + 1, y - 24), flame)
    c.draw(teardrop(x, y - 6, 3.0, x, y - 15), core, outline=None)


def base_player(c):
    stone = "#8a8580"
    # Ground and foundation.
    c.draw(ellipse(80, 250, 66, 6), "#3d3a33")
    for rock_x, rock_y, radius in ((26, 246, 6), (138, 246, 7), (118, 250, 4), (40, 251, 4)):
        c.draw(circle(rock_x, rock_y, radius), "#6e6a64")
    brick_wall(c, 30, 222, 130, 250, darker(stone, 0.05), row_height=9, brick_width=20, seed=2)
    # Side towers.
    for tower_x in (34, 126):
        brick_wall(c, tower_x - 13, 120, tower_x + 13, 230, stone, row_height=10, brick_width=13, seed=tower_x)
        c.draw(box(tower_x, 116, 16, 5, 2), lighter(stone, 0.08))
        shingles(c, (tower_x, 66), (tower_x - 19, 114), (tower_x + 19, 114), "#3f6fb5", rows=4)
        c.draw(capsule(tower_x, 68, tower_x, 52, 1.2), "#5a4636")
        c.draw(polygon([(tower_x + 1, 52), (tower_x + 14, 55), (tower_x + 10, 58), (tower_x + 14, 61), (tower_x + 1, 61)]), "#c9493d")
        c.glow(tower_x, 160, 10, "#ffcf6a", 0.45)
        c.draw(box(tower_x, 160, 5, 9, 4.5) | circle(tower_x, 152, 5), "#2a2026", outline_px=1.0)
        c.flat(box(tower_x, 161, 3.4, 7, 3) | circle(tower_x, 154, 3.4), "#ffcf6a", alpha=0.95)
        c.line([(tower_x, 148), (tower_x, 168)], 0.5, "#5a4636", 0.9)
    # Keep.
    brick_wall(c, 48, 100, 112, 232, lighter(stone, 0.04), row_height=11, brick_width=16, seed=9)
    for crenel_x in (51, 65, 80, 95, 109):
        c.draw(box(crenel_x, 94, 5.5, 7, 1.5), lighter(stone, 0.1))
    c.draw(box(80, 101, 34, 3, 1.2), darker(stone, 0.15), outline_px=0.9)
    shingles(c, (80, 18), (44, 92), (116, 92), "#3f6fb5", rows=6)
    c.draw(capsule(80, 22, 80, 4, 1.4), "#5a4636")
    c.draw(polygon([(81, 4), (104, 8), (97, 13), (104, 18), (81, 18)]), "#4f7dc2")
    c.flat(polygon([(84, 8), (98, 10), (93, 13), (84, 15)]), "#e6b649", alpha=0.8)
    # Hanging banner with a crest.
    c.draw(box(80, 108, 15, 2.4, 1.2), "#5a4636", outline_px=0.8)
    c.draw(polygon([(66, 110), (94, 110), (94, 146), (80, 154), (66, 146)]), "#3f6fb5")
    c.draw(polygon([(70, 112), (90, 112), (90, 143), (80, 149), (70, 143)]) - polygon([(72, 114), (88, 114), (88, 142), (80, 147), (72, 142)]), GOLD, outline_px=0.5)
    c.draw(polygon([(80, 118), (86, 122), (86, 132), (80, 138), (74, 132), (74, 122)]), STEEL_LIGHT, shine=0.6)
    c.flat(box(80, 128, 0.9, 8) | box(80, 126, 4.5, 0.9), "#3f6fb5")
    # Windows with warm light.
    for window_x in (62, 98):
        c.glow(window_x, 170, 9, "#ffcf6a", 0.4)
        c.draw(box(window_x, 172, 4.5, 8, 4.5) | circle(window_x, 165, 4.5), "#2a2026", outline_px=1.0)
        c.flat(box(window_x, 173, 3, 6, 3) | circle(window_x, 166, 3), "#ffcf6a")
    # Gate: arch of voussoirs, plank door with iron bands and studs.
    c.draw(box(80, 224, 19, 16, 1) | circle(80, 208, 19), darker(stone, 0.12))
    for angle in range(180, 361, 30):
        vx = 80 + math.cos(math.radians(angle)) * 18
        vy = 208 + math.sin(math.radians(angle)) * 18
        c.draw(box(vx, vy, 3.6, 3, 1.0, angle=angle + 90), lighter(stone, 0.12), outline_px=0.7)
    door = box(80, 226, 15, 14, 0) | circle(80, 211, 15)
    c.draw(door, "#7a4f30")
    for plank_x in (70, 76.5, 83.5, 90):
        c.line([(plank_x, 198 if abs(plank_x - 80) < 6 else 202), (plank_x, 239)], 0.5, "#3c2618", 0.8)
    for band_y in (214, 230):
        c.draw(box(80, band_y, 15, 1.8, 0.6) & door, "#4a4448", outline_px=0.6, shine=0.4)
        rivets(c, [(68, band_y), (74, band_y), (80, band_y), (86, band_y), (92, band_y)], 0.9, "#a8adb5")
    c.draw(ring(87, 222, 2.6, 0.9), GOLD, outline_px=0.5, shine=0.5)
    # Ivy on the left tower.
    for leaf_x, leaf_y in ((22, 200), (25, 192), (20, 184), (24, 176), (28, 206), (19, 212)):
        c.draw(ellipse(leaf_x, leaf_y, 3.2, 2.2, angle=leaf_y * 7), "#5d8f45", outline_px=0.6)
    c.line([(22, 216), (21, 200), (24, 186), (22, 172)], 0.5, "#3c5a2e", 0.8)
    torch(c, 58, 206)
    torch(c, 102, 206)


def base_enemy(c):
    stone = "#5a5260"
    c.glow(80, 150, 46, "#ff4040", 0.28)
    c.draw(ellipse(80, 250, 66, 6), "#2a2330")
    for bone_x, bone_y, angle in ((30, 247, 20), (128, 248, -15), (112, 251, 70)):
        c.draw(capsule(bone_x - 5, bone_y, bone_x + 5, bone_y, 1.4) | circle(bone_x - 6, bone_y - 1, 1.8) | circle(bone_x - 6, bone_y + 1, 1.8) | circle(bone_x + 6, bone_y - 1, 1.8) | circle(bone_x + 6, bone_y + 1, 1.8), "#d8cdb2", outline_px=0.6)
    brick_wall(c, 30, 222, 130, 250, darker(stone, 0.1), row_height=9, brick_width=22, seed=12)
    # Leaning spike towers.
    for tower_x, lean in ((34, -1), (126, 1)):
        brick_wall(c, tower_x - 13, 124, tower_x + 13, 230, darker(stone, 0.05), row_height=10, brick_width=12, seed=tower_x + 3)
        c.draw(polygon([(tower_x - 17, 126), (tower_x + 17, 126), (tower_x + lean * 6, 70)]), "#3a3440")
        for stripe in range(3):
            y = 120 - stripe * 16
            half = 17 - stripe * 5
            c.line([(tower_x - half + lean * stripe * 2, y), (tower_x + half + lean * stripe * 2, y)], 0.6, "#221c26", 0.8)
        c.draw(polygon([(tower_x + lean * 6 - 2, 72), (tower_x + lean * 9, 52), (tower_x + lean * 6 + 2, 72)]), "#d8cdb2", shine=0.4)
        c.glow(tower_x, 164, 9, "#ff5050", 0.5)
        c.draw(polygon([(tower_x - 4, 158), (tower_x + 4, 158), (tower_x + 3, 172), (tower_x - 3, 172)]), "#1a1418", outline_px=1.0)
        c.flat(polygon([(tower_x - 2.6, 160), (tower_x + 2.6, 160), (tower_x + 2, 170), (tower_x - 2, 170)]), "#ff6a5a")
    # Keep with jagged battlements.
    brick_wall(c, 46, 100, 114, 232, stone, row_height=11, brick_width=15, seed=21)
    c.draw(polygon([(42, 104), (118, 104), (118, 90), (110, 96), (104, 80), (96, 94), (88, 70), (80, 88), (72, 70), (64, 94), (56, 80), (50, 96), (42, 90)]), "#3a3440")
    for horn_points in (((70, 74), (56, 34), (78, 68)), ((90, 74), (104, 34), (82, 68))):
        c.draw(polygon(list(horn_points)), "#d8cdb2", shine=0.4)
        hx, hy = horn_points[1]
        for ring_index in range(3):
            t = 0.25 + ring_index * 0.2
            rx = horn_points[0][0] + (hx - horn_points[0][0]) * t
            ry = horn_points[0][1] + (hy - horn_points[0][1]) * t
            c.line([(rx - 3, ry), (rx + 3, ry + 1)], 0.5, "#8a7e66", 0.8)
    # Tattered banner.
    c.draw(box(80, 110, 16, 2.2, 1), "#2a2026", outline_px=0.8)
    c.draw(polygon([(66, 112), (94, 112), (94, 140), (90, 134), (86, 146), (81, 136), (76, 148), (71, 136), (66, 142)]), "#8e2f36")
    skull(c, 80, 124, 0.32, "#e6dcc4")
    # The eye.
    c.glow(80, 170, 22, "#ff5050", 0.7)
    c.draw(ellipse(80, 170, 14, 9), "#2a1a1e", outline_px=1.2)
    c.draw(ellipse(80, 170, 11, 7), "#ff6a5a", shine=0.6)
    c.flat(ellipse(80, 170, 2.6, 6), "#1a0e10")
    c.flat(circle(76, 167, 1.6), (1.0, 0.9, 0.85), alpha=0.8)
    for spike_x in (38, 54, 106, 122):
        c.draw(polygon([(spike_x - 5, 230), (spike_x - 1, 206), (spike_x + 5, 230)]), "#d8cdb2", shine=0.3)
    # Maw gate with teeth and a skull.
    c.draw(box(80, 226, 18, 16, 1) | circle(80, 210, 18), "#2a2330")
    c.flat(box(80, 228, 14, 13, 0) | circle(80, 214, 14), "#140e12")
    teeth(c, 66, 94, 201, 6, 2.2, "#d8cdb2")
    for bar_x in (70, 76, 84, 90):
        c.draw(capsule(bar_x, 205, bar_x, 241, 1.1), "#4a4448", outline_px=0.6, shine=0.5)
    c.draw(capsule(66, 222, 94, 222, 1.0), "#4a4448", outline_px=0.6, shine=0.5)
    skull(c, 80, 196, 0.26, "#e6dcc4")
    # Chains hanging from the towers.
    for chain_x in (46, 114):
        for link in range(5):
            c.draw(ring(chain_x, 178 + link * 6, 2.0, 0.8), "#6a6470", outline_px=0.5)
    torch(c, 58, 206, flame="#ff7a5a", core="#ffd0a0", glow_color="#ff4040")
    torch(c, 102, 206, flame="#ff7a5a", core="#ffd0a0", glow_color="#ff4040")


# ============================================
# BACKDROP PROPS (100 x 100, standing on y = 96)
# ============================================

def bark_lines(c, x_from, x_to, y_top, y_bottom, color, count=4, seed=1):
    rng = random.Random(seed)
    for index in range(count):
        x = x_from + (x_to - x_from) * (index + 0.5) / count
        c.line([(x + rng.uniform(-1, 1), y_top + rng.uniform(0, 4)), (x + rng.uniform(-1.5, 1.5), (y_top + y_bottom) / 2.0), (x + rng.uniform(-1, 1), y_bottom - rng.uniform(0, 3))], 0.45, darker(color, 0.45), 0.6)


def needle_tier(c, center_x, top, bottom, half_width, color, snow=None):
    teeth_count = 5
    # The bottom edge zigzags like hanging needles.
    tier = polygon([(center_x, top), (center_x + half_width, bottom)] + [(center_x + half_width - (index + 0.5) * half_width * 2.0 / teeth_count, bottom - 3.5 if index % 2 == 0 else bottom) for index in range(teeth_count)] + [(center_x - half_width, bottom)])
    c.draw(tier, color)
    for line_index in range(3):
        offset = (line_index - 1) * half_width * 0.45
        c.line([(center_x + offset * 0.3, top + (bottom - top) * 0.35), (center_x + offset, bottom - 2)], 0.4, darker(color, 0.4), 0.55)
    if snow:
        c.draw(polygon([(center_x, top - 0.5), (center_x + half_width * 0.55, top + (bottom - top) * 0.45), (center_x + half_width * 0.25, top + (bottom - top) * 0.38), (center_x, top + (bottom - top) * 0.5), (center_x - half_width * 0.3, top + (bottom - top) * 0.36), (center_x - half_width * 0.55, top + (bottom - top) * 0.45)]), snow, outline_px=0.6)


def prop_oak(c):
    bark = "#6b4a2e"
    c.draw(capsule(38, 96, 46, 88, 2.6) | capsule(62, 96, 54, 88, 2.6), darker(bark, 0.1))
    c.draw(capsule(50, 96, 50, 52, 7, 4.5) | capsule(50, 66, 34, 50, 2.6, 1.6) | capsule(50, 62, 66, 48, 2.4, 1.4), bark)
    bark_lines(c, 45, 55, 56, 94, bark, 3, seed=4)
    c.draw(ellipse(53, 80, 2.0, 3.0), darker(bark, 0.4), outline_px=0.5)
    for index, (cx, cy, radius) in enumerate(((34, 44, 16), (66, 44, 16), (50, 28, 19), (42, 36, 13), (60, 34, 13))):
        leaf_cluster(c, (cx, cy), radius, "#4f8a3c", 40 + index)
    for apple_x, apple_y in ((40, 50), (62, 40), (52, 22)):
        c.draw(circle(apple_x, apple_y, 2.4), "#c9493d", outline_px=0.6, shine=0.6)


def prop_bush(c):
    for index, (cx, cy, radius) in enumerate(((34, 82, 14), (56, 78, 18), (74, 84, 12))):
        leaf_cluster(c, (cx, cy), radius, "#467a36", 60 + index)
    for flower_x, flower_y in ((48, 70), (64, 76), (36, 78), (70, 88)):
        for petal in range(5):
            angle = math.radians(petal * 72)
            c.flat(circle(flower_x + math.cos(angle) * 1.8, flower_y + math.sin(angle) * 1.8, 1.4), "#f2e6c8")
        c.flat(circle(flower_x, flower_y, 1.1), "#e8c64a")


def prop_pine_dark(c):
    c.draw(capsule(50, 96, 50, 76, 4), "#3d2c22")
    bark_lines(c, 47, 53, 78, 95, "#3d2c22", 2, seed=8)
    needle_tier(c, 50, 40, 84, 30, "#24483a")
    needle_tier(c, 50, 22, 64, 24, "#2a5242")
    needle_tier(c, 50, 4, 44, 17, "#30594a")


def prop_mushroom(c):
    c.glow(50, 70, 34, "#7fe0c8", 0.35)
    for stem_x, cap_y, stem_top, cap_rx, cap_ry in ((50, 66, 70, 24, 13), (24, 84, 86, 10, 6), (76, 86, 88, 8, 5)):
        c.draw(capsule(stem_x, 96, stem_x, stem_top, cap_rx * 0.22, cap_rx * 0.18), "#e8e0cc")
        c.flat(ellipse(stem_x, cap_y + cap_ry * 0.25, cap_rx * 0.9, cap_ry * 0.25), "#a8d8cc", alpha=0.8)
        for gill in range(-3, 4):
            c.line([(stem_x + gill * cap_rx * 0.12, cap_y + cap_ry * 0.1), (stem_x + gill * cap_rx * 0.2, cap_y + cap_ry * 0.4)], 0.3, "#6fa89a", 0.6)
        cap = ellipse(stem_x, cap_y, cap_rx, cap_ry) & half_plane(0, 1, cap_y + cap_ry * 0.2)
        c.draw(cap, "#4fb8a6", shine=0.4)
        for spot_index in range(4):
            angle = math.radians(200 + spot_index * 40)
            c.flat(circle(stem_x + math.cos(angle) * cap_rx * 0.55, cap_y + math.sin(angle) * cap_ry * 0.55, cap_rx * 0.1), "#e8fff8", alpha=0.85)


def prop_cactus(c):
    color = "#5f8f4a"
    c.draw(ellipse(50, 96, 18, 3), "#a88656")
    c.draw(capsule(50, 66, 30, 66, 5) | capsule(30, 66, 30, 44, 5), color)
    c.draw(capsule(50, 56, 70, 56, 5) | capsule(70, 56, 70, 38, 5), color)
    c.draw(capsule(50, 96, 50, 26, 8.5), color)
    for rib_x in (46, 50, 54):
        c.line([(rib_x, 22), (rib_x, 92)], 0.4, darker(color, 0.4), 0.6)
    for rib_x in (30, 70):
        c.line([(rib_x, 40 if rib_x == 70 else 46), (rib_x, 64 if rib_x == 30 else 54)], 0.4, darker(color, 0.4), 0.6)
    for spine_x, spine_y in ((42, 34), (58, 44), (42, 58), (58, 72), (42, 82), (26, 52), (74, 46), (34, 60), (66, 42)):
        side = -1 if spine_x < 50 else 1
        c.line([(spine_x, spine_y), (spine_x + side * 3, spine_y - 1.5)], 0.3, "#f2e6c8", 0.9)
    c.draw(circle(50, 22, 4.5) | circle(46, 19, 3) | circle(54, 19, 3), "#e05a78", outline_px=0.7)
    c.flat(circle(50, 21, 1.6), "#ffd35a")


def prop_desert_rock(c):
    rock = "#b08657"
    c.draw(polygon([(14, 96), (20, 74), (36, 62), (52, 58), (66, 64), (80, 76), (88, 96)]), rock)
    c.draw(polygon([(54, 96), (62, 80), (76, 78), (90, 88), (94, 96)]), darker(rock, 0.08))
    for y, x_from, x_to in ((72, 24, 76), (82, 18, 84), (90, 16, 88)):
        c.line([(x_from, y), ((x_from + x_to) / 2.0, y + 1.5), (x_to, y - 1)], 0.45, darker(rock, 0.4), 0.55)
    c.line([(40, 64), (44, 74), (40, 80)], 0.5, darker(rock, 0.5), 0.7)
    skull(c, 30, 90, 0.16, "#e6dcc4")


def prop_pine_snow(c):
    c.draw(capsule(50, 96, 50, 76, 4), "#4a3628")
    c.draw(ellipse(50, 96, 22, 3.4), "#eef3f8")
    needle_tier(c, 50, 40, 84, 30, "#3f6a5e", snow="#f1f5fa")
    needle_tier(c, 50, 22, 64, 24, "#467266", snow="#f1f5fa")
    needle_tier(c, 50, 4, 44, 17, "#4c7a6d", snow="#f1f5fa")


def prop_ice_spike(c):
    for left, tip_x, tip_y, right in ((30, 40, 30, 50), (66, 76, 50, 84), (46, 60, 12, 72)):
        c.draw(polygon([(left, 96), (tip_x, tip_y), (right, 96)]), "#bfe3f5", shine=0.9)
        c.flat(polygon([(tip_x, tip_y + 2), (tip_x + (right - tip_x) * 0.4, 94), (tip_x - (tip_x - left) * 0.1, 94)]), "#e8f7ff", alpha=0.55)
        c.line([(tip_x, tip_y + 4), (tip_x - 1, 92)], 0.35, "#7fb2d0", 0.7)
    c.draw(ellipse(56, 96, 32, 3.2), "#eef3f8")


def prop_dead_tree(c):
    color = "#3e302c"
    branches = capsule(50, 96, 52, 40, 5.5, 3) | capsule(51, 60, 30, 36, 3, 1.6) | capsule(52, 50, 74, 28, 2.6, 1.4) | capsule(52, 40, 46, 14, 2.4, 1.2)
    branches = branches | capsule(30, 36, 22, 30, 1.4, 0.8) | capsule(74, 28, 82, 24, 1.2, 0.7) | capsule(66, 36, 70, 22, 1.2, 0.7)
    c.draw(branches, color)
    bark_lines(c, 47, 55, 50, 94, color, 3, seed=11)
    c.draw(ellipse(51, 72, 2.4, 3.4), "#1a1416", outline_px=0.5)
    c.draw(capsule(40, 96, 46, 90, 2.0) | capsule(62, 96, 56, 90, 2.0), color)


def prop_lava_rock(c):
    c.glow(50, 84, 36, "#ff7a3a", 0.38)
    c.draw(polygon([(14, 96), (22, 72), (40, 58), (58, 56), (74, 64), (86, 96)]), "#3b2b2b")
    c.draw(polygon([(60, 96), (70, 78), (84, 80), (92, 96)]), "#332626")
    for crack_points, width in ((((32, 92), (40, 78), (36, 70), (48, 62)), 1.5), (((60, 92), (56, 80), (66, 70)), 1.2), (((76, 94), (80, 84)), 1.0)):
        c.glow(crack_points[0][0], crack_points[0][1] - 8, 10, "#ff7a3a", 0.35)
        c.flat(zigzag(list(crack_points), width), "#ff8a3a")
        c.flat(zigzag(list(crack_points), width * 0.4), "#ffd35a")
    for ember_x, ember_y in ((30, 50), (64, 44), (48, 36)):
        c.flat(circle(ember_x, ember_y, 1.3), EMBER)


PROPS = {
    "oak": prop_oak, "bush": prop_bush, "pine_dark": prop_pine_dark, "mushroom": prop_mushroom,
    "cactus": prop_cactus, "desert_rock": prop_desert_rock, "pine_snow": prop_pine_snow,
    "ice_spike": prop_ice_spike, "dead_tree": prop_dead_tree, "lava_rock": prop_lava_rock,
}


# ============================================
# ICONS (100 x 100, centered)
# ============================================

def sword(c, x1=26, y1=74, x2=80, y2=20, blade=STEEL_LIGHT, guard=GOLD, scale=1.0):
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    gx, gy = x1 + ux * 12 * scale, y1 + uy * 12 * scale
    c.draw(capsule(gx, gy, x2, y2, 9.5 * scale, 3.5 * scale), blade)
    c.flat(capsule(gx + ux * 4, gy + uy * 4, x2 - ux * 10, y2 - uy * 10, 1.6 * scale), WHITE, alpha=0.55)
    c.draw(capsule(gx - uy * 14 * scale, gy + ux * 14 * scale, gx + uy * 14 * scale, gy - ux * 14 * scale, 5.2 * scale), guard)
    c.draw(capsule(x1, y1, gx, gy, 5.0 * scale), LEATHER)
    c.draw(circle(x1 - ux * 2, y1 - uy * 2, 6.5 * scale), guard)


def icon_attack(c):
    sword(c)


def icon_attack_speed(c):
    for index, y in enumerate((30, 46, 62)):
        c.draw(capsule(10 + index * 4, y, 30 + index * 4, y, 3.2), "#f2ede2")
    sword(c, 36, 78, 86, 28)


def icon_dps(c):
    c.draw(star(50, 50, 44, 26, 9, angle=-80), "#ff7a3a")
    c.flat(star(50, 50, 30, 18, 9, angle=-80), "#ffcf6a")
    sword(c, 30, 72, 72, 28, scale=0.8)


def icon_health(c):
    shape = heart(50, 52, 84)
    c.draw(shape, "#e0484e")
    c.flat(ellipse(34, 36, 7, 4.5, angle=-35), WHITE, alpha=0.55)


def icon_defense(c):
    shield = polygon([(16, 18), (84, 18), (84, 50), (50, 90), (16, 50)])
    c.draw(shield, "#6f8fb8")
    c.flat(polygon([(26, 26), (74, 26), (74, 48), (50, 78), (26, 48)]), "#89a7cc")
    c.flat(ellipse(34, 34, 6, 4, angle=-30), WHITE, alpha=0.5)


def icon_crit(c):
    c.draw(star(50, 50, 44, 14, 4, angle=-90), "#ffc23a")
    c.flat(star(50, 50, 24, 8, 4, angle=-90), "#fff1b8")
    c.draw(star(80, 22, 11, 4, 4), "#ffe27a", outline_px=2.0)


def icon_range(c):
    for radius, color in ((40, "#e8e2d6"), (29, "#e0484e"), (18, "#e8e2d6"), (8, "#e0484e")):
        c.draw(circle(50, 52, radius), color, outline_px=2.6 if radius < 40 else None, shadow=0.0 if radius < 40 else 0.38)
    c.draw(capsule(52, 50, 86, 16, 2.6), WOOD)
    c.draw(polygon([(80, 10), (94, 8), (92, 22)]), "#f2ede2", outline_px=2.0)


def icon_melee(c):
    sword(c, 22, 78, 78, 22)
    sword(c, 78, 78, 22, 22, blade="#c9cfd8")


def icon_ranged(c):
    c.draw(ring(30, 50, 40, 6) & half_plane(-1, 0, -42), WOOD)
    c.flat(capsule(52, 14, 52, 86, 1.2), "#efe6d0")
    c.draw(capsule(18, 50, 82, 50, 2.4), "#c9a26a")
    c.draw(polygon([(80, 40), (96, 50), (80, 60)]), STEEL_LIGHT)
    c.draw(polygon([(10, 40), (22, 50), (10, 60), (18, 50)]), "#e0484e", outline_px=2.0)


def icon_flying(c):
    feathers = ellipse(54, 30, 34, 12, angle=-20) | ellipse(52, 48, 32, 11, angle=-8) | ellipse(50, 66, 26, 10, angle=8)
    c.draw(feathers, "#f3efe6")
    c.draw(ellipse(26, 52, 12, 22), "#e2dccd")


def icon_ground(c):
    boot = box(42, 46, 16, 26, 6) | box(54, 72, 30, 12, 8)
    c.draw(boot, "#8b5b37")
    c.flat(box(42, 26, 18, 4, 2), "#5e3c22")
    c.flat(box(54, 84, 30, 2.6, 1), INK, alpha=0.5)


def icon_move_speed(c):
    icon_ground(c)
    c.draw(ellipse(24, 32, 16, 6, angle=-30) | ellipse(22, 44, 14, 5, angle=-12), "#f3efe6", outline_px=2.2)


def icon_level(c):
    c.draw(circle(50, 50, 42), "#4fa35a")
    c.draw(polygon([(50, 18), (78, 50), (62, 50), (62, 80), (38, 80), (38, 50), (22, 50)]), "#e9f6dc")


def icon_star(c):
    c.draw(star(50, 54, 44, 19, 5), "#f4c542")
    c.flat(ellipse(38, 40, 6, 3.5, angle=-35), WHITE, alpha=0.5)


def icon_cooldown(c):
    c.draw(box(50, 14, 30, 6, 3) | box(50, 86, 30, 6, 3), WOOD)
    glass = polygon([(26, 20), (74, 20), (54, 50), (74, 80), (26, 80), (46, 50)])
    c.draw(glass, "#dfeef6")
    c.flat(polygon([(34, 26), (66, 26), (50, 46)]), "#f2c25a")
    c.flat(polygon([(34, 78), (66, 78), (50, 62)]), "#f2c25a")


def skull(c, cx=50, cy=50, scale=1.0, color="#ece6d6"):
    c.draw(circle(cx, cy - 6 * scale, 30 * scale) | box(cx, cy + 20 * scale, 16 * scale, 10 * scale, 4 * scale), color)
    c.flat(ellipse(cx - 12 * scale, cy - 2 * scale, 8 * scale, 9 * scale), INK)
    c.flat(ellipse(cx + 12 * scale, cy - 2 * scale, 8 * scale, 9 * scale), INK)
    c.flat(polygon([(cx - 4 * scale, cy + 14 * scale), (cx, cy + 6 * scale), (cx + 4 * scale, cy + 14 * scale)]), INK)
    for tooth in (-8, 0, 8):
        c.flat(box(cx + tooth * scale, cy + 26 * scale, 1.2 * scale, 4 * scale), INK)


def icon_enemy_power(c):
    skull(c, 44, 54, 0.85)
    c.draw(polygon([(80, 10), (96, 30), (86, 30), (86, 50), (74, 50), (74, 30), (64, 30)]), "#e0484e")


def icon_boss(c):
    skull(c, 50, 58, 0.8)
    c.draw(polygon([(22, 30), (22, 8), (36, 20), (50, 4), (64, 20), (78, 8), (78, 30)]), GOLD)


def up_arrow(c, color, x=80, top=10, bottom=50):
    c.draw(polygon([(x, top), (x + 16, top + 20), (x + 6, top + 20), (x + 6, bottom), (x - 6, bottom), (x - 6, top + 20), (x - 16, top + 20)]), color)


def down_arrow(c, color, x=80, top=50, bottom=90):
    c.draw(polygon([(x, bottom), (x + 16, bottom - 20), (x + 6, bottom - 20), (x + 6, top), (x - 6, top), (x - 6, bottom - 20), (x - 16, bottom - 20)]), color)


def icon_counter_strong(c):
    """Beats this race on the race wheel."""
    sword(c, 16, 86, 62, 34, scale=0.78)
    up_arrow(c, "#4fa35a", x=78, top=8, bottom=52)


def icon_counter_weak(c):
    """Loses to this race on the race wheel."""
    sword(c, 16, 86, 62, 34, scale=0.78)
    down_arrow(c, "#e0484e", x=78, top=44, bottom=92)


def helmet(c, cx, cy, size, plume):
    c.draw(circle(cx, cy, size) & half_plane(0, 1, cy + size * 0.6), STEEL)
    c.flat(box(cx, cy, size * 0.82, size * 0.11, size * 0.05), INK)
    c.draw(box(cx, cy + size * 0.6, size * 1.04, size * 0.17, size * 0.08), STEEL)
    c.draw(ellipse(cx - size * 0.1, cy - size * 1.05, size * 0.28, size * 0.42, angle=-30), plume)


def icon_team(c):
    """The whole squad (team-wide star bonuses)."""
    helmet(c, 24, 50, 19, "#4f7dc2")
    helmet(c, 76, 50, 19, "#5d8f45")
    helmet(c, 50, 62, 25, "#c9493d")


def icon_hits_air(c):
    icon_flying(c)
    c.draw(circle(76, 76, 18), "#4fa35a")
    c.flat(capsule(66, 76, 73, 84, 3) | capsule(73, 84, 86, 68, 3), WHITE)


def icon_misses_air(c):
    icon_flying(c)
    c.draw(circle(76, 76, 18), "#d0453f")
    c.flat(capsule(68, 68, 84, 84, 3) | capsule(84, 68, 68, 84, 3), WHITE)


def icon_shards(c):
    c.draw(polygon([(50, 6), (74, 38), (58, 94), (34, 70), (30, 30)]), "#c77ad8")
    c.flat(polygon([(50, 12), (62, 38), (52, 84), (44, 40)]), "#e2a8ee")
    c.draw(polygon([(76, 52), (88, 64), (80, 88), (70, 72)]), "#b45fc8", outline_px=2.2)


def icon_gold(c):
    c.draw(circle(50, 50, 42), "#f2c13d")
    c.draw(circle(50, 50, 28), "#e0a92a", outline_px=2.4)
    c.flat(box(50, 50, 6, 14, 2), "#f7dc7a")
    c.flat(ellipse(32, 30, 8, 5, angle=-35), WHITE, alpha=0.55)


def icon_gems(c):
    c.draw(polygon([(22, 36), (36, 16), (64, 16), (78, 36), (50, 88)]), "#58c7e8")
    c.flat(polygon([(36, 36), (50, 18), (64, 36), (50, 80)]), "#9be2f5")
    c.flat(capsule(22, 36, 78, 36, 0.9), INK, alpha=0.5)


def icon_souls(c):
    c.glow(50, 56, 44, "#b77cff", 0.4)
    c.draw(teardrop(50, 62, 26, 58, 6), "#9a6ae0")
    c.flat(teardrop(50, 66, 14, 54, 34), "#d2b8ff")
    c.eyes([(43, 62), (57, 62)], 3.6)


def tower(c, roof, body, flag):
    c.draw(box(50, 66, 22, 26, 4), body)
    c.draw(polygon([(20, 42), (80, 42), (50, 8)]), roof)
    c.draw(box(50, 82, 7, 10, 6), "#3b2a24", outline_px=2.0)
    if flag:
        c.draw(polygon([(50, 10), (70, 14), (50, 20)]), roof, outline_px=2.0)


def icon_base_player(c):
    tower(c, "#3f6fb5", "#8b5b37", True)


def icon_base_enemy(c):
    tower(c, "#8e2f36", "#5a5260", False)
    c.glow(50, 60, 14, "#ff5050", 0.7)
    c.flat(ellipse(50, 60, 6, 4), "#ff6a5a")


def icon_income_rate(c):
    icon_gold(c)
    c.draw(polygon([(80, 44), (98, 66), (88, 66), (88, 94), (72, 94), (72, 66), (62, 66)]), "#4fa35a")


def icon_tab_heroes(c):
    c.draw(circle(50, 52, 36) & half_plane(0, 1, 74), STEEL)
    c.flat(box(50, 52, 30, 4, 2), INK)
    c.draw(box(50, 74, 38, 6, 3), STEEL)
    c.draw(ellipse(46, 14, 10, 16, angle=-30), "#c9493d")


def icon_tab_income(c):
    c.draw(circle(50, 60, 32) | polygon([(36, 32), (64, 32), (58, 18), (42, 18)]), "#b98a52")
    c.draw(box(50, 32, 18, 4, 2), "#7a5236")
    c.draw(circle(50, 62, 13), "#f2c13d", outline_px=2.4)
    c.flat(box(50, 62, 3, 7, 1), "#e0a92a")


def icon_tab_relics(c):
    c.draw(polygon([(20, 16), (80, 16), (72, 48), (50, 58), (28, 48)]), GOLD)
    c.draw(box(50, 70, 5, 12, 2), GOLD)
    c.draw(box(50, 86, 22, 6, 3), GOLD)
    c.draw(circle(50, 34, 8), "#e0484e", outline_px=2.4)


def badge(c, color):
    c.draw(circle(50, 50, 44), color)


def icon_race_human(c):
    badge(c, "#3f6fb5")
    c.draw(polygon([(24, 64), (24, 32), (37, 46), (50, 26), (63, 46), (76, 32), (76, 64)]), GOLD)


def icon_race_elf(c):
    badge(c, "#3f6b34")
    c.draw(ellipse(50, 50, 16, 30, angle=35), "#8fd06a")
    c.flat(capsule(36, 70, 64, 30, 1.4), "#3f6b34")


def icon_race_dwarf(c):
    badge(c, "#7a5236")
    c.draw(capsule(34, 76, 64, 30, 3.4), WOOD)
    c.draw(polygon([(52, 24), (78, 30), (82, 52), (64, 44)]), STEEL_LIGHT)


def icon_race_celestial(c):
    badge(c, "#c79a3a")
    c.draw(ellipse(28, 54, 14, 8, angle=-25) | ellipse(72, 54, 14, 8, angle=25), "#f6f1e6", outline_px=2.4)
    c.draw(ring(50, 40, 16, 5), "#fff1b8", outline_px=2.4)


def icon_race_beast(c):
    badge(c, "#8a5a36")
    c.draw(ellipse(50, 62, 16, 13), "#f2e6c8", outline_px=2.4)
    for toe_x, toe_y in ((30, 42), (42, 32), (58, 32), (70, 42)):
        c.draw(circle(toe_x, toe_y, 6.5), "#f2e6c8", outline_px=2.2)


def icon_race_demon(c):
    badge(c, "#7e2422")
    c.draw(polygon([(30, 70), (22, 26), (44, 60)]) | polygon([(70, 70), (78, 26), (56, 60)]), "#f2e6c8", outline_px=2.4)
    c.flat(ellipse(40, 62, 4, 3), "#ffcf6a")
    c.flat(ellipse(60, 62, 4, 3), "#ffcf6a")


def icon_race_elemental(c):
    badge(c, "#3b5b8a")
    c.draw(polygon([(50, 16), (72, 50), (50, 84), (28, 50)]), "#9fe0ff", outline_px=2.4)
    c.flat(polygon([(50, 28), (60, 50), (50, 72), (40, 50)]), "#e4f7ff")


def icon_race_goblinoid(c):
    badge(c, "#5b6b3a")
    c.draw(polygon([(32, 44), (10, 30), (32, 58)]) | polygon([(68, 44), (90, 30), (68, 58)]), "#8fbf5a", outline_px=2.4)
    c.draw(circle(50, 52, 20), "#8fbf5a", outline_px=2.4)
    c.eyes([(43, 50), (57, 50)], 3.4)


def icon_race_undead(c):
    badge(c, "#4a4550")
    skull(c, 50, 50, 0.62)


def icon_lumber_camp(c):
    c.draw(ellipse(50, 70, 36, 14), "#8b5b37")
    c.draw(ellipse(18, 70, 6, 14), "#d9b27a", outline_px=2.4)
    c.draw(capsule(44, 66, 70, 14, 3.2), WOOD)
    c.draw(polygon([(60, 18), (84, 12), (86, 36), (70, 32)]), STEEL_LIGHT)


def icon_copper_mine(c):
    c.draw(polygon([(16, 86), (30, 62), (54, 58), (74, 70), (84, 86)]), "#c9784a")
    c.flat(circle(44, 72, 4), "#f0a878")
    c.draw(capsule(30, 66, 70, 22, 3.2), WOOD)
    c.draw(ring(66, 42, 26, 5.5) & half_plane(0, 1, 30) & half_plane(-1, 0, -42), STEEL)


def icon_fishing_dock(c):
    c.draw(ellipse(46, 50, 30, 18), "#6fa8c9")
    c.draw(polygon([(72, 50), (92, 34), (90, 66)]), "#5b91b3")
    c.flat(ellipse(44, 54, 20, 8), "#b8dcec", alpha=0.7)
    c.eyes([(28, 46)], 3.4)


def icon_blacksmith(c):
    c.draw(polygon([(14, 34), (86, 34), (74, 50), (64, 50), (64, 70), (76, 84), (24, 84), (36, 70), (36, 50), (24, 50)]), "#5a5f6b")
    c.draw(capsule(56, 30, 84, 6, 3), WOOD)
    c.draw(box(52, 30, 12, 7, 2, angle=-40), STEEL_LIGHT)
    c.flat(circle(76, 40, 2.6), EMBER)
    c.flat(circle(84, 30, 2), EMBER)


def icon_merchant_caravan(c):
    c.draw(box(50, 46, 34, 20, 5), "#b98a52")
    c.draw(ellipse(50, 30, 36, 14) & half_plane(0, 1, 34), "#e8e0cc")
    c.draw(circle(28, 72, 12), WOOD)
    c.draw(circle(72, 72, 12), WOOD)
    c.flat(circle(28, 72, 3), GOLD)
    c.flat(circle(72, 72, 3), GOLD)


def icon_royal_mint(c):
    for index, y in enumerate((80, 66, 52)):
        c.draw(ellipse(50, y, 30, 9), "#f2c13d", outline_px=2.4)
    c.draw(polygon([(28, 40), (28, 16), (40, 28), (50, 10), (60, 28), (72, 16), (72, 40)]), GOLD)


def icon_warlords_blade(c):
    c.glow(50, 50, 46, "#ff5040", 0.4)
    sword(c, 24, 80, 82, 18, blade="#e8ecf2", guard="#c9493d")


def icon_iron_heart(c):
    c.draw(heart(50, 52, 84), "#9aa3b0")
    c.flat(heart(50, 50, 52), "#e0484e")
    for rivet_x, rivet_y in ((22, 34), (78, 34), (50, 84)):
        c.flat(circle(rivet_x, rivet_y, 3), "#d9dee6")


def icon_golden_idol(c):
    c.glow(50, 50, 44, "#ffe27a", 0.35)
    c.draw(box(50, 84, 24, 7, 3), "#a77b2a")
    c.draw(box(50, 60, 16, 20, 7), GOLD)
    c.draw(circle(50, 30, 16), GOLD)
    c.flat(ellipse(44, 30, 3, 4), INK)
    c.flat(ellipse(56, 30, 3, 4), INK)
    c.flat(circle(50, 58, 4), "#e0484e")


def icon_bastion_stone(c):
    c.draw(polygon([(20, 88), (16, 30), (36, 12), (66, 12), (84, 32), (80, 88)]), "#8e8a86")
    c.glow(50, 50, 22, "#6fc8ff", 0.5)
    c.flat(zigzag([(42, 30), (58, 42), (42, 56), (58, 70)], 3), "#9fe0ff")


def icon_skill_volley(c):
    for index, (x, y) in enumerate(((20, 68), (36, 80), (52, 92))):
        c.draw(capsule(x, y, x + 44, y - 44, 2.2), "#c9a26a", outline_px=2.2)
        c.draw(polygon([(x + 38, y - 46), (x + 50, y - 50), (x + 46, y - 38)]), STEEL_LIGHT, outline_px=2.0)


def icon_skill_lightning(c):
    c.glow(50, 50, 44, "#ffe066", 0.4)
    c.draw(polygon([(58, 4), (24, 54), (48, 54), (38, 96), (78, 40), (54, 40), (66, 4)]), "#ffe066")


def icon_skill_holy(c):
    c.glow(50, 50, 46, "#fff1b8", 0.5)
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        c.draw(capsule(50 + math.cos(rad) * 26, 50 + math.sin(rad) * 26, 50 + math.cos(rad) * 42, 50 + math.sin(rad) * 42, 3.4), "#f4d35e", outline_px=2.2)
    c.draw(circle(50, 50, 20), "#fff1b8")


def icon_skill_heal(c):
    c.glow(50, 50, 44, "#9cf06b", 0.35)
    c.draw(box(50, 50, 12, 36, 4) | box(50, 50, 36, 12, 4), "#6fd06a")
    c.flat(box(46, 40, 3, 10, 1.5), WHITE, alpha=0.5)


def icon_skill_barrage(c):
    c.draw(star(50, 50, 44, 26, 10, angle=-80), "#ff9a3c")
    for ball_x, ball_y in ((36, 56), (58, 40), (62, 64)):
        c.draw(circle(ball_x, ball_y, 11), "#3b3f49", outline_px=2.4)


def icon_skill_fireball(c):
    c.glow(50, 56, 44, "#ffb347", 0.5)
    c.draw(teardrop(42, 62, 24, 90, 14), "#ff7a3a")
    c.flat(teardrop(42, 64, 14, 70, 36), "#ffcd57")


def icon_skill_dive(c):
    c.draw(ellipse(34, 30, 26, 10, angle=-30) | ellipse(34, 46, 24, 9, angle=-12), "#f3efe6")
    c.draw(polygon([(60, 30), (86, 70), (94, 52), (90, 92), (54, 84), (72, 78)]), "#e0484e")


def icon_skill_clang(c):
    c.draw(star(64, 40, 30, 12, 8), "#ffe27a", outline_px=2.2)
    c.draw(polygon([(14, 30), (56, 30), (56, 56), (35, 86), (14, 56)]), "#6f8fb8")


def icon_skill_vines(c):
    c.draw(ring(50, 56, 26, 7) & half_plane(0, -1, -40), "#4f8a3c")
    c.draw(capsule(24, 56, 30, 92, 3.6), "#4f8a3c")
    for leaf_x, leaf_y, angle in ((30, 30, -30), (70, 30, 30), (50, 22, 0), (24, 74, -60)):
        c.draw(ellipse(leaf_x, leaf_y, 6, 11, angle=angle), "#8fd06a", outline_px=2.2)


def icon_skill_frenzy(c):
    for offset in (0, 30):
        c.draw(polygon([(14 + offset, 20), (44 + offset, 50), (14 + offset, 80), (28 + offset, 80), (58 + offset, 50), (28 + offset, 20)]), "#ff9a3c")


def icon_skill_horn(c):
    c.draw(polygon([(16, 64), (60, 20), (88, 30), (90, 50), (30, 82)]).blend(circle(84, 40, 14), 6), "#d8c08a")
    c.flat(ellipse(84, 40, 7, 10), "#5e3c22")
    c.draw(capsule(30, 54, 58, 70, 2.4), GOLD, outline_px=2.2)


def icon_key(c):
    c.draw(ring(32, 34, 16, 9), GOLD)
    c.draw(capsule(44, 46, 82, 84, 5.5), GOLD)
    c.draw(box(70, 82, 5, 7, 2, angle=45) | box(80, 72, 5, 6, 2, angle=45), GOLD)
    c.flat(ellipse(26, 26, 5, 3, angle=-35), WHITE, alpha=0.6)


def icon_lock(c):
    c.draw(ring(50, 38, 18, 8) & half_plane(0, 1, 46), "#9aa3b0")
    c.draw(box(50, 64, 30, 24, 7), "#e6b649")
    c.flat(circle(50, 60, 6) | box(50, 70, 2.6, 8), "#5e3c22")


def icon_hero_index(c):
    c.draw(box(52, 52, 34, 40, 5), "#7a3a32")
    c.draw(box(56, 52, 28, 36, 3), "#efe6d0")
    c.draw(box(22, 52, 6, 40, 3), "#5a2a24")
    c.draw(circle(56, 46, 13) & half_plane(0, 1, 52), STEEL)
    c.flat(box(56, 48, 11, 2, 1), INK)
    c.draw(box(56, 64, 14, 3, 1.5), "#c9493d", outline_px=1.8)


def chest(c, is_open):
    wood, wood_dark, band, metal = "#9a5f34", "#6e4022", "#d9a63e", "#c9cfd8"
    if is_open:
        c.glow(50, 50, 50, "#ffe27a", 0.85)
        # Lid tipped back: the inside face shows.
        c.draw(polygon([(16, 50), (84, 50), (78, 16), (22, 16)]), wood)
        c.draw(polygon([(22, 46), (78, 46), (74, 22), (26, 22)]), wood_dark)
        for plank_y in (30, 38):
            c.line([(24, plank_y), (76, plank_y)], 0.5, "#3c2618", 0.7)
        for band_x in (28, 72):
            c.draw(polygon([(band_x - 4, 50), (band_x + 4, 50), (band_x + 3 * (1 if band_x > 50 else -1) + 3, 16), (band_x + 3 * (1 if band_x > 50 else -1) - 3, 16)]), band, shine=0.6)
    # Body: planks, gold bands with rivets, metal corners.
    body = box(50, 72, 38, 20, 4)
    c.draw(body, wood)
    for plank_y in (64, 72, 80):
        c.line([(13, plank_y), (87, plank_y)], 0.5, "#3c2618", 0.7)
    for grain_x, grain_y in ((34, 68), (62, 76), (44, 84)):
        c.line([(grain_x, grain_y), (grain_x + 6, grain_y + 0.6)], 0.3, wood_dark, 0.6)
    for band_x in (28, 72):
        c.draw(box(band_x, 72, 4.5, 20, 1.2), band, shine=0.6)
        rivets(c, [(band_x, 58), (band_x, 72), (band_x, 86)], 1.0, "#fff1b8")
    for corner_x, side in ((14, 1), (86, -1)):
        c.draw(polygon([(corner_x - side * 2, 92), (corner_x - side * 2, 80), (corner_x + side * 8, 92)]), metal, shine=0.7)
    c.draw(box(50, 54.5, 38.5, 3, 1.5), band, shine=0.6)
    if is_open:
        c.draw(ellipse(50, 54, 33, 5), "#3a2416")
        c.flat(ellipse(50, 54, 30, 4), "#ffe9a0")
        for coin_x, coin_y in ((36, 50), (44, 48), (56, 49), (63, 51), (50, 46)):
            c.draw(ellipse(coin_x, coin_y, 4, 2.6), GOLD, outline_px=0.6, shine=0.9)
        c.draw(polygon([(58, 44), (62, 38), (66, 44), (62, 50)]), "#5fb6ff", outline_px=0.7, shine=0.9)
        for sparkle_x, sparkle_y, size in ((30, 30, 3.5), (70, 26, 2.8), (52, 18, 4.0)):
            c.flat(star(sparkle_x, sparkle_y, size, size * 0.25, 4), "#fff8d8")
    else:
        lid = ellipse(50, 54, 38, 16) & half_plane(0, 1, 56)
        c.draw(lid, wood)
        for plank_y in (44, 50):
            c.line([(14, plank_y + 4), (30, plank_y), (70, plank_y), (86, plank_y + 4)], 0.5, "#3c2618", 0.7)
        for band_x in (28, 72):
            c.draw(lid & box(band_x, 46, 4.5, 12, 1.2), band, shine=0.6)
            rivets(c, [(band_x, 44)], 1.0, "#fff1b8")
        c.draw(box(50, 54.5, 38.5, 3, 1.5), band, shine=0.6)
        # Lock plate with a keyhole.
        c.draw(box(50, 60, 8, 9, 2.5), metal, shine=0.8)
        rivets(c, [(44.5, 53.5), (55.5, 53.5), (44.5, 66.5), (55.5, 66.5)], 0.8, "#f1f3f6")
        c.flat(circle(50, 58.5, 2.2) | polygon([(48.6, 59), (51.4, 59), (52.2, 65), (47.8, 65)]), "#1a1416")


def icon_chest(c):
    chest(c, False)


ICONS = {name[5:]: function for name, function in globals().items() if name.startswith("icon_") and callable(function)}


def rays(c):
    """Soft light rays (white; tinted in the game)."""
    for index in range(14):
        angle = math.radians(index * 360.0 / 14)
        spread = math.radians(7)
        far = 50.0
        c.flat(polygon([(50, 50), (50 + math.cos(angle - spread) * far, 50 + math.sin(angle - spread) * far), (50 + math.cos(angle + spread) * far, 50 + math.sin(angle + spread) * far)]), WHITE, alpha=0.5)
    c.glow(50, 50, 30, WHITE, 0.6)


# ============================================
# ENTRY POINT
# ============================================

def painted(width, height, name, outline_px, design_width=100.0):
    """A canvas in the painted look: shaded volumes, one silhouette outline."""
    return Canvas(width, height, design_width=design_width, seed=name, outline_px=outline_px, palette=muted, paint=True, supersample=SUPERSAMPLE)


def render_character(name, draw, size):
    canvas = painted(size, size, name, size / 44.0)
    draw(canvas)
    canvas.finish()
    return canvas


def render_base(name, draw):
    canvas = painted(240, 384, name, 4.0, design_width=160.0)
    draw(canvas)
    canvas.finish()
    return canvas


def render_icon(name, draw):
    # A lighter silhouette line than the characters, so icons stay crisp at 40 px.
    canvas = painted(ICON_SIZE, ICON_SIZE, name, 2.8)
    draw(canvas)
    canvas.finish(grain=0.03)
    return canvas


def build_jobs():
    """(folder, name, render) for every image, in a fixed order."""
    jobs = []
    for name, draw in HEROES.items():
        jobs.append(("Heroes", name, partial(render_character, name, draw, CHARACTER_SIZE)))
    for name, draw in MONSTERS.items():
        jobs.append(("Monsters", name, partial(render_character, name, draw, BOSS_SIZE if name in BOSSES else CHARACTER_SIZE)))
    for name, draw in (("player_base", base_player), ("enemy_base", base_enemy)):
        jobs.append(("Bases", name, partial(render_base, name, draw)))
    for name, draw in PROPS.items():
        jobs.append(("Props", name, partial(render_character, name, draw, 160)))
    for name, is_open in (("hero_chest_closed", False), ("hero_chest_open", True)):
        jobs.append(("Chest", name, partial(render_character, name, partial(chest, is_open=is_open), 192)))
    jobs.append(("Effects", "rays", _render_rays))
    for name, draw in ICONS.items():
        jobs.append(("Icons", name, partial(render_icon, name, draw)))
    return jobs


def _render_rays():
    canvas = Canvas(256, 256, seed="rays", outline_px=0.0, wobble_px=0.0)
    rays(canvas)
    # Fade the rays out toward the edge so they read as light, not wedges.
    center = canvas.width / 2.0
    for py in range(canvas.height):
        for px in range(canvas.width):
            falloff = max(0.0, 1.0 - math.hypot(px + 0.5 - center, py + 0.5 - center) / center)
            canvas.pixels[(py * canvas.width + px) * 4 + 3] *= falloff ** 1.3
    return canvas


def write_sheet(path, canvases):
    """Preview: every image on a dark backdrop, 6 per row."""
    cell = 168
    columns = 6
    rows = (len(canvases) + columns - 1) // columns
    sheet = Canvas(cell * columns, cell * rows, design_width=cell * columns, seed="sheet", outline_px=0.0, wobble_px=0.0)
    background = rgb("#2b2630")
    for index in range(0, len(sheet.pixels), 4):
        sheet.pixels[index:index + 4] = [background[0], background[1], background[2], 1.0]
    for item_index, canvas in enumerate(canvases):
        origin_x = (item_index % columns) * cell + (cell - min(canvas.output_width, cell)) // 2
        origin_y = (item_index // columns) * cell + (cell - min(canvas.output_height, cell)) // 2
        source_pixels = canvas.output_pixels()
        source_width, source_height = canvas.output_width, canvas.output_height
        step = max(1.0, max(source_width, source_height) / (cell - 8))
        for sy in range(min(cell - 8, int(source_height / step))):
            for sx in range(min(cell - 8, int(source_width / step))):
                source = (int(sy * step) * source_width + int(sx * step)) * 4
                alpha = source_pixels[source + 3]
                if alpha > 0.0:
                    sheet._blend(((origin_y + sy) * sheet.width + origin_x + sx) * 4, source_pixels[source:source + 3], alpha)
    sheet.save(Path(path))


def _run_job(job, keep=False):
    folder, name, render = job
    canvas = render()
    canvas.save(ART_DIR / folder / (name + ".png"))
    # Canvases only travel back to the parent when a preview sheet needs them.
    return folder, name, canvas if keep else None


def main(arguments):
    sheet_path = None
    if "--sheet" in arguments:
        sheet_index = arguments.index("--sheet")
        sheet_path = arguments[sheet_index + 1]
        arguments = arguments[:sheet_index] + arguments[sheet_index + 2:]
    wanted = set(arguments)
    jobs = [job for job in build_jobs() if not wanted or job[0] in wanted or job[1] in wanted]
    rendered = []
    # Painting is CPU-bound pure Python: one process per core ("fork" keeps
    # the drawing functions without pickling them).
    with multiprocessing.get_context("fork").Pool() as pool:
        for folder, name, canvas in pool.imap(partial(_run_job, keep=sheet_path is not None), jobs):
            print(folder, name)
            if sheet_path:
                rendered.append(canvas)
    if sheet_path:
        write_sheet(sheet_path, rendered)


if __name__ == "__main__":
    main(sys.argv[1:])
