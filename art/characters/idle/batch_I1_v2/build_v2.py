"""Replace only Guard Amiya's NW and NE idle rows with painted back views."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


HERE = Path(__file__).resolve().parent
IDLE = HERE.parent
BASE = IDLE / "batch_I1_v1" / "amiya_guard_idle_source.png"
WALK = IDLE / "refs" / "amiya_guard_walk_source.png"
CELL = 256
ROW_NAMES = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
CHANGES = {
    3: ("NW", HERE / "source_paintings" / "amiya_guard_nw_painting.png", 122),
    5: ("NE", HERE / "source_paintings" / "amiya_guard_ne_painting.png", 125),
}


def bounds(mask: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(mask)
    if not len(xs):
        raise ValueError("Empty sprite")
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def keep_largest_component(rgba: np.ndarray) -> None:
    mask = rgba[:, :, 3] >= 128
    seen = np.zeros(mask.shape, dtype=bool)
    regions = []
    for y in range(mask.shape[0]):
        for x in range(mask.shape[1]):
            if not mask[y, x] or seen[y, x]:
                continue
            region = [(y, x)]
            seen[y, x] = True
            for cy, cx in region:
                for ny in range(max(0, cy - 1), min(mask.shape[0], cy + 2)):
                    for nx in range(max(0, cx - 1), min(mask.shape[1], cx + 2)):
                        if mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            region.append((ny, nx))
            regions.append(region)
    largest = max(regions, key=len)
    for region in regions:
        if region is largest:
            continue
        for y, x in region:
            rgba[y, x, 3] = 0


def stand_frame(painting: Path, target_height: int, center: int) -> Image.Image:
    source = np.asarray(Image.open(painting).convert("RGBA")).copy()
    source[:, :, 3] = np.where(source[:, :, 3] >= 128, 255, 0).astype(np.uint8)
    x0, y0, x1, y1 = bounds(source[:, :, 3] >= 128)
    crop = Image.fromarray(source[y0:y1 + 1, x0:x1 + 1], "RGBA")
    width = round(crop.width * target_height / crop.height)
    crop = crop.resize((width, target_height), Image.Resampling.NEAREST)
    pixels = np.asarray(crop).copy()
    keep_largest_component(pixels)
    x0, y0, x1, y1 = bounds(pixels[:, :, 3] >= 128)
    pixels = pixels[y0:y1 + 1, x0:x1 + 1]
    crop = Image.fromarray(pixels, "RGBA")
    xs = np.where(pixels[:, :, 3] >= 128)[1]
    x = round(center - float(np.median(xs)))
    y = 241 - crop.height + 1
    if x < 0 or x + crop.width > CELL or y < 0 or y + crop.height > CELL:
        raise ValueError(f"Painted sprite exceeds its 256 px cell: {(x, y, crop.size)}")
    frame = Image.new("RGBA", (CELL, CELL))
    frame.paste(crop, (x, y))
    return frame


def breath_frame(stand: Image.Image) -> tuple[Image.Image, int]:
    source = np.asarray(stand)
    out = np.zeros_like(source)
    top = bounds(source[:, :, 3] >= 128)[1]
    fixed_from, taper_from, pixels = 203, 156, 8
    for y in range(CELL):
        if y < top + 15:
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


def cell_array(sheet: Image.Image, row: int, column: int) -> np.ndarray:
    return np.asarray(sheet.crop((column * CELL, row * CELL, (column + 1) * CELL, (row + 1) * CELL)))


def preview(sheet: Image.Image, walk: Image.Image) -> None:
    small = Image.new("RGBA", (96, 256), (110, 113, 109, 255))
    for row in range(8):
        frames = [
            walk.crop((CELL, row * CELL, 2 * CELL, (row + 1) * CELL)),
            sheet.crop((0, row * CELL, CELL, (row + 1) * CELL)),
            sheet.crop((CELL, row * CELL, 2 * CELL, (row + 1) * CELL)),
        ]
        for column, frame in enumerate(frames):
            mini = np.asarray(frame.resize((32, 32), Image.Resampling.BOX)).copy()
            mini[:, :, 3] = np.where(mini[:, :, 3] >= 128, 255, 0)
            small.alpha_composite(Image.fromarray(mini, "RGBA"), (column * 32, row * 32))
    small.resize((576, 1536), Image.Resampling.NEAREST).convert("RGB").save(
        HERE / "amiya_guard_idle_v2_preview_32_6x.png"
    )


def main() -> None:
    base = Image.open(BASE).convert("RGBA")
    walk = Image.open(WALK).convert("RGBA")
    if base.size != (512, 2048) or walk.size != (1024, 2048):
        raise ValueError("Reference sheets have unexpected dimensions")
    sheet = base.copy()
    for row, (label, painting, center) in CHANGES.items():
        walk_frame = walk.crop((CELL, row * CELL, 2 * CELL, (row + 1) * CELL))
        _, wy0, _, wy1 = bounds(np.asarray(walk_frame.getchannel("A")) >= 128)
        stand = stand_frame(painting, wy1 - wy0 + 1, center)
        breath, _ = breath_frame(stand)
        sheet.paste(stand, (0, row * CELL))
        sheet.paste(breath, (CELL, row * CELL))

    report = ["Batch I1 v2 validation", "Source: batch_I1_v1/amiya_guard_idle_source.png", "Canvas: 512 x 2048 RGBA; 2 columns x 8 rows; 256 x 256 cells.", "Changed rows (one-based): 4 NW, 6 NE.", ""]
    retained = changed = border_pixels = 0
    for row in range(8):
        for column in range(2):
            old = cell_array(base, row, column)
            new = cell_array(sheet, row, column)
            same = np.array_equal(old, new)
            if row in CHANGES:
                assert not same, f"Expected changed cell {row},{column}"
                changed += 1
            else:
                assert same, f"Accepted cell changed: {row},{column}"
                retained += 1
            a = new[:, :, 3]
            border_pixels += sum(int(np.count_nonzero(edge)) for edge in (a[0], a[-1], a[:, 0], a[:, -1]))
    assert (retained, changed, border_pixels) == (12, 4, 0)
    report.append(f"Unchanged cells pixel-identical to v1: {retained}/12")
    report.append(f"Changed cells: {changed}/4 (NW and NE, stand and breath)")
    report.append(f"Pixels touching/crossing cell borders: {border_pixels}")
    report.append("")
    report.append("row | walk foot/height | stand foot/height | breath foot/height | median x | fixed from")
    for row, (label, _, target_center) in CHANGES.items():
        walk_frame = walk.crop((CELL, row * CELL, 2 * CELL, (row + 1) * CELL))
        _, wy0, _, wy1 = bounds(np.asarray(walk_frame.getchannel("A")) >= 128)
        stand = cell_array(sheet, row, 0)
        breath = cell_array(sheet, row, 1)
        _, sy0, _, sy1 = bounds(stand[:, :, 3] >= 128)
        _, by0, _, by1 = bounds(breath[:, :, 3] >= 128)
        mid = float(np.median(np.where(stand[:, :, 3] >= 128)[1]))
        assert sy1 == by1 == wy1 == 241
        assert abs(mid - target_center) <= 1
        assert abs((sy1 - sy0) - (wy1 - wy0)) <= 3
        assert abs((by1 - by0) - (wy1 - wy0)) <= 3
        assert np.array_equal(stand[203:], breath[203:])
        report.append(f"{label} | {wy1}/{wy1-wy0+1} | {sy1}/{sy1-sy0+1} | {by1}/{by1-by0+1} | {mid:.1f} | 203")
    report.append("NW/NE breath cells are pixel-identical to their stand cells from row 203 through 255.")
    sheet.save(HERE / "amiya_guard_idle_source.png")
    preview(sheet, walk)
    (HERE / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    manifest = {"sheets": [{
        "file": "amiya_guard_idle_source.png", "character": "Guard Amiya", "cols": 2,
        "rows": 8, "cell": [256, 256], "row_order": ROW_NAMES,
        "columns": ["stand", "breath"], "base": "../batch_I1_v1/amiya_guard_idle_source.png",
        "changed_rows": ["NW", "NE"], "painted_sources": [
            "source_paintings/amiya_guard_nw_painting.png",
            "source_paintings/amiya_guard_ne_painting.png",
        ],
    }]}
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
