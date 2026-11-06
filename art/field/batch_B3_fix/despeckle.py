"""B3 fix (2026-11-04): drop stray specks (<40 px, disconnected) from the new rows of
扎罗 (rows 9-10) and 空洞雪祀 (row 8); every other board is copied unchanged."""
import json, shutil, sys
from pathlib import Path
import numpy as np
from PIL import Image
SRC = Path(__file__).resolve().parent.parent / "batch_B3_v1"
OUT = Path(__file__).resolve().parent
FIX = {"zaro": [9, 10], "hollow_snowpriest": [8]}

def components(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    out = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]: continue
        stack = [(y0, x0)]; seen[y0, x0] = True; pts = []
        while stack:
            y, x = stack.pop(); pts.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not seen[yy, xx]:
                        seen[yy, xx] = True; stack.append((yy, xx))
        out.append(pts)
    return out

manifest = json.load(open(SRC / "manifest.json", encoding="utf-8"))
for board in manifest["boards"]:
    i = board["id"]
    img = np.array(Image.open(SRC / f"{i}_action.png").convert("RGBA"))
    removed = 0
    for r in FIX.get(i, []):
        for c in range(8):
            cell = img[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256]
            for pts in components(cell[..., 3] > 0):
                if len(pts) < 40:
                    for y, x in pts: cell[y, x] = 0
                    removed += len(pts)
    Image.fromarray(img).save(OUT / f"{i}_action.png")
    print(i, "removed", removed)
for f in SRC.glob("emblem_*.png"): shutil.copyfile(f, OUT / f.name)
for f in SRC.glob("prop_*.png"): shutil.copyfile(f, OUT / f.name)
