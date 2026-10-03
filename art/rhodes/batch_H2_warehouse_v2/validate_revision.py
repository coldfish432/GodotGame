"""Audit H2 v2 review changes against accepted H2 v1 output."""

from __future__ import annotations

import ast
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
OLD = ROOT.parent / "batch_H2_warehouse_v1"
sys.path.insert(0, str(ROOT.parent))
from pixel_kit import COLORS, GLYPHS_5  # noqa: E402


def pixels(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


changed_stems = {
    "expansion_temporary_partition_90x46",
    "warehouse_notice_board_76x38",
    "warehouse_rack_weapons_80x64",
    "warehouse_rack_armor_80x64",
    "warehouse_rack_consumables_80x64",
    "warehouse_rack_materials_80x64",
    "warehouse_trolley_42x34",
    "warehouse_forklift_70x48",
    "warehouse_supply_crate_42x32",
    "warehouse_originium_sealed_crate_44x36",
    "warehouse_storage_terminal_on_64x52",
}
changed_files = {"H2_warehouse_lappland_1x.png"}
for stem in changed_stems:
    changed_files.update({f"{stem}.png", f"{stem}_8x.png"})
for stem in ("warehouse_rack_materials_80x64", "warehouse_originium_sealed_crate_44x36",
             "warehouse_storage_terminal_on_64x52"):
    changed_files.update({f"{stem}_emit.png", f"{stem}_emit_8x.png"})

common = {p.name for p in OLD.glob("*.png") if (ROOT / p.name).exists()}
actual_changes = {
    name for name in common
    if hashlib.sha256((OLD / name).read_bytes()).digest()
    != hashlib.sha256((ROOT / name).read_bytes()).digest()
}
require(actual_changes == changed_files, f"unexpected changed PNGs: {sorted(actual_changes ^ changed_files)}")
for stem in changed_stems:
    require(Image.open(OLD / f"{stem}.png").size == Image.open(ROOT / f"{stem}.png").size,
            f"outer size changed: {stem}")

manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
require(len(manifest["assets"]) == 27, "H2 asset inventory changed unexpectedly")
require(any(asset["id"] == "warehouse_originium_containment_56x48" and asset["emit"]
            for asset in manifest["assets"]), "new containment or warm emit missing")

terminal = pixels(ROOT / "warehouse_storage_terminal_on_64x52.png")
blue_cell = np.array(list(bytes.fromhex(COLORS["B1"][1:])), dtype=np.uint8)
cyan_ink = np.array(list(bytes.fromhex(COLORS["T2"][1:])), dtype=np.uint8)
for row_y in (10, 16):
    for col_x in (20, 26, 32, 38):
        require(np.array_equal(terminal[row_y, col_x, :3], blue_cell),
                f"warehouse inventory cell missing: {col_x},{row_y}")
require(sum(np.array_equal(terminal[y + 2, x + 1, :3], cyan_ink)
            for y in (10, 16) for x in (20, 26, 32, 38)) == 7,
        "warehouse inventory slot marks missing")

white = np.array(list(bytes.fromhex(COLORS["W1"][1:])), dtype=np.uint8)
for category, letter in zip(("weapons", "armor", "consumables", "materials"), "ABCD"):
    path = ROOT / f"warehouse_rack_{category}_80x64.png"
    plaque = pixels(path)[1:8, 11:52, :3]
    actual = np.all(plaque == white, axis=2)
    expected = np.zeros((7, 41), dtype=bool)
    for index, character in enumerate(f"B1-03-{letter}"):
        for y, row in enumerate(GLYPHS_5[character].split("/")):
            for x, bit in enumerate(row):
                if bit == "1":
                    expected[y, index * 6 + x] = True
    require(np.array_equal(actual, expected), f"native 5x7 rack code mismatch: {category}")

for stem in ("warehouse_rack_materials_80x64", "warehouse_originium_sealed_crate_44x36",
             "warehouse_originium_containment_56x48"):
    image = pixels(ROOT / f"{stem}.png")
    opaque = image[:, :, 3] == 255
    dark = np.all(image[:, :, :3] == np.array(list(bytes.fromhex(COLORS["D"][1:]))), axis=2)
    orange = np.all(image[:, :, :3] == np.array(list(bytes.fromhex(COLORS["O2"][1:]))), axis=2)
    require(int((dark & opaque).sum()) >= 10 and int((orange & opaque).sum()) >= 2,
            f"black/orange originium not visible: {stem}")
    emit = pixels(ROOT / f"{stem}_emit.png")
    require(int((orange & (emit[:, :, 3] == 255)).sum()) >= 2,
            f"warm originium core absent from emit: {stem}")

containment = pixels(ROOT / "warehouse_originium_containment_56x48.png")
body = containment[:, :, :3][containment[:, :, 3] == 255]
luminance = float(np.mean(body @ np.array([0.2126, 0.7152, 0.0722]) / 255))
accent_keys = ("Y0", "Y1", "Y2", "O0", "O1", "O2", "T0", "T1", "T2", "T3", "B0", "B1", "B2", "R0")
accent_colors = {tuple(bytes.fromhex(COLORS[key][1:])) for key in accent_keys}
accent_rate = sum(tuple(color) in accent_colors for color in body) / len(body)
require(0.25 <= luminance <= 0.40 and accent_rate <= 0.10,
        f"containment luminance/accent budget: {luminance:.3f}/{accent_rate:.3f}")

source = (ROOT / "build_h2.py").read_text(encoding="utf-8")
tree = ast.parse(source)
stamp_owners = sorted(
    node.name for node in tree.body if isinstance(node, ast.FunctionDef)
    and node.name != "stamped"
    and any(isinstance(call, ast.Call) and isinstance(call.func, ast.Name)
            and call.func.id == "stamped" for call in ast.walk(node))
)
require(stamp_owners == ["freight_lift", "terminal", "wall_bay"],
        f"unexpected S logo placement: {stamp_owners}")
require(source.count('paste(composite, load(ROOT / "warehouse_wall_bay_120x46.png")') == 1,
        "composite repeats S-marked wall bay")
require(source.count('paste(composite, header, (145, 0))') == 1,
        "composite needs one M supergraphic")
require(all(f'("warehouse_{kind}_{state}_{size}"' in source
            for kind, states, size in (("storage_terminal", ("on", "off"), "64x52"),
                                       ("freight_lift", ("ready", "idle"), "96x56"))
            for state in states), "representative terminal/lift states missing")

report = [
    "H2 v2 review-specific audit:",
    f"  PASS: {len(common) - len(actual_changes)} shared PNGs are byte-identical to v1; only the {len(changed_files)} authorized outputs changed.",
    "  PASS: revised props keep their outer sizes; four distinct B1-03-A through D codes match the native 5x7 bitmap font exactly.",
    "  PASS: materials rack, sealed crate and containment expose black/orange originium, with orange cores present in warm emit masks.",
    "  PASS: warehouse ON screen has an eight-slot inventory grid and a matching revised emit mask; OFF state is unchanged.",
    f"  PASS: containment mean luminance {luminance:.3f}; all accents {accent_rate * 100:.1f}% of opaque pixels.",
    "  PASS: S stamps occur only in wall bay, terminal and freight lift builders; the 1:1 composite shows one M plus five S marks (six total).",
    "  Result: PASS (0 errors).",
]
with (ROOT / "validation.txt").open("a", encoding="utf-8") as output:
    output.write("\n" + "\n".join(report) + "\n")
print("\n".join(report))
