"""ARMORY v3: generated straight-on equipment plus native wall graphics."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from h3_source_pipeline import Kit  # noqa: E402
from pixel_kit import COLORS, GLYPHS_5, canvas, draw_text, load, paste, poly, rect  # noqa: E402

OLD = ART / "batch_H3_armory_v1"
LIGHT = ART / "batch3_equipment_v3"
H1 = ART / "batch_H1_bridge_hall_v2"
H1B = ART / "batch_H1b_wayfinding_v1"
H2 = ART / "batch_H2_warehouse_v2"
L0 = ART / "batch_L0_logo_v1"
B1 = ART / "batch1_v5"


def lift_equipment_values(im: Image.Image, *, hoist: bool = False) -> None:
    """Light enamel on top planes, dark local joints and recesses retained."""
    mapping = {"D": "S2", "S0": "S2", "S1": "S3", "S2": "G0",
               "S3": "G1", "G0": "G1", "G1": "G2", "G2": "W1",
               "W0": "W1", "W1": "W2"}
    if hoist:
        # The trolley is mostly white enamel; yellow remains a narrow warning edge.
        mapping["Y2"] = "G2"
        mapping["Y0"] = "G1"
    lookup = {tuple(bytes.fromhex(COLORS[src][1:])): tuple(bytes.fromhex(COLORS[dst][1:]))
              for src, dst in mapping.items()}
    pixels = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = pixels[x, y]
            if a:
                pixels[x, y] = (*lookup.get((r, g, b), (r, g, b)), a)


def case_polish(im: Image.Image) -> None:
    lift_equipment_values(im)
    # The small front face needs a mid-grey step to hold form against the wall.
    mapping = {"W2": "W1", "W1": "G2", "G1": "G0"}
    lookup = {tuple(bytes.fromhex(COLORS[src][1:])): tuple(bytes.fromhex(COLORS[dst][1:]))
              for src, dst in mapping.items()}
    pixels = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = pixels[x, y]
            if a:
                pixels[x, y] = (*lookup.get((r, g, b), (r, g, b)), a)


def workbench_polish(im: Image.Image) -> None:
    lift_equipment_values(im)
    # New source's monitor occupies x61..86. Keep its housing and redraw the UI.
    rect(im, (63, 3, 82, 12), "B0")
    poly(im, [(64, 7), (67, 7), (68, 8), (64, 10)], "W1")
    rect(im, (68, 7, 73, 8), "W1")
    rect(im, (74, 7, 80, 7), "W1")
    rect(im, (79, 6, 81, 9), "G2")
    rect(im, (69, 9, 70, 11), "W1")
    rect(im, (73, 9, 75, 10), "G2")
    rect(im, (65, 4, 79, 4), "B2")
    rect(im, (64, 11, 66, 11), "T2")
    paste(im, load(L0 / "rhodes_logo_S_gray_v1.png"), (8, 28))


def department_sign() -> Image.Image:
    image = canvas(120, 36)
    rect(image, (0, 0, 119, 35), "S1")
    rect(image, (2, 2, 117, 33), "S0")
    rect(image, (3, 3, 116, 4), "Y1")
    rect(image, (3, 31, 116, 32), "Y1")
    paste(image, load(L0 / "rhodes_logo_M_gray_v1.png"), (4, 6))
    for index, char in enumerate("ARMORY"):
        for yy, row in enumerate(GLYPHS_5[char].split("/")):
            for xx, bit in enumerate(row):
                if bit == "1":
                    rect(image, (32 + index * 12 + xx * 2, 8 + yy * 2,
                                 33 + index * 12 + xx * 2, 9 + yy * 2), "W1")
    draw_text(image, "B1-02", 34, 25, 3, "W1")
    return image


def main() -> None:
    wall = LIGHT / "wall_straight_60x46_light_v2.png"
    floor = LIGHT / "rhodes_floor_equipment_v1.png"
    kit = Kit(ROOT, "ARMORY", "B1-02", (18, 12), (270, 152), wall, floor, version=3)
    kit.add("armory_department_sign_120x36", department_sign(), "wall",
            "Native 5x7 ARMORY/B1-02 sign, accepted M mark and safety-yellow band; fits 40px wall face.",
            ["B: department sign", "C: safety-yellow band"], wall=True,
            postprocess="geometric sign with accepted glyph grid; no generated lettering")
    kit.generated_asset("armory_workbench_source.png", "armory_equipment_workbench", 18, "billboard",
                        "Main equipment UI station: axis-aligned top/front planes, tools and weapon-schematic screen; under 45px high.",
                        ["A: shaped workbench", "B: representative S identity", "C: weapon schematic"],
                        emit=("T2", "B2"), polish=workbench_polish,
                        postprocess="native weapon-schematic screen polish and accepted S mark")
    kit.generated_asset("armory_weapon_wall_source.png", "armory_weapon_wall", 22, "wall",
                        "Six visibly distinct hung weapons in a front-facing recessed wall rack; no small S stamps.",
                        ["A: deep wall weapon storage", "C: narrow safety-yellow guide"], wall=True,
                        polish=lift_equipment_values, postprocess="local-value lift for light room shell")
    kit.generated_asset("armory_robotic_arm_source.png", "armory_robotic_arm", 29, "billboard",
                        "Articulated arm with separate dark joints, top/front pedestal and orange cable.",
                        ["A: jointed repair robot", "C: cold-grey body and small orange cable"],
                        polish=lift_equipment_values, postprocess="local-value lift for light room shell")
    kit.generated_asset("armory_hoist_source.png", "armory_overhead_hoist", 30, "wall",
                        "Level front-facing rail, yellow trolley, vertical chain and repair hook; mount at ceiling.",
                        ["A: overhead hoist structure", "C: yellow safety carriage"], wall=True,
                        polish=lambda image: lift_equipment_values(image, hoist=True),
                        postprocess="light-enamel lift; large yellow trolley panel recolored grey")
    kit.generated_asset("armory_toolboard_source.png", "armory_tool_board", 28, "wall",
                        "Shaded pegboard with distinct hanging tools and recessed cubbies.",
                        ["A: wall tooling with thickness", "D: ready-use tools"], wall=True, life=True,
                        polish=lift_equipment_values, postprocess="local-value lift for light room shell")
    kit.generated_asset("armory_equipment_case_source.png", "armory_equipment_case", 44, "billboard",
                        "Portable case with level lid, front latches and no receding side plane. Reuse for two placements.",
                        ["A: equipment storage case", "C: narrow yellow band"], life=True,
                        polish=case_polish, postprocess="light-room enamel with a distinct mid-grey front face")
    kit.generated_asset("armory_task_lamp_source.png", "armory_task_lamp", 40, "wall",
                        "Shaded suspended cool task lamp.", ["A: overhead service light", "C: cool-white emit"],
                        wall=True, emit=("W2",))
    for old_name, stem, kind in (("armory_bench_zone_100x44.png", "armory_bench_zone_100x44", "decal"),
                                 ("armory_safety_strip_30x10.png", "armory_safety_strip_30x10", "decal"),
                                 ("armory_stand_spot_bench_operator_12x6.png", "armory_stand_spot_bench_operator_12x6", "decal"),
                                 ("armory_stand_spot_weapon_wall_inspector_12x6.png", "armory_stand_spot_weapon_wall_inspector_12x6", "decal")):
        kit.geometric(OLD / old_name, stem, kind, "Accepted native floor graphic; no resampling.",
                      ["A: reserved character position" if "stand_spot" in stem else "C: safety zone/hazard"],
                      stand="stand_spot" in stem)
    life = [(H1 / "duty_mug_clip_12x10.png", "Accepted mug"),
            (H1 / "desk_memo_sticker_16x14.png", "Accepted service memo"),
            (H1 / "emergency_stop_plate_16x20.png", "Accepted emergency stop"),
            (H1 / "wall_mounted_extinguisher_14x28.png", "Accepted extinguisher"),
            (H2 / "warehouse_wall_clipboard_22x28.png", "Accepted operations clipboard")]
    for path, use in life:
        kit.dep(path, use)
        kit.life_details.append(kit.dependencies[str(path.resolve())]["file"])
    lap = load(B1 / "lappland_frame0_64.png")
    placements = [
        (ROOT / "armory_bench_zone_100x44.png", (70, 138)),
        (ROOT / "armory_safety_strip_30x10.png", (176, 174)),
        (ROOT / "armory_stand_spot_bench_operator_12x6.png", (114, 173)),
        (ROOT / "armory_stand_spot_weapon_wall_inspector_12x6.png", (216, 110)),
        (ROOT / "armory_weapon_wall.png", (179, 14)),
        (ROOT / "armory_tool_board.png", (121, 17)),
        (ROOT / "armory_department_sign_120x36.png", (0, 0)),
        (ROOT / "armory_overhead_hoist.png", (113, 0)),
        (ROOT / "armory_task_lamp.png", (146, 58)),
        (ROOT / "armory_robotic_arm.png", (7, 124)),
        (ROOT / "armory_equipment_workbench.png", (68, 118)),
        (ROOT / "armory_equipment_case.png", (188, 140)),
        (ROOT / "armory_equipment_case.png", (217, 164)),
        (H1 / "duty_mug_clip_12x10.png", (80, 114)),
        (H1 / "desk_memo_sticker_16x14.png", (108, 115)),
        (H1 / "emergency_stop_plate_16x20.png", (242, 102)),
        (H1 / "wall_mounted_extinguisher_14x28.png", (2, 68)),
        (H2 / "warehouse_wall_clipboard_22x28.png", (39, 62)),
        (H1B / "small_number_plate_B1_02.png", (238, 3)),
    ]
    size = kit.composite("H3_armory_lappland_1x", placements, lap, (112, 137))
    kit.finish("H3_armory_lappland_1x", size, (112, 137),
               {"station": "Workbench is equipment interaction; leave 30px in front of its operator spot.",
                "walls": "Weapon wall, hoist, pegboard and lamp attach to locked 46px light shell.",
                "lighting": "Cool lamp and schematic screen emit; accepted additive cool light pool on floor."},
               {"A": "Generated front-facing workbench, weapon rack, robot arm, hoist, pegboard and cases.",
                "B": "B1-02 plate and ARMORY department sign; unique schematic UI.",
                "C": "Light shell, cold white equipment and safety-yellow guide lines.",
                "D": "Tools, cases, mug, memo, emergency stop, extinguisher and clipboard."},
               [(B1 / "lappland_frame0_64.png", "Unscaled Lappland"),
                (L0 / "rhodes_logo_M_gray_v1.png", "Accepted M logo in geometric sign"),
                (L0 / "rhodes_logo_S_gray_v1.png", "Accepted S mark on bench"),
                (H1B / "small_number_plate_B1_02.png", "Accepted B1-02 door plate"),
                (H1 / "light_pool_rectangle_cool_90x60.png", "Accepted additive cool pool")])
    print(f"ARMORY v3: {len(kit.assets)} assets; 1:1 shell composite {size}")


if __name__ == "__main__":
    main()
