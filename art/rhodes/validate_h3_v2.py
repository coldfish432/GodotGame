"""Audit H3 v2 generated-source provenance, native exports and room previews."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from pixel_kit import COLORS

ART = Path(__file__).resolve().parent
ALLOWED = {tuple(bytes.fromhex(value[1:])) for value in COLORS.values()}
GROUPS = {name: {tuple(bytes.fromhex(COLORS[key][1:])) for key in keys}
          for name, keys in {"yellow": ("Y0", "Y1", "Y2"), "orange": ("O0", "O1", "O2"),
                             "cyan": ("T0", "T1", "T2", "T3"), "blue": ("B0", "B1", "B2"),
                             "red": ("R0",)}.items()}
LAP = np.asarray(Image.open(ART / "batch1_v5" / "lappland_frame0_64.png").convert("RGBA"))
LIGHT_WALL = np.asarray(Image.open(ART / "batch3_equipment_v3" / "wall_straight_60x46_light_v2.png").convert("RGBA"))


def array(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"))


def check(result: bool, message: str, errors: list[str]) -> None:
    if not result:
        errors.append(message)


def metrics(pixels: np.ndarray) -> tuple[float, float, float, float, int]:
    body = pixels[:, :, :3][pixels[:, :, 3] == 255]
    lum = float(np.mean(body @ np.array([0.2126, 0.7152, 0.0722]) / 255))
    families = [sum(tuple(pixel) in group for pixel in body) / len(body) for group in GROUPS.values()]
    nearblack = float(np.mean(np.all(body == np.array([11, 12, 13]), axis=1)))
    gray_names = ("S0", "S1", "S2", "S3", "G0", "G1", "G2", "W0", "W1", "W2")
    gray_colors = {tuple(bytes.fromhex(COLORS[name][1:])) for name in gray_names}
    gray_steps = len({tuple(pixel) for pixel in body} & gray_colors)
    return lum, sum(families), max(families), nearblack, gray_steps


def audit(room: str, units: tuple[int, int], floor_size: tuple[int, int],
          main: str, s_xy: tuple[int, int], expected_generated: int) -> None:
    root = ART / f"batch_H3_{room.lower()}_v2"
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    errors: list[str] = []
    detail: list[str] = []
    generated = [asset for asset in manifest["assets"] if asset["source"]]
    check(len(generated) == expected_generated, "generated item inventory", errors)
    check(len(manifest["stand_spots"]) == 2, "two stand spots", errors)
    check(len(manifest["life_details"]) >= 5, "five life details", errors)
    check(manifest["shell"]["size_units"] == list(units) and
          manifest["shell"]["floor_size_px"] == list(floor_size) and
          manifest["shell"]["wall_height_px"] == 46, "shell scale", errors)
    check((root / manifest["build_script"]).exists(), "local build script", errors)
    for asset in manifest["assets"]:
        path = root / asset["file"]
        check(path.exists(), f"missing asset: {asset['id']}", errors)
        if not path.exists():
            continue
        image = array(path)
        check(list(image.shape[1::-1]) == asset["size_px"], f"size: {asset['id']}", errors)
        check(bool(np.isin(image[:, :, 3], (0, 255)).all()), f"binary alpha: {asset['id']}", errors)
        colors = {tuple(pixel) for pixel in image[:, :, :3][image[:, :, 3] == 255]}
        check(colors <= ALLOWED, f"palette: {asset['id']}", errors)
        check(not any(tuple(bytes.fromhex(COLORS[key][1:])) in colors for key in ("E0", "E1")),
              f"exit-only green: {asset['id']}", errors)
        scale = array(root / (path.stem + "_8x.png"))
        check(np.array_equal(scale, np.repeat(np.repeat(image, 8, 0), 8, 1)),
              f"exact 8x: {asset['id']}", errors)
        if asset["source"]:
            source = asset["source"]
            sp = root / source["source"]
            check(sp.exists() and sp.parent.name == "sources", f"generated original in sources: {asset['id']}", errors)
            if sp.exists():
                check(hashlib.sha256(sp.read_bytes()).hexdigest() == source["source_sha256"],
                      f"source hash: {asset['id']}", errors)
                check(list(Image.open(sp).size) == source["source_size_px"], f"source dimensions: {asset['id']}", errors)
            check(isinstance(source["integer_reduction"], int) and source["integer_reduction"] >= 2,
                  f"integer reduction: {asset['id']}", errors)
            lum, accent, maximum, nearblack, steps = metrics(image)
            detail.append(f"  {asset['id']}: luminance {lum:.3f}; accents {accent*100:.1f}% (max family {maximum*100:.1f}%); near-black {nearblack*100:.1f}%; gray steps {steps}.")
            check(steps >= 4, f"insufficient grey tone steps: {asset['id']}", errors)
            check(nearblack <= 0.03001, f"near-black >3%: {asset['id']}", errors)
            if room == "ARMORY":
                check(0.50 <= lum <= 0.65, f"armory light-room value key: {asset['id']}", errors)
            if room == "MEDICAL" and "monitor" not in asset["id"]:
                check(0.60 <= lum <= 0.75, f"medical white-room value key: {asset['id']}", errors)
            # Signs, luminous screens and decorative printed graphics are functional accent exceptions.
            if not any(word in asset["id"] for word in ("sign", "counter", "workbench", "monitor", "recovery_bed", "poster", "lamp")):
                check(accent <= 0.10001, f"accent total >10%: {asset['id']}", errors)
                check(maximum <= 0.06001, f"accent family >6%: {asset['id']}", errors)
        if asset["emit"]:
            emit = array(root / asset["emit"])
            check(emit.shape == image.shape and bool((emit[:, :, 3] == 255).any()),
                  f"emit existence/content: {asset['id']}", errors)
            check(np.array_equal(emit[emit[:, :, 3] == 255], image[emit[:, :, 3] == 255]),
                  f"emit source alignment: {asset['id']}", errors)
            emit8 = array(root / asset["emit"].replace(".png", "_8x.png"))
            check(np.array_equal(emit8, np.repeat(np.repeat(emit, 8, 0), 8, 1)),
                  f"emit 8x: {asset['id']}", errors)
    for dep in manifest["external_dependencies"]:
        path = root / dep["file"]
        check(path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == dep["sha256"],
              f"locked dependency: {dep['file']}", errors)

    shell = manifest["shell"]
    wall, floor = array(root / shell["wall_tile"]), array(root / shell["floor_tile"])
    check(wall.shape == LIGHT_WALL.shape and np.array_equal(wall[:, :, 3], LIGHT_WALL[:, :, 3]),
          "locked wall geometry/alpha", errors)
    check(floor.shape == (120, 120, 4), "floor native 120x120", errors)
    if room == "MEDICAL":
        floor_limit = {tuple(bytes.fromhex(COLORS[key][1:])) for key in ("S1", "S2", "S3", "G0", "G1")}
        check({tuple(pixel) for pixel in floor[:, :, :3].reshape(-1, 3)} <= floor_limit,
              "medical floor brighter than #98a2a6", errors)
    if room == "STORE":
        check(metrics(wall)[0] > metrics(array(ART / "batch1_v5" / "wall_straight_60x46_v5.png"))[0],
              "store wall not brighter than hall", errors)
    main_image = array(root / f"{main}.png")
    s = array(ART / "batch_L0_logo_v1" / "rhodes_logo_S_gray_v1.png")
    sx, sy = s_xy
    check(np.array_equal(main_image[sy:sy+9, sx:sx+9][s[:, :, 3] == 255], s[s[:, :, 3] == 255]),
          "accepted S mark drift", errors)
    preview = array(root / manifest["preview"]["file"])
    x, y = manifest["preview"]["character_origin_px"]
    check(list(preview.shape[1::-1]) == [floor_size[0], floor_size[1] + 46], "review shell dimensions", errors)
    lap_h, lap_w = min(64, preview.shape[0] - y), min(64, preview.shape[1] - x)
    lap_mask = LAP[:lap_h, :lap_w, 3] == 255
    check(np.array_equal(preview[y:y+lap_h, x:x+lap_w][lap_mask], LAP[:lap_h, :lap_w][lap_mask])
          and not (LAP[lap_h:, :, 3] == 255).any() and not (LAP[:, lap_w:, 3] == 255).any(),
          "Lappland pixels changed or resampled", errors)
    check(np.array_equal(preview[20, 0], wall[20, 0]) and
          np.array_equal(preview[-1, -1], floor[(preview.shape[0]-47) % 120, (preview.shape[1]-1) % 120]),
          "composite not on own shell", errors)
    four = array(root / manifest["preview"]["review_4x"])
    check(np.array_equal(four, np.repeat(np.repeat(preview, 4, 0), 4, 1)), "4x review scaling", errors)
    report = [f"Independent H3 {room} v2 audit:",
              f"  Generated items {len(generated)}; assets {len(manifest['assets'])}; emit masks {sum(bool(a['emit']) for a in manifest['assets'])}; locked dependencies {len(manifest['external_dependencies'])}.",
              "  Checked source hashes, integer factors, palette, binary alpha, exact 8x, mask alignment, wall alpha, own-shell composite and Lappland 1:1.",
              *detail, f"  Result: {'PASS' if not errors else 'FAIL'} ({len(errors)} errors).",
              *(f"  ERROR {error}" for error in errors)]
    with (root / "validation.txt").open("a", encoding="utf-8") as output:
        output.write("\n" + "\n".join(report) + "\n")
    print(f"{room}: {report[-1]}")
    if errors:
        print("\n".join(errors))
        raise SystemExit(1)


if __name__ == "__main__":
    audit("STORE", (12, 9), (180, 115), "store_front_counter", (8, 25), 9)
    audit("ARMORY", (18, 12), (270, 152), "armory_equipment_workbench", (9, 34), 7)
    audit("MEDICAL", (18, 12), (270, 152), "medical_recovery_bed", (83, 45), 8)
