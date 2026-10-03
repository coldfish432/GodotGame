"""Build the H1b native-grid wayfinding assets."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from pixel_kit import (  # noqa: E402
    COLORS, GLYPH_ORDER, canvas, dependency, draw_text, glyph_sheet, line,
    load, paste, poly, rect, rgba, save_native, write_json,
)

H1 = ART / "batch_H1_bridge_hall_v2"
L0 = ART / "batch_L0_logo_v1"
B1 = ART / "batch1_v5"
B2 = ART / "batch2_v2"
ROOT.mkdir(exist_ok=True)
assets: list[dict] = []


def register(stem: str, image: Image.Image, kind: str, notes: str, coverage: list[str],
             *, wall: bool = False, anchor: tuple[int, int] | None = None) -> None:
    save_native(image, ROOT, stem)
    if anchor is None:
        anchor = (image.width // 2, 0 if wall else image.height // 2)
    assets.append({
        "id": stem, "file": f"{stem}.png", "emit": None, "kind": kind,
        "size_px": list(image.size), "anchor_px": list(anchor),
        "footprint_units": [0, 0] if wall else [round(image.width / 15, 2), round(image.height / 15, 2)],
        "wall_mounted": wall, "states": ["default"], "notes": notes,
        "coverage_35": coverage,
    })


def icon_from_arrow(index: int) -> Image.Image:
    original = load(H1 / f"floor_arrow_icon_{index:02}.png")
    icon = canvas(13, 12)
    dark = rgba("D")
    for y in range(12):
        for x in range(13):
            if original.getpixel((x + 14, y + 14)) == dark:
                icon.putpixel((x, y), dark)
    return icon


icons = [icon_from_arrow(i) for i in range(1, 5)]


def horizontal_arrow(index: int, direction: str) -> Image.Image:
    image = canvas(40, 28)
    if direction == "left":
        dark = [(0, 14), (14, 2), (14, 7), (39, 7), (39, 21), (14, 21), (14, 26)]
        yellow = [(3, 14), (13, 5), (13, 9), (37, 9), (37, 19), (13, 19), (13, 23)]
    else:
        dark = [(39, 14), (25, 2), (25, 7), (0, 7), (0, 21), (25, 21), (25, 26)]
        yellow = [(36, 14), (26, 5), (26, 9), (2, 9), (2, 19), (26, 19), (26, 23)]
    poly(image, dark, "D")
    poly(image, yellow, "Y2")
    line(image, [(15, 9), (24, 9)], "W1")
    paste(image, icons[index - 1], (14, 8))
    return image


for font in (5, 3):
    image, lookup = glyph_sheet(font)
    stem = f"rhodes_glyphs_{font}x{7 if font == 5 else 5}"
    register(stem, image, "decal", f"Native {font}x{7 if font == 5 else 5} glyph atlas; use glyph_lookup.json rectangles and one-pixel tracking.", ["B: complete native-grid glyph sheet"])
    if font == 5:
        lookup_5 = lookup
    else:
        lookup_3 = lookup

write_json(ROOT / "glyph_lookup.json", {
    "characters": GLYPH_ORDER,
    "fonts": {"5x7": lookup_5, "3x5": lookup_3},
    "text_rules": {"capitals_only": True, "tracking_px": 1, "line_spacing_px": 2},
})

names = ["STORE", "ARMORY", "WAREHOUSE", "MEDICAL"]
directions = ["left", "right", "left", "right"]
board = canvas(192, 50)
rect(board, (0, 0, 191, 49), "S0")
rect(board, (1, 1, 190, 48), "S2")
rect(board, (2, 2, 189, 47), "S1")
rect(board, (2, 0, 189, 1), "Y2")
for index, (name, direction) in enumerate(zip(names, directions, strict=True)):
    y = 2 + index * 12
    rect(board, (3, y, 176, y + 10), "S2" if index % 2 else "S1")
    rect(board, (3, y, 4, y + 10), "Y2" if index == 0 else "B1")
    draw_text(board, f"B1-0{index + 1}", 7, y + 2, 5, "G2")
    rect(board, (39, y, 51, y + 10), "Y2")
    paste(board, icons[index], (39, y))
    draw_text(board, name, 59, y + 2, 5, "W1")
    arrow_x = 160
    if direction == "left":
        line(board, [(arrow_x + 10, y + 5), (arrow_x, y + 5), (arrow_x + 4, y + 2)], "Y2")
        line(board, [(arrow_x, y + 5), (arrow_x + 4, y + 8)], "Y2")
    else:
        line(board, [(arrow_x, y + 5), (arrow_x + 10, y + 5), (arrow_x + 6, y + 2)], "Y2")
        line(board, [(arrow_x + 10, y + 5), (arrow_x + 6, y + 8)], "Y2")
paste(board, load(L0 / "rhodes_logo_S_gray_v1.png"), (180, 20))
register("hall_directory_board_192x50", board, "wall", "Lists B1-01 STORE, B1-02 ARMORY, B1-03 WAREHOUSE, B1-04 MEDICAL; icons are pixel masks extracted from accepted H1 v2 arrows, with left/right directions from hall plan.", ["B: hall directory board", "B: four numbered destinations", "D: accepted S identity stamp"], wall=True)

for index in range(1, 13):
    plate = canvas(32, 12)
    rect(plate, (0, 0, 31, 11), "S0")
    rect(plate, (1, 1, 30, 10), "S2")
    rect(plate, (2, 2, 29, 9), "S1")
    rect(plate, (2, 2, 29, 3), "Y2" if index <= 4 else "G0")
    draw_text(plate, f"B1-{index:02}", 6, 5, 3, "W1")
    register(f"small_number_plate_B1_{index:02}", plate, "wall", f"Small numbered plate B1-{index:02}; 3x5 lettering. B1-01 through B1-04 pair with accepted hall room signs; B1-05 through B1-12 reserve future rooms.", ["B: numbered room plate", "D: standardized ship ID"], wall=True)

for direction in ("left", "right"):
    for index, name in enumerate(names, start=1):
        arrow = horizontal_arrow(index, direction)
        register(f"floor_arrow_{name.lower()}_{direction}_40x28", arrow, "decal", f"{direction.upper()} floor arrow for B1-0{index} {name}; 40x28, bright safety yellow, dark outline; icon remains upright and matches the H1 v2 source mask.", [f"B: {name} {direction}-pointing floor arrow and upright icon"])

floor = load(B2 / "rhodes_floor_v1.png")
wall = load(B1 / "wall_straight_60x46_v5.png")
lap = load(B1 / "lappland_frame0_64.png")
composite = canvas(760, 300)
for y in range(300):
    for x in range(760):
        source = wall.getpixel((x % 60, y)) if y < 46 else floor.getpixel((x % 120, (y - 46) % 120))
        composite.putpixel((x, y), source)
paste(composite, board, (12, 0))
rect(composite, (11, 59, 106, 119), "S0")
rect(composite, (121, 59, 186, 112), "S0")
paste(composite, load(ROOT / "rhodes_glyphs_5x7.png"), (14, 62))
paste(composite, load(ROOT / "rhodes_glyphs_3x5.png"), (124, 62))
for index in range(12):
    plate = load(ROOT / f"small_number_plate_B1_{index + 1:02}.png")
    paste(composite, plate, (215 + (index % 4) * 40, 65 + (index // 4) * 18))
for index, name in enumerate(names, start=1):
    paste(composite, load(ROOT / f"floor_arrow_{name.lower()}_left_40x28.png"), (18 + (index - 1) * 50, 165))
    paste(composite, load(ROOT / f"floor_arrow_{name.lower()}_right_40x28.png"), (18 + (index - 1) * 50, 205))
alpha_bounds = lap.getchannel("A").getbbox()
paste(composite, lap.crop((0, 0, 64, 64)), (680, 260 - (alpha_bounds[3] - 1)))
composite.save(ROOT / "H1b_wayfinding_lappland_1x.png")

deps = [
    dependency(B2 / "rhodes_floor_v1.png", ROOT, "Accepted dark-steel floor for native-scale composite"),
    dependency(B1 / "wall_straight_60x46_v5.png", ROOT, "Accepted 46px wall for native-scale composite"),
    dependency(B1 / "lappland_frame0_64.png", ROOT, "Lappland frame 0 at original 1:1 scale"),
    dependency(L0 / "rhodes_logo_S_gray_v1.png", ROOT, "Accepted S stamp on directory board"),
    dependency(H1 / "exit_wayfinding_sign.png", ROOT, "Accepted green EXIT sign; reuse unchanged"),
]
for index in range(1, 5):
    deps.append(dependency(H1 / f"floor_arrow_icon_{index:02}.png", ROOT, "Accepted icon shape source for horizontal arrows and hall directory"))
    deps.append(dependency(H1 / f"side_wall_top_sign_{index:02}.png", ROOT, "Accepted door/sign plate styling; use unchanged"))

manifest = {
    "batch": "H1b wayfinding v1",
    "spec": "罗德岛基地美术策划案_v2_0.md §§3.4, 3.5 B, 4.2 H1b, 4.4",
    "pixel_scale": 1,
    "assets": assets,
    "glyph_lookup": "glyph_lookup.json",
    "external_dependencies": deps,
    "preview": {"file": "H1b_wayfinding_lappland_1x.png", "size_px": [760, 300], "character": "Lappland frame 0, unscaled 64x64 source", "character_origin_px": [680, 260 - (alpha_bounds[3] - 1)], "purpose": "Native-scale parts sheet"},
    "assembly": {"directory": "Wall-mount as one 192x50 board; STORE and WAREHOUSE point left, ARMORY and MEDICAL point right.", "arrows": "Use the accepted upward arrows from H1 v2 and these eight new left/right arrows; icons stay upright.", "font": "Glyphs are hand-drawn. Use glyph_lookup.json rect_px and 1px tracking; no engine text rendering required."},
}
write_json(ROOT / "manifest.json", manifest)
(ROOT / "validation.txt").write_text(
    f"H1b v1 generated: {len(assets)} native assets; glyph lookup includes {len(GLYPH_ORDER)} characters in both 5x7 and 3x5.\n"
    "Directory has B1-01 STORE, B1-02 ARMORY, B1-03 WAREHOUSE and B1-04 MEDICAL; its icon masks derive from accepted H1 v2 arrows.\n"
    "Twelve small number plates cover B1-01 through B1-12. Eight horizontal arrow variants keep their four accepted icons upright.\n"
    "§3.5 B coverage is listed per asset in manifest.json; full-room readability awaits assembly.\n",
    encoding="utf-8",
)
print(f"H1b: {len(assets)} assets, glyph lookup and 1:1 composite")
