"""Install the accepted N2 enemy boards and the barrier effect into the game.

Run from any directory: python art/install_n2_boards.py

Each of the 17 new enemies (装备扩充策划案 §2.1), and 萨卡兹哨兵 (N3: action
batch_N3_v3, walk batch_N3_claude), gets the latest accepted
version of its boards (用户 2026-10-11: 差不多就接入):
  v1 (re-baked) for most, v2 for caster / distorted_caster / greytail /
  greytail_lord / slug_volatile, v3 for rock_hornbeast; all walk boards are v1.
They are copied to art/field/enemy_dir_<id>_64.png (8 columns × 5 or 6 rows)
and art/field/enemy_walk_<id>_64.png (8 × 4), the same layout as the sheets
art/prepare_enemy_directional.py bakes, so FieldArt plays them the same way.

Also writes art/enemy_n2_data.gd (EnemyN2Data: per-direction charge-pose tips
and the sixth-row special poses) and copies Sol's v3 barrier strips to
art/field/fx/. The boards themselves are never modified; the installed walk
sheets have their frames stood on one foot line (settle_walk).
"""
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
FIELD = ROOT / "field"
IDS = ["armed", "caster", "shield", "slug_volatile", "picket", "greytail", "greytail_lord", "thrower", "bully",
    "avenger", "breacher", "taint_husk", "distorted_caster", "shattered_champion", "shell_vine", "rock_hornbeast",
    "fallen_snowpriest", "sentinel"]
ACTION_BATCH = {"sentinel": "batch_N3_v3", "caster": "batch_N2_v2", "distorted_caster": "batch_N2_v2", "greytail": "batch_N2_v2",
    "greytail_lord": "batch_N2_v2", "slug_volatile": "batch_N2_v2", "rock_hornbeast": "batch_N2_v3"}
# 萨卡兹哨兵's walk is re-baked at its action board's scale (bake_n2.py
# --scale-from; its first walk cell carries the pole tilted), 2026-10-14.
WALK_BATCH = {"sentinel": "batch_N3_claude"}
# The sixth action row, where a board has one (N2 brief: LASSO, GLIDE).
EXTRA_ROW = {"picket": "lasso", "distorted_caster": "glide"}
# Those that shoot or lob from the chest: their tip is the release point.
RANGED = {"thrower", "fallen_snowpriest"}
DIRECTIONS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
CELL = 64
FOOT = 51
CENTRE = 32
CHEST = 12
FX = ["barrier_shell", "barrier_cracked", "barrier_break"]


def tips_of(sheet: Image.Image, enemy: str) -> list[list[int]]:
    """Charge-pose tip per direction, as art/prepare_enemy_directional.py."""
    alpha = np.array(sheet)[:, :, 3] >= 128
    facing_x = {"S": 0, "SW": -1, "W": -1, "NW": -1, "N": 0, "NE": 1, "E": 1, "SE": 1}
    tips = []
    for column, name in enumerate(DIRECTIONS):
        cell = alpha[2 * CELL:3 * CELL, column * CELL:(column + 1) * CELL]
        if enemy in RANGED:
            if facing_x[name] == 0:
                tips.append([0, -CHEST])
                continue
            band = cell[FOOT - CHEST - 6:FOOT - CHEST + 6]
            ys, xs = np.nonzero(band)
            far = int(np.argmax(xs * facing_x[name]))
            tips.append([int(xs[far] - CENTRE), int(ys[far] - CHEST - 6)])
            continue
        ys, xs = np.nonzero(cell[:FOOT - 8])
        far = int(np.argmax((xs - CENTRE) ** 2 + (ys - FOOT) ** 2 * 0.6))
        tips.append([int(xs[far] - CENTRE), int(ys[far] - FOOT)])
    return tips


def settle_walk(path: Path) -> int:
    """Stand every walk frame of a direction on the same foot line (用户
    2026-10-14: 走路一跳一跳的). Some boards draw their third frame lifted
    clear of the ground, which played as a hop; each frame is moved down to
    the lowest foot line of its column. Returns the largest shift made."""
    sheet = np.array(Image.open(path).convert("RGBA"))
    worst = 0
    for col in range(sheet.shape[1] // CELL):
        cells = [sheet[r * CELL:(r + 1) * CELL, col * CELL:(col + 1) * CELL] for r in range(sheet.shape[0] // CELL)]
        bottoms = []
        for cell in cells:
            rows = np.nonzero(cell[:, :, 3].max(axis=1) > 0)[0]
            bottoms.append(int(rows[-1]) if rows.size else -1)
        target = max(bottoms)
        for r, cell in enumerate(cells):
            shift = target - bottoms[r] if bottoms[r] >= 0 else 0
            if shift <= 0: continue
            worst = max(worst, shift)
            moved = np.zeros_like(cell)
            moved[shift:] = cell[:CELL - shift]
            sheet[r * CELL:(r + 1) * CELL, col * CELL:(col + 1) * CELL] = moved
    Image.fromarray(sheet).save(path)
    return worst


def main() -> None:
    tips = {}
    for enemy in IDS:
        action = FIELD / ACTION_BATCH.get(enemy, "batch_N2_v1") / f"{enemy}_action_64.png"
        walk = FIELD / WALK_BATCH.get(enemy, "batch_N2_v1") / f"{enemy}_walk_64.png"
        sheet = Image.open(action).convert("RGBA")
        rows = sheet.height // CELL
        want = 6 if enemy in EXTRA_ROW else 5
        if sheet.size != (8 * CELL, want * CELL): raise SystemExit(f"{action}: expected 8 × {want} cells, got {sheet.size}")
        if Image.open(walk).size != (8 * CELL, 4 * CELL): raise SystemExit(f"{walk}: expected 8 × 4 cells")
        shutil.copyfile(action, FIELD / f"enemy_dir_{enemy}_64.png")
        shutil.copyfile(walk, FIELD / f"enemy_walk_{enemy}_64.png")
        settle_walk(FIELD / f"enemy_walk_{enemy}_64.png")
        tips[enemy] = tips_of(sheet, enemy)
        print(f"{enemy}: {action.parent.name}, {rows} rows, tips {tips[enemy]}")
    fx_dir = FIELD / "fx"
    fx_dir.mkdir(exist_ok=True)
    for name in FX:
        shutil.copyfile(FIELD / "batch_N2_v3" / "fx" / f"{name}.png", fx_dir / f"{name}.png")
    lines = ["class_name EnemyN2Data", "extends RefCounted", "## GENERATED by art/install_n2_boards.py - do not edit by hand.",
        "## The new enemies' eight-direction sheets (装备扩充策划案 §2.1): each direction's",
        "## charge-pose tip in texels from the foot-line centre (columns S, SW, W, NW, N, NE, E, SE).", "const TIPS := {"]
    for enemy, row in tips.items():
        lines.append(f'\t"{enemy}": [' + ", ".join(f"Vector2({x}, {y})" for x, y in row) + "],")
    lines.append("}")
    lines.append("## Every one of them also has a 4-frame walk sheet.")
    lines.append("const WALK := [" + ", ".join(f'"{enemy}"' for enemy in IDS) + "]")
    lines.append("## The sixth action row, where a board has one.")
    lines.append("const EXTRA_ROW := {" + ", ".join(f'"{k}": "{v}"' for k, v in EXTRA_ROW.items()) + "}")
    (ROOT / "enemy_n2_data.gd").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote", ROOT / "enemy_n2_data.gd")


if __name__ == "__main__":
    main()
