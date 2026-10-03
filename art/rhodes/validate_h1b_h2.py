"""Validate native pixel exports, locked inputs, glyphs and H2 prop color budgets."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from pixel_kit import COLORS, GLYPH_ORDER


ART = Path(__file__).resolve().parent
ALLOWED = {tuple(bytes.fromhex(value[1:])) for value in COLORS.values()}
ACCENTS = {
    "yellow": {tuple(bytes.fromhex(COLORS[key][1:])) for key in ("Y0", "Y1", "Y2")},
    "orange": {tuple(bytes.fromhex(COLORS[key][1:])) for key in ("O0", "O1", "O2")},
    "cyan": {tuple(bytes.fromhex(COLORS[key][1:])) for key in ("T0", "T1", "T2", "T3")},
    "blue": {tuple(bytes.fromhex(COLORS[key][1:])) for key in ("B0", "B1", "B2")},
    "red": {tuple(bytes.fromhex(COLORS["R0"][1:]))},
}


def array(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"))


def audit(batch: str) -> None:
    root = ART / batch
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    errors: list[str] = []
    emit_count = 0
    used: set[tuple[int, int, int]] = set()

    def check(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    def exact_8x(path: Path, native: np.ndarray) -> None:
        scaled_path = path.with_name(path.stem + "_8x.png")
        check(scaled_path.exists(), f"missing 8x: {scaled_path.name}")
        if scaled_path.exists():
            expected = np.repeat(np.repeat(native, 8, axis=0), 8, axis=1)
            check(np.array_equal(array(scaled_path), expected), f"non-integer export: {scaled_path.name}")

    for asset in manifest["assets"]:
        path = root / asset["file"]
        check(path.exists(), f"missing asset: {asset['file']}")
        if not path.exists():
            continue
        native = array(path)
        height, width = native.shape[:2]
        check([width, height] == asset["size_px"], f"size: {asset['id']}")
        check(np.isin(native[:, :, 3], (0, 255)).all(), f"nonbinary alpha: {asset['id']}")
        colors = {tuple(map(int, row)) for row in native[:, :, :3][native[:, :, 3] == 255]}
        used |= colors
        check(colors <= ALLOWED, f"outside 31-color palette: {asset['id']}")
        check(bool(asset["coverage_35"]), f"no checklist coverage: {asset['id']}")
        exact_8x(path, native)
        if asset["emit"]:
            emit_count += 1
            ep = root / asset["emit"]
            check(ep.exists(), f"missing emit: {ep.name}")
            if ep.exists():
                emit = array(ep)
                check(emit.shape == native.shape, f"emit size: {ep.name}")
                check(np.isin(emit[:, :, 3], (0, 255)).all(), f"emit alpha: {ep.name}")
                mask = emit[:, :, 3] == 255
                check(mask.any(), f"empty emit: {ep.name}")
                check(np.array_equal(emit[mask], native[mask]), f"emit source mismatch: {ep.name}")
                exact_8x(ep, emit)

    for dependency in manifest["external_dependencies"]:
        target = root / dependency["file"]
        check(target.exists(), f"missing locked dependency: {dependency['file']}")
        if target.exists():
            check(hashlib.sha256(target.read_bytes()).hexdigest() == dependency["sha256"], f"locked hash changed: {dependency['file']}")
            check(list(Image.open(target).size) == dependency["size_px"], f"locked size changed: {dependency['file']}")

    preview = array(root / manifest["preview"]["file"])
    check(list(preview.shape[1::-1]) == manifest["preview"]["size_px"], "preview size")
    lap = array(ART / "batch1_v5" / "lappland_frame0_64.png")
    ox, oy = manifest["preview"]["character_origin_px"]
    patch = preview[oy : oy + 64, ox : ox + 64]
    check(patch.shape == lap.shape and np.array_equal(patch[lap[:, :, 3] > 0], lap[lap[:, :, 3] > 0]), "Lappland visible pixels changed or resampled")

    detail: list[str] = []
    if batch.startswith("batch_H1b"):
        lookup = json.loads((root / manifest["glyph_lookup"]).read_text(encoding="utf-8"))
        check(lookup["characters"] == GLYPH_ORDER and len(GLYPH_ORDER) == 41, "glyph inventory")
        for name, width, height in (("5x7", 5, 7), ("3x5", 3, 5)):
            font = lookup["fonts"][name]
            check(set(font["glyphs"]) == set(GLYPH_ORDER), f"glyph set {name}")
            for char, info in font["glyphs"].items():
                check(len(info["rows"]) == height and all(len(row) == width and set(row) <= {"0", "1"} for row in info["rows"]), f"glyph geometry {name} {char}")
        plates = [a for a in manifest["assets"] if a["id"].startswith("small_number_plate_")]
        arrows = [a for a in manifest["assets"] if a["id"].startswith("floor_arrow_")]
        check(len(plates) == 12 and len(arrows) == 8, "H1b plate/arrow count")
        for index, name in enumerate(("store", "armory", "warehouse", "medical"), 1):
            source = array(ART / "batch_H1_bridge_hall_v2" / f"floor_arrow_icon_{index:02}.png")
            upright = np.all(source[14:26, 14:27, :3] == np.array([21, 24, 26]), axis=2)
            for direction in ("left", "right"):
                arrow = array(root / f"floor_arrow_{name}_{direction}_40x28.png")
                check(arrow.shape[:2] == (28, 40), f"arrow size {name} {direction}")
                region = arrow[8:20, 14:27, :3]
                check(np.all(region[upright] == np.array([21, 24, 26])), f"icon not upright {name} {direction}")
        detail.append("PASS: 41 glyphs in each sheet with complete lookup; 12 B1 plates; 8 arrows reuse the accepted upright icon masks.")

    if batch.startswith("batch_H2"):
        required = {f"warehouse_rack_{c}_80x64" for c in ("weapons", "armor", "consumables", "materials")}
        required |= {f"warehouse_zone_{c}_90x44" for c in ("weapons", "armor", "consumables", "materials")}
        check(required <= {a["id"] for a in manifest["assets"]}, "four category racks and zones")
        check(manifest["shell"]["floor_size_px"] == [360, 229] and manifest["shell"]["wall_height_px"] == 46, "warehouse shell scale")
        for state in ("off", "on"):
            terminal = array(root / f"warehouse_storage_terminal_{state}_64x52.png")
            check(terminal.shape[:2] == (52, 64), f"terminal size {state}")
            if state == "off":
                check(not np.isin(terminal[:, :, :3].reshape(-1, 3), np.array([[42, 138, 146], [95, 208, 216], [184, 244, 246]])).all(axis=1).any(), "OFF terminal contains cyan")
        measured: list[str] = []
        for asset in manifest["assets"]:
            if not asset["id"].startswith(("warehouse_rack_", "warehouse_trolley", "warehouse_forklift", "warehouse_pallet", "warehouse_supply_crate", "warehouse_originium_sealed_crate")):
                continue
            native = array(root / asset["file"])
            pixels = native[:, :, :3][native[:, :, 3] == 255]
            luminance = float(np.mean(pixels @ np.array([0.2126, 0.7152, 0.0722]) / 255))
            accent_rates = {name: float(np.mean(np.any(np.all(pixels[:, None, :] == np.array(list(group))[None, :, :], axis=2), axis=1))) for name, group in ACCENTS.items()}
            total = sum(accent_rates.values())
            check(0.25 <= luminance <= 0.40, f"warehouse prop luminance: {asset['id']} {luminance:.3f}")
            check(total <= 0.10001 and max(accent_rates.values()) <= 0.06001, f"warehouse prop accent budget: {asset['id']} {total:.3f}")
            measured.append(f"  {asset['id']}: mean luminance {luminance:.3f}; accent total {total*100:.1f}% (max family {max(accent_rates.values())*100:.1f}%).")
        detail.append("PASS: 24x18-unit shell metadata, four rack/zone pairs, OFF terminal cyan-free, and prop luminance/accent budgets.")
        detail.extend(measured)

    report = [
        "Independent native-grid audit:",
        f"  Assets {len(manifest['assets'])}; emit masks {emit_count}; palette colors used {len(used)}/31; locked dependencies {len(manifest['external_dependencies'])}.",
        "  Exact 8x nearest-neighbor exports, binary alpha, palette membership, emit/source alignment, dependency hashes and visible Lappland pixels checked.",
        *detail,
        f"  Result: {'PASS' if not errors else 'FAIL'} ({len(errors)} errors).",
        *(f"  ERROR {error}" for error in errors),
    ]
    with (root / "validation.txt").open("a", encoding="utf-8") as handle:
        handle.write("\n" + "\n".join(report) + "\n")
    print(f"{batch}: {report[-1]}")
    if errors:
        print("\n".join(errors[:20]))
        raise SystemExit(1)


if __name__ == "__main__":
    import sys

    for batch in sys.argv[1:] or ("batch_H1b_wayfinding_v1", "batch_H2_warehouse_v1"):
        audit(batch)
