"""Draw H3 STORE, ARMORY and MEDICAL as native-grid, assembly-ready kits."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

from pixel_kit import (
    COLORS, GLYPHS_5, canvas, dependency, draw_text, emit_from_colors,
    line, load, paste, poly, rect, rgba, save_native, write_json,
)

ART = Path(__file__).resolve().parent
B1 = ART / "batch1_v5"
LIGHT = ART / "batch3_equipment_v3"
H1 = ART / "batch_H1_bridge_hall_v2"
H1B = ART / "batch_H1b_wayfinding_v1"
L0 = ART / "batch_L0_logo_v1"
LOGO_M = load(L0 / "rhodes_logo_M_gray_v1.png")
LOGO_S = load(L0 / "rhodes_logo_S_gray_v1.png")
LAP = load(B1 / "lappland_frame0_64.png")


def ellipse(im: Image.Image, box: tuple[int, int, int, int], color: str, width: int = 0) -> None:
    d = ImageDraw.Draw(im)
    if width:
        d.ellipse(box, outline=rgba(color), width=width)
    else:
        d.ellipse(box, fill=rgba(color))


def text2(im: Image.Image, value: str, x: int, y: int, color: str) -> None:
    ink = rgba(color)
    for index, char in enumerate(value):
        if char == " ":
            continue
        for yy, row in enumerate(GLYPHS_5[char].split("/")):
            for xx, bit in enumerate(row):
                if bit == "1":
                    rect(im, (x + index * 12 + xx * 2, y + yy * 2,
                              x + index * 12 + xx * 2 + 1, y + yy * 2 + 1), color)


def recolor(source: Image.Image, mapping: dict[str, str]) -> Image.Image:
    table = {rgba(old): rgba(new) for old, new in mapping.items()}
    target = source.copy()
    target.putdata([table.get(pixel, pixel) for pixel in source.get_flattened_data()])
    return target


class Room:
    def __init__(self, name: str, code: str, units: tuple[int, int], floor_size: tuple[int, int],
                 wall: Path | None, floor: Path | None):
        self.name, self.code, self.units, self.floor_size = name, code, units, floor_size
        self.root = ART / f"batch_H3_{name.lower()}_v1"
        self.root.mkdir(exist_ok=True)
        self.wall, self.floor = wall, floor
        self.assets: list[dict] = []
        self.dependencies: dict[str, dict] = {}
        self.details: list[str] = []
        self.preview_positions: list[tuple[str, tuple[int, int]]] = []

    def dep(self, path: Path, use: str) -> None:
        self.dependencies[str(path)] = dependency(path, self.root, use)

    def add(self, stem: str, image: Image.Image, kind: str, notes: str, covers: list[str],
            *, emit: tuple[str, ...] = (), wall: bool = False, states: list[str] | None = None,
            footprint: tuple[float, float] | None = None, life: bool = False) -> None:
        save_native(image, self.root, stem)
        emit_name = None
        if emit:
            mask = emit_from_colors(image, emit)
            if mask.getchannel("A").getbbox():
                emit_name = f"{stem}_emit.png"
                save_native(mask, self.root, f"{stem}_emit")
        if footprint is None:
            footprint = (0.0, 0.0) if wall else (round(image.width / 15, 2),
                         round(image.height / 15, 2) if kind == "decal" else 1.0)
        anchor = [image.width // 2, 0 if wall else image.height // 2 if kind == "decal" else image.height - 1]
        self.assets.append({
            "id": stem, "file": f"{stem}.png", "emit": emit_name, "kind": kind,
            "size_px": list(image.size), "anchor_px": anchor,
            "footprint_units": list(footprint), "wall_mounted": wall,
            "states": states or ["default"], "notes": notes, "coverage_35": covers,
        })
        if life:
            self.details.append(stem)

    def show(self, stem: str, x: int, y: int) -> None:
        self.preview_positions.append((stem, (x, y)))

    def complete(self, preview_size: tuple[int, int], lap_xy: tuple[int, int], assembly: dict,
                 checklist: dict, lighting: list[Path]) -> None:
        wall = load(self.wall)
        floor = load(self.floor)
        preview = canvas(*preview_size)
        for y in range(preview.height):
            for x in range(preview.width):
                preview.putpixel((x, y), wall.getpixel((x % 60, y)) if y < 46 else
                                 floor.getpixel((x % floor.width, (y - 46) % floor.height)))
        for stem, xy in self.preview_positions:
            paste(preview, load(self.root / f"{stem}.png"), xy)
        paste(preview, LAP, lap_xy)
        preview_name = f"H3_{self.name.lower()}_lappland_1x.png"
        preview.save(self.root / preview_name)
        self.dep(self.wall, f"{self.name} wall shell; locked 46px geometry")
        self.dep(self.floor, f"{self.name} floor tile; 30px plate pattern")
        self.dep(B1 / "lappland_frame0_64.png", "Native 1:1 character scale proof")
        self.dep(L0 / "rhodes_logo_M_gray_v1.png", "Accepted M mark for department sign")
        self.dep(L0 / "rhodes_logo_S_gray_v1.png", "Accepted S mark for principal interactive prop")
        self.dep(H1B / f"small_number_plate_{self.code.replace('-', '_')}.png", "Accepted doorway number plate")
        for path in lighting:
            self.dep(path, "Accepted opaque-black additive light pool; layer with additive blend")
        self.dep(LIGHT / "door_open_45x46_light_v2.png", "Accepted 45x46 light door with 32x36 clearance")
        self.dep(LIGHT / "door_closed_45x46_light_v2.png", "Accepted light door closed state")
        manifest = {
            "batch": f"H3 {self.name} v1", "spec": "罗德岛基地美术策划案_v2_0.md §§2.3, 3.1.1, 3.5, 3.7, 4.4",
            "pixel_scale": 1, "assets": self.assets,
            "external_dependencies": list(self.dependencies.values()),
            "shell": {"size_units": list(self.units), "floor_size_px": list(self.floor_size),
                      "wall_height_px": 46, "wall_tile": self.dependencies[str(self.wall)]["file"],
                      "floor_tile": self.dependencies[str(self.floor)]["file"],
                      "door_plate": f"../batch_H1b_wayfinding_v1/small_number_plate_{self.code.replace('-', '_')}.png",
                      "assembly": "Parts only; use accepted light door, side strip and corner geometry; keep a >=45px central route."},
            "preview": {"file": preview_name, "size_px": list(preview_size),
                        "character": "Lappland frame 0; 64x64 canvas, 30px visible character, no scaling",
                        "character_origin_px": list(lap_xy), "purpose": "1:1 native-scale asset review sheet, not an assembled room"},
            "logo_policy": "Exactly two representative marks in the preview: M on department sign and S on main interactive prop; <=6 per assembled screen.",
            "stand_spots": [a["id"] for a in self.assets if "stand_spot" in a["id"]],
            "life_details": self.details,
            "assembly": assembly, "checklist_35": checklist,
        }
        write_json(self.root / "manifest.json", manifest)
        (self.root / "validation.txt").write_text(
            f"H3 {self.name} v1 native-grid delivery: {len(self.assets)} assets, {sum(bool(a['emit']) for a in self.assets)} emit masks.\n"
            f"Shell: {self.units[0]}x{self.units[1]} units, {self.floor_size[0]}x{self.floor_size[1]} floor px, 46px wall.\n"
            f"Two stand spots; {len(self.details)} attached life details; two accepted logo instances in preview.\n"
            "All assets exported natively and at exact 8x nearest-neighbor; independent audit follows.\n",
            encoding="utf-8",
        )


def make_shells() -> tuple[Path, Path, Path]:
    light_wall = load(LIGHT / "wall_straight_60x46_light_v2.png")
    light_floor = load(LIGHT / "rhodes_floor_equipment_v1.png")
    store_root = ART / "batch_H3_store_v1"
    med_root = ART / "batch_H3_medical_v1"
    store_wall = recolor(light_wall, {"G1": "W0", "W0": "G2", "G2": "L2", "G0": "G1", "Y1": "L1"})
    med_wall = recolor(light_wall, {"G1": "G2", "W0": "W1", "G2": "W2", "G0": "G1", "Y1": "B1"})
    med_floor = recolor(light_floor, {"S3": "G0", "G0": "G1", "S0": "S2", "S2": "S3", "D": "S1"})
    for root, stem, image in ((store_root, "store_wall_warm_60x46", store_wall),
                              (med_root, "medical_wall_white_60x46", med_wall),
                              (med_root, "medical_floor_cool_120x120", med_floor)):
        save_native(image, root, stem)
    return (store_root / "store_wall_warm_60x46.png", med_root / "medical_wall_white_60x46.png",
            med_root / "medical_floor_cool_120x120.png")


def department_sign(name: str, code: str, hue: str, dark: str = "S1") -> Image.Image:
    im = canvas(120, 46)
    rect(im, (0, 0, 119, 45), "S2")
    rect(im, (2, 2, 117, 43), dark)
    rect(im, (3, 4, 116, 6), hue)
    rect(im, (4, 39, 115, 41), hue)
    paste(im, LOGO_M, (5, 11))
    text2(im, name, 31, 13, "W1" if dark == "S1" else "D")
    draw_text(im, code, 33, 32, 5, "G2" if dark == "S1" else "S1")
    return im


def stand_spot(color: str = "S3") -> Image.Image:
    im = canvas(12, 6)
    ellipse(im, (0, 1, 11, 4), color, 1)
    return im


def floor_zone(width: int, height: int, color: str) -> Image.Image:
    im = canvas(width, height)
    for x in range(3, width - 6, 12):
        rect(im, (x, 2, min(x + 7, width - 4), 3), color)
        rect(im, (x, height - 4, min(x + 7, width - 4), height - 3), color)
    for y in range(7, height - 6, 10):
        rect(im, (2, y, 3, min(y + 5, height - 6)), color)
        rect(im, (width - 4, y, width - 3, min(y + 5, height - 6)), color)
    return im


def hazard_strip() -> Image.Image:
    im = canvas(30, 10)
    rect(im, (0, 2, 29, 8), "S1")
    for x in range(-7, 34, 9):
        poly(im, [(x, 8), (x + 4, 8), (x + 10, 2), (x + 6, 2)], "Y1")
    rect(im, (0, 2, 29, 2), "G0")
    return im


def task_lamp() -> Image.Image:
    im = canvas(34, 18)
    rect(im, (15, 0, 18, 6), "G0")
    poly(im, [(8, 6), (25, 6), (31, 14), (2, 14)], "G1")
    rect(im, (6, 12, 27, 15), "G2")
    rect(im, (9, 16, 24, 17), "W2")
    return im


def price_tag(value: str) -> Image.Image:
    im = canvas(24, 14)
    rect(im, (1, 0, 22, 13), "L2")
    rect(im, (2, 1, 21, 12), "G2")
    rect(im, (2, 1, 21, 2), "O1")
    draw_text(im, value, 3, 4, 3, "D")
    return im


def store_counter() -> Image.Image:
    im = canvas(84, 48)
    # Self-service screen sits on the counter, not on a floor stalk.
    rect(im, (46, 3, 70, 24), "S2")
    rect(im, (48, 5, 68, 20), "B0")
    rect(im, (50, 7, 66, 18), "G0")
    line(im, [(51, 15), (55, 12), (59, 14), (64, 9)], "T2")
    rect(im, (56, 22, 60, 25), "S3")
    rect(im, (4, 27, 79, 30), "W1")
    rect(im, (5, 31, 78, 44), "G2")
    rect(im, (6, 32, 77, 34), "W0")
    rect(im, (8, 35, 75, 42), "G1")
    rect(im, (4, 45, 79, 47), "S3")
    rect(im, (9, 25, 43, 26), "L1")
    rect(im, (11, 28, 16, 29), "O2")
    rect(im, (69, 28, 73, 29), "T2")
    paste(im, LOGO_S, (13, 35))
    # Small till and receipt are attached to the top.
    rect(im, (20, 19, 32, 25), "S3")
    rect(im, (22, 18, 30, 20), "W1")
    rect(im, (31, 22, 35, 27), "L2")
    return im


def display_case(weapon: bool) -> Image.Image:
    im = canvas(58, 42)
    rect(im, (4, 3, 53, 30), "G1")
    rect(im, (6, 5, 51, 27), "G0")
    rect(im, (8, 7, 49, 25), "S1")
    rect(im, (9, 8, 48, 24), "S2")
    if weapon:
        line(im, [(17, 19), (37, 8)], "W1", 2)
        line(im, [(20, 21), (39, 10)], "G2")
        line(im, [(15, 16), (21, 23)], "S3", 2)
        rect(im, (11, 15, 17, 16), "L1")
    else:
        poly(im, [(21, 9), (34, 9), (39, 15), (36, 23), (19, 23), (16, 15)], "G2")
        poly(im, [(23, 11), (32, 11), (35, 16), (33, 21), (21, 21), (19, 16)], "W1")
        rect(im, (24, 13, 30, 14), "B1")
    line(im, [(8, 7), (18, 7), (11, 23)], "G2")
    rect(im, (5, 28, 52, 31), "W1")
    rect(im, (6, 32, 51, 37), "G1")
    rect(im, (9, 38, 13, 41), "S3")
    rect(im, (44, 38, 48, 41), "S3")
    rect(im, (12, 29, 15, 29), "T2")
    rect(im, (42, 29, 45, 29), "T2")
    return im


def product_shelf() -> Image.Image:
    im = canvas(92, 56)
    rect(im, (3, 3, 88, 6), "G2")
    rect(im, (4, 7, 87, 53), "G1")
    for y in (21, 38, 52):
        rect(im, (5, y, 86, y + 2), "S3")
        rect(im, (5, y, 86, y), "W1")
    for x in (6, 42, 85):
        rect(im, (x, 6, x + 2, 54), "S3")
    for x in (11, 26, 49, 65, 75):
        rect(im, (x, 11, x + 6, 19), "W0")
        rect(im, (x + 1, 9, x + 5, 11), "S2")
        rect(im, (x + 2, 14, x + 4, 15), "L1")
    for x in (12, 31, 52, 70):
        rect(im, (x, 27, x + 10, 36), "G2")
        rect(im, (x + 2, 29, x + 8, 30), "B1")
        rect(im, (x + 3, 34, x + 7, 35), "L1")
    draw_text(im, "RI-01", 9, 44, 3, "S1")
    return im


def shop_poster() -> Image.Image:
    im = canvas(30, 38)
    rect(im, (1, 1, 28, 36), "S2")
    rect(im, (3, 3, 26, 34), "L2")
    rect(im, (5, 5, 24, 8), "O1")
    rect(im, (7, 12, 22, 13), "D")
    rect(im, (10, 15, 19, 16), "O1")
    poly(im, [(15, 19), (20, 25), (15, 31), (10, 25)], "B0")
    rect(im, (14, 22, 16, 27), "W1")
    return im


def shop_lamp() -> Image.Image:
    im = canvas(34, 18)
    rect(im, (15, 0, 18, 5), "S3")
    poly(im, [(8, 6), (25, 6), (31, 14), (2, 14)], "L1")
    rect(im, (6, 12, 27, 15), "L2")
    rect(im, (9, 16, 24, 17), "W1")
    return im


def armory_bench() -> Image.Image:
    im = canvas(110, 50)
    rect(im, (38, 0, 68, 23), "S3")
    rect(im, (40, 2, 66, 20), "B0")
    rect(im, (42, 4, 64, 18), "G0")
    line(im, [(43, 14), (47, 10), (51, 12), (57, 7), (63, 9)], "T2")
    rect(im, (47, 22, 59, 27), "G1")
    rect(im, (4, 27, 105, 31), "W1")
    rect(im, (6, 32, 103, 45), "G2")
    rect(im, (8, 34, 101, 38), "W0")
    rect(im, (9, 39, 100, 43), "G1")
    rect(im, (7, 46, 17, 49), "S3")
    rect(im, (92, 46, 102, 49), "S3")
    rect(im, (18, 24, 33, 26), "S2")
    rect(im, (20, 22, 31, 23), "W1")
    rect(im, (76, 23, 93, 25), "S3")
    rect(im, (79, 21, 91, 22), "Y1")
    paste(im, LOGO_S, (12, 34))
    draw_text(im, "RI-02", 75, 35, 3, "S2")
    return im


def weapon_wall() -> Image.Image:
    im = canvas(106, 60)
    rect(im, (2, 2, 103, 57), "G1")
    rect(im, (4, 4, 101, 55), "G2")
    rect(im, (5, 8, 100, 9), "Y1")
    for x in (15, 35, 55, 75, 94):
        line(im, [(x + 4, 15), (x + 4, 47)], "S2", 2)
        line(im, [(x + 3, 16), (x + 3, 38)], "W2")
        poly(im, [(x + 3, 13), (x + 6, 17), (x + 5, 23), (x + 2, 23)], "S3")
        rect(im, (x, 40, x + 7, 42), "S3")
        rect(im, (x + 2, 43, x + 5, 48), "S2")
    rect(im, (7, 51, 98, 53), "G0")
    draw_text(im, "B1-02", 9, 11, 3, "S2")
    return im


def robotic_arm() -> Image.Image:
    im = canvas(55, 58)
    rect(im, (7, 51, 47, 56), "S3")
    rect(im, (16, 45, 37, 51), "G1")
    ellipse(im, (17, 37, 30, 50), "G0")
    ellipse(im, (20, 40, 27, 47), "S2")
    poly(im, [(23, 39), (27, 18), (34, 19), (31, 40)], "W1")
    line(im, [(26, 25), (31, 25)], "G2")
    ellipse(im, (26, 13, 39, 26), "G0")
    ellipse(im, (30, 17, 35, 22), "S2")
    poly(im, [(34, 15), (18, 5), (13, 10), (28, 23)], "G2")
    line(im, [(16, 7), (29, 18)], "W2")
    poly(im, [(12, 8), (8, 14), (15, 20), (20, 13)], "G1")
    rect(im, (6, 15, 9, 22), "S3")
    rect(im, (19, 22, 20, 30), "Y1")
    line(im, [(42, 53), (46, 44), (46, 27), (37, 19)], "O1")
    return im


def hoist() -> Image.Image:
    im = canvas(64, 74)
    rect(im, (3, 1, 60, 4), "S3")
    rect(im, (4, 1, 59, 1), "W1")
    for x in (8, 55):
        rect(im, (x, 4, x + 2, 11), "G1")
    rect(im, (28, 5, 39, 13), "G1")
    rect(im, (30, 7, 37, 12), "Y1")
    rect(im, (33, 14, 34, 54), "S2")
    rect(im, (32, 14, 32, 48), "G0")
    poly(im, [(27, 55), (39, 55), (39, 60), (36, 64), (34, 65), (34, 69), (30, 69), (30, 63), (27, 61)], "G1")
    rect(im, (29, 56, 37, 57), "W1")
    line(im, [(30, 68), (31, 72), (36, 72), (38, 68)], "S2", 2)
    rect(im, (8, 5, 20, 6), "Y1")
    return im


def tool_board() -> Image.Image:
    im = canvas(58, 42)
    rect(im, (1, 1, 56, 40), "G1")
    rect(im, (3, 3, 54, 38), "W0")
    for x in range(6, 54, 8):
        for y in range(7, 38, 8):
            rect(im, (x, y, x + 1, y + 1), "G0")
    for x in (12, 24, 39):
        rect(im, (x, 11, x + 2, 30), "S3")
        rect(im, (x - 3, 9, x + 5, 12), "G2")
        rect(im, (x - 1, 30, x + 3, 32), "Y1")
    rect(im, (44, 17, 47, 30), "S2")
    return im


def equipment_case() -> Image.Image:
    im = canvas(48, 30)
    rect(im, (3, 8, 44, 26), "G1")
    rect(im, (4, 9, 43, 12), "W1")
    rect(im, (5, 13, 42, 24), "G2")
    rect(im, (4, 25, 43, 28), "S3")
    rect(im, (10, 7, 15, 10), "S3")
    rect(im, (32, 7, 37, 10), "S3")
    rect(im, (20, 6, 28, 8), "S2")
    rect(im, (20, 14, 27, 16), "S3")
    rect(im, (22, 17, 25, 18), "Y1")
    draw_text(im, "RI-02", 16, 21, 3, "S2")
    return im


def recovery_bed() -> Image.Image:
    im = canvas(110, 67)
    # Raised treatment gantry and head monitor identify the death-recovery bed.
    rect(im, (17, 3, 22, 40), "G1")
    rect(im, (20, 3, 73, 5), "G2")
    rect(im, (69, 5, 72, 16), "S3")
    rect(im, (57, 16, 86, 34), "G1")
    rect(im, (59, 18, 84, 31), "S2")
    rect(im, (59, 18, 84, 18), "B1")
    line(im, [(61, 26), (65, 26), (68, 21), (71, 28), (74, 24), (82, 24)], "T2")
    rect(im, (28, 32, 94, 49), "G1")
    rect(im, (27, 35, 92, 46), "W1")
    rect(im, (30, 33, 49, 39), "W2")
    rect(im, (50, 36, 89, 43), "W1")
    rect(im, (24, 29, 28, 48), "S3")
    rect(im, (94, 32, 99, 49), "S3")
    rect(im, (23, 49, 100, 52), "G0")
    rect(im, (30, 53, 36, 62), "S3")
    rect(im, (86, 53, 92, 62), "S3")
    ellipse(im, (28, 61, 36, 66), "S2")
    ellipse(im, (86, 61, 94, 66), "S2")
    rect(im, (40, 47, 78, 49), "B1")
    paste(im, LOGO_S, (5, 42))
    rect(im, (103, 41, 105, 44), "T2")
    return im


def ward_bed(variant: int) -> Image.Image:
    im = canvas(80, 47)
    rect(im, (7, 8, 73, 35), "G1")
    rect(im, (9, 11, 70, 32), "W1")
    rect(im, (12, 13, 30, 20), "W2")
    rect(im, (31, 17, 65, 29), "G2" if variant == 1 else "W2")
    rect(im, (6, 5, 11, 37), "S3")
    rect(im, (71, 7, 75, 38), "S3")
    rect(im, (6, 36, 75, 39), "G0")
    rect(im, (13, 40, 18, 46), "S3")
    rect(im, (63, 40, 68, 46), "S3")
    rect(im, (37, 32, 56, 34), "B1")
    return im


def med_monitor() -> Image.Image:
    im = canvas(56, 47)
    rect(im, (2, 1, 7, 8), "G1")
    rect(im, (6, 4, 27, 6), "G1")
    rect(im, (25, 6, 29, 13), "S3")
    poly(im, [(16, 12), (48, 10), (52, 33), (20, 35)], "G1")
    poly(im, [(19, 15), (46, 13), (49, 30), (22, 32)], "B0")
    line(im, [(23, 25), (28, 25), (31, 19), (34, 28), (38, 22), (46, 22)], "T2")
    rect(im, (24, 28, 28, 29), "B2")
    rect(im, (42, 28, 45, 29), "T3")
    line(im, [(19, 36), (35, 36), (40, 42)], "O1")
    return im


def privacy_curtain() -> Image.Image:
    im = canvas(74, 66)
    rect(im, (2, 1, 71, 3), "S3")
    for x in (5, 21, 39, 56, 69):
        rect(im, (x, 4, x + 2, 8), "G1")
    poly(im, [(4, 8), (69, 8), (68, 58), (61, 61), (52, 58), (42, 61),
              (33, 58), (23, 61), (13, 58), (5, 60)], "G2")
    rect(im, (5, 10, 68, 14), "W1")
    for x in (14, 30, 47, 61):
        line(im, [(x, 15), (x + 2, 54)], "G1")
    rect(im, (5, 50, 68, 50), "B1")
    rect(im, (5, 52, 68, 52), "B0")
    return im


def medicine_cabinet() -> Image.Image:
    im = canvas(76, 59)
    rect(im, (4, 2, 71, 55), "G1")
    rect(im, (6, 4, 69, 51), "W1")
    rect(im, (8, 7, 67, 42), "G0")
    for y in (19, 31, 43):
        rect(im, (9, y, 66, y + 1), "W2")
    for x in (13, 26, 39, 52):
        rect(im, (x, 10, x + 5, 18), "W2")
        rect(im, (x + 1, 9, x + 4, 10), "B1")
        rect(im, (x, 23, x + 7, 30), "G2")
        rect(im, (x + 2, 24, x + 5, 25), "B1")
    rect(im, (8, 44, 67, 51), "G2")
    rect(im, (11, 53, 19, 58), "S3")
    rect(im, (57, 53, 65, 58), "S3")
    draw_text(im, "B1-04", 24, 45, 3, "S2")
    return im


def med_sink() -> Image.Image:
    im = canvas(52, 42)
    rect(im, (5, 10, 47, 18), "W1")
    rect(im, (9, 12, 43, 22), "G2")
    rect(im, (16, 14, 36, 21), "G0")
    ellipse(im, (21, 17, 31, 20), "S3")
    rect(im, (23, 3, 27, 12), "S3")
    rect(im, (25, 3, 33, 5), "G1")
    rect(im, (32, 5, 34, 9), "G1")
    rect(im, (7, 23, 45, 36), "W1")
    rect(im, (9, 24, 43, 27), "G2")
    rect(im, (11, 37, 15, 41), "S3")
    rect(im, (38, 37, 42, 41), "S3")
    rect(im, (40, 18, 42, 20), "T2")
    return im


def small_detail(kind: str) -> Image.Image:
    if kind == "mug":
        im = canvas(13, 14)
        rect(im, (2, 4, 9, 11), "W1")
        rect(im, (3, 5, 8, 6), "L1")
        line(im, [(9, 6), (12, 6), (12, 10), (9, 10)], "G0")
    elif kind == "memo":
        im = canvas(20, 22)
        rect(im, (1, 1, 18, 20), "L2")
        rect(im, (4, 5, 15, 6), "S3")
        rect(im, (4, 10, 14, 11), "G0")
        rect(im, (4, 15, 12, 16), "G0")
        rect(im, (8, 0, 11, 2), "O1")
    elif kind == "plant":
        im = canvas(22, 27)
        poly(im, [(4, 15), (18, 15), (16, 26), (6, 26)], "G1")
        line(im, [(11, 18), (11, 5)], "S2")
        poly(im, [(10, 13), (2, 8), (3, 4), (11, 8)], "L0")
        poly(im, [(12, 11), (20, 5), (19, 2), (12, 6)], "L1")
        rect(im, (6, 20, 16, 21), "L1")
    elif kind == "sticker":
        im = canvas(18, 16)
        rect(im, (1, 1, 16, 14), "G2")
        poly(im, [(9, 3), (14, 8), (9, 13), (4, 8)], "Y1")
        rect(im, (8, 5, 9, 10), "S1")
    elif kind == "cable":
        im = canvas(36, 31)
        line(im, [(4, 0), (4, 17), (9, 24), (26, 24), (32, 18), (32, 11)], "O1")
        rect(im, (29, 8, 34, 12), "S2")
    elif kind == "stop":
        im = canvas(19, 22)
        rect(im, (2, 1, 17, 20), "G1")
        ellipse(im, (5, 5, 14, 14), "R0")
        rect(im, (6, 16, 13, 17), "Y1")
    elif kind == "clipboard":
        im = canvas(23, 29)
        rect(im, (2, 3, 20, 27), "G1")
        rect(im, (4, 5, 18, 24), "W1")
        rect(im, (8, 1, 14, 5), "S3")
        for y in (9, 14, 19):
            rect(im, (6, y, 16, y), "B1")
    elif kind == "iv":
        im = canvas(22, 56)
        rect(im, (10, 5, 11, 50), "G1")
        rect(im, (5, 4, 17, 5), "G1")
        rect(im, (4, 7, 9, 22), "W2")
        rect(im, (6, 17, 7, 18), "B2")
        line(im, [(7, 22), (7, 34), (13, 37)], "G0")
        rect(im, (4, 51, 18, 53), "S3")
    elif kind == "sanitizer":
        im = canvas(14, 22)
        rect(im, (3, 7, 10, 20), "W2")
        rect(im, (5, 11, 8, 12), "B1")
        rect(im, (5, 4, 8, 7), "G1")
        rect(im, (7, 2, 12, 3), "S3")
    else:
        raise ValueError(kind)
    return im


def build_store(wall: Path) -> None:
    room = Room("STORE", "B1-01", (12, 9), (180, 115), wall, LIGHT / "rhodes_floor_equipment_v1.png")
    room.dep(LIGHT / "wall_straight_60x46_light_v2.png", "Accepted light wall alpha/geometry source for warm recolor")
    room.add("store_department_sign_120x46", department_sign("STORE", "B1-01", "L1", "L2"), "wall",
             "Warm B1-01 wall supergraphic with accepted M mark; pair with accepted door plate.",
             ["B: STORE supergraphic and B1-01", "C: warm department identity"], emit=("L1",), wall=True)
    room.add("store_front_counter_self_service_84x48", store_counter(), "billboard",
             "Primary sales counter; screen is self-service until Closure is recruited. Leave the operator stand spot behind it.",
             ["A: waist-high counter and built-in terminal", "B: representative S mark", "D: receipt and till"],
             emit=("T2",), footprint=(5.6, 1.0))
    room.add("store_weapon_glass_case_58x42", display_case(True), "billboard",
             "Glass case with one visible blade and two cold-light pins; attach price tag 01.",
             ["A: glass product display", "C: restrained cold case light"], emit=("T2",), footprint=(3.87, 0.93))
    room.add("store_equipment_glass_case_58x42", display_case(False), "billboard",
             "Second glass case with a visible chest piece; attach price tag 02.",
             ["A: paired product display", "C: restrained cold case light"], emit=("T2",), footprint=(3.87, 0.93))
    room.add("store_back_product_shelf_92x56", product_shelf(), "wall",
             "Back-wall stocked shelf. RI-01 inventory code replaces any S stamp.",
             ["A: wall-backed product display", "B: inventory code", "D: bottles and packs"], wall=True)
    room.add("store_warm_pendant_34x18", shop_lamp(), "wall", "Warm pendant above front counter.",
             ["A: suspended shop luminaire", "C: warm source"], emit=("L2",), wall=True)
    room.add("store_counter_zone_80x36", floor_zone(80, 36, "L1"), "decal",
             "Warm dashed counter work-zone outline, native top-down decal.", ["B: floor work-zone line", "C: warm identity"])
    room.add("store_safety_strip_30x10", hazard_strip(), "decal",
             "Yellow-black counter-side safety strip.", ["D: industrial hazard marking"])
    room.add("store_price_tag_weapon_24x14", price_tag("01"), "wall", "Attach to weapon case edge.",
             ["B: product price/category tag", "D: retail detail"], life=True)
    room.add("store_price_tag_equipment_24x14", price_tag("02"), "wall", "Attach to equipment case edge.",
             ["B: product price/category tag", "D: retail detail"], life=True)
    room.add("store_sale_poster_30x38", shop_poster(), "wall", "Warm illustrated product poster attached to wall; no non-spec text.",
             ["B: shop promotion", "D: lived-in wall poster"], wall=True, life=True)
    for kind in ("mug", "memo", "plant", "cable"):
        im = small_detail(kind)
        room.add(f"store_{kind}_{im.width}x{im.height}", im, "wall" if kind in ("memo", "cable") else "billboard",
                 f"Attach {kind} to counter, shelf or wall; never scatter on floor.",
                 ["D: attached shop life detail"], wall=kind in ("memo", "cable"), life=True)
    for role in ("closure_behind_counter", "customer_at_terminal"):
        room.add(f"store_stand_spot_{role}_12x6", stand_spot(), "decal",
                 f"Reserved {role.replace('_', ' ')} position; keep 30px body clearance.", ["A: future character position"])
    room.show("store_department_sign_120x46", 16, 0)
    room.show("store_back_product_shelf_92x56", 180, 76)
    room.show("store_sale_poster_30x38", 300, 78)
    room.show("store_warm_pendant_34x18", 360, 76)
    room.show("store_front_counter_self_service_84x48", 18, 173)
    room.show("store_weapon_glass_case_58x42", 130, 180)
    room.show("store_equipment_glass_case_58x42", 205, 180)
    room.show("store_counter_zone_80x36", 270, 226)
    room.show("store_safety_strip_30x10", 365, 234)
    room.show("store_price_tag_weapon_24x14", 146, 202)
    room.show("store_price_tag_equipment_24x14", 221, 202)
    for stem, x, y in (("store_mug_13x14", 293, 181), ("store_memo_20x22", 318, 177),
                       ("store_plant_22x27", 352, 173), ("store_cable_36x31", 384, 174),
                       ("store_stand_spot_closure_behind_counter_12x6", 35, 154),
                       ("store_stand_spot_customer_at_terminal_12x6", 45, 234)):
        room.show(stem, x, y)
    room.complete((540, 270), (464, 195),
                  {"counter": "Self-service until Closure is recruited; operator spot behind, customer spot in front.",
                   "displays": "Two cases and price tags flank the >=45px central approach; back shelf mounts on north wall.",
                   "lighting": "Warm pendant emit with accepted additive warm pool; display pins stay cool."},
                  {"A": "Warm light wall shell, counter, suspended lamp and paired glass cases.",
                   "B": "B1-01 plate and STORE supergraphic.", "C": "Warm L1/L2 sign and lamp, restrained cool case lights.",
                   "D": "Two tags, poster, mug, memo, plant, cable and yellow-black safety strip, attached to fixtures."},
                  [H1 / "light_pool_circle_warm_60x40.png", H1 / "light_pool_rectangle_cool_90x60.png"])


def build_armory() -> None:
    room = Room("ARMORY", "B1-02", (18, 12), (270, 152),
                LIGHT / "wall_straight_60x46_light_v2.png", LIGHT / "rhodes_floor_equipment_v1.png")
    room.add("armory_department_sign_120x46", department_sign("ARMORY", "B1-02", "Y1"), "wall",
             "B1-02 safety-yellow department supergraphic and accepted M mark.",
             ["B: ARMORY wall supergraphic", "C: safety-yellow identity"], wall=True)
    room.add("armory_equipment_workbench_110x50", armory_bench(), "billboard",
             "Primary equipment UI station, native 110x50 redraw. Desk top at 27-31px sprite y; 13px front, screens sit on desk.",
             ["A: raised equipment station", "B: representative S mark", "C: yellow tool highlight"],
             emit=("T2",), footprint=(7.33, 1.0))
    room.add("armory_weapon_wall_106x60", weapon_wall(), "wall",
             "Five visible hanging blades; B1-02 category number, no S stamp.",
             ["A: wall-backed weapon storage", "B: B1-02 rack ID"], wall=True)
    room.add("armory_robotic_arm_55x58", robotic_arm(), "billboard",
             "Jointed cold-grey robotic arm with dark joints and orange control cable.",
             ["A: equipment manipulator", "C: three-tone light shell and orange cable"], footprint=(3.67, 1.0))
    room.add("armory_overhead_hoist_64x74", hoist(), "wall",
             "Overhead beam and suspended hook, 64x74; anchor to north wall ceiling at y=0.",
             ["A: overhead repair structure", "C: yellow carriage warning"], wall=True)
    room.add("armory_tool_board_58x42", tool_board(), "wall",
             "Pegboard with visible hanging tools; mount beside weapon wall.",
             ["A: wall-mounted tooling", "D: ready-use tools"], wall=True)
    room.add("armory_task_lamp_34x18", task_lamp(), "wall", "Cool-white task lamp over the repair workbench.",
             ["A: overhead task lamp", "C: white work illumination"], emit=("W2",), wall=True)
    room.add("armory_bench_zone_100x44", floor_zone(100, 44, "Y1"), "decal",
             "Safety-yellow dashed workbench footprint on the floor.", ["B: floor work-zone line", "C: safety-yellow department"])
    room.add("armory_safety_strip_30x10", hazard_strip(), "decal",
             "Yellow-black hoist base warning strip.", ["D: industrial hazard marking"])
    for index in (1, 2):
        room.add(f"armory_equipment_case_{index}_48x30", equipment_case(), "billboard",
                 f"Cold-grey equipment case {index}; numbered, no S stamp.",
                 ["A: equipment storage", "B: RI-02 case code"], footprint=(3.2, 0.8))
    # Wall-attached life/safety details, using accepted palette.
    for kind in ("memo", "mug", "sticker", "cable", "stop", "clipboard"):
        im = small_detail(kind)
        room.add(f"armory_{kind}_{im.width}x{im.height}", im,
                 "wall" if kind != "mug" else "billboard", f"Attach {kind} to workbench, wall or hoist.",
                 ["D: attached repair-room life and safety detail"], wall=kind != "mug", life=True)
    for role in ("bench_operator", "weapon_wall_inspector"):
        room.add(f"armory_stand_spot_{role}_12x6", stand_spot(), "decal",
                 f"Reserved {role.replace('_', ' ')} 30px character footprint.", ["A: future character position"])
    room.show("armory_department_sign_120x46", 16, 0)
    room.show("armory_weapon_wall_106x60", 176, 76)
    room.show("armory_overhead_hoist_64x74", 310, 76)
    room.show("armory_tool_board_58x42", 410, 77)
    room.show("armory_task_lamp_34x18", 500, 80)
    room.show("armory_equipment_workbench_110x50", 18, 195)
    room.show("armory_robotic_arm_55x58", 157, 186)
    room.show("armory_equipment_case_1_48x30", 236, 216)
    room.show("armory_equipment_case_2_48x30", 300, 216)
    room.show("armory_bench_zone_100x44", 320, 268)
    room.show("armory_safety_strip_30x10", 430, 278)
    for stem, x, y in (("armory_memo_20x22", 374, 199), ("armory_mug_13x14", 406, 207),
                       ("armory_sticker_18x16", 434, 206), ("armory_cable_36x31", 462, 191),
                       ("armory_stop_19x22", 512, 199), ("armory_clipboard_23x29", 545, 192),
                       ("armory_stand_spot_bench_operator_12x6", 71, 264),
                       ("armory_stand_spot_weapon_wall_inspector_12x6", 219, 152)):
        room.show(stem, x, y)
    room.complete((660, 320), (580, 250),
                  {"station": "Workbench is the equipment interaction; leave 30px at operator spot in front.",
                   "wall": "Weapon rack, hoist and tool board attach to light 46px north wall. Arm and cases form the service edge.",
                   "lighting": "Use accepted cool additive pool in front of bench and masked screen emit."},
                  {"A": "Light wall/corner shell, workbench, hanging hoist and jointed arm.",
                   "B": "B1-02 accepted door plate and ARMORY sign, numbered wall rack.",
                   "C": "Cold grey/white body, safety-yellow band, tiny orange cable and cyan screen.",
                   "D": "Peg tools, memo, mug, sticker, cable, emergency stop, clipboard and safety strip."},
                  [H1 / "light_pool_rectangle_cool_90x60.png"])


def build_medical(wall: Path, floor: Path) -> None:
    room = Room("MEDICAL", "B1-04", (18, 12), (270, 152), wall, floor)
    room.dep(LIGHT / "wall_straight_60x46_light_v2.png", "Accepted light wall alpha/geometry source for medical recolor")
    room.dep(LIGHT / "rhodes_floor_equipment_v1.png", "Accepted plate pattern source for medical floor recolor")
    room.add("medical_department_sign_120x46", department_sign("MEDICAL", "B1-04", "B1"), "wall",
             "White/blue B1-04 supergraphic with accepted M mark.",
             ["B: MEDICAL wall supergraphic", "C: Rhodes blue department identity"], wall=True)
    room.add("medical_recovery_bed_110x67", recovery_bed(), "billboard",
             "Death-recovery wake-up bed and monitor gantry; principal interaction/display point. Leave patient side clear.",
             ["A: main recovery treatment station", "B: representative S mark", "C: blue-white treatment signal"],
             emit=("T2",), footprint=(7.33, 1.2))
    for index in (1, 2):
        room.add(f"medical_ward_bed_{index}_80x47", ward_bed(index), "billboard",
                 f"Secondary bed {index}; place against wall with a privacy curtain between beds.",
                 ["A: ward bed", "C: soft white shell and blue ID stripe"], footprint=(5.33, 1.0))
    room.add("medical_suspended_monitor_56x47", med_monitor(), "wall",
             "Angled articulated EMR monitor; do not use a floor stand.",
             ["A: wall/ceiling articulated screen", "C: cool medical vital trace"], emit=("T2", "T3"), wall=True)
    room.add("medical_privacy_curtain_74x66", privacy_curtain(), "billboard",
             "Folded white privacy curtain with Rhodes-blue band, hanging from an overhead rail.",
             ["A: curtain and overhead rail", "C: white/blue ward textile"], footprint=(4.93, 0.7))
    room.add("medical_medicine_cabinet_76x59", medicine_cabinet(), "wall",
             "Glass medicine cabinet with stocked bottles and B1-04 number.",
             ["A: stocked medicine wall", "B: B1-04 service code", "D: visible medicines"], wall=True)
    room.add("medical_wash_sink_52x42", med_sink(), "billboard",
             "Wash sink with faucet, cabinet and one tiny cyan indicator.",
             ["A: wash station", "D: clinical handwash point"], emit=("T2",), footprint=(3.47, 0.8))
    room.add("medical_recovery_zone_100x44", floor_zone(100, 44, "B1"), "decal",
             "Rhodes-blue recovery-bed floor outline; clear central approach.", ["B: floor work-zone line", "C: medical blue"])
    room.add("medical_safety_strip_30x10", hazard_strip(), "decal",
             "Yellow-black threshold at recovery equipment service side.", ["D: clinical equipment hazard marking"])
    for kind in ("clipboard", "iv", "sanitizer", "memo", "sticker", "cable"):
        im = small_detail(kind)
        room.add(f"medical_{kind}_{im.width}x{im.height}", im,
                 "wall" if kind in ("clipboard", "memo", "sticker", "cable") else "billboard",
                 f"Attach {kind} to bed, cabinet or wall; no loose floor scatter.",
                 ["D: attached clinic life/safety detail"], wall=kind in ("clipboard", "memo", "sticker", "cable"), life=True)
    for role in ("recovery_attendant", "medicine_cabinet_staff"):
        room.add(f"medical_stand_spot_{role}_12x6", stand_spot("S3"), "decal",
                 f"Reserved {role.replace('_', ' ')} position; keep full 30px body visible.", ["A: future character position"])
    room.show("medical_department_sign_120x46", 16, 0)
    room.show("medical_medicine_cabinet_76x59", 180, 77)
    room.show("medical_suspended_monitor_56x47", 286, 77)
    room.show("medical_privacy_curtain_74x66", 383, 76)
    room.show("medical_recovery_bed_110x67", 18, 196)
    room.show("medical_ward_bed_1_80x47", 154, 218)
    room.show("medical_ward_bed_2_80x47", 252, 218)
    room.show("medical_wash_sink_52x42", 355, 222)
    room.show("medical_recovery_zone_100x44", 325, 278)
    room.show("medical_safety_strip_30x10", 438, 285)
    for stem, x, y in (("medical_clipboard_23x29", 430, 205), ("medical_iv_22x56", 467, 183),
                       ("medical_sanitizer_14x22", 503, 217), ("medical_memo_20x22", 533, 217),
                       ("medical_sticker_18x16", 565, 222), ("medical_cable_36x31", 590, 211),
                       ("medical_stand_spot_recovery_attendant_12x6", 76, 280),
                       ("medical_stand_spot_medicine_cabinet_staff_12x6", 206, 152)):
        room.show(stem, x, y)
    room.complete((700, 330), (626, 263),
                  {"recovery": "Wake-up point is the principal bed. Keep a 30px attendant position beside it.",
                   "ward": "Total three beds. Curtain separates recovery and secondary beds; cabinet staff stands at wall.",
                   "lighting": "Brightest room. Use accepted cool additive pool and screen emit. Floor never exceeds #98a2a6; preserve Lappland's dark-coat contrast."},
                  {"A": "Whiter 46px wall shell, three beds, articulated monitor and curtain rail.",
                   "B": "B1-04 accepted door plate and MEDICAL supergraphic.",
                   "C": "Rhodes blue/medical white identity, restrained cyan vital trace.",
                   "D": "Medicines, clipboard, IV, sanitizer, memo, sticker, service cable and safety strip."},
                  [H1 / "light_pool_rectangle_cool_90x60.png"])


if __name__ == "__main__":
    store_wall, med_wall, med_floor = make_shells()
    build_store(store_wall)
    build_armory()
    build_medical(med_wall, med_floor)
    print("H3 generated: STORE, ARMORY, MEDICAL kits with native PNGs, emit masks, manifests and 1:1 composites")
