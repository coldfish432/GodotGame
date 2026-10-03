"""MEDICAL v2: generated recovery furniture on the own white shell."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from h3_source_pipeline import Kit  # noqa: E402
from pixel_kit import COLORS, draw_text, line, load, paste, rect  # noqa: E402

OLD = ART / "batch_H3_medical_v1"
LIGHT = ART / "batch3_equipment_v3"
H1 = ART / "batch_H1_bridge_hall_v2"
H1B = ART / "batch_H1b_wayfinding_v1"
H2 = ART / "batch_H2_warehouse_v2"
L0 = ART / "batch_L0_logo_v1"
B1 = ART / "batch1_v5"


def cap_blue_fabric(im: Image.Image) -> None:
    """Keep the blue linen edge thin while retaining its generated folds."""
    blue = {tuple(bytes.fromhex(COLORS[name][1:])) for name in ("B0", "B1", "B2")}
    pixels = im.load()
    opaque = [(x, y) for y in range(im.height) for x in range(im.width) if pixels[x, y][3]]
    blue_count = sum(pixels[x, y][:3] in blue for x, y in opaque)
    remove = max(0, blue_count - int(len(opaque) * 0.055))
    for source, replacement in (("B0", "S2"), ("B1", "G2")):
        if not remove:
            break
        src = tuple(bytes.fromhex(COLORS[source][1:]))
        dst = tuple(bytes.fromhex(COLORS[replacement][1:]))
        candidates = [(x, y) for x, y in opaque if pixels[x, y][:3] == src]
        take = min(remove, len(candidates))
        # Spread replacements over the fabric instead of removing one solid patch.
        selected = {round((i + 0.5) * len(candidates) / take - 0.5) for i in range(take)} if take else set()
        for index in selected:
            x, y = candidates[index]
            pixels[x, y] = (*dst, 255)
        remove -= take


def shift_values(im: Image.Image, mapping: dict[str, str]) -> None:
    lookup = {tuple(bytes.fromhex(COLORS[src][1:])): tuple(bytes.fromhex(COLORS[dst][1:]))
              for src, dst in mapping.items()}
    pixels = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = pixels[x, y]
            if a:
                pixels[x, y] = (*lookup.get((r, g, b), (r, g, b)), a)


def cabinet_polish(im: Image.Image) -> None:
    shift_values(im, {"D": "S1", "S0": "S2", "S1": "S3", "S2": "G0",
                      "S3": "G1", "G0": "G1", "G1": "G2"})


def iv_polish(im: Image.Image) -> None:
    shift_values(im, {"D": "S3", "S0": "G0", "S1": "G1", "S2": "G1",
                      "S3": "W0", "G0": "G2", "G1": "W0", "G2": "W1"})


def curtain_polish(im: Image.Image) -> None:
    cap_blue_fabric(im)
    # A narrow dark fold tempers the large white fabric plane.
    white = tuple(bytes.fromhex(COLORS["W2"][1:]))
    shade = tuple(bytes.fromhex(COLORS["W1"][1:]))
    pixels = im.load()
    candidates = [(x, y) for y in range(im.height) for x in range(im.width) if pixels[x, y][:3] == white and pixels[x, y][3]]
    for x, y in candidates:
        if y % 12 >= 6:
            pixels[x, y] = (*shade, 255)


def recovery_polish(im: Image.Image) -> None:
    # The generated monitor is reduced uniformly; restore its EKG at the native grid.
    rect(im, (53, 5, 67, 15), "B0")
    line(im, [(54, 11), (56, 11), (57, 8), (58, 13), (59, 10),
              (62, 10), (63, 7), (64, 13), (65, 10), (67, 10)], "T2")
    rect(im, (54, 6, 57, 6), "B2")
    rect(im, (64, 6, 66, 6), "W1")
    paste(im, load(L0 / "rhodes_logo_S_gray_v1.png"), (83, 45))


def monitor_polish(im: Image.Image) -> None:
    # Both generated screens retain their housings; the face is an EKG, never a line chart.
    rect(im, (10, 27, 32, 41), "B0")
    line(im, [(11, 35), (14, 35), (15, 31), (16, 38), (17, 35), (21, 35),
              (22, 32), (23, 38), (24, 35), (31, 35)], "T2")
    rect(im, (11, 29, 15, 29), "B2")
    draw_text(im, "98", 24, 28, 3, "W1")
    rect(im, (39, 34, 50, 43), "B0")
    line(im, [(40, 40), (42, 40), (43, 37), (44, 42), (45, 39), (49, 39)], "T2")


def main() -> None:
    wall = OLD / "medical_wall_white_60x46.png"
    floor = OLD / "medical_floor_cool_120x120.png"
    kit = Kit(ROOT, "MEDICAL", "B1-04", (18, 12), (270, 152), wall, floor)
    kit.geometric(OLD / "medical_department_sign_120x46.png", "medical_department_sign_120x46", "wall",
                  "Accepted geometric MEDICAL B1-04 / M sign on Rhodes-blue band.",
                  ["B: department supergraphic", "C: blue-white identity"], wall=True)
    kit.generated_asset("medical_recovery_bed_source.png", "medical_recovery_bed", 14, "billboard",
                        "Primary death-recovery/wake-up bed with top mattress, rails, casters and distinct EKG vital screen.",
                        ["A: deep white recovery station", "B: S on representative main object", "C: EKG signal"],
                        emit=("T2", "T3"), polish=recovery_polish,
                        postprocess="native EKG screen polish and accepted S mark")
    kit.generated_asset("medical_ward_bed_source.png", "medical_ward_bed", 20, "billboard",
                        "Simpler secondary white/blue ward bed; place twice for three beds total.",
                        ["A: 3/4 secondary bed", "C: Rhodes blue linen band"],
                        polish=cap_blue_fabric, postprocess="reduce broad blue areas to a narrow linen band")
    kit.generated_asset("medical_monitor_source.png", "medical_suspended_monitor", 22, "wall",
                        "Ceiling-arm dual vitals monitors with EKG spike and saturation number.",
                        ["A: articulated suspended screens", "C: EKG and vitals"],
                        wall=True, emit=("T2", "T3"), polish=monitor_polish,
                        postprocess="native EKG/vital overlays inside generated screen housings")
    kit.generated_asset("medical_privacy_curtain_source.png", "medical_privacy_curtain", 17, "billboard",
                        "Folded medical-white curtain with right return and blue fabric band.",
                        ["A: overhead curtain rail", "C: banded soft-white fabric"],
                        polish=curtain_polish, postprocess="narrow blue band and soft white fold shading")
    kit.generated_asset("medical_medicine_cabinet_source.png", "medical_medicine_cabinet", 19, "wall",
                        "Glazed cabinet with dense medicines, gauze and bandages.",
                        ["A: deep glazed medicine cabinet", "D: stocked clinical supplies"], wall=True, life=True,
                        polish=cabinet_polish, postprocess="brighten cabinet enamel while retaining dark recesses")
    kit.generated_asset("medical_wash_sink_source.png", "medical_wash_sink", 25, "billboard",
                        "3/4 white ceramic wash station with basin, faucet and grey doors.",
                        ["A: clinical sink top/front/side", "D: handwash point"])
    kit.generated_asset("medical_iv_stand_source.png", "medical_iv_stand", 25, "billboard",
                        "Wheeled IV stand with visible bag and tubing attached beside recovery bed.",
                        ["A: clinical support", "D: IV therapy detail"], life=True,
                        polish=iv_polish, postprocess="light-metal IV frame for the white medical room")
    kit.generated_asset("medical_sanitizer_source.png", "medical_sanitizer", 50, "wall",
                        "Small white wall sanitizer with blue label and push lever.",
                        ["D: attached hygiene detail"], wall=True, life=True)
    for old_name, stem, kind in (("medical_recovery_zone_100x44.png", "medical_recovery_zone_100x44", "decal"),
                                 ("medical_safety_strip_30x10.png", "medical_safety_strip_30x10", "decal"),
                                 ("medical_stand_spot_recovery_attendant_12x6.png", "medical_stand_spot_recovery_attendant_12x6", "decal"),
                                 ("medical_stand_spot_medicine_cabinet_staff_12x6.png", "medical_stand_spot_medicine_cabinet_staff_12x6", "decal")):
        kit.geometric(OLD / old_name, stem, kind, "Accepted native floor graphic; no resampling.",
                      ["A: reserved character position" if "stand_spot" in stem else "C: clinical zone/hazard"],
                      stand="stand_spot" in stem)
    life = [(H1 / "desk_memo_sticker_16x14.png", "Accepted treatment memo"),
            (H1 / "wall_mounted_extinguisher_14x28.png", "Accepted safety extinguisher"),
            (H2 / "warehouse_wall_clipboard_22x28.png", "Accepted care clipboard")]
    for path, use in life:
        kit.dep(path, use)
        kit.life_details.append(kit.dependencies[str(path.resolve())]["file"])
    lap = load(B1 / "lappland_frame0_64.png")
    placements = [
        (ROOT / "medical_recovery_zone_100x44.png", (2, 146)),
        (ROOT / "medical_safety_strip_30x10.png", (196, 181)),
        (ROOT / "medical_stand_spot_recovery_attendant_12x6.png", (90, 181)),
        (ROOT / "medical_stand_spot_medicine_cabinet_staff_12x6.png", (236, 105)),
        (ROOT / "medical_department_sign_120x46.png", (6, 0)),
        (ROOT / "medical_suspended_monitor.png", (65, 42)),
        (ROOT / "medical_privacy_curtain.png", (133, 35)),
        (ROOT / "medical_medicine_cabinet.png", (198, 43)),
        (ROOT / "medical_sanitizer.png", (248, 101)),
        (ROOT / "medical_wash_sink.png", (209, 104)),
        (ROOT / "medical_iv_stand.png", (3, 100)),
        (ROOT / "medical_recovery_bed.png", (12, 116)),
        (ROOT / "medical_ward_bed.png", (108, 111)),
        (ROOT / "medical_ward_bed.png", (185, 145)),
        (H1 / "desk_memo_sticker_16x14.png", (229, 54)),
        (H1 / "wall_mounted_extinguisher_14x28.png", (2, 50)),
        (H2 / "warehouse_wall_clipboard_22x28.png", (165, 48)),
        (H1B / "small_number_plate_B1_04.png", (236, 3)),
    ]
    size = kit.composite("H3_medical_lappland_1x", placements, lap, (83, 138))
    kit.finish("H3_medical_lappland_1x", size, (83, 138),
               {"wake_up": "Main recovery bed is the death wake-up point; keep a 30px attendant station alongside.",
                "ward": "One recovery bed plus two placements of the secondary bed; curtain creates privacy.",
                "contrast": "White wall and brighter floor remain behind Lappland in the 1:1 review; floor capped at #98a2a6.",
                "lighting": "Vital screens use EKG emit masks; layer accepted cool additive pool under recovery bed."},
               {"A": "Generated deep recovery bed, ward beds, articulated dual monitors, curtain, cabinet and sink.",
                "B": "B1-04 plate and MEDICAL supergraphic; vital UI distinct from store/armory/warehouse.",
                "C": "Bright medical white with Rhodes-blue band, restrained cyan EKG signals.",
                "D": "Stocked medicine cabinet, IV bag, sanitizer, clipboard, memo and extinguisher."},
               [(B1 / "lappland_frame0_64.png", "Unscaled Lappland"),
                (L0 / "rhodes_logo_M_gray_v1.png", "Accepted M in geometric department sign"),
                (L0 / "rhodes_logo_S_gray_v1.png", "Accepted S on recovery bed"),
                (H1B / "small_number_plate_B1_04.png", "Accepted B1-04 door plate"),
                (H1 / "light_pool_rectangle_cool_90x60.png", "Accepted additive cool pool")])
    print(f"MEDICAL v2: {len(kit.assets)} assets; 1:1 shell composite {size}")


if __name__ == "__main__":
    main()
