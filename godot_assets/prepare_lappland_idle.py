"""Build lappland_idle_32.png (2 columns x 8 rows, 32x32 cells).

Source: Sol's standing idle, art/characters/idle/batch_I1_v1/lappland_idle_source.png
(2 x 8 cells of 222 px, the same scale and per-row foot line as her walk
source; column 1 stands with both feet flat, column 2 breathes with the knees
down unchanged). Each cell gets the walk sheet's treatment: premultiplied BOX
downsample to 32 and alpha thresholded at 128. Row order matches
lappland_8dir_walk_32.png.

Before 2026-10-10 the idle was the walk cycle's passing frame plus a 1-texel
shift, which left a foot lifted in several directions (用户: 腿不是迈开的).
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / "art" / "characters" / "idle" / "batch_I1_v1" / "lappland_idle_source.png"
SRC = 222
C = 32

src = np.array(Image.open(SOURCE).convert("RGBA"))
sheet = np.zeros((8 * C, 2 * C, 4), np.uint8)
for r in range(8):
    for c in range(2):
        cell = Image.fromarray(src[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC], "RGBA")
        small = cell.convert("RGBa").resize((C, C), Image.Resampling.BOX).convert("RGBA")
        small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
        sheet[r * C:(r + 1) * C, c * C:(c + 1) * C] = np.array(small)
Image.fromarray(sheet).save(ROOT / "lappland_idle_32.png")
