"""Check H1 v2 exports and append measured results to validation.txt."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
V1 = ART / "batch_H1_bridge_hall_v1"
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8-sig"))
source = (ROOT / "build_h1_kit.ps1").read_text(encoding="utf-8")
palette = {tuple(bytes.fromhex(value[1:])) for value in re.findall(r'C\("(#[0-9a-fA-F]{6})"\)', source)}
black = (0, 0, 0)
errors: list[str] = []
asset_count = 0
emit_count = 0
used_colors: set[tuple[int, int, int]] = set()


def check(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def image_array(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"))


def check_8x(path: Path, base: np.ndarray) -> None:
    target = path.with_name(path.stem + "_8x.png")
    check(target.exists(), f"missing 8x export: {target.name}")
    if target.exists():
        scaled = image_array(target)
        expected = np.repeat(np.repeat(base, 8, axis=0), 8, axis=1)
        check(np.array_equal(scaled, expected), f"8x mismatch: {target.name}")


for asset in manifest["assets"]:
    asset_count += 1
    path = ROOT / asset["file"]
    check(path.exists(), f"missing asset: {asset['file']}")
    if not path.exists():
        continue
    pixels = image_array(path)
    h, w = pixels.shape[:2]
    check([w, h] == asset["size_px"], f"size mismatch: {asset['id']}")
    check(np.isin(pixels[:, :, 3], (0, 255)).all(), f"nonbinary alpha: {asset['id']}")
    check_8x(path, pixels)
    opaque = pixels[:, :, 3] == 255
    colors = {tuple(int(v) for v in row) for row in pixels[:, :, :3][opaque]}
    used_colors.update(colors)
    extra = colors - palette - ({black} if asset["id"].startswith("light_pool_") else set())
    check(not extra, f"unapproved colors: {asset['id']} {sorted(extra)}")
    if asset["id"].startswith("light_pool_"):
        check(opaque.all(), f"light pool not fully opaque: {asset['id']}")
        check(tuple(int(v) for v in pixels[0, 0, :3]) == black, f"light pool corner not black: {asset['id']}")
        allowed = {black, (110, 47, 20), (90, 68, 40), (200, 154, 90)} if "warm" in asset["id"] else {black, (15, 58, 64), (56, 88, 120), (42, 138, 146)}
        check(colors <= allowed, f"light pool has bright/wrong hue: {asset['id']}")
        check(len(colors - {black}) == 3, f"light pool does not have three light levels: {asset['id']}")
    emit = asset["emit"]
    if emit:
        emit_count += 1
        emit_path = ROOT / emit
        check(emit_path.exists(), f"missing emit: {emit}")
        if emit_path.exists():
            mask = image_array(emit_path)
            check(mask.shape == pixels.shape, f"emit size mismatch: {emit}")
            check(np.isin(mask[:, :, 3], (0, 255)).all(), f"emit alpha not binary: {emit}")
            on = mask[:, :, 3] == 255
            check(on.any(), f"empty emit: {emit}")
            check(np.all(pixels[:, :, 3][on] == 255), f"emit outside source: {emit}")
            check(np.array_equal(mask[:, :, :3][on], pixels[:, :, :3][on]), f"emit color differs from source: {emit}")
            check_8x(emit_path, mask)


def same_pixels(left: Path, right: Path) -> bool:
    return np.array_equal(image_array(left), image_array(right))


locked_h1 = [
    "exit_lift_closed_module", "exit_lift_standby_module", "exit_lift_open_module",
    "hall_elevator_closed_64x58", "hall_elevator_open", "exit_wayfinding_sign",
    "wall_mounted_extinguisher_14x28", "emergency_stop_plate_16x20",
    "desk_memo_sticker_16x14", "duty_mug_clip_12x10",
    "interaction_marker_cyan", "interaction_marker_yellow",
    "side_wall_top_sign_02", "side_wall_top_sign_03", "side_wall_top_sign_04",
]
for stem in locked_h1:
    for suffix in (".png", "_8x.png", "_emit.png", "_emit_8x.png"):
        old = V1 / (stem + suffix)
        if old.exists():
            new = ROOT / (stem + suffix)
            check(new.exists() and old.read_bytes() == new.read_bytes(), f"accepted H1 changed: {new.name}")

console_dir = ART / "batch1_v5"
for state in ("off", "on"):
    check(
        same_pixels(ROOT / f"accepted_dispatch_console_{state}_95x43.png", console_dir / f"console_{state}_v4.png"),
        f"accepted dispatch console changed: {state}",
    )
    station = image_array(ROOT / f"duty_station_empty_{state}.png")
    check(station.shape[:2] == (50, 48), f"duty desk wrong size: {state}")
    if state == "off":
        cyan = {(42, 138, 146), (95, 208, 216), (184, 244, 246)}
        check(not any(tuple(int(v) for v in rgb) in cyan for rgb in station[:, :, :3][station[:, :, 3] == 255]), "OFF duty desk contains cyan")

atlas = Image.open(ART / "batch2_v1" / "rhodes_logistics_atlas_v1.png").convert("RGBA")
for state, box in (("off", (156, 74, 227, 114)), ("on", (28, 74, 99, 114))):
    expected = np.asarray(atlas.crop(box))
    actual = image_array(ROOT / f"accepted_logistics_counter_{state}_71x40.png")
    check(np.array_equal(actual, expected), f"accepted counter crop changed: {state}")
check(same_pixels(ROOT / "accepted_generic_door_open_45x46.png", console_dir / "door_open_45x46_v5.png"), "accepted generic door changed")

header = image_array(ART / "batch_L0_logo_v1" / "rhodes_logo_FIELD_OPS_header_v1.png")
for state in ("closed", "standby", "open"):
    lift = image_array(ROOT / f"exit_lift_{state}_module.png")
    check(np.array_equal(lift[0:12, 16:80], header), f"accepted FIELD OPS header changed: {state}")

tarp = image_array(ART / "batch_L0_logo_v1" / "rhodes_logo_tarp_print_v1.png")
barrier = image_array(ROOT / "wing_construction_barrier_uncleared_128x56.png")
check(np.array_equal(barrier[9:49, 44:84], tarp), "accepted tarp print changed inside barrier")

for i in range(1, 5):
    arrow = image_array(ROOT / f"floor_arrow_icon_{i:02}.png")
    check(arrow.shape[:2] == (28, 40), f"arrow {i} wrong size")
check('"STORE"' in source, "B1-01 STORE label missing from source")
check(not (ROOT / "equipment_id_badge_RI-07_24x14.png").exists(), "stale clipped badge remains")
check("case '7'" in source, "RI-07 glyph 7 missing")

preview = image_array(ROOT / manifest["preview"]["file"])
check(preview.shape[:2] == (480, 960), "composite dimensions changed")
lap = image_array(console_dir / "lappland_frame0_64.png")
ys, xs = np.nonzero(lap[:, :, 3] > 0)
top = 440 - int(ys.max())
patch = preview[top : top + 64, 870 : 870 + 64]
check(np.array_equal(patch[lap[:, :, 3] > 0], lap[lap[:, :, 3] > 0]), "Lappland visible pixels resampled/altered")

for dependency in manifest["external_dependencies"]:
    path = ROOT / dependency["file"]
    check(hashlib.sha256(path.read_bytes()).hexdigest() == dependency["sha256"], f"locked dependency hash changed: {dependency['file']}")
    if dependency.get("emit_file"):
        ep = ROOT / dependency["emit_file"]
        check(hashlib.sha256(ep.read_bytes()).hexdigest() == dependency["emit_sha256"], f"locked lightbox emit hash changed: {dependency['emit_file']}")

lines = [
    "Independent H1 v2 pixel audit:",
    f"  Native assets: {asset_count}; emit masks: {emit_count}; RGB colors used: {len(used_colors)} including additive black.",
    f"  Accepted H1 assets fixed against v1: {len(locked_h1)} families and their available emit/8x exports.",
    f"  Result: {'PASS' if not errors else 'FAIL'} ({len(errors)} errors).",
]
lines.extend("  ERROR " + error for error in errors)
with (ROOT / "validation.txt").open("a", encoding="utf-8") as stream:
    stream.write("\n" + "\n".join(lines) + "\n")
print("\n".join(lines))
if errors:
    raise SystemExit(1)
