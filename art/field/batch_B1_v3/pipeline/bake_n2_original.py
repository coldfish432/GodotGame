"""Bake an N2 enemy board to the game's 64×64 cells, the way N1 was approved.

An N2 board is a clean grid: 8 columns (S, SW, W, NW, N, NE, E, SE) × R rows
(the action rows, or the 4 walk rows), every cell the same square size, no
labels, transparent background. Each figure is reduced with the method the
user picked for N1 (用户 2026-10-11: 要这种的; see reduce_n1.py):
  box downscale with one scale for the whole board (taken from the S / IDLE
  figure so it stands at the enemy's native height), 16-colour median-cut
  quantize without dither, crumbs under 25 px dropped, thin parts (weapons) grown 1 px each side,
  1 px #0b0c0d outline on the body's own edge pixels.
Each cell puts the feet at y = 51 and the body centre at x = 32, like the
existing enemy_dir_*_64.png sheets.

  python art/field/bake_n2.py <board.png> <enemy id> <rows> [--scale-from <action board.png>]

--scale-from takes the scale from another board's S / first-row figure, so a
walk board whose first cell does not stand at full height (萨卡兹哨兵 carries
its pole tilted) comes out the same size as its action board.

Writes <board>_64.png (the runtime sheet) and <board>_64_x6.png (a preview).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from reduce_n1 import FIGURES, OUTLINE, components, edge_of, thicken_thin  # noqa: E402

# Enemies drawn after N1 (no cell on its identity sheet): native height in
# texels of the S / IDLE figure's whole box. 萨卡兹哨兵's box runs to the top
# of its signal pole (30); its body comes out about 暴徒's height (用户 2026-10-14:
# 再小一点, from 34; batch_N3_claude/size_options_x8.png).
EXTRA_HEIGHTS = {"sentinel": 30,
                 # N4 叙拉古 (叙拉古敌人设计案_v1 §五): the caster's box includes its hood's
                 # wolf ears; the car's is the whole S-facing car, roof to tyres.
                 "family_soldier": 28, "family_intimidator": 33, "family_crossbow": 27,
                 "family_caster": 27, "family_capo": 31, "family_eraser": 31, "family_car": 24,
                 # B1 bosses and wardens (Boss与守卫者策划案 §11), measured on the
                 # approved identities: Patriot and Eikthyrnir with their antlers,
                 # Zaro lying down (his S / IDLE is the phase-1 crouch).
                 "patriot": 46, "rat_king": 36, "eikthyrnir": 46, "zaro": 38,
                 "crownslayer": 30, "skullshatterer": 32, "hollow_snowpriest": 33, "father_agnir": 31}
# Per-enemy quantizer: median cut (the approved N1 method) folds a small warm
# prop into the greys; octree keeps 萨卡兹哨兵's brass horn gold and its flat
# masses clean (batch_N3_claude/quantize_compare_x8.png, 2026-10-14).
QUANTIZE = {"sentinel": Image.Quantize.FASTOCTREE}
# B1: median cut drops Patriot's red and orange, Zaro's red eye and the Hollow
# Snowpriest's purple (batch_B1_v1/qa/quantizer_comparison.png), so all eight use octree.
QUANTIZE.update({k: Image.Quantize.FASTOCTREE for k in ["patriot", "rat_king", "eikthyrnir", "zaro", "crownslayer", "skullshatterer", "hollow_snowpriest", "father_agnir"]})
# N4 叙拉古 family enemies (叙拉古敌人设计案 §1.2, 用户 2026-10-16: 只换特征色):
# painted in the Saluzzo accent pair, the other families made by swapping those
# two values after the bake, so the pair must come out of the bake exact. The
# painting is snapped to the pair before quantizing (the quantizer then cannot
# fold it into the suit) and the sheet after; octree keeps the flat masses.
ACCENTS = [(0x9A, 0x2A, 0x3A), (0x5E, 0x16, 0x20)]
ACCENT_ENEMIES = {"family_soldier", "family_intimidator", "family_crossbow", "family_caster", "family_capo"}
for _id in ACCENT_ENEMIES | {"family_eraser", "family_car"}:
    QUANTIZE[_id] = Image.Quantize.FASTOCTREE


def snap_accents(img: Image.Image, reach: float) -> Image.Image:
    """Every opaque pixel within `reach` of an accent becomes that accent."""
    a = np.array(img).astype(int)
    acc = np.array(ACCENTS)
    d = np.sqrt(((a[..., None, :3] - acc[None, None]) ** 2).sum(-1))
    near = (d.min(-1) < reach) & (a[..., 3] > 0)
    a[..., :3][near] = acc[d.argmin(-1)[near]]
    return Image.fromarray(a.astype(np.uint8))

CELL = 64
FOOT = 51
CENTRE = 32


def figure_box(cell: np.ndarray) -> tuple[int, int, int, int] | None:
    ys, xs = np.where(cell[..., 3] > 128)
    if len(ys) == 0: return None
    return ys.min(), ys.max() + 1, xs.min(), xs.max() + 1


def bake_cell(cell: Image.Image, scale: float, method: int = Image.Quantize.MEDIANCUT) -> Image.Image:
    a = np.array(cell)
    box = figure_box(a)
    out = Image.new("RGBA", (CELL, CELL))
    if box is None: return out
    y0, y1, x0, x1 = box
    fig = cell.crop((x0, y0, x1, y1))
    w = max(1, round(fig.width * scale))
    h = max(1, round(fig.height * scale))
    small = np.array(fig.resize((w, h), Image.BOX))
    alpha = small[..., 3] > 140
    for comp in components(alpha):
        if len(comp) < 25: alpha[comp[:, 0], comp[:, 1]] = False
    rgb = np.array(Image.fromarray(small[..., :3]).quantize(colors=16, method=method, dither=Image.Dither.NONE).convert("RGB"))
    alpha, rgb = thicken_thin(np.pad(alpha, 1), np.pad(rgb, ((1, 1), (1, 1), (0, 0))))
    sprite = np.zeros((h + 2, w + 2, 4), np.uint8)
    sprite[..., :3] = rgb
    sprite[..., 3] = np.where(alpha, 255, 0)
    sprite[edge_of(alpha)] = (*OUTLINE, 255)
    sprite_img = Image.fromarray(sprite)
    # Feet on the foot line; body centre (the lower half's mean column) on x = 32.
    body = sprite[..., 3] > 0
    lower = body[body.shape[0] // 2:]
    cols = np.where(lower.any(axis=0))[0]
    cx = int(round(cols.mean())) if len(cols) else sprite_img.width // 2
    out.alpha_composite(sprite_img, (max(0, CENTRE - cx), max(0, FOOT + 1 - sprite_img.height)))
    return out


def main() -> None:
    path = Path(sys.argv[1])
    enemy = sys.argv[2]
    rows = int(sys.argv[3])
    board = Image.open(path).convert("RGBA")
    if enemy in ACCENT_ENEMIES: board = snap_accents(board, 34)
    side = board.width // 8
    if board.height // rows != side:
        sys.exit("board must be a uniform 8 × %d grid of square cells (got %s)" % (rows, board.size))
    native_height = EXTRA_HEIGHTS[enemy] if enemy in EXTRA_HEIGHTS else FIGURES[enemy][2]
    reference = board
    if "--scale-from" in sys.argv:
        reference = Image.open(sys.argv[sys.argv.index("--scale-from") + 1]).convert("RGBA")
    ref_side = reference.width // 8
    first = np.array(reference.crop((0, 0, ref_side, ref_side)))
    box = figure_box(first)
    # Measured on the reference board's cells; the same cell size keeps it valid here.
    scale = native_height / (box[1] - box[0]) * ref_side / side
    sheet = Image.new("RGBA", (8 * CELL, rows * CELL))
    for r in range(rows):
        for c in range(8):
            cell = board.crop((c * side, r * side, (c + 1) * side, (r + 1) * side))
            sheet.alpha_composite(bake_cell(cell, scale, QUANTIZE.get(enemy, Image.Quantize.MEDIANCUT)), (c * CELL, r * CELL))
    if enemy in ACCENT_ENEMIES: sheet = snap_accents(sheet, 26)
    out = path.with_name(path.stem + "_64.png")
    sheet.save(out)
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(path.with_name(path.stem + "_64_x6.png"))
    print("baked", out, "scale", round(scale, 4))


if __name__ == "__main__":
    main()
