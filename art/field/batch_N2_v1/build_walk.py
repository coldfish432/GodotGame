"""Package painted N2 walk boards into clean 320 px cells and bake them.

The source images in source_paintings/ are the authored art. This script only
extracts their existing 8 x 4 frames, centers them on a uniform transparent
grid, and invokes the project's N2 bake without redrawing figures.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
sys.path.insert(0, str(FIELD))
from reduce_n1 import EYES, FIGURES, components, find_light, stamp  # noqa: E402

CELL = 320
COLS = 8
ROWS = 4
IDS = (
    "armed", "caster", "shield", "slug_volatile", "picket",
    "greytail", "greytail_lord", "thrower", "bully", "avenger", "breacher",
    "taint_husk", "distorted_caster", "shattered_champion", "shell_vine",
    "rock_hornbeast", "fallen_snowpriest",
)


def column_bounds(source: Image.Image) -> list[int]:
    """Find figure gaps; generated art is not guaranteed to start at x=0."""
    alpha = np.asarray(source.getchannel("A")) > 128
    for row in range(ROWS):
        y0 = round(row * source.height / ROWS)
        y1 = round((row + 1) * source.height / ROWS)
        occupied = alpha[y0:y1].any(axis=0)
        starts = np.where(occupied & ~np.r_[False, occupied[:-1]])[0]
        ends = np.where(occupied & ~np.r_[occupied[1:], False])[0] + 1
        figures = [(int(start), int(end)) for start, end in zip(starts, ends) if end - start > 30]
        if len(figures) == COLS:
            projection = alpha.sum(axis=0)
            bounds = [0]
            for left, right in zip(figures, figures[1:]):
                middle = (left[1] + right[0]) // 2
                candidates = range(max(bounds[-1] + 1, middle - 12), min(source.width, middle + 13))
                bounds.append(min(candidates, key=lambda x: (int(projection[x]), abs(x - middle))))
            return bounds + [source.width]
    raise ValueError("could not locate eight distinct figure columns")


def preserve_sami_lights(enemy_id: str, board: Image.Image, baked_path: Path, rows: int = ROWS) -> int:
    """Reapply N1's native-pixel eye-light treatment after box reduction."""
    if enemy_id not in EYES:
        return 0
    sheet = Image.open(baked_path).convert("RGBA")
    first = np.asarray(board.crop((0, 0, CELL, CELL)))
    first_y = np.where(first[..., 3] > 128)[0]
    scale = FIGURES[enemy_id][2] / (int(first_y.max()) - int(first_y.min()) + 1)
    count = 0
    for row in range(rows):
        for col in range(COLS):
            source = np.asarray(board.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL)))
            yy, xx = np.where(source[..., 3] > 128)
            if len(xx) == 0:
                continue
            y0, x0 = int(yy.min()), int(xx.min())
            fig = source[y0:int(yy.max()) + 1, x0:int(xx.max()) + 1]
            lights = []
            if enemy_id in ("taint_husk", "distorted_caster") and col not in (3, 4, 5):
                kind, region, style = EYES[enemy_id][0]
                hit = find_light(fig, kind, region)
                if hit is None:
                    # Strong action lean can move a painted eye outside the
                    # N1 standing-pose search region. The bright eye remains
                    # in the upper half; weapon highlights are lower down.
                    upper = max(1, int(fig.shape[0] * 0.55))
                    bright = (fig[:upper, :, 3] > 128) & (fig[:upper, :, :3].min(axis=2) >= 235)
                    sy, sx = np.where(bright)
                    if len(sx):
                        hit = (float(sy.mean()), float(sx.mean()))
                if hit is not None:
                    lights.append((hit[0], hit[1], style))
            elif enemy_id == "fallen_snowpriest":
                rgb = fig[..., :3].astype(int)
                violet = (fig[..., 3] > 128) & (rgb[..., 2] > rgb[..., 1] + 35) & (rgb[..., 2] > 130)
                spots = sorted((part for part in components(violet) if len(part) >= 50), key=lambda part: part[:, 0].mean())
                if col in (3, 4, 5):
                    if spots:
                        sy, sx = spots[0].mean(axis=0)
                        lights.append((sy, sx, "orb_small"))
                elif len(spots) >= 2:
                    for spot, style in ((spots[0], "orb_small"), (spots[-1], "orb")):
                        sy, sx = spot.mean(axis=0)
                        lights.append((sy, sx, style))
                elif spots:
                    sy, sx = spots[0].mean(axis=0)
                    lights.append((sy, sx, "orb"))
            baked = np.asarray(sheet.crop((col * 64, row * 64, (col + 1) * 64, (row + 1) * 64)))
            by, bx = np.where(baked[..., 3] > 0)
            if len(bx) == 0:
                continue
            for sy, sx, style in lights:
                target_y = row * 64 + int(by.min()) + 1 + round(float(sy) * scale)
                target_x = col * 64 + int(bx.min()) + 1 + round(float(sx) * scale)
                stamp(sheet, (target_y, target_x), style)
                count += 1
    sheet.save(baked_path)
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.Resampling.NEAREST).save(baked_path.with_name(baked_path.stem + "_x6.png"))
    return count


def make_board(enemy_id: str) -> dict:
    source_path = HERE / "source_paintings" / f"{enemy_id}_walk_source.png"
    source = Image.open(source_path).convert("RGBA")
    board = Image.new("RGBA", (COLS * CELL, ROWS * CELL))
    bounds = column_bounds(source)
    boxes = []
    for row in range(ROWS):
        for col in range(COLS):
            x0 = bounds[col]
            x1 = bounds[col + 1]
            y0 = round(row * source.height / ROWS)
            y1 = round((row + 1) * source.height / ROWS)
            frame = source.crop((x0, y0, x1, y1))
            mask = np.asarray(frame.getchannel("A")) > 128
            yy, xx = np.where(mask)
            if len(xx) == 0:
                raise ValueError(f"empty frame: {enemy_id} row={row} col={col}")
            frame = frame.crop((int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1))
            # The selected four-legged painting faces right in its W/SW poses.
            # Reflect these painted frames so the heading matches the N2 grid.
            if enemy_id == "rock_hornbeast" and col in (1, 2):
                frame = ImageOps.mirror(frame)
            if frame.width > CELL - 40 or frame.height > CELL - 40:
                raise ValueError(f"frame too large: {enemy_id} row={row} col={col} {frame.size}")
            px = col * CELL + (CELL - frame.width) // 2
            py = row * CELL + 300 - frame.height
            board.alpha_composite(frame, (px, py))
            boxes.append({"row": row, "col": col, "source_bbox": [int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1], "size": list(frame.size)})
    path = HERE / f"{enemy_id}_walk.png"
    board.save(path)
    subprocess.run([sys.executable, str(FIELD / "bake_n2.py"), str(path), enemy_id, "4"], check=True)
    stamped = preserve_sami_lights(enemy_id, board, HERE / f"{enemy_id}_walk_64.png")
    return {"id": enemy_id, "source": source_path.name, "source_size": list(source.size), "column_bounds": bounds, "board_size": list(board.size), "light_stamps": stamped, "frames": boxes}


def main() -> None:
    records = [make_board(enemy_id) for enemy_id in IDS]
    (HERE / "walk_build_report.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(f"built {len(records)} walk boards / {len(records) * COLS * ROWS} frames")


if __name__ == "__main__":
    main()
