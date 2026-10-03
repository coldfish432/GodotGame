"""Bake eight-direction enemy boards into runtime atlases (requires Pillow + numpy).

Run from any directory: python art/prepare_enemy_directional.py

Input: art/enemy_multidirection_originals_v1/NN_<name>_八方向动作原画.png, an
imagegen board with eight direction columns (S, SW, W, NW, N, NE, E, SE) and
five pose rows (idle, startup, charge, strike, recovery), plus text labels.
Boards that do not exist yet are skipped; those enemies keep the side-view
sheet. Originals are never modified.

Output per board: art/field/enemy_dir_<id>_64.png, 8 columns x 5 rows of
64x64 cells in the same column/row order. Every cell puts the foot line at
y=51 and the body centre at x=32, so the billboard offset is (0, 19) in all
directions. One scale per enemy (not per frame) keeps the body the same size
while turning; it matches the enemy's existing side-view idle height so
directional and side-view enemies stand at one scale. Downsampling is
premultiplied-alpha BOX with a hard alpha cut, like the other sheets.

Also written: art/field/enemy_dir_alignment.json with per-frame bounds and the
charge-pose weapon tip per direction (texels from the foot-line centre).
"""
from collections import deque
from pathlib import Path
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
BOARDS = ROOT / "enemy_multidirection_originals_v1"
WALK_BOARDS = ROOT / "enemy_movement_originals_v1"
WALK_FRAMES = 4
FIELD = ROOT / "field"
IDS = ["thug", "crossbow", "slug", "brawler", "crossbow_leader", "ice_warrior", "ice_hunter"]
DIRECTIONS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
POSES = 5
CELL = 64
FOOT = 51
CENTRE = 32
MIN_FIGURE = 5000
MIN_FIGURE_HEIGHT = 70
LABEL_MARGIN_X = 112  # row labels live left of this
LABEL_MARGIN_Y = 45   # column labels live above this
# Source rows with at least this many opaque pixels count as body, not a
# thin blade; used for the foot line, body centre and standing height.
BODY_ROW = 20
# Side-view sheet, used to match the existing idle height per enemy.
SIDE_SHEET = FIELD / "enemy_attacks_64.png"
RANGED = {"crossbow", "crossbow_leader", "ice_hunter"}
# Boards whose E column is not a true right profile (the charge pose was drawn
# turned away). Their whole E column is replaced by the W column mirrored, so
# every pose stays a consistent profile; the weapon changes hands as a result.
MIRROR_E_FROM_W = {"thug", "ice_warrior"}
MIRROR_E_FROM_W_WALK: set[str] = set()
CHEST = 12  # texels above the foot line where levelled crossbows and rifles sit


def components(mask: np.ndarray) -> list[np.ndarray]:
    height, width = mask.shape
    labels = np.zeros(mask.shape, np.int32)
    found = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if labels[y0, x0]:
            continue
        index = len(found) + 1
        labels[y0, x0] = index
        queue = deque([(y0, x0)])
        count = 0
        while queue:
            y, x = queue.popleft()
            count += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < height and 0 <= xx < width and mask[yy, xx] and not labels[yy, xx]:
                        labels[yy, xx] = index
                        queue.append((yy, xx))
        found.append(count)
    parts = []
    for index, count in enumerate(found, 1):
        if count < MIN_FIGURE:
            continue
        part = labels == index
        ys, xs = np.nonzero(part)
        if xs.max() < LABEL_MARGIN_X or ys.max() < LABEL_MARGIN_Y:
            continue
        # Row/column labels are one line of text; figures are far taller.
        if np.ptp(ys) < MIN_FIGURE_HEIGHT:
            continue
        parts.append(part)
    return parts


def split_widest(parts: list[np.ndarray]) -> list[np.ndarray]:
    """Two neighbouring figures joined by touching weapons: cut the widest
    blob at its thinnest column near the middle."""
    widths = [np.ptp(np.nonzero(part.any(0))[0]) for part in parts]
    widest = int(np.argmax(widths))
    part = parts[widest]
    columns = np.nonzero(part.any(0))[0]
    lo, hi = columns.min(), columns.max()
    counts = part.sum(0)
    span = range(lo + (hi - lo) // 3, hi - (hi - lo) // 3)
    cut = min(span, key=lambda x: counts[x])
    left, right = part.copy(), part.copy()
    left[:, cut:] = False
    right[:, :cut] = False
    return parts[:widest] + [left, right] + parts[widest + 1:]


def body(part: np.ndarray) -> tuple[int, int, float]:
    """Head row, foot row and body centre column, ignoring thin weapon rows."""
    rows = np.nonzero(part.sum(1) >= BODY_ROW)[0]
    head, foot = int(rows.min()), int(rows.max())
    body_rows = part[head:foot + 1]
    return head, foot, float(np.median(np.nonzero(body_rows)[1]))


def side_idle_height(row: int) -> int:
    sheet = np.array(Image.open(SIDE_SHEET).convert("RGBA"))[:, :, 3] >= 128
    cell = sheet[row * CELL:(row + 1) * CELL, 0:CELL]
    rows = np.nonzero(cell.sum(1) >= 3)[0]
    return int(rows.max() - rows.min() + 1)


def slice_board(board_path: Path, enemy: str, rows: int, standing_rows: list[int]) -> tuple[Image.Image, list, float, int]:
    """Cut an 8-column board into a rows x 8 atlas of aligned 64x64 cells.
    One scale per board, chosen so the median standing height over
    `standing_rows` equals the enemy's side-view idle height; every cell puts
    the foot line at y=51 and the body centre at x=32."""
    pixels = np.array(Image.open(board_path).convert("RGBA"))
    parts = components(pixels[:, :, 3] >= 128)
    while len(parts) < len(DIRECTIONS) * rows:
        parts = split_widest(parts)
    assert len(parts) == len(DIRECTIONS) * rows, f"{board_path.name}: {len(parts)} figures"
    # Rows by vertical position, then columns left to right.
    parts.sort(key=lambda part: np.nonzero(part.any(1))[0].min())
    grid = [sorted(parts[row * 8:(row + 1) * 8], key=lambda part: np.nonzero(part.any(0))[0].min()) for row in range(rows)]

    standing = [body(part) for row in standing_rows for part in grid[row]]
    target = side_idle_height(IDS.index(enemy))
    scale = target / float(np.median([foot - head + 1 for head, foot, _ in standing]))

    atlas = Image.new("RGBA", (len(DIRECTIONS) * CELL, rows * CELL))
    frames = []
    for row in range(rows):
        for column, part in enumerate(grid[row]):
            _, foot, centre = body(part)
            sprite = np.where(part[:, :, None], pixels, 0).astype(np.uint8)
            canvas_size = round(CELL / scale)
            actual = CELL / canvas_size
            offset_x = round((CENTRE + 0.5) / actual - (centre + 0.5))
            offset_y = round(FOOT / actual - (foot + 1))
            canvas = Image.new("RGBA", (canvas_size, canvas_size))
            canvas.paste(Image.fromarray(sprite, "RGBA"), (offset_x, offset_y))
            cell = canvas.convert("RGBa").resize((CELL, CELL), Image.Resampling.BOX).convert("RGBA")
            cell.putalpha(cell.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
            bounds = cell.getbbox()
            assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < CELL and bounds[3] < CELL, (enemy, row, column, bounds)
            atlas.paste(cell, (column * CELL, row * CELL))
            frames.append({"direction": DIRECTIONS[column], "pose": row, "bounds": list(bounds)})
    return atlas, frames, scale, target


def mirror_east(atlas: Image.Image, frames: list, rows: int) -> None:
    """Replace the E column with the W column mirrored (see MIRROR_E_FROM_W)."""
    west, east = DIRECTIONS.index("W"), DIRECTIONS.index("E")
    for row in range(rows):
        cell = atlas.crop((west * CELL, row * CELL, (west + 1) * CELL, (row + 1) * CELL)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        # Mirroring maps texel x to 63 - x; shift one texel so the body
        # centre lands back on x = 32 instead of 31.
        shifted = Image.new("RGBA", (CELL, CELL))
        shifted.paste(cell, (1, 0))
        atlas.paste(shifted, (east * CELL, row * CELL))
        frames[row * len(DIRECTIONS) + east]["mirrored_from"] = "W"


def bake(board_path: Path, enemy: str, manifest: dict) -> None:
    atlas, frames, scale, target = slice_board(board_path, enemy, POSES, [0, POSES - 1])
    if enemy in MIRROR_E_FROM_W:
        mirror_east(atlas, frames, POSES)
    atlas.save(FIELD / f"enemy_dir_{enemy}_64.png")

    # Weapon tip in the charge pose. Melee weapons are raised: take the
    # texel farthest from the body centre above the waist. Ranged weapons
    # are levelled at the chest: take the texel farthest toward the facing
    # side within the chest band; facing the camera or away, the muzzle is
    # the chest centre.
    tips = {}
    alpha = np.array(atlas)[:, :, 3] >= 128
    facing_x = {"S": 0, "SW": -1, "W": -1, "NW": -1, "N": 0, "NE": 1, "E": 1, "SE": 1}
    for column, name in enumerate(DIRECTIONS):
        cell = alpha[2 * CELL:3 * CELL, column * CELL:(column + 1) * CELL]
        if enemy in RANGED:
            if facing_x[name] == 0:
                tips[name] = [0, -CHEST]
                continue
            band = cell[FOOT - CHEST - 6:FOOT - CHEST + 6]
            ys, xs = np.nonzero(band)
            far = int(np.argmax(xs * facing_x[name]))
            tips[name] = [int(xs[far] - CENTRE), int(ys[far] + FOOT - CHEST - 6 - FOOT)]
            continue
        ys, xs = np.nonzero(cell[:FOOT - 8])
        far = int(np.argmax((xs - CENTRE) ** 2 + (ys - FOOT) ** 2 * 0.6))
        tips[name] = [int(xs[far] - CENTRE), int(ys[far] - FOOT)]
    if enemy in MIRROR_E_FROM_W:
        tips["E"] = [-tips["W"][0], tips["W"][1]]
    manifest[enemy] = {"board": board_path.name, "scale": scale, "idle_height": target, "tips": tips, "frames": frames}
    print(f"{enemy}: scale {scale:.4f}, idle {target} texels, tips {tips}")


def bake_walk(board_path: Path, enemy: str, manifest: dict) -> None:
    """Four-frame walk loop per direction (contact A, pass A, contact B, pass B),
    scaled and anchored exactly like the attack sheet so walking into an
    attack never changes the body size or foot line."""
    atlas, frames, scale, target = slice_board(board_path, enemy, WALK_FRAMES, list(range(WALK_FRAMES)))
    if enemy in MIRROR_E_FROM_W_WALK:
        mirror_east(atlas, frames, WALK_FRAMES)
    atlas.save(FIELD / f"enemy_walk_{enemy}_64.png")
    manifest[enemy] = {"board": board_path.name, "scale": scale, "height": target, "frames": frames}
    print(f"{enemy} walk: scale {scale:.4f}, height {target} texels")


def main() -> None:
    manifest = {"cell": CELL, "foot": FOOT, "centre": CENTRE, "directions": DIRECTIONS,
        "poses": ["idle", "startup", "charge", "strike", "recovery"], "enemies": {}}
    for number, enemy in enumerate(IDS, 1):
        boards = sorted(BOARDS.glob(f"{number:02d}_*_八方向动作原画.png"))
        if not boards:
            print(f"{enemy}: no board yet, keeps the side-view sheet")
            continue
        bake(boards[0], enemy, manifest["enemies"])
    manifest["walk"] = {}
    for number, enemy in enumerate(IDS, 1):
        boards = sorted(WALK_BOARDS.glob(f"{number:02d}_*_八方向移动原画.png"))
        if boards:
            bake_walk(boards[0], enemy, manifest["walk"])
    (FIELD / "enemy_dir_alignment.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    # The runtime needs the tips too; a JSON file would not be exported, so
    # they are also written as a generated GDScript constant.
    lines = ["class_name EnemyDirectionalData", "extends RefCounted", "## GENERATED by art/prepare_enemy_directional.py - do not edit by hand.",
        "## Enemies with an eight-direction sheet, and each direction's charge-pose",
        "## weapon tip in texels from the foot-line centre (columns S, SW, W, NW, N, NE, E, SE).", "const TIPS := {"]
    for enemy, data in manifest["enemies"].items():
        tips = ", ".join(f"Vector2({data['tips'][name][0]}, {data['tips'][name][1]})" for name in DIRECTIONS)
        lines.append(f'\t"{enemy}": [{tips}],')
    lines.append("}")
    lines.append("## Enemies with an eight-direction walk sheet (4 frames per direction).")
    lines.append("const WALK := [" + ", ".join(f'"{enemy}"' for enemy in manifest["walk"]) + "]")
    (ROOT / "enemy_directional_data.gd").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
