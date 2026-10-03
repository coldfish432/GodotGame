"""Bake the imagegen poses at runtime scale; never independently fit each pose.

Requires Pillow + numpy. Splits actual transparent gutters, uses a single scale
per enemy, premultiplied-alpha BOX sampling, a shared foot line and hip centre.
Preserves original generated artwork. Emits a measurable alignment manifest.
"""
from pathlib import Path
from collections import deque
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent / "field"
CELL, FOOT, CENTRE = 64, 51, 28
IDS = ["thug", "crossbow", "slug", "brawler", "crossbow_leader", "ice_warrior", "ice_hunter"]

def bands(mask):
    indices = np.flatnonzero(mask)
    return np.split(indices, np.flatnonzero(np.diff(indices) > 1) + 1)

def main_component(pixels):
    mask = pixels[:, :, 3] >= 128
    seen = np.zeros(mask.shape, bool)
    largest = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        pending = deque([(y, x)])
        seen[y, x] = True
        part = []
        while pending:
            yy, xx = pending.popleft()
            part.append((yy, xx))
            for dy in [-1, 0, 1]:
                for dx in [-1, 0, 1]:
                    ny, nx = yy + dy, xx + dx
                    if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        pending.append((ny, nx))
        if len(part) > len(largest):
            largest = part
    result = np.zeros_like(pixels)
    yy, xx = np.array(largest).T
    result[yy, xx] = pixels[yy, xx]
    return result

def main():
    source = Image.open(ROOT / "enemy_attacks_source.png").convert("RGBA")
    pixels = np.array(source)
    rows = [b for b in bands((pixels[:, :, 3] >= 128).any(1)) if len(b) > 50]
    assert len(rows) == 7
    atlas = Image.new("RGBA", (CELL * 5, CELL * 7))
    manifest = {"cell": CELL, "foot": FOOT, "centre": CENTRE, "filter": "premultiplied alpha BOX", "enemies": {}}
    for row, ys in enumerate(rows):
        band = pixels[ys[0]:ys[-1] + 1]
        mask = band[:, :, 3] >= 128
        columns = [b for b in bands(mask.any(0)) if len(b) > 30]
        if row == 6:
            # The hunter's long barrels overlap the next cell's cloak.
            # Authored gutter cuts preserve each body and its own rifle.
            edges = [0, 214, 440, 663, 883, source.width]
            columns = [np.arange(a, b) for a, b in zip(edges, edges[1:])]
        # A rifle can touch the neighbouring cell. Split at the narrowest
        # alpha column in the authored gutter rather than a uniform grid.
        while len(columns) < 5:
            widest = max(range(len(columns)), key=lambda i: len(columns[i]))
            xs = columns[widest]
            mid = (xs[0] + xs[-1]) // 2
            cut = min(range(mid - 32, mid + 33), key=lambda x: mask[:, x].sum())
            columns[widest:widest + 1] = [xs[xs < cut], xs[xs >= cut]]
        assert len(columns) == 5, (row, len(columns))
        first = mask[:, columns[0][0]:columns[0][-1] + 1]
        y_idle = np.flatnonzero(first.any(1))
        scale = (19 if row == 2 else 27) / len(y_idle)
        frames = []
        for col, xs in enumerate(columns):
            part = band[:, xs[0]:xs[-1] + 1]
            if row == 6: part = main_component(part)
            occupied = part[:, :, 3] >= 128
            yy, xx = np.nonzero(occupied)
            # Feet/hips align bodies; weapon extension must not move the body.
            lower = occupied[max(0, yy.max() - round(35 if row != 2 else 60)):yy.max() + 1]
            hip = float(np.median(np.nonzero(lower)[1]))
            if row == 2: hip = float(np.median(xx))
            size = round(CELL / scale)
            actual = CELL / size
            canvas = Image.new("RGBA", (size, size))
            canvas.paste(Image.fromarray(part), (round(CENTRE / actual - hip), round(FOOT / actual - (yy.max() + 1))))
            cell = canvas.convert("RGBa").resize((CELL, CELL), Image.Resampling.BOX).convert("RGBA")
            cell.putalpha(cell.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
            bounds = cell.getbbox()
            assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < CELL and bounds[3] < CELL, (row, col, bounds)
            atlas.paste(cell, (CELL * col, CELL * row))
            frames.append({"bounds": list(bounds), "foot": bounds[3], "height": bounds[3] - bounds[1]})
        manifest["enemies"][IDS[row]] = {"row": row, "scale": scale, "frames": frames}
    atlas.save(ROOT / "enemy_attacks_64.png")
    (ROOT / "enemy_attacks_alignment.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    main()
