"""Draw the H2 warehouse asset kit at native pixel scale."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from pixel_kit import (  # noqa: E402
    canvas, dependency, draw_text, emit_from_colors, line, load, paste, poly,
    rect, save_native, write_json,
)

B1 = ART / "batch1_v5"
B2 = ART / "batch2_v2"
L0 = ART / "batch_L0_logo_v1"
H1 = ART / "batch_H1_bridge_hall_v2"
H1B = ART / "batch_H1b_wayfinding_v1"
ROOT.mkdir(exist_ok=True)
logo_s = load(L0 / "rhodes_logo_S_gray_v1.png")
logo_m = load(L0 / "rhodes_logo_M_gray_v1.png")
assets: list[dict] = []


def add(stem: str, image: Image.Image, kind: str, notes: str, coverage: list[str],
        *, emit: tuple[str, ...] = (), wall: bool = False, states: list[str] | None = None,
        footprint: tuple[float, float] | None = None) -> None:
    save_native(image, ROOT, stem)
    emit_name = None
    if emit:
        emit_name = f"{stem}_emit.png"
        save_native(emit_from_colors(image, emit), ROOT, f"{stem}_emit")
    anchor = [image.width // 2, 0 if wall else image.height // 2 if kind == "decal" else image.height - 1]
    if footprint is None:
        footprint = (0.0, 0.0) if wall else (round(image.width / 15, 2), round(image.height / 45, 2) if kind == "billboard" else round(image.height / 15, 2))
    assets.append({
        "id": stem, "file": f"{stem}.png", "emit": emit_name, "kind": kind,
        "size_px": list(image.size), "anchor_px": anchor,
        "footprint_units": list(footprint), "wall_mounted": wall,
        "states": states or ["default"], "notes": notes, "coverage_35": coverage,
    })


def stamped(image: Image.Image, x: int, y: int) -> None:
    paste(image, logo_s, (x, y))


def wall_bay() -> Image.Image:
    image = canvas(120, 46)
    wall = load(B1 / "wall_straight_60x46_v5.png")
    paste(image, wall, (0, 0))
    paste(image, wall, (60, 0))
    rect(image, (3, 10, 116, 10), "O1")
    line(image, [(3, 11), (42, 11), (45, 14), (116, 14)], "O0")
    rect(image, (3, 39, 116, 40), "Y1")
    draw_text(image, "B1-03", 86, 23, 3, "G2")
    stamped(image, 8, 24)
    return image


add("warehouse_wall_bay_120x46", wall_bay(), "wall",
    "Two exact accepted 60x46 dark-wall modules with a shallow orange service conduit and B1-03/S stamps. Tile along the 360px north wall; keep accepted 46px wall height.",
    ["A: dark-steel modular warehouse shell", "B: B1-03 bay ID", "C: restrained orange conduit", "D: accepted S mark"], wall=True)

header = canvas(160, 46)
rect(header, (0, 0, 159, 45), "S0")
rect(header, (2, 2, 157, 43), "S1")
rect(header, (4, 4, 155, 7), "O1")
rect(header, (4, 8, 155, 9), "O2")
rect(header, (4, 40, 155, 42), "S3")
paste(header, logo_m, (8, 12))
text = canvas(56, 7)
draw_text(text, "WAREHOUSE", 0, 0, 5, "G2")
paste(header, text.resize((112, 14), Image.Resampling.NEAREST), (41, 17))
draw_text(header, "B1-03", 120, 34, 3, "W1")
add("warehouse_supergraphic_160x46", header, "wall",
    "B1-03 WAREHOUSE supergraphic for the primary wall. Accepted M tower at 24x24; native 5x7 glyphs integer-upscaled to 10x14; orange warehouse identity band.",
    ["B: WAREHOUSE supergraphic", "B: B1-03", "C: orange department identity", "D: accepted M logo"], wall=True)


def pending_zone() -> Image.Image:
    image = canvas(90, 60)
    for x in range(3, 87, 10):
        rect(image, (x, 3, min(x + 5, 86), 4), "Y1")
        rect(image, (x, 55, min(x + 5, 86), 56), "Y1")
    for y in range(7, 55, 10):
        rect(image, (3, y, 4, min(y + 5, 54)), "Y1")
        rect(image, (85, y, 86, min(y + 5, 54)), "Y1")
    line(image, [(35, 24), (53, 40)], "S3", 2)
    line(image, [(53, 24), (35, 40)], "S3", 2)
    rect(image, (31, 42, 58, 43), "S2")
    rect(image, (32, 15, 57, 16), "S2")
    return image


add("expansion_pending_zone_90x60", pending_zone(), "decal",
    "Pending-build frame for the warehouse expansion area; dashed safety boundary and crossed construction tools, no lettering.",
    ["A: reserved warehouse expansion", "C: safety-yellow floor boundary"])


def partition() -> Image.Image:
    image = canvas(90, 46)
    rect(image, (4, 7, 85, 11), "S2")
    rect(image, (4, 31, 85, 35), "S2")
    for x in range(4, 85, 9):
        rect(image, (x, 13, x + 4, 30), "Y1")
        line(image, [(x, 13), (x + 4, 21), (x, 30)], "S0")
    rect(image, (2, 4, 5, 42), "S3")
    rect(image, (84, 4, 87, 42), "S3")
    rect(image, (0, 42, 11, 45), "D")
    rect(image, (78, 42, 89, 45), "D")
    rect(image, (4, 7, 85, 8), "Y2")
    rect(image, (4, 34, 85, 35), "Y1")
    rect(image, (34, 17, 56, 25), "S1")
    draw_text(image, "B1-03", 36, 19, 3, "W1")
    return image


add("expansion_temporary_partition_90x46", partition(), "billboard",
    "Removable striped divider for the pending construction zone; 90px wide and 46px high with free-standing feet.",
    ["A: temporary partition", "C: safety-yellow fencing", "D: B1-03 number plate"], footprint=(6.0, 0.8))


def terminal(on: bool) -> Image.Image:
    image = canvas(64, 52)
    rect(image, (13, 2, 51, 27), "S0")
    rect(image, (15, 4, 49, 24), "S3")
    rect(image, (17, 6, 47, 22), "B0" if on else "S1")
    if on:
        # Inventory slots, not the hall console's cyan chart.
        rect(image, (20, 8, 43, 8), "T3")
        for row_y in (10, 16):
            for col_x in (20, 26, 32, 38):
                rect(image, (col_x, row_y, col_x + 4, row_y + 4), "B1")
                rect(image, (col_x + 1, row_y + 1, col_x + 3, row_y + 3), "B0")
        for col_x, row_y in ((20, 10), (26, 10), (32, 10), (38, 10),
                             (20, 16), (26, 16), (32, 16)):
            rect(image, (col_x + 1, row_y + 2, col_x + 3, row_y + 2), "T2")
            rect(image, (col_x + 2, row_y + 1, col_x + 2, row_y + 1), "W1")
        rect(image, (39, 17, 41, 19), "T3")  # selected slot
    else:
        rect(image, (21, 13, 43, 14), "S2")
    rect(image, (29, 28, 35, 31), "S2")
    rect(image, (4, 32, 59, 38), "G0")
    rect(image, (6, 39, 57, 46), "S2")
    rect(image, (8, 40, 55, 44), "S1")
    rect(image, (9, 47, 13, 51), "S0")
    rect(image, (50, 47, 54, 51), "S0")
    stamped(image, 9, 39)
    rect(image, (49, 40, 50, 42), "T2" if on else "S3")
    return image


for state in ("off", "on"):
    add(f"warehouse_storage_terminal_{state}_64x52", terminal(state == "on"), "billboard",
        f"Warehouse inventory terminal {state.upper()} state; S plaque, native 64x52 and a standing space in front. ON screen shows an inventory slot grid, with screen and indicator emit.",
        ["A: storage interaction terminal", "B: S/PRTS identity", "C: cold cyan screen signal"],
        emit=("T2", "T3") if state == "on" else (), states=[state], footprint=(4.27, 1.0))


def freight_lift(ready: bool) -> Image.Image:
    image = canvas(96, 56)
    poly(image, [(6, 12), (89, 12), (95, 19), (95, 47), (89, 55), (6, 55), (0, 47), (0, 19)], "S0")
    poly(image, [(8, 15), (87, 15), (92, 20), (92, 46), (86, 51), (9, 51), (3, 46), (3, 20)], "S2")
    rect(image, (9, 18, 86, 43), "S3")
    rect(image, (12, 20, 83, 39), "S2")
    rect(image, (16, 22, 79, 37), "S1")
    rect(image, (8, 42, 87, 44), "Y1")
    for x in range(10, 88, 10):
        line(image, [(x, 42), (x + 3, 44)], "D")
    rect(image, (9, 45, 86, 50), "S2")
    rect(image, (10, 51, 85, 54), "D")
    rect(image, (6, 7, 17, 18), "S0")
    rect(image, (8, 9, 15, 15), "B0")
    rect(image, (10, 10, 13, 12), "T2" if ready else "S3")
    rect(image, (79, 7, 90, 18), "S0")
    rect(image, (81, 9, 88, 15), "B0")
    rect(image, (83, 10, 86, 12), "T2" if ready else "S3")
    stamped(image, 44, 26)
    return image


for state in ("idle", "ready"):
    add(f"warehouse_freight_lift_{state}_96x56", freight_lift(state == "ready"), "billboard",
        f"Cargo delivery/recovery lift deck {state.upper()} state; 96x56, raised front riser, paired control posts and clear pallet landing surface.",
        ["A: freight lift/recovery point", "B: S-marked cargo deck", "C: safety-yellow loading edge"],
        emit=("T2",) if state == "ready" else (), states=[state], footprint=(6.4, 2.0))


def shelf(category: str) -> Image.Image:
    image = canvas(80, 64)
    rect(image, (3, 3, 76, 6), "S2")
    rect(image, (4, 4, 75, 4), "G0")
    for y in (22, 39, 56):
        rect(image, (5, y, 74, y + 3), "S3")
        rect(image, (5, y, 74, y), "G0")
    rect(image, (3, 3, 7, 60), "S2")
    rect(image, (72, 3, 76, 60), "S2")
    rect(image, (4, 7, 5, 55), "G0")
    rect(image, (74, 7, 75, 55), "S1")
    rect(image, (2, 60, 10, 63), "D")
    rect(image, (69, 60, 77, 63), "D")
    if category == "weapons":
        for x in (16, 29, 42, 55):
            line(image, [(x, 25), (x + 1, 11)], "G1")
            line(image, [(x + 1, 11), (x + 2, 25)], "W1")
            rect(image, (x - 3, 26, x + 4, 27), "S0")
            rect(image, (x, 28, x + 1, 34), "S2")
        for x in (14, 34, 54):
            rect(image, (x, 43, x + 12, 52), "S1")
            rect(image, (x + 1, 44, x + 11, 45), "G0")
    elif category == "armor":
        for x in (14, 38):
            poly(image, [(x + 2, 12), (x + 16, 12), (x + 20, 19), (x + 17, 31), (x, 31), (x - 2, 19)], "G0")
            poly(image, [(x + 4, 14), (x + 14, 14), (x + 16, 20), (x + 14, 28), (x + 3, 28), (x + 1, 20)], "S3")
            rect(image, (x + 6, 16, x + 12, 18), "G1")
        for x in (16, 38, 59):
            poly(image, [(x, 44), (x + 10, 44), (x + 12, 51), (x - 2, 51)], "S3")
            rect(image, (x + 2, 44, x + 8, 45), "G1")
    elif category == "consumables":
        for y in (11, 28, 45):
            for x in (14, 28, 42, 56):
                rect(image, (x, y + 3, x + 8, y + 11), "G0")
                rect(image, (x + 1, y + 4, x + 7, y + 9), "S3")
                rect(image, (x + 3, y + 1, x + 5, y + 2), "W0")
                rect(image, (x + 3, y + 5, x + 5, y + 6), "B0")
    else:
        for y in (11, 28, 45):
            for x in (13, 32, 51):
                rect(image, (x, y + 2, x + 14, y + 11), "S3")
                rect(image, (x + 1, y + 3, x + 13, y + 9), "S2")
                rect(image, (x + 3, y + 2, x + 11, y + 2), "O1")
                rect(image, (x + 6, y + 5, x + 8, y + 7), "Y1")
        rect(image, (34, 14, 45, 20), "S0")
        poly(image, [(35, 20), (37, 15), (39, 18), (40, 20)], "D")
        poly(image, [(39, 20), (41, 14), (44, 20)], "S0")
        rect(image, (39, 17, 40, 18), "O2")
        rect(image, (67, 49, 69, 51), "T2")
    code = {"weapons": "B1-03-A", "armor": "B1-03-B", "consumables": "B1-03-C", "materials": "B1-03-D"}[category]
    rect(image, (9, 0, 55, 8), "S1")
    rect(image, (9, 0, 55, 0), "G0")
    draw_text(image, code, 11, 1, 5, "W1")
    return image


categories = ("weapons", "armor", "consumables", "materials")
for category in categories:
    add(f"warehouse_rack_{category}_80x64", shelf(category), "billboard",
        f"Wall-backed {category} shelving/display group; 80x64 with unique 5x7 rack code B1-03-{'ABCD'[categories.index(category)]}. Keep shelf face against north wall.",
        ["A: high wall-backed category rack", f"B: {category.upper()} category and unique 5x7 rack code", "C: dark-steel warehouse palette", "D: numbered shelf identity"],
        emit=("T2", "O2") if category == "materials" else (), wall=True, footprint=(5.33, 1.0))


def zone_icon(image: Image.Image, category: str, x: int, y: int, color: str) -> None:
    if category == "weapons":
        line(image, [(x + 1, y + 10), (x + 10, y + 1)], color)
        line(image, [(x + 2, y + 10), (x + 11, y + 1)], color)
        rect(image, (x, y + 8, x + 5, y + 9), color)
    elif category == "armor":
        poly(image, [(x + 1, y + 1), (x + 10, y + 1), (x + 11, y + 7), (x + 6, y + 12), (x, y + 7)], color)
        poly(image, [(x + 3, y + 3), (x + 8, y + 3), (x + 9, y + 7), (x + 6, y + 10), (x + 2, y + 7)], "S1")
    elif category == "consumables":
        rect(image, (x + 3, y + 1, x + 7, y + 3), color)
        rect(image, (x + 1, y + 4, x + 9, y + 11), color)
        rect(image, (x + 4, y + 6, x + 6, y + 9), "S1")
    else:
        poly(image, [(x + 5, y), (x + 10, y + 6), (x + 5, y + 12), (x, y + 6)], color)
        rect(image, (x + 5, y + 3, x + 5, y + 8), "S1")


def zone(category: str) -> Image.Image:
    image = canvas(90, 44)
    hue = {"weapons": "Y1", "armor": "B1", "consumables": "T1", "materials": "O1"}[category]
    bright = {"weapons": "Y2", "armor": "B2", "consumables": "T2", "materials": "O2"}[category]
    for x in range(2, 88, 11):
        rect(image, (x, 2, x + 6, 3), hue)
        rect(image, (x, 40, x + 6, 41), hue)
    for y in range(7, 40, 10):
        rect(image, (2, y, 3, y + 5), hue)
        rect(image, (86, y, 87, y + 5), hue)
    rect(image, (5, 5, 84, 5), "S2")
    rect(image, (5, 38, 84, 38), "S2")
    zone_icon(image, category, 38, 15, bright)
    return image


for category in categories:
    add(f"warehouse_zone_{category}_90x44", zone(category), "decal",
        f"Top-down category floor frame and icon for {category.upper()}; place at the corresponding rack group. Orange identifies MATERIALS; all zones keep the 45px center aisle clear.",
        [f"B: {category.upper()} floor icon", "C: category-colored boundary"])


def ceiling_lamp() -> Image.Image:
    image = canvas(48, 12)
    rect(image, (0, 0, 47, 11), "S1")
    rect(image, (2, 2, 45, 9), "S3")
    rect(image, (6, 4, 41, 7), "W1")
    rect(image, (7, 5, 40, 6), "W2")
    rect(image, (1, 10, 46, 11), "S0")
    return image


add("warehouse_over_shelf_lamp_48x12", ceiling_lamp(), "wall",
    "Ceiling-mounted strip above a category rack; pair with accepted H1 v2 additive cool pool using additive blend.",
    ["A: overhead rack light", "C: cool-white work light"], emit=("W1", "W2"), wall=True)


def trolley() -> Image.Image:
    image = canvas(42, 34)
    rect(image, (8, 15, 31, 23), "S3")
    rect(image, (10, 16, 29, 20), "G0")
    rect(image, (5, 24, 36, 26), "S2")
    line(image, [(34, 24), (38, 8), (40, 8)], "G0", 2)
    rect(image, (7, 27, 13, 32), "D")
    rect(image, (28, 27, 34, 32), "D")
    rect(image, (15, 11, 25, 15), "S2")
    rect(image, (16, 12, 24, 13), "O1")
    draw_text(image, "RI-07", 11, 16, 3, "S1")
    return image


add("warehouse_trolley_42x34", trolley(), "billboard",
    "Unoccupied handling trolley with a gray crate, two wheels and a handle; leave a 30px character standing space beside it.",
    ["A: warehouse handling cart", "C: gray body with a narrow orange seal", "D: RI-07 equipment number"], footprint=(2.8, 0.8))


def forklift() -> Image.Image:
    image = canvas(70, 48)
    rect(image, (9, 26, 52, 39), "S2")
    rect(image, (11, 27, 50, 35), "S3")
    rect(image, (11, 29, 45, 30), "G0")
    rect(image, (16, 18, 38, 26), "S1")
    rect(image, (18, 19, 36, 22), "G0")
    line(image, [(15, 26), (17, 8), (43, 8), (45, 25)], "S3", 2)
    rect(image, (17, 7, 44, 9), "G0")
    rect(image, (24, 19, 32, 25), "S0")
    rect(image, (50, 19, 53, 40), "S2")
    rect(image, (54, 35, 68, 37), "G0")
    rect(image, (54, 40, 68, 42), "S3")
    rect(image, (15, 39, 25, 47), "D")
    rect(image, (42, 39, 52, 47), "D")
    rect(image, (19, 41, 22, 44), "G0")
    rect(image, (46, 41, 49, 44), "G0")
    rect(image, (11, 31, 12, 35), "O1")
    rect(image, (43, 25, 46, 26), "Y1")
    draw_text(image, "B1-03", 25, 29, 3, "W1")
    return image


add("warehouse_forklift_70x48", forklift(), "billboard",
    "Parked unmanned gray forklift with roll cage, wheels and two forward forks; orange/yellow is confined to small safety parts.",
    ["A: warehouse forklift", "C: dark steel with small safety accents", "D: B1-03 chassis number"], footprint=(4.67, 1.4))


def pallet() -> Image.Image:
    image = canvas(48, 24)
    rect(image, (3, 12, 44, 19), "L0")
    for x in (4, 17, 30):
        rect(image, (x, 7, x + 10, 16), "S3")
        rect(image, (x + 1, 8, x + 9, 9), "G0")
    rect(image, (8, 20, 15, 23), "D")
    rect(image, (32, 20, 39, 23), "D")
    return image


add("warehouse_pallet_48x24", pallet(), "billboard", "Empty low pallet for modular cargo placement; gray deck over warm-dark supports.", ["A: pallet logistics prop", "C: cool-gray steel and warm-dark supports"], footprint=(3.2, 0.6))


def crate(sealed: bool) -> Image.Image:
    w, h = (44, 36) if sealed else (42, 32)
    image = canvas(w, h)
    rect(image, (3, 7, w - 4, h - 5), "S2")
    rect(image, (5, 9, w - 6, h - 8), "S3")
    rect(image, (5, 9, w - 6, 11), "G0")
    rect(image, (3, 5, w - 4, 8), "S1")
    rect(image, (12, 5, w - 13, 5), "O1")
    rect(image, (7, 14, 9, h - 10), "S2")
    rect(image, (w - 10, 14, w - 8, h - 10), "S2")
    rect(image, (3, h - 4, w - 4, h - 2), "D")
    if sealed:
        rect(image, (10, 12, 34, 27), "G0")
        rect(image, (12, 14, 32, 25), "D")
        poly(image, [(12, 25), (15, 18), (18, 15), (21, 25)], "S0")
        poly(image, [(14, 23), (17, 17), (18, 22)], "S3")
        poly(image, [(18, 25), (22, 14), (27, 25)], "S0")
        poly(image, [(20, 24), (23, 17), (24, 23)], "S2")
        poly(image, [(25, 25), (29, 18), (32, 25)], "S0")
        rect(image, (16, 20, 17, 21), "O2")
        rect(image, (23, 19, 24, 21), "O2")
        rect(image, (29, 22, 29, 23), "O2")
        rect(image, (23, 19, 23, 19), "L1")
        rect(image, (10, 26, 34, 27), "S3")
        poly(image, [(38, 17), (41, 23), (35, 23)], "Y1")
        rect(image, (38, 20, 38, 21), "D")
        rect(image, (36, 13, 37, 14), "T2")
    else:
        draw_text(image, "RI-07", 12, 18, 3, "W1")
    return image


add("warehouse_supply_crate_42x32", crate(False), "billboard",
    "Cold-gray supply crate with a single orange lid band and RI-07 number; may stack on pallet.",
    ["A: modular supply crate", "C: narrow orange lid accent", "D: RI-07 cargo number"], footprint=(2.8, 0.8))
add("warehouse_originium_sealed_crate_44x36", crate(True), "billboard",
    "Sealed material crate with black faceted originium and orange cores visible behind a locked port; tiny status lamp and narrow lid band.",
    ["A: sealed materials cargo", "C: orange-core originium and warm emit", "D: originium warning sign"], emit=("T2", "O2", "L1"), footprint=(2.93, 0.9))


def originium_containment() -> Image.Image:
    image = canvas(56, 48)
    rect(image, (3, 5, 52, 43), "S2")
    rect(image, (5, 6, 50, 9), "G0")
    rect(image, (7, 10, 48, 35), "G0")
    rect(image, (9, 12, 46, 33), "D")
    poly(image, [(10, 33), (14, 22), (20, 13), (27, 33)], "S0")
    poly(image, [(13, 29), (18, 17), (20, 25), (22, 33)], "S3")
    poly(image, [(18, 33), (26, 11), (34, 33)], "S0")
    poly(image, [(22, 30), (27, 16), (30, 27), (31, 33)], "S2")
    poly(image, [(31, 33), (39, 17), (46, 33)], "S0")
    poly(image, [(34, 31), (39, 20), (42, 28), (43, 33)], "S3")
    poly(image, [(16, 25), (18, 20), (20, 23), (19, 27)], "O1")
    rect(image, (18, 22, 19, 25), "O2")
    rect(image, (19, 23, 19, 23), "L1")
    poly(image, [(25, 25), (28, 17), (30, 23), (29, 28)], "O1")
    rect(image, (28, 20, 29, 24), "O2")
    rect(image, (29, 21, 29, 21), "L1")
    poly(image, [(37, 28), (39, 22), (42, 27), (41, 31)], "O1")
    rect(image, (39, 25, 40, 28), "O2")
    rect(image, (40, 26, 40, 26), "L1")
    rect(image, (7, 34, 48, 36), "S3")
    rect(image, (5, 38, 50, 44), "S2")
    rect(image, (7, 39, 48, 40), "G0")
    rect(image, (2, 44, 53, 47), "D")
    rect(image, (5, 9, 7, 36), "S1")
    rect(image, (48, 9, 50, 36), "S1")
    rect(image, (10, 36, 14, 38), "Y1")
    rect(image, (42, 36, 46, 38), "Y1")
    return image


add("warehouse_originium_containment_56x48", originium_containment(), "billboard",
    "Sealed clear-front material vessel with multiple black faceted originium crystals, orange cores and a warm emit mask. Place inside the MATERIALS floor frame.",
    ["A: sealed materials containment", "C: visible black/orange originium", "D: controlled hazard handling"], emit=("O2", "L1"), footprint=(3.73, 1.0))


def clipboard() -> Image.Image:
    image = canvas(22, 28)
    rect(image, (2, 2, 19, 27), "S2")
    rect(image, (4, 4, 17, 24), "W0")
    rect(image, (8, 1, 13, 4), "G0")
    for y in (8, 11, 14, 17):
        rect(image, (6, y, 15, y), "S3")
    rect(image, (6, 20, 12, 20), "O1")
    return image


add("warehouse_wall_clipboard_22x28", clipboard(), "wall",
    "Wall-attached cargo tally clipboard, one of the warehouse's small work-life details.",
    ["D: wall-attached cargo tally clipboard"], wall=True)

notice = canvas(76, 38)
rect(notice, (0, 0, 75, 37), "S0")
rect(notice, (2, 2, 73, 35), "S2")
rect(notice, (3, 3, 72, 4), "O1")
draw_text(notice, "WAREHOUSE", 7, 8, 3, "W1")
draw_text(notice, "B1-03", 7, 18, 3, "G2")
draw_text(notice, "RI-07", 42, 18, 3, "G1")
for x in (5, 25, 45, 65):
    rect(notice, (x, 28, x + 6, 30), "G0")
add("warehouse_notice_board_76x38", notice, "wall",
    "Wall-mounted warehouse notice and shelf number board; approved labels WAREHOUSE, B1-03 and RI-07.",
    ["B: warehouse section and equipment IDs", "D: wall-attached notice board"], wall=True)

spot = canvas(12, 6)
line(spot, [(1, 4), (3, 2), (8, 2), (10, 4), (8, 5), (3, 5), (1, 4)], "S3")
add("warehouse_operator_spot_12x6", spot, "decal",
    "Subtle 12x6 standing mark; use one in front of inventory terminal and one beside trolley/forklift with a 30px-tall character clearance.",
    ["D: reserved future operator station"])

shadow = canvas(60, 8)
rect(shadow, (0, 0, 59, 2), "D")
rect(shadow, (1, 3, 58, 5), "S0")
rect(shadow, (2, 6, 57, 7), "S1")
add("warehouse_wall_contact_shadow_60x8", shadow, "decal",
    "Dark 8px shadow strip at the north wall/floor contact; tile horizontally. Uses the accepted dark-steel material steps.",
    ["C: darker wall-root value framing"])


# Parts-only native-scale review sheet with the accepted floor/wall and Lappland.
floor = load(B2 / "rhodes_floor_v1.png")
wall = load(B1 / "wall_straight_60x46_v5.png")
lap = load(B1 / "lappland_frame0_64.png")
composite = canvas(700, 420)
for y in range(420):
    for x in range(700):
        composite.putpixel((x, y), wall.getpixel((x % 60, y)) if y < 46 else floor.getpixel((x % 120, (y - 46) % 120)))
paste(composite, load(ROOT / "warehouse_wall_bay_120x46.png"), (12, 0))
paste(composite, header, (145, 0))
for stem, xy in [
    ("warehouse_storage_terminal_on_64x52", (18, 72)),
    ("warehouse_storage_terminal_off_64x52", (90, 72)),
    ("warehouse_freight_lift_ready_96x56", (165, 72)),
    ("warehouse_freight_lift_idle_96x56", (270, 72)),
    ("expansion_temporary_partition_90x46", (385, 78)),
    ("warehouse_notice_board_76x38", (490, 79)),
    ("warehouse_over_shelf_lamp_48x12", (590, 80)),
]:
    paste(composite, load(ROOT / f"{stem}.png"), xy)
for index, category in enumerate(categories):
    x = 18 + index * 102
    paste(composite, load(ROOT / f"warehouse_rack_{category}_80x64.png"), (x, 158))
    paste(composite, load(ROOT / f"warehouse_zone_{category}_90x44.png"), (x, 231))
paste(composite, load(ROOT / "warehouse_originium_containment_56x48.png"), (341, 228))
for stem, xy in [
    ("warehouse_trolley_42x34", (18, 319)),
    ("warehouse_forklift_70x48", (85, 310)),
    ("warehouse_pallet_48x24", (175, 329)),
    ("warehouse_supply_crate_42x32", (241, 321)),
    ("warehouse_originium_sealed_crate_44x36", (302, 317)),
    ("expansion_pending_zone_90x60", (376, 306)),
    ("warehouse_wall_clipboard_22x28", (490, 319)),
    ("warehouse_operator_spot_12x6", (540, 348)),
]:
    paste(composite, load(ROOT / f"{stem}.png"), xy)
lap_bbox = lap.getchannel("A").getbbox()
paste(composite, lap.crop((0, 0, 64, 64)), (565, 350 - (lap_bbox[3] - 1)))
composite.save(ROOT / "H2_warehouse_lappland_1x.png")

deps = [
    dependency(B2 / "rhodes_floor_v1.png", ROOT, "Locked dark-steel seamless floor tile for 360x229 shell and composite"),
    dependency(B1 / "wall_straight_60x46_v5.png", ROOT, "Locked 46px dark-steel wall module"),
    dependency(B1 / "corner_left_L_v5.png", ROOT, "Locked left wall-cap corner"),
    dependency(B1 / "corner_right_L_v5.png", ROOT, "Locked right wall-cap corner"),
    dependency(B1 / "wall_rib_6x46_v5.png", ROOT, "Locked separate structural rib; keep away from door frames"),
    dependency(B1 / "wall_top_6_plus2_v5.png", ROOT, "Locked 6px side-wall top strip and 2px contact shadow"),
    dependency(B1 / "door_side_gap38_v5.png", ROOT, "Locked top-down side-wall doorway"),
    dependency(B1 / "wall_floor_contact_shadow_60x2_v5.png", ROOT, "Locked wall-root shadow strip"),
    dependency(B1 / "door_open_45x46_v5.png", ROOT, "Locked 45px open warehouse doorway"),
    dependency(B1 / "door_closed_45x46_v5.png", ROOT, "Locked 45px closed warehouse doorway"),
    dependency(B1 / "door_sealed_45x46_v5.png", ROOT, "Locked 45px sealed warehouse doorway"),
    dependency(B1 / "lappland_frame0_64.png", ROOT, "Lappland frame 0 at native 1:1 scale"),
    dependency(L0 / "rhodes_logo_S_gray_v1.png", ROOT, "Accepted S identity stamps on props"),
    dependency(L0 / "rhodes_logo_M_gray_v1.png", ROOT, "Accepted M tower in warehouse supergraphic"),
    dependency(H1B / "small_number_plate_B1_03.png", ROOT, "Accepted H1b B1-03 plate to pair with warehouse door"),
    dependency(H1 / "light_pool_rectangle_cool_90x60.png", ROOT, "Additive rack light pool; apply opaque-black additive blend"),
    dependency(H1 / "light_pool_rectangle_cool_90x60_emit.png", ROOT, "Accepted cool pool emit mask"),
    dependency(H1 / "light_pool_circle_warm_60x40.png", ROOT, "Additive small warm pool near sealed materials crate"),
    dependency(H1 / "light_pool_circle_warm_60x40_emit.png", ROOT, "Accepted warm pool emit mask"),
    dependency(H1 / "wall_mounted_extinguisher_14x28.png", ROOT, "Accepted fire extinguisher for warehouse safety wall"),
]

manifest = {
    "batch": "H2 warehouse v2",
    "spec": "罗德岛基地美术策划案_v2_0.md §§2.1, 2.3 warehouse, 2.4 expansion, 3.2, 3.5, 3.7 v2.0.2 cap, 4.2 H2, 4.4",
    "pixel_scale": 1,
    "assets": assets,
    "external_dependencies": deps,
    "style_reference": {"file": "../../field/props_v1.png", "use": "Field originium black angular facets and orange cores; H2 crystals are redrawn on the native grid."},
    "logo_policy": "At most six marks per displayed screen. Use only the M supergraphic and S marks on wall bay, storage terminal and freight lift; small props and shelves use numbers or category icons.",
    "shell": {
        "type": "large", "size_units": [24, 18], "floor_size_px": [360, 229],
        "wall_height_px": 46, "floor_tile": "../batch2_v2/rhodes_floor_v1.png",
        "north_wall_modules": ["warehouse_wall_bay_120x46.png", "../batch1_v5/wall_straight_60x46_v5.png"],
        "corners_and_doors": "Use locked batch1_v5 corners and 45x46 door states; no wall geometry changed.",
        "side_walls": ["../batch1_v5/wall_top_6_plus2_v5.png", "../batch1_v5/door_side_gap38_v5.png"],
        "assembly": "Asset kit only; position shelves against walls and reserve a central aisle at least 45px wide.",
    },
    "preview": {"file": "H2_warehouse_lappland_1x.png", "size_px": [700, 420], "character": "Lappland frame 0, original 64x64 source unscaled", "character_origin_px": [565, 350 - (lap_bbox[3] - 1)], "purpose": "Native-scale asset sheet; no room blockout"},
    "assembly": {
        "categories": "Pair each rack's unique B1-03-A through B1-03-D 5x7 code with its same-named floor zone. Place the sealed originium containment inside MATERIALS; preserve a >=45px central aisle.",
        "delivery": "Inventory terminal opens warehouse UI; freight lift is the delivery/recovery point. Leave a 30px character position at both.",
        "expansion": "Pair the 90x60 pending frame with the removable 90x46 partition at the reserved expansion area.",
        "lighting": "Place the 48x12 lamp over each rack, with the locked H1 v2 additive cool pool on the floor; use a small warm pool for the sealed originium containment and its warm emit mask.",
        "identity": "Use accepted B1-03 plate at the door and M supergraphic on the primary wall. S marks appear only on wall bay, storage terminal and freight lift; smaller items use codes/icons.",
    },
    "checklist_35": {
        "A": "Dark-steel 46px modular shell, four high wall-backed rack groups, freight lift, trolley/forklift and expansion partition.",
        "B": "B1-03 door plate dependency, WAREHOUSE supergraphic, shelf IDs and four category icons/zone frames.",
        "C": "Dark-steel body with restrained orange warehouse identity, safety yellow loading edges, cold screens and warm emit from black/orange originium under seal.",
        "D": "Representative S marks only; four unique 5x7 rack IDs, equipment codes, sealed-material warning, wall clipboard, notice board, extinguisher dependency and operator positions.",
        "one_screen_readability": "Parts carry warehouse and Rhodes identity; final assembled-room recognition is for scene assembly.",
    },
}
write_json(ROOT / "manifest.json", manifest)
(ROOT / "validation.txt").write_text(
    f"H2 v2 generated: {len(assets)} native assets and {len(deps)} locked dependencies.\n"
    "Warehouse shell metadata: 24x18 units, 360x229 floor pixels, 46px locked wall height; no assembled blockout.\n"
    "Four category racks and matching floor zones: WEAPONS B1-03-A, ARMOR B1-03-B, CONSUMABLES B1-03-C, MATERIALS B1-03-D, each drawn in the native 5x7 font.\n"
    "Logo cap: representative marks only on supergraphic, wall bay, storage terminal and freight lift; smaller props use number plates or icons.\n"
    "MATERIALS contains visible field-style black faceted originium with orange cores inside sealed containment and warm emit.\n"
    "Inventory terminal and freight lift have dark/active states; lit states have matching emit masks.\n"
    "§3.5 A/B/C/D per-asset coverage is recorded in manifest.json; final full-room read awaits assembly.\n",
    encoding="utf-8",
)
print(f"H2: {len(assets)} native assets, {len(deps)} locked dependencies and 1:1 composite")
