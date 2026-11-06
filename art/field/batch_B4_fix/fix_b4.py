"""B4 fix (2026-11-05): 扎罗 rows 19 HOWL-SWELL and 20 PACK-CALL were drawn about 12%
smaller than his HOWL row (8); each cell is scaled up 1.12 about its foot-line
centre. 鼠王 and 埃克提尔尼尔 pass as delivered. 爱国者 waits for the black-halberd
revision (B4_revision_v2.md)."""
import shutil
from pathlib import Path
import numpy as np
from PIL import Image
SRC = Path(__file__).resolve().parent.parent / "batch_B4_v1"
OUT = Path(__file__).resolve().parent
FOOT = 247
SCALE = {"zaro": {19: 1.12, 20: 1.12}}

for fid in ["rat_king", "eikthyrnir", "zaro"]:
    board = Image.open(SRC / f"{fid}_action.png").convert("RGBA")
    for row in SCALE.get(fid, {}):
        for c in range(8):
            box = (c * 256, row * 256, (c + 1) * 256, (row + 1) * 256)
            cell = board.crop(box)
            a = np.array(cell)[..., 3] > 127
            xs = np.nonzero(a.any(axis=0))[0]
            cx = (xs.min() + xs.max()) / 2.0
            # never wider than fits the 64 px cell after the bake (about 236 px here)
            k = min(SCALE[fid][row], 236.0 / (xs.max() - xs.min() + 1))
            big = cell.resize((round(256 * k), round(256 * k)), Image.LANCZOS)
            out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
            # keep the foot line and the body's centre where they were
            out.alpha_composite(big, (round(cx - cx * k), round(FOOT + 1 - (FOOT + 1) * k)))
            arr = np.array(out)
            arr[..., 3] = np.where(arr[..., 3] >= 128, 255, 0)
            if arr[0, :, 3].any() or arr[:, 0, 3].any() or arr[:, -1, 3].any(): print("WARN edge", fid, row, c)
            board.paste(Image.fromarray(arr), box[:2])
    board.save(OUT / f"{fid}_action.png")
    print(fid, "written")
