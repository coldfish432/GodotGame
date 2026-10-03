"""ARMORY v2: generated shaded equipment sources plus locked geometric modules."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from h3_source_pipeline import Kit  # noqa: E402
from pixel_kit import COLORS, load, paste, poly, rect  # noqa: E402

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
    # Restore a native schematic read after uniform reduction; no cyan chart.
    rect(im, (54, 4, 72, 13), "B0")
    poly(im, [(55, 8), (58, 8), (59, 9), (56, 11), (55, 10)], "W1")  # shoulder stock
    rect(im, (59, 8, 64, 9), "W1")  # receiver
    rect(im, (65, 8, 70, 8), "W1")  # long barrel
    rect(im, (70, 7, 71, 9), "G2")  # muzzle bracket
    rect(im, (60, 6, 62, 7), "G2")  # sight
    rect(im, (61, 10, 62, 12), "W1")  # grip
    rect(im, (64, 10, 66, 11), "G2")  # magazine
    rect(im, (56, 5, 69, 5), "B2")  # dimension rule
    rect(im, (56, 12, 58, 12), "T2")
    paste(im, load(L0 / "rhodes_logo_S_gray_v1.png"), (9, 34))


def main() -> None:
    wall = LIGHT / "wall_straight_60x46_light_v2.png"
    floor = LIGHT / "rhodes_floor_equipment_v1.png"
    kit = Kit(ROOT, "ARMORY", "B1-02", (18, 12), (270, 152), wall, floor)
    kit.geometric(OLD / "armory_department_sign_120x46.png", "armory_department_sign_120x46", "wall",
                  "Accepted native wayfinding module: ARMORY, B1-02, M mark and safety-yellow band.",
                  ["B: department sign", "C: safety-yellow band"], wall=True)
    kit.generated_asset("armory_workbench_source.png", "armory_equipment_workbench", 14, "billboard",
                        "Main equipment UI station: 3/4 top/front/right planes, tools and weapon-schematic screen; total 48px high.",
                        ["A: shaped workbench", "B: representative S identity", "C: weapon schematic"],
                        emit=("T2", "B2"), polish=workbench_polish,
                        postprocess="native weapon-schematic screen polish and accepted S mark")
    kit.generated_asset("armory_weapon_wall_source.png", "armory_weapon_wall", 16, "wall",
                        "Six visibly distinct hung weapons in recessed 3/4 wall rack; no small S stamps.",
                        ["A: deep wall weapon storage", "C: narrow safety-yellow guide"], wall=True,
                        polish=lift_equipment_values, postprocess="local-value lift for light room shell")
    kit.generated_asset("armory_robotic_arm_source.png", "armory_robotic_arm", 20, "billboard",
                        "Articulated arm with separate dark joints, top/front pedestal and orange cable.",
                        ["A: jointed repair robot", "C: cold-grey body and small orange cable"],
                        polish=lift_equipment_values, postprocess="local-value lift for light room shell")
    kit.generated_asset("armory_hoist_source.png", "armory_overhead_hoist", 18, "wall",
                        "Suspended beam, yellow trolley, chain and repair hook; mount at ceiling.",
                        ["A: overhead hoist structure", "C: yellow safety carriage"], wall=True,
                        polish=lambda image: lift_equipment_values(image, hoist=True),
                        postprocess="light-enamel lift; large yellow trolley panel recolored grey")
    kit.generated_asset("armory_toolboard_source.png", "armory_tool_board", 20, "wall",
                        "Shaded pegboard with distinct hanging tools and recessed cubbies.",
                        ["A: wall tooling with thickness", "D: ready-use tools"], wall=True, life=True,
                        polish=lift_equipment_values, postprocess="local-value lift for light room shell")
    kit.generated_asset("armory_equipment_case_source.png", "armory_equipment_case", 30, "billboard",
                        "Portable case with top lid, front latches and right-side plane. Reuse for two placements.",
                        ["A: equipment storage case", "C: narrow yellow band"], life=True,
                        polish=lift_equipment_values, postprocess="local-value lift for light room shell")
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
        (ROOT / "armory_weapon_wall.png", (166, 40)),
        (ROOT / "armory_overhead_hoist.png", (102, 35)),
        (ROOT / "armory_department_sign_120x46.png", (5, 0)),
        (ROOT / "armory_tool_board.png", (8, 51)),
        (ROOT / "armory_task_lamp.png", (146, 58)),
        (ROOT / "armory_robotic_arm.png", (5, 108)),
        (ROOT / "armory_equipment_workbench.png", (69, 112)),
        (ROOT / "armory_equipment_case.png", (184, 126)),
        (ROOT / "armory_equipment_case.png", (212, 153)),
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
               {"A": "Generated 3/4 workbench, weapon rack, robot arm, hoist, pegboard and cases.",
                "B": "B1-02 plate and ARMORY department sign; unique schematic UI.",
                "C": "Light shell, cold white equipment and safety-yellow guide lines.",
                "D": "Tools, cases, mug, memo, emergency stop, extinguisher and clipboard."},
               [(B1 / "lappland_frame0_64.png", "Unscaled Lappland"),
                (L0 / "rhodes_logo_M_gray_v1.png", "Accepted M logo in geometric sign"),
                (L0 / "rhodes_logo_S_gray_v1.png", "Accepted S mark on bench"),
                (H1B / "small_number_plate_B1_02.png", "Accepted B1-02 door plate"),
                (H1 / "light_pool_rectangle_cool_90x60.png", "Accepted additive cool pool")])
    print(f"ARMORY v2: {len(kit.assets)} assets; 1:1 shell composite {size}")


if __name__ == "__main__":
    main()
