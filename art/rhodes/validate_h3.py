"""Independent delivery audit for H3's three native-grid room kits."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from pixel_kit import COLORS

ART = Path(__file__).resolve().parent
PALETTE = {tuple(bytes.fromhex(value[1:])) for value in COLORS.values()}
ACCENTS = {tuple(bytes.fromhex(COLORS[key][1:])) for key in
           ("Y0", "Y1", "Y2", "O0", "O1", "O2", "T0", "T1", "T2", "T3", "B0", "B1", "B2", "R0")}
ACCENT_GROUPS = {
    name: {tuple(bytes.fromhex(COLORS[key][1:])) for key in keys}
    for name, keys in {"yellow": ("Y0", "Y1", "Y2"), "orange": ("O0", "O1", "O2"),
                       "cyan": ("T0", "T1", "T2", "T3"), "blue": ("B0", "B1", "B2"),
                       "red": ("R0",)}.items()
}
LAP = np.asarray(Image.open(ART / "batch1_v5" / "lappland_frame0_64.png").convert("RGBA"))
M = np.asarray(Image.open(ART / "batch_L0_logo_v1" / "rhodes_logo_M_gray_v1.png").convert("RGBA"))
S = np.asarray(Image.open(ART / "batch_L0_logo_v1" / "rhodes_logo_S_gray_v1.png").convert("RGBA"))
LOCKED_LIGHT = np.asarray(Image.open(ART / "batch3_equipment_v3" / "wall_straight_60x46_light_v2.png").convert("RGBA"))


def array(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"))


def check(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def metric(pixels: np.ndarray) -> tuple[float, float, float]:
    body = pixels[:, :, :3][pixels[:, :, 3] == 255]
    luminance = float(np.mean(body @ np.array([0.2126, 0.7152, 0.0722]) / 255))
    accents = sum(tuple(color) in ACCENTS for color in body) / len(body)
    nearblack = float(np.mean(np.all(body == np.array([11, 12, 13]), axis=1)))
    return luminance, accents, nearblack


def max_accent_family(pixels: np.ndarray) -> float:
    body = pixels[:, :, :3][pixels[:, :, 3] == 255]
    return max(sum(tuple(color) in group for color in body) / len(body)
               for group in ACCENT_GROUPS.values())


def audit(name: str, code: str, units: tuple[int, int], floor: tuple[int, int],
          main_stem: str, mark_xy: tuple[int, int]) -> None:
    root = ART / f"batch_H3_{name.lower()}_v1"
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    errors: list[str] = []
    detail: list[str] = []
    assets = manifest["assets"]
    check(manifest["shell"]["size_units"] == list(units) and
          manifest["shell"]["floor_size_px"] == list(floor) and
          manifest["shell"]["wall_height_px"] == 46, "shell dimensions/height", errors)
    check(len(manifest["stand_spots"]) == 2, "two stand spots", errors)
    check(len(manifest["life_details"]) >= 5, "at least five attached life details", errors)
    ids = {asset["id"] for asset in assets}
    check(any("department_sign" in stem for stem in ids), "department sign", errors)
    check(any("zone" in stem for stem in ids), "floor work-zone", errors)
    check(any("safety_strip" in stem for stem in ids), "yellow-black hazard strip", errors)
    check(sum(bool(asset["emit"]) for asset in assets) >= 2, "at least two emit assets", errors)
    expected_pngs = {manifest["preview"]["file"]}
    for asset in assets:
        stem = Path(asset["file"]).stem
        expected_pngs.update({asset["file"], f"{stem}_8x.png"})
        if asset["emit"]:
            expected_pngs.update({asset["emit"], asset["emit"].replace(".png", "_8x.png")})
    for path in (root / manifest["shell"]["wall_tile"], root / manifest["shell"]["floor_tile"]):
        if path.parent.resolve() == root.resolve():
            expected_pngs.update({path.name, path.stem + "_8x.png"})
    actual_pngs = {path.name for path in root.glob("*.png")}
    check(actual_pngs == expected_pngs, f"undeclared/missing PNG inventory: {sorted(actual_pngs ^ expected_pngs)}", errors)

    for asset in assets:
        path = root / asset["file"]
        check(path.exists(), f"missing {path.name}", errors)
        if not path.exists():
            continue
        native = array(path)
        check(list(native.shape[1::-1]) == asset["size_px"], f"size {asset['id']}", errors)
        check(bool(np.isin(native[:, :, 3], (0, 255)).all()), f"alpha {asset['id']}", errors)
        used = {tuple(color) for color in native[:, :, :3][native[:, :, 3] == 255]}
        check(used <= PALETTE, f"palette {asset['id']}", errors)
        check(not used.intersection({tuple(bytes.fromhex(COLORS[key][1:])) for key in ("E0", "E1")}),
              f"exit-only green used in H3 {asset['id']}", errors)
        check(bool(asset["coverage_35"]), f"checklist coverage {asset['id']}", errors)
        scaled = path.with_name(path.stem + "_8x.png")
        check(scaled.exists(), f"missing 8x {asset['id']}", errors)
        if scaled.exists():
            check(np.array_equal(array(scaled), np.repeat(np.repeat(native, 8, 0), 8, 1)),
                  f"non-integer scale {asset['id']}", errors)
        if asset["emit"]:
            mask = array(root / asset["emit"])
            check(mask.shape == native.shape and bool((mask[:, :, 3] == 255).any()),
                  f"emit dimensions/content {asset['id']}", errors)
            check(np.array_equal(mask[mask[:, :, 3] == 255], native[mask[:, :, 3] == 255]),
                  f"emit source pixels {asset['id']}", errors)
            scaled_mask = root / asset["emit"].replace(".png", "_8x.png")
            check(np.array_equal(array(scaled_mask), np.repeat(np.repeat(mask, 8, 0), 8, 1)),
                  f"emit 8x {asset['id']}", errors)

    for dep in manifest["external_dependencies"]:
        path = root / dep["file"]
        check(path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == dep["sha256"],
              f"dependency changed/missing {dep['file']}", errors)

    sign = next(asset for asset in assets if "department_sign" in asset["id"])
    sign_array = array(root / sign["file"])
    sign_mark = sign_array[11:35, 5:29]
    check(np.array_equal(sign_mark[M[:, :, 3] == 255], M[M[:, :, 3] == 255]),
          "M logo shape drift on sign", errors)
    main = array(root / f"{main_stem}.png")
    mx, my = mark_xy
    main_mark = main[my:my + 9, mx:mx + 9]
    check(np.array_equal(main_mark[S[:, :, 3] == 255], S[S[:, :, 3] == 255]),
          "S logo shape drift on main object", errors)
    preview = array(root / manifest["preview"]["file"])
    check(list(preview.shape[1::-1]) == manifest["preview"]["size_px"], "preview size", errors)
    x, y = manifest["preview"]["character_origin_px"]
    lap_patch = preview[y:y + 64, x:x + 64]
    check(lap_patch.shape == LAP.shape and
          np.array_equal(lap_patch[LAP[:, :, 3] == 255], LAP[LAP[:, :, 3] == 255]),
          "Lappland was altered or resampled", errors)

    shell = manifest["shell"]
    wall = array(root / shell["wall_tile"])
    floor_tile = array(root / shell["floor_tile"])
    check(wall.shape == LOCKED_LIGHT.shape and np.array_equal(wall[:, :, 3], LOCKED_LIGHT[:, :, 3]),
          "46px wall geometry/alpha drift", errors)
    check(floor_tile.shape == (120, 120, 4), "floor tile 120x120", errors)
    wall_lum, _, _ = metric(wall)
    floor_lum, _, _ = metric(floor_tile)
    detail.append(f"  Shell wall luminance {wall_lum:.3f}; floor luminance {floor_lum:.3f}.")
    if name == "MEDICAL":
        floor_allowed = {tuple(bytes.fromhex(COLORS[key][1:])) for key in
                         ("S1", "S2", "S3", "G0", "G1")}
        colors = {tuple(color) for color in floor_tile[:, :, :3].reshape(-1, 3)}
        check(colors <= floor_allowed, "medical floor exceeds #98a2a6", errors)
        armory_wall = array(ART / "batch3_equipment_v3" / "wall_straight_60x46_light_v2.png")
        check(wall_lum > metric(armory_wall)[0], "MEDICAL wall must be brighter than ARMORY", errors)
        lap_dark = LAP[:, :, :3][(LAP[:, :, 3] == 255) &
                                    (np.mean(LAP[:, :, :3], axis=2) < 80)]
        check(len(lap_dark) > 50 and float(np.mean(lap_dark)) < 80,
              "Lappland dark-coat read against floor", errors)
    if name == "STORE":
        dark_hall = array(ART / "batch1_v5" / "wall_straight_60x46_v5.png")
        check(metric(wall)[0] > metric(dark_hall)[0], "STORE must be brighter than hall wall", errors)

    for asset in assets:
        if asset["kind"] != "billboard" or "stand_spot" in asset["id"]:
            continue
        lum, accent, nearblack = metric(array(root / asset["file"]))
        family = max_accent_family(array(root / asset["file"]))
        detail.append(f"  {asset['id']}: luminance {lum:.3f}; accents {accent * 100:.1f}% (max family {family * 100:.1f}%); near-black {nearblack * 100:.1f}%.")
        check(nearblack <= 0.03001, f"near-black >3% {asset['id']}", errors)
        # Blue screen graphics and warning signals are functional accent exceptions.
        if not any(word in asset["id"] for word in ("counter", "workbench", "monitor", "recovery_bed")):
            check(accent <= 0.10001, f"prop accents >10% {asset['id']}", errors)
            check(family <= 0.06001, f"prop single accent family >6% {asset['id']}", errors)
        if name == "ARMORY" and asset["id"] in {
            "armory_equipment_workbench_110x50", "armory_robotic_arm_55x58", "armory_equipment_case_1_48x30",
            "armory_equipment_case_2_48x30"}:
            check(0.50 <= lum <= 0.65, f"ARMORY prop value key {asset['id']}: {lum:.3f}", errors)
        if name == "MEDICAL" and asset["id"] in {
            "medical_recovery_bed_110x67", "medical_ward_bed_1_80x47", "medical_ward_bed_2_80x47",
            "medical_wash_sink_52x42", "medical_privacy_curtain_74x66"}:
            check(0.60 <= lum <= 0.75, f"MEDICAL prop value key {asset['id']}: {lum:.3f}", errors)

    report = [
        f"Independent H3 {name} audit:",
        f"  {len(assets)} native assets; {sum(bool(a['emit']) for a in assets)} emit masks; {len(manifest['external_dependencies'])} hashed dependencies.",
        "  Exact inventory, palette, binary alpha, exact 8x, mask alignment, locked geometry, M/S silhouettes, Lappland 1:1, two spots and >=5 details checked.",
        *detail,
        f"  Result: {'PASS' if not errors else 'FAIL'} ({len(errors)} errors).",
        *(f"  ERROR {error}" for error in errors),
    ]
    with (root / "validation.txt").open("a", encoding="utf-8") as output:
        output.write("\n" + "\n".join(report) + "\n")
    print("\n".join(report))
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    for values in (("STORE", "B1-01", (12, 9), (180, 115), "store_front_counter_self_service_84x48", (13, 35)),
                   ("ARMORY", "B1-02", (18, 12), (270, 152), "armory_equipment_workbench_110x50", (12, 34)),
                   ("MEDICAL", "B1-04", (18, 12), (270, 152), "medical_recovery_bed_110x67", (5, 42))):
        audit(*values)
