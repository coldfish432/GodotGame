"""OBSOLETE since 2026-10-09: Sol's A1 is in (prepare_amiya_guard_atlas.py).
Running this overwrites the real sheets with the stand-in.

Stand-in Amiya (Guard) sheets until Sol's batch A1 arrives.

Run from godot_assets/: python prepare_amiya_placeholder.py

Takes Lappland's runtime sheets (walk 32, idle 32, combat 64), recolours her (white hair -> chestnut,
black coat -> navy, red eyes -> teal, blades -> black with a cyan edge) and adds
two upright rabbit ears above the head. Same grids and row order as Lappland's,
so the animator reads them with her ACTIONS table. Replace these files with the
real downsampled art; nothing else depends on how they were made.
"""
import colorsys
import numpy as np
from PIL import Image

OUTLINE = (12, 10, 18)
EAR = (138, 94, 68)
EAR_INNER = (217, 167, 154)
HAIR = [(70, 44, 32), (90, 59, 44), (138, 94, 68), (185, 138, 102)]
NAVY = [(14, 18, 34), (24, 32, 58), (36, 48, 84)]
TEAL = (63, 179, 200)
CYAN = (51, 214, 198)
BLADE = (16, 20, 24)


def recolour(px):
    r, g, b, a = [int(v) for v in px]
    if a == 0:
        return px
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if r > 140 and g < 90 and b < 100:                      # red eyes
        return (*TEAL, 255)
    if l > 0.8 and r - b >= 10:                              # skin stays
        return px
    if b - r > 18 and l > 0.45:                              # cold blades / blue rims
        return (*(CYAN if l > 0.62 else BLADE), 255)
    if l > 0.55:                                             # white hair
        return (*HAIR[min(3, int((l - 0.55) / 0.45 * 4))], 255)
    if l > 0.32:
        return (*HAIR[0], 255)
    if l > 0.09:                                             # black coat
        return (*NAVY[min(2, int((l - 0.09) / 0.23 * 3))], 255)
    return px


def shrink(cell, foot):
    h, w = cell.shape[:2]
    img = Image.fromarray(cell)
    nw, nh = round(w * 0.9), round(h * 0.9)
    small = np.array(img.resize((nw, nh), Image.NEAREST))
    out = np.zeros_like(cell)
    ox = (w - nw) // 2
    oy = foot - round(foot * 0.9)
    out[oy:oy + nh, ox:ox + nw] = small[: h - oy]
    return out


def ears(cell, row):
    """row: 0 S, 1 SW, 2 W, 3 NW, 4 N, 5 NE, 6 E, 7 SE (walk order)."""
    m = cell[:, :, 3] > 0
    rows = np.where(m.any(1))[0]
    if rows.size == 0:
        return cell
    top = rows[0]
    cols = np.where(m[top:top + 4].any(0))[0]
    cx = int(round(cols.mean()))
    side = {1: -1, 2: -1, 3: -1, 5: 1, 6: 1, 7: 1}.get(row, 0)
    back = row in (3, 4, 5)
    xs = [cx - 4, cx + 3] if side == 0 else [cx - 1 + side, cx + 3 * side]
    height = 6
    for i, x in enumerate(xs):
        lean = 0 if side == 0 else -side * (1 if i == 1 else 0)
        for dy in range(height + 2):
            y = top + 3 - dy
            if y < 0:
                break
            for dx in (-1, 0, 1, 2):
                xx = x + dx + (lean if dy > 3 else 0)
                if not 0 <= xx < cell.shape[1]:
                    continue
                edge = dx in (-1, 2) or dy == height + 1
                if edge:
                    if cell[y, xx, 3] == 0:
                        cell[y, xx] = (*OUTLINE, 255)
                else:
                    inner = (not back) and dx == 0 and 1 <= dy <= height - 1 and (side == 0 or i == 0)
                    cell[y, xx] = (*(EAR_INNER if inner else EAR), 255)
    return cell


def build(src, out, cell, rows_order):
    a = np.array(Image.open(src).convert("RGBA"))
    res = np.zeros_like(a)
    for r in range(a.shape[0] // cell):
        for c in range(a.shape[1] // cell):
            block = a[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell].copy()
            m = block[:, :, 3] > 0
            if not m.any():
                continue
            flat = block.reshape(-1, 4)
            block = np.array([recolour(p) for p in flat], np.uint8).reshape(block.shape)
            block = ears(block, rows_order[r])
            res[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = block
    Image.fromarray(res).save(out)


WALK_ROWS = [0, 1, 2, 3, 4, 5, 6, 7]
COMBAT_ROWS = [0, 1, 2, 3, 4]   # S, SW, W, NW, N
build("lappland_8dir_walk_32.png", "amiya_guard_walk_32.png", 32, WALK_ROWS)
build("lappland_idle_32.png", "amiya_guard_idle_32.png", 32, WALK_ROWS)
build("lappland_combat_64.png", "amiya_guard_combat_64.png", 64, COMBAT_ROWS)
