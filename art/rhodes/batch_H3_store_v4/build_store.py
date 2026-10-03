"""Closure STORE v4: level main counter and quieter clean warm floor."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from h3_source_pipeline import Kit  # noqa: E402
from pixel_kit import COLORS, GLYPHS_5, canvas, draw_text, load, paste, rect, rgba, save_native  # noqa: E402

OLD = ART / "batch_H3_store_v1"
H1 = ART / "batch_H1_bridge_hall_v2"
H1B = ART / "batch_H1b_wayfinding_v1"
L0 = ART / "batch_L0_logo_v1"
B1 = ART / "batch1_v5"
LIGHT = ART / "batch3_equipment_v3"


def warm_floor() -> Path:
    # Regular warm metal plates; no stochastic rust/grime from the old floor.
    result = canvas(120, 120, "G0")
    for row in range(4):
        for col in range(4):
            x, y = col * 30, row * 30
            rect(result, (x + 1, y + 1, x + 28, y + 28),
                 "L1" if (row + col) % 2 else "G1")
            rect(result, (x + 2, y + 2, x + 27, y + 3), "W0")
            rect(result, (x + 2, y + 27, x + 27, y + 27), "G0")
            for sx in (x + 4, x + 25):
                for sy in (y + 7, y + 24):
                    rect(result, (sx, sy, sx, sy), "S3")
    save_native(result, ROOT, "store_floor_warm_120x120")
    return ROOT / "store_floor_warm_120x120.png"


def draw_big(im: Image.Image, word: str, x: int, y: int, color: str) -> None:
    for index, char in enumerate(word):
        for yy, row in enumerate(GLYPHS_5[char].split("/")):
            for xx, bit in enumerate(row):
                if bit == "1":
                    rect(im, (x + index * 12 + xx * 2, y + yy * 2,
                              x + index * 12 + xx * 2 + 1, y + yy * 2 + 1), color)


def sign_polish(im: Image.Image) -> None:
    logo = load(L0 / "rhodes_logo_M_gray_v1.png")
    rect(im, (4, 5, 31, 31), "S1")
    paste(im, logo, (6, 7))
    # Cover all generated STURE/ST0RE artifacts before accepted bitmap lettering.
    rect(im, (34, 5, 97, 30), "L2")
    rect(im, (34, 5, 97, 6), "L1")
    rect(im, (34, 30, 97, 30), "L0")
    draw_big(im, "STORE", 35, 9, "S1")
    draw_text(im, "B1-01", 39, 25, 3, "S2")


def recolor(im: Image.Image, mapping: dict[str, str]) -> None:
    table = {rgba(old): rgba(new) for old, new in mapping.items()}
    im.putdata([table.get(pixel, pixel) for pixel in im.get_flattened_data()])


def muted_glass(im: Image.Image) -> None:
    recolor(im, {"B0": "S2", "B1": "G0"})
    cap_blue(im)


def cap_blue(im: Image.Image) -> None:
    blue = {tuple(bytes.fromhex(COLORS[name][1:])) for name in ("B0", "B1", "B2")}
    target = {"B0": "S2", "B1": "G0", "B2": "G2"}
    pixels = im.load()
    opaque = [(x, y) for y in range(im.height) for x in range(im.width) if pixels[x, y][3]]
    remaining = sum(pixels[x, y][:3] in blue for x, y in opaque) - int(len(opaque) * 0.05)
    for source in ("B0", "B1", "B2"):
        if remaining <= 0:
            break
        src = tuple(bytes.fromhex(COLORS[source][1:]))
        dst = tuple(bytes.fromhex(COLORS[target[source]][1:]))
        positions = [(x, y) for x, y in opaque if pixels[x, y][:3] == src]
        take = min(remaining, len(positions))
        if take:
            for index in {round((i + 0.5) * len(positions) / take - 0.5) for i in range(take)}:
                x, y = positions[index]
                pixels[x, y] = (*dst, 255)
            remaining -= take


def neutral_boxes(im: Image.Image) -> None:
    recolor(im, {"B0": "S2"})


def warm_plant(im: Image.Image) -> None:
    recolor(im, {"Y0": "L0", "Y1": "L1", "Y2": "L2",
                 "O0": "L0", "O1": "L1", "O2": "L2"})


def counter_polish(im: Image.Image) -> None:
    # Restore a native product/price UI after reduction; the furniture remains generated.
    pixels = im.load()
    yellow = rgba("Y2")
    orange = rgba("O2")
    for x in range(im.width):
        if pixels[x, 18] == yellow:
            pixels[x, 18] = rgba("L2")
        if pixels[x, 19] == orange:
            pixels[x, 19] = rgba("L1")
    rect(im, (54, 5, 69, 15), "B0")
    rect(im, (55, 6, 59, 12), "G2")
    rect(im, (56, 8, 58, 10), "S2")
    rect(im, (61, 7, 67, 7), "L2")
    draw_text(im, "12", 61, 8, 3, "W1")  # price beside product thumbnail
    rect(im, (66, 14, 67, 14), "T2")
    paste(im, load(L0 / "rhodes_logo_S_gray_v1.png"), (8, 24))


def main() -> None:
    wall = OLD / "store_wall_warm_60x46.png"
    floor = warm_floor()
    kit = Kit(ROOT, "STORE", "B1-01", (12, 9), (180, 115), wall, floor, version=4)
    kit.generated_asset("store_warm_sign_source.png", "store_warm_sign", 20, "wall",
                        "Generated warm shop sign; native B1-01 lettering and accepted M mark added after quantization.",
                        ["B: STORE supergraphic", "C: warm lit identity"], wall=True, emit=("L2",),
                        polish=sign_polish, postprocess="M and exact native text over generated face")
    kit.generated_asset("store_front_counter_source.png", "store_front_counter", 18, "billboard",
                        "Crowded front-facing shop counter; self-service product/price screen until Closure is recruited.",
                        ["A: axis-aligned level top and flat front, no receding side", "B: S on representative main object", "D: boxed goods and receipt"],
                        emit=("T2", "B2"), polish=counter_polish,
                        postprocess="native product/price screen polish and accepted S mark")
    kit.generated_asset("store_weapon_case_source.png", "store_weapon_glass_case", 29, "billboard",
                        "Front-facing glass case with sword and attached brass price holder.",
                        ["A: level glass top and front display planes", "C: cold display glints"], emit=("T2", "B2"),
                        polish=muted_glass, postprocess="blue glass body muted to grey; bright glass glints retained")
    kit.generated_asset("store_equipment_case_source.png", "store_equipment_glass_case", 25, "billboard",
                        "Front-facing glass case with armor and attached brass price holder.",
                        ["A: second glass product display", "C: restrained cool case light"], emit=("T2", "B2"),
                        polish=muted_glass, postprocess="blue glass body muted to grey; bright glass glints retained")
    kit.generated_asset("store_product_shelf_source.png", "store_back_product_shelf", 22, "wall",
                        "Dense wall-backed stock: boxed gadgets, consumables, weapon parts and price tabs.",
                        ["A: front-on shelf with shallow top cap", "B: shelf price tabs", "D: busy retail inventory"],
                        wall=True, polish=cap_blue, postprocess="restrain blue stock labels to the accent budget")
    kit.generated_asset("store_stacked_boxes_source.png", "store_stacked_merchandise_boxes", 24, "billboard",
                        "Six axis-aligned merchandise boxes stacked by the counter; shallow tops and front faces, no logo.",
                        ["A: stocked shop cargo", "D: packed merchandise"], life=True,
                        polish=neutral_boxes, postprocess="box bodies cooled to grey; narrow accent tapes retained")
    kit.generated_asset("store_pendant_lamp_source.png", "store_warm_pendant_lamp", 42, "wall",
                        "Warm ceiling pendant above the counter.", ["A: suspended light", "C: amber emit"],
                        wall=True, emit=("L2",))
    kit.generated_asset("store_product_poster_source.png", "store_product_poster", 40, "wall",
                        "Illustrated product poster on side wall, without unsupported text.",
                        ["B: retail poster", "D: attached shop life detail"], wall=True, life=True)
    kit.generated_asset("store_potted_plant_source.png", "store_potted_plant", 40, "billboard",
                        "Small warm-metal pot on merchandise shelf.", ["D: attached shop plant"], life=True,
                        polish=warm_plant, postprocess="leaves mapped to warm-light material tones")
    for old_name, stem, kind in (("store_counter_zone_80x36.png", "store_counter_zone_80x36", "decal"),
                                 ("store_safety_strip_30x10.png", "store_safety_strip_30x10", "decal"),
                                 ("store_price_tag_weapon_24x14.png", "store_price_tag_weapon_24x14", "wall"),
                                 ("store_price_tag_equipment_24x14.png", "store_price_tag_equipment_24x14", "wall"),
                                 ("store_stand_spot_closure_behind_counter_12x6.png", "store_stand_spot_closure_behind_counter_12x6", "decal"),
                                 ("store_stand_spot_customer_at_terminal_12x6.png", "store_stand_spot_customer_at_terminal_12x6", "decal")):
        kit.geometric(OLD / old_name, stem, kind, "Accepted native geometric signage/decal; no resampling.",
                      ["B: shop wayfinding" if "price" in stem else "A: reserved standing area" if "stand_spot" in stem else "C: shop floor graphic"],
                      wall=kind == "wall", stand="stand_spot" in stem)
    kit.life_details.extend(("store_price_tag_weapon_24x14", "store_price_tag_equipment_24x14",
                             "../batch_H1_bridge_hall_v2/duty_mug_clip_12x10.png",
                             "../batch_H1_bridge_hall_v2/desk_memo_sticker_16x14.png"))
    kit.dep(H1 / "duty_mug_clip_12x10.png", "Accepted counter mug")
    kit.dep(H1 / "desk_memo_sticker_16x14.png", "Accepted attached memo")
    lap = load(B1 / "lappland_frame0_64.png")
    placements = [
        (ROOT / "store_counter_zone_80x36.png", (49, 113)),
        (ROOT / "store_safety_strip_30x10.png", (100, 145)),
        (ROOT / "store_stand_spot_closure_behind_counter_12x6.png", (77, 87)),
        (ROOT / "store_stand_spot_customer_at_terminal_12x6.png", (88, 145)),
        (ROOT / "store_warm_sign.png", (80, 4)),
        (ROOT / "store_back_product_shelf.png", (0, 10)),
        (ROOT / "store_warm_pendant_lamp.png", (113, 37)),
        (ROOT / "store_stacked_merchandise_boxes.png", (83, 77)),
        (ROOT / "store_potted_plant.png", (145, 91)),
        (ROOT / "store_equipment_glass_case.png", (122, 115)),
        (ROOT / "store_weapon_glass_case.png", (2, 120)),
        (ROOT / "store_front_counter.png", (42, 98)),
        (ROOT / "store_price_tag_weapon_24x14.png", (20, 127)),
        (ROOT / "store_price_tag_equipment_24x14.png", (137, 132)),
        (H1 / "duty_mug_clip_12x10.png", (76, 105)),
        (H1 / "desk_memo_sticker_16x14.png", (110, 107)),
        (H1B / "small_number_plate_B1_01.png", (2, 46)),
    ]
    size = kit.composite("H3_store_lappland_1x", placements, lap, (60, 105))
    kit.finish("H3_store_lappland_1x", size, (60, 105),
               {"counter": "Self-service until Closure is recruited; operator spot behind and customer spot in front.",
                "retail": "Place densely stocked shelf and poster on the north wall; two glass cases flank the main counter.",
                "lighting": "Use warm sign and pendant emit with accepted warm additive pool, cool case pins only."},
               {"A": "Generated front-facing counter, two glass cases, deep shelf and suspended lamp.",
                "B": "B1-01 plate, warm STORE sign, case price tags and product/price UI.",
                "C": "Warm wall/floor, amber sign, cool case glints and two work-zone signals.",
                "D": "Stacked stock, poster, plant, mug, memo, receipt, price holders and hazard strip."},
               [(B1 / "lappland_frame0_64.png", "Native unscaled character"),
                (L0 / "rhodes_logo_M_gray_v1.png", "Accepted M identity mark"),
                (L0 / "rhodes_logo_S_gray_v1.png", "Accepted S identity mark"),
                (H1B / "small_number_plate_B1_01.png", "Accepted B1-01 door plate"),
                (H1 / "light_pool_circle_warm_60x40.png", "Accepted additive warm pool")])
    print(f"STORE v4: {len(kit.assets)} assets; 1:1 shell composite {size}")


if __name__ == "__main__":
    main()
