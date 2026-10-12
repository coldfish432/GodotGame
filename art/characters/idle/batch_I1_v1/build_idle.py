"""Package the painted idle studies into aligned, deterministic game sheets."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


HERE = Path(__file__).resolve().parent
REFS = HERE.parent / "refs"
ROWS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
PAINTINGS = HERE / "painted_inputs"

SHEETS = [
    {
        "file": "lappland_idle_source.png",
        "character": "Lappland",
        "painting": PAINTINGS / "lappland_idle_painting.png",
        "walk": REFS / "lappland_walk_source.png",
        "cell": 222,
        "foot": [210, 209, 207, 214, 215, 213, 209, 210],
        "center": [114, 118, 124, 108, 113, 103, 101, 118],
        "breath": 7,
    },
    {
        "file": "amiya_guard_idle_source.png",
        "character": "Guard Amiya",
        "painting": PAINTINGS / "amiya_guard_idle_painting.png",
        "walk": REFS / "amiya_guard_walk_source.png",
        "cell": 256,
        "foot": [241] * 8,
        "center": [127, 134, 119, 122, 149, 125, 130, 112],
        "breath": 8,
    },
]


def box(alpha: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(alpha >= 128)
    if not len(xs):
        raise ValueError("Empty sprite")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def breath_frame(stand: Image.Image, foot: int, pixels: int) -> tuple[Image.Image, int]:
    source = np.asarray(stand)
    out = np.zeros_like(source)
    fixed_from = foot - 38
    taper_from = foot - 85
    top = box(source[:, :, 3])[1]
    for y in range(stand.height):
        if y < top + 15:
            # Ear tips descend slightly. Face and shoulders reach the full
            # one-texel breathing shift while the total height stays aligned.
            shift = 3
        elif y < top + 55:
            shift = round(3 + (pixels - 3) * (y - top - 15) / 40)
        elif y < taper_from:
            shift = pixels
        elif y >= fixed_from:
            shift = 0
        else:
            shift = round(pixels * (fixed_from - y) / (fixed_from - taper_from))
        sy = y - shift
        if sy >= 0:
            out[y] = source[sy]
    assert np.array_equal(out[fixed_from:], source[fixed_from:])
    return Image.fromarray(out, "RGBA"), fixed_from


def remove_specks(rgba: np.ndarray) -> None:
    """Retain the character's connected silhouette; drop row-edge ghosts."""
    mask = rgba[:, :, 3] >= 128
    seen = np.zeros(mask.shape, dtype=bool)
    height, width = mask.shape
    regions = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or seen[y, x]:
                continue
            region = [(y, x)]
            seen[y, x] = True
            for cy, cx in region:
                for ny in range(max(0, cy - 1), min(height, cy + 2)):
                    for nx in range(max(0, cx - 1), min(width, cx + 2)):
                        if mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            region.append((ny, nx))
            regions.append(region)
    largest = max(regions, key=len)
    for region in regions:
        if region is largest:
            continue
        for cy, cx in region:
            rgba[cy, cx, 3] = 0


def packed_stand(painting: Image.Image, row: int, cell: int, foot: int, center: int, height: int) -> Image.Image:
    # The painted studies are on a loose 887 x 1774 canvas. Each character's
    # first-column painting is extracted; no character geometry is drawn here.
    rgba = np.asarray(painting.crop((200, row * 222, 445, min((row + 1) * 222, painting.height))).convert("RGBA")).copy()
    rgba[:, :, 3] = np.where(rgba[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    remove_specks(rgba)
    bx0, by0, bx1, by1 = box(rgba[:, :, 3])
    source = Image.fromarray(rgba[by0:by1 + 1, bx0:bx1 + 1], "RGBA")
    factor = height / source.height
    width = round(source.width * factor)
    source = source.resize((width, height), Image.Resampling.NEAREST)
    arr = np.asarray(source)
    xs = np.where(arr[:, :, 3] >= 128)[1]
    body_mid = float(np.median(xs))
    x = round(center - body_mid)
    y = foot - height + 1
    if x < 0 or x + width > cell or y < 0 or y + height > cell:
        raise ValueError(f"row {row} overflows cell: {(x, y, width, height)}")
    canvas = Image.new("RGBA", (cell, cell))
    canvas.paste(source, (x, y))
    return canvas


def preview(spec: dict, sheet: Image.Image, walk: Image.Image) -> None:
    # Three 32px images per row, enlarged sixfold on flat mid-grey.
    small = Image.new("RGBA", (96, 256), (110, 113, 109, 255))
    cell = spec["cell"]
    for row in range(8):
        frames = [
            walk.crop((cell, row * cell, 2 * cell, (row + 1) * cell)),
            sheet.crop((0, row * cell, cell, (row + 1) * cell)),
            sheet.crop((cell, row * cell, 2 * cell, (row + 1) * cell)),
        ]
        for column, frame in enumerate(frames):
            mini = frame.resize((32, 32), Image.Resampling.BOX)
            pixels = np.asarray(mini).copy()
            pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 128, 255, 0)
            small.alpha_composite(Image.fromarray(pixels, "RGBA"), (32 * column, 32 * row))
    small.resize((576, 1536), Image.Resampling.NEAREST).convert("RGB").save(
        HERE / spec["file"].replace("_source.png", "_preview_32_6x.png")
    )


def main() -> None:
    notes = ["Batch I1 v1 idle validation", "Measurements use alpha >= 128 and cell-local pixel coordinates.", ""]
    manifest = {"sheets": []}
    for spec in SHEETS:
        painting = Image.open(spec["painting"]).convert("RGBA")
        walk = Image.open(spec["walk"]).convert("RGBA")
        cell = spec["cell"]
        if painting.size != (887, 1774) or walk.size != (4 * cell, 8 * cell):
            raise ValueError(f"Unexpected input size for {spec['character']}")
        sheet = Image.new("RGBA", (2 * cell, 8 * cell))
        notes.extend([spec["character"], f"canvas: {sheet.width} x {sheet.height}", "row | walk foot/height | stand foot/height | breath foot/height | knees fixed from | body center"])
        for row, label in enumerate(ROWS):
            walk_frame = walk.crop((cell, row * cell, 2 * cell, (row + 1) * cell))
            _, wy0, _, wy1 = box(np.asarray(walk_frame.getchannel("A")))
            height = wy1 - wy0 + 1
            stand = packed_stand(painting, row, cell, spec["foot"][row], spec["center"][row], height)
            breath, fixed_from = breath_frame(stand, spec["foot"][row], spec["breath"])
            for column, frame in enumerate((stand, breath)):
                sheet.paste(frame, (column * cell, row * cell))
            sx0, sy0, sx1, sy1 = box(np.asarray(stand.getchannel("A")))
            _, by0, _, by1 = box(np.asarray(breath.getchannel("A")))
            stand_xs = np.where(np.asarray(stand.getchannel("A")) >= 128)[1]
            measured_center = round(float(np.median(stand_xs)), 1)
            assert sy1 == by1 == spec["foot"][row]
            assert np.array_equal(np.asarray(stand)[fixed_from:], np.asarray(breath)[fixed_from:])
            notes.append(
                f"{label:2} | {wy1:3}/{height:3} | {sy1:3}/{sy1-sy0+1:3} | "
                f"{by1:3}/{by1-by0+1:3} | {fixed_from:3} | {measured_center}"
            )
        sheet.save(HERE / spec["file"])
        preview(spec, sheet, walk)
        alpha = np.asarray(sheet.getchannel("A"))
        border_pixels = 0
        for row in range(8):
            for column in range(2):
                frame = alpha[row * cell:(row + 1) * cell, column * cell:(column + 1) * cell]
                border_pixels += sum(int(np.count_nonzero(edge)) for edge in (
                    frame[0], frame[-1], frame[:, 0], frame[:, -1],
                ))
        assert border_pixels == 0
        notes.append(f"pixels touching/crossing cell borders: {border_pixels}")
        notes.append("breath versus stand: pixel-identical from stated knees-fixed row through cell bottom, all 8 rows")
        notes.append("")
        manifest["sheets"].append({
            "file": spec["file"], "character": spec["character"], "cols": 2, "rows": 8,
            "cell": [cell, cell], "row_order": ROWS, "columns": ["stand", "breath"],
        })
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (HERE / "validation.txt").write_text("\n".join(notes), encoding="utf-8")


if __name__ == "__main__":
    main()
