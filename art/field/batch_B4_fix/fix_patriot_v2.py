"""B4 v2 fix (2026-11-05): Patriot's black-halberd board. Detached bits under 200 px
(old-weapon residue, stray specks) are cleared in every cell; in row 28 E (CLENCH-OPEN)
the detached banner scrap floating left of the head is cleared. Row 10 W (RISE) has a
doubled head and goes back to Sol (B4_revision_v3.md); until then it holds row 9 W."""
from pathlib import Path
import numpy as np
from PIL import Image
SRC = Path(__file__).resolve().parent.parent / "batch_B4_v2"
OUT = Path(__file__).resolve().parent

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
    out.sort(key=len, reverse=True)
    return out

img = np.array(Image.open(SRC / "patriot_action.png").convert("RGBA"))
cleared = 0
for r in range(img.shape[0] // 256):
    for c in range(8):
        cell = img[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256]
        parts = components(cell[..., 3] > 0)
        for k, pts in enumerate(parts[1:], 1):
            if len(pts) < 200 or (r == 28 and c == 5 and k == 1):
                for y, x in pts: cell[y, x] = 0
                cleared += len(pts)
# Row 10 W: a placeholder until Sol's v3 cell comes in.
img[10 * 256:11 * 256, 2 * 256:3 * 256] = img[9 * 256:10 * 256, 2 * 256:3 * 256]
Image.fromarray(img).save(OUT / "patriot_action.png")
walk = np.array(Image.open(SRC / "patriot_walk.png").convert("RGBA"))
for r in range(8):
    for c in range(8):
        cell = walk[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256]
        for pts in components(cell[..., 3] > 0)[1:]:
            if len(pts) < 200:
                for y, x in pts: cell[y, x] = 0
                cleared += len(pts)
Image.fromarray(walk).save(OUT / "patriot_walk.png")
print("cleared px", cleared)
