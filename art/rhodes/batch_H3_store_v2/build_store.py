"""Closure STORE v2: generated item sources -> native 31-color asset kit."""

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
    source = load(LIGHT / "rhodes_floor_equipment_v1.png")
    mapping = {rgba("S3"): rgba("G0"), rgba("G0"): rgba("L0"), rgba("S0"): rgba("S2"),
               rgba("S2"): rgba("S3"), rgba("D"): rgba("S1"), rgba("G1"): rgba("L1")}
    result = source.copy()
    result.putdata([mapping.get(pixel, pixel) for pixel in source.get_flattened_data()])
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
    draw_big(im, "STORE", 35, 9, "S1")
    draw_text(im, "B1-01", 39, 25, 3, "S2")


def recolor(im: Image.Image, mapping: dict[str, str]) -> None:
    table = {rgba(old): rgba(new) for old, new in mapping.items()}
    im.putdata([table.get(pixel, pixel) for pixel in im.get_flattened_data()])


def muted_glass(im: Image.Image) -> None:
    recolor(im, {"B0": "S2", "B1": "G0"})


def neutral_boxes(im: Image.Image) -> None:
    recolor(im, {"B0": "S2"})


def warm_plant(im: Image.Image) -> None:
    recolor(im, {"Y0": "L0", "Y1": "L1", "Y2": "L2",
                 "O0": "L0", "O1": "L1", "O2": "L2"})


def counter_polish(im: Image.Image) -> None:
    # Restore a native product/price UI after reduction; the furniture remains generated.
    rect(im, (48, 5, 63, 15), "B0")
    rect(im, (49, 6, 53, 12), "G2")
    rect(im, (50, 8, 52, 10), "S2")
    rect(im, (55, 7, 61, 7), "L2")
    draw_text(im, "12", 55, 8, 3, "W1")  # price beside product thumbnail
    rect(im, (60, 14, 61, 14), "T2")
    paste(im, load(L0 / "rhodes_logo_S_gray_v1.png"), (8, 25))


def main() -> None:
    wall = OLD / "store_wall_warm_60x46.png"
    floor = warm_floor()
    kit = Kit(ROOT, "STORE", "B1-01", (12, 9), (180, 115), wall, floor)
    kit.generated_asset("store_warm_sign_source.png", "store_warm_sign", 20, "wall",
                        "Generated warm shop sign; native B1-01 lettering and accepted M mark added after quantization.",
                        ["B: STORE supergraphic", "C: warm lit identity"], wall=True, emit=("L2",),
                        polish=sign_polish, postprocess="M and exact native text over generated face")
    kit.generated_asset("store_front_counter_source.png", "store_front_counter", 16, "billboard",
                        "Crowded 3/4 shop counter; self-service product/price screen until Closure is recruited.",
                        ["A: top/front/right counter planes", "B: S on representative main object", "D: boxed goods and receipt"],
                        emit=("T2", "B2"), polish=counter_polish,
                        postprocess="native product/price screen polish and accepted S mark")
    kit.generated_asset("store_weapon_case_source.png", "store_weapon_glass_case", 24, "billboard",
                        "3/4 glass case with sword and attached brass price holder.",
                        ["A: glass top/front/right display planes", "C: cold display glints"], emit=("T2", "B2"),
                        polish=muted_glass, postprocess="blue glass body muted to grey; bright glass glints retained")
    kit.generated_asset("store_equipment_case_source.png", "store_equipment_glass_case", 20, "billboard",
                        "3/4 glass case with armor and attached brass price holder.",
                        ["A: second glass product display", "C: restrained cool case light"], emit=("T2", "B2"),
                        polish=muted_glass, postprocess="blue glass body muted to grey; bright glass glints retained")
    kit.generated_asset("store_product_shelf_source.png", "store_back_product_shelf", 15, "wall",
                        "Dense wall-backed stock: boxed gadgets, consumables, weapon parts and price tabs.",
                        ["A: top/front/side shelf planes", "B: shelf price tabs", "D: busy retail inventory"], wall=True)
    kit.generated_asset("store_stacked_boxes_source.png", "store_stacked_merchandise_boxes", 24, "billboard",
                        "Six merchandise boxes stacked by the counter; distinct top/front/side planes, no logo.",
                        ["A: stocked shop cargo", "D: packed merchandise"], life=True,
                        polish=neutral_boxes, postprocess="box bodies cooled to grey; narrow accent tapes retained")
    kit.generated_asset("store_pendant_lamp_source.png", "store_warm_pendant_lamp", 42, "wall",
                        "Warm ceiling pendant above the counter.", ["A: suspended light", "C: amber emit"],
                        wall=True, emit=("L2",))
    kit.generated_asset("store_product_poster_source.png", "store_product_poster", 36, "wall",
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
    kit.dep(LIGHT / "rhodes_floor_equipment_v1.png", "Plate pattern source for warm store floor")
    kit.dep(H1 / "duty_mug_clip_12x10.png", "Accepted counter mug")
    kit.dep(H1 / "desk_memo_sticker_16x14.png", "Accepted attached memo")
    lap = load(B1 / "lappland_frame0_64.png")
    placements = [
        (ROOT / "store_counter_zone_80x36.png", (49, 113)),
        (ROOT / "store_safety_strip_30x10.png", (100, 145)),
        (ROOT / "store_stand_spot_closure_behind_counter_12x6.png", (77, 87)),
        (ROOT / "store_stand_spot_customer_at_terminal_12x6.png", (88, 145)),
        (ROOT / "store_warm_sign.png", (78, 4)),
        (ROOT / "store_back_product_shelf.png", (4, 30)),
        (ROOT / "store_product_poster.png", (152, 49)),
        (ROOT / "store_warm_pendant_lamp.png", (113, 37)),
        (ROOT / "store_stacked_merchandise_boxes.png", (83, 77)),
        (ROOT / "store_potted_plant.png", (145, 91)),
        (ROOT / "store_equipment_glass_case.png", (120, 103)),
        (ROOT / "store_weapon_glass_case.png", (3, 111)),
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
               {"A": "Generated 3/4 counter, two glass cases, deep shelf and suspended lamp.",
                "B": "B1-01 plate, warm STORE sign, case price tags and product/price UI.",
                "C": "Warm wall/floor, amber sign, cool case glints and two work-zone signals.",
                "D": "Stacked stock, poster, plant, mug, memo, receipt, price holders and hazard strip."},
               [(B1 / "lappland_frame0_64.png", "Native unscaled character"),
                (L0 / "rhodes_logo_M_gray_v1.png", "Accepted M identity mark"),
                (L0 / "rhodes_logo_S_gray_v1.png", "Accepted S identity mark"),
                (H1B / "small_number_plate_B1_01.png", "Accepted B1-01 door plate"),
                (H1 / "light_pool_circle_warm_60x40.png", "Accepted additive warm pool")])
    print(f"STORE v2: {len(kit.assets)} assets; 1:1 shell composite {size}")


if __name__ == "__main__":
    main()
