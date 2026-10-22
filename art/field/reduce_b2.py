"""B2 叙拉古平民: from Sol's paintings to the game's 26 px sprite (用户 2026-10-19).

Two ways down:
- `reduce` (straight): the check Sol runs. Box-downscale weighted by coverage,
  fast octree, thin parts grown, the 1 px inner outline of reduce_n1.
- `reduce_clean` (the one the game uses, 用户 2026-10-19: 压平色块、固定调色板、补耳朵):
  1. flatten each painted mass first (a median filter takes out the cel
     facets and texture that turn into speckle at 26 px);
  2. box-downscale weighted by coverage;
  3. snap every pixel to PALETTE, one colour per costume mass;
  4. grow thin parts, add the inner outline;
  5. (用户 2026-10-19 起不补耳朵: the painted ears are kept as they reduce;
     `ears` stays only for the old single-painting check.)

    python art/field/reduce_b2.py <painting.png> <height> <out.png> [--clean]
    python art/field/reduce_b2.py --board <board.png> <rows> <out_64.png>

Writes <out.png> and <out>_on_ground_x6.png (beside the family soldier on
the piazza ground). A board is cut into its 8 × rows cells, each reduced
with one scale (from the first cell's figure height) and laid on the 64 px
grid at the N2 foot line, then <out>_x6.png.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reduce_n1 as r  # noqa: E402

HEIGHT = 26
## The flattening filter, sized on the approved v4 painting (figure 1223 px
## tall); a board cell's figure gets the same size relative to its height.
MEDIAN = 15
MEDIAN_AT = 1223.0
## One colour per mass of the v4 costume (B2_siracusa_civilian_brief_v2.md, B2_revision_v3/v4).
PALETTE = ["0b0c0d", "4a3c30", "2e2824", "b8b0a4", "d8c8a8", "f0d0b0", "c89878", "e8e0cc",
           "b8ac94", "3a322c", "7a5a3c", "3a3634", "5a524c"]
CAP = (74, 60, 48)
EAR = (184, 176, 164, 255)
EAR_IN = (232, 224, 204, 255)
OUTLINE = (*r.OUTLINE, 255)
CELL = 64
FOOT = 51
CENTRE = 32


def _figure(painting: Image.Image) -> np.ndarray:
    arr = np.array(painting.convert("RGBA")).astype(float)
    ys, xs = np.where(arr[..., 3] > 128)
    return arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def _down(arr: np.ndarray, height: int, scale: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    cover = (arr[..., 3] > 128).astype(float)
    if scale <= 0.0: scale = height / arr.shape[0]
    size = (max(1, round(arr.shape[1] * scale)), max(1, round(arr.shape[0] * scale)))
    rgb = np.array(Image.fromarray(np.uint8(arr[..., :3] * cover[..., None])).resize(size, Image.BOX)).astype(float)
    alpha = np.array(Image.fromarray(np.uint8(cover * 255)).resize(size, Image.BOX)).astype(float) / 255.0
    return (rgb / np.maximum(alpha[..., None], 1e-3)).clip(0, 255), alpha > 0.5


def _finish(rgb: np.ndarray, solid: np.ndarray) -> Image.Image:
    solid, rgb = r.thicken_thin(np.pad(solid, 1), np.pad(rgb.astype(np.uint8), ((1, 1), (1, 1), (0, 0))))
    out = np.zeros((*solid.shape, 4), np.uint8)
    out[..., :3] = rgb
    out[..., 3] = np.where(solid, 255, 0)
    out[r.edge_of(solid)] = OUTLINE
    return Image.fromarray(out)


def reduce(painting: Image.Image, height: int = HEIGHT) -> Image.Image:
    rgb, solid = _down(_figure(painting), height)
    flat = np.array(Image.fromarray(np.uint8(rgb)).quantize(16, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB"))
    return _finish(flat, solid)


def _flatten(arr: np.ndarray, figure_height: float = 0.0) -> np.ndarray:
    size = MEDIAN if figure_height <= 0.0 else max(3, int(round(MEDIAN * figure_height / MEDIAN_AT)) | 1)
    rgb = Image.fromarray(np.uint8(arr[..., :3])).filter(ImageFilter.MedianFilter(size))
    out = arr.copy()
    out[..., :3] = np.array(rgb).astype(float)
    return out


def _snap(rgb: np.ndarray) -> np.ndarray:
    pal = np.array([tuple(bytes.fromhex(c)) for c in PALETTE], float)
    return pal[((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1).argmin(-1)]


def ears(img: Image.Image) -> Image.Image:
    """Two 3 × 3 wolf ears on the cap's top corners, the figure grown 2 px up for them."""
    a = np.array(img)
    a = np.concatenate([np.zeros((2, a.shape[1], 4), np.uint8), a])
    # Placed on the cap itself, not on whatever is topmost: a hand held on the
    # cap or arms over the head must not get ears.
    cap = (a[..., 3] > 0) & np.all(a[..., :3] == CAP, axis=-1)
    rows = np.where(cap.sum(axis=1) >= 3)[0]
    if len(rows) == 0: return img
    top = rows.min()
    xs = np.where(cap[top:top + 2].any(axis=0))[0]
    # The painted ears already survived above the cap: leave them.
    above = a[max(0, top - 3):top]
    if np.all(above[:, xs.min():xs.max() + 1, :3] == EAR[:3], axis=-1).sum() >= 3: return Image.fromarray(a)
    for cx in (xs.min() + 1, xs.max() - 1):
        for (dx, dy), c in {(0, -2): OUTLINE, (-1, -1): OUTLINE, (0, -1): EAR, (1, -1): OUTLINE,
                            (-1, 0): EAR, (0, 0): EAR_IN, (1, 0): EAR}.items():
            x, y = cx + dx, top + dy
            if 0 <= x < a.shape[1] and 0 <= y: a[y, x] = c
    return Image.fromarray(a)


def reduce_clean(painting: Image.Image, height: int = HEIGHT, scale: float = 0.0, with_ears: bool = False) -> Image.Image:
    fig = _figure(painting)
    # On a board the first cell's height sets the filter for every cell.
    reference = height / scale if scale > 0.0 else fig.shape[0]
    arr = _flatten(fig, reference)
    rgb, solid = _down(arr, height, scale)
    img = _finish(_snap(rgb), solid)
    return ears(img) if with_ears else img


def bake_board(board: Image.Image, rows: int) -> Image.Image:
    side = board.width // 8
    cells = [[board.crop((c * side, rw * side, (c + 1) * side, (rw + 1) * side)) for c in range(8)] for rw in range(rows)]
    scale = HEIGHT / _figure(cells[0][0]).shape[0]
    sheet = Image.new("RGBA", (8 * CELL, rows * CELL))
    for rw in range(rows):
        for c in range(8):
            if cells[rw][c].getbbox() is None: continue
            small = reduce_clean(cells[rw][c], HEIGHT, scale)
            box = small.getbbox()
            small = small.crop(box)
            sheet.alpha_composite(small, (c * CELL + CENTRE - small.width // 2, rw * CELL + FOOT + 1 - small.height))
    return sheet


def _ground_check(small: Image.Image, out: Path) -> None:
    soldier = Image.open(HERE / "enemy_dir_family_soldier_64.png").convert("RGBA").crop((64, 0, 128, 64))
    soldier = soldier.crop(soldier.getbbox())
    ground = Image.open(HERE / "refs_B2" / "siracusa_arena_ingame.png").convert("RGBA").crop((700, 250, 800, 300))
    ground.alpha_composite(small, (20, 47 - small.height))
    ground.alpha_composite(soldier, (60, 47 - soldier.height))
    ground.resize((ground.width * 6, ground.height * 6), Image.NEAREST).save(out.with_name(out.stem + "_on_ground_x6.png"))


def main() -> None:
    if sys.argv[1] == "--board":
        board, rows, out = Image.open(sys.argv[2]).convert("RGBA"), int(sys.argv[3]), Path(sys.argv[4])
        sheet = bake_board(board, rows)
        sheet.save(out)
        sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(out.with_name(out.stem + "_x6.png"))
        print("baked", out, sheet.size)
        return
    painting, height, out = Image.open(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])
    small = reduce_clean(painting, height) if "--clean" in sys.argv else reduce(painting, height)
    small.save(out)
    _ground_check(small, out)
    print("reduced", out, small.size)


if __name__ == "__main__":
    main()
