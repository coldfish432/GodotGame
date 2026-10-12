"""Extract painted 8-direction attack poses and bake clean N2 action boards."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

from build_walk import CELL, COLS, FIELD, HERE, IDS, preserve_sami_lights

ROWS_BY_ID = {enemy_id: (6 if enemy_id in {"picket", "greytail", "greytail_lord", "distorted_caster"} else 5) for enemy_id in IDS}
SOURCE_ROW_MAP = {"greytail_lord": [0, 1, 2, 3, 1, 4]}


def occupied_runs(occupied: np.ndarray, minimum: int) -> list[tuple[int, int]]:
    starts = np.where(occupied & ~np.r_[False, occupied[:-1]])[0]
    ends = np.where(occupied & ~np.r_[occupied[1:], False])[0] + 1
    return [(int(start), int(end)) for start, end in zip(starts, ends) if end - start >= minimum]


def keep_largest_component(figure: Image.Image) -> Image.Image:
    """Remove a disconnected spill from an adjacent painted grid row."""
    pixels = np.asarray(figure).copy()
    mask = pixels[..., 3] > 128
    visited = np.zeros(mask.shape, dtype=bool)
    largest = []
    height, width = mask.shape
    for sy, sx in zip(*np.where(mask & ~visited)):
        if visited[sy, sx]:
            continue
        stack = [(int(sy), int(sx))]
        visited[sy, sx] = True
        component = []
        while stack:
            y, x = stack.pop()
            component.append((y, x))
            for ny in (y - 1, y, y + 1):
                for nx in (x - 1, x, x + 1):
                    if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = True
                        stack.append((ny, nx))
        if len(component) > len(largest):
            largest = component
    keep = np.zeros(mask.shape, dtype=bool)
    for y, x in largest:
        keep[y, x] = True
    pixels[~keep, 3] = 0
    return Image.fromarray(pixels, "RGBA")


def clean_baked_thrower_start(baked_path: Path) -> None:
    """Discard tiny detached charge-glow spill under the START row."""
    sheet = Image.open(baked_path).convert("RGBA")
    for col in range(COLS):
        box = (col * 64, 64, (col + 1) * 64, 128)
        sheet.paste(keep_largest_component(sheet.crop(box)), box)
    sheet.save(baked_path)
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.Resampling.NEAREST).save(baked_path.with_name(baked_path.stem + "_x6.png"))


def make_board(enemy_id: str) -> dict:
    rows = ROWS_BY_ID[enemy_id]
    source_path = HERE / "source_paintings" / f"{enemy_id}_action_source.png"
    source = Image.open(source_path).convert("RGBA")
    alpha = np.asarray(source.getchannel("A")) > 128
    row_runs = occupied_runs(alpha.any(axis=1), 30)
    row_map = SOURCE_ROW_MAP.get(enemy_id, list(range(rows)))
    grid_rows = False
    if len(row_runs) != max(row_map) + 1:
        if enemy_id not in {"fallen_snowpriest", "thrower"}:
            raise ValueError(f"{enemy_id}: expected {max(row_map) + 1} painted pose rows, found {row_runs}")
        grid_rows = True
        row_runs = []
        for source_row in range(max(row_map) + 1):
            top = round(source_row * source.height / (max(row_map) + 1))
            bottom = round((source_row + 1) * source.height / (max(row_map) + 1))
            active = np.where(alpha[top:bottom].any(axis=1))[0]
            if len(active) == 0:
                raise ValueError(f"{enemy_id}: empty source row {source_row}")
            row_runs.append((top + int(active[0]), top + int(active[-1]) + 1))
    board = Image.new("RGBA", (COLS * CELL, rows * CELL))
    charge_strip = None
    charge_strip_runs = None
    if enemy_id in {"caster", "distorted_caster", "rock_hornbeast"}:
        charge_strip = Image.open(HERE / "source_paintings" / f"{enemy_id}_action_charge_source.png").convert("RGBA")
        charge_alpha = np.asarray(charge_strip.getchannel("A")) > 128
        charge_strip_runs = occupied_runs(charge_alpha.any(axis=0), 25)
        charge_y = np.where(charge_alpha.any(axis=1))[0]
        if len(charge_strip_runs) != COLS or len(charge_y) == 0:
            raise ValueError(f"{enemy_id}: charge strip must have eight separate figures")
    frames = []
    grid_crops = []
    for row, source_row in enumerate(row_map):
        y0, y1 = row_runs[source_row]
        col_runs = occupied_runs(alpha[y0:y1].any(axis=0), 25)
        if len(col_runs) != COLS:
            # Long held weapons can touch the next painted figure. Use the
            # regular source grid for that row and record the fallback.
            grid_crops.append(row)
            col_runs = []
            for col in range(COLS):
                left = round(col * source.width / COLS)
                right = round((col + 1) * source.width / COLS)
                slot = alpha[y0:y1, left:right]
                active = np.where(slot.any(axis=0))[0]
                if len(active) == 0:
                    raise ValueError(f"{enemy_id}: empty grid slot ({row}, {col})")
                col_runs.append((left + int(active[0]), left + int(active[-1]) + 1))
        for col, (x0, x1) in enumerate(col_runs):
            figure = source.crop((x0, y0, x1, y1))
            frame_source = source_path.name
            if charge_strip is not None and row == 2:
                x0, x1 = charge_strip_runs[col]
                y0, y1 = int(charge_y.min()), int(charge_y.max()) + 1
                figure = charge_strip.crop((x0, y0, x1, y1))
                frame_source = f"{enemy_id}_action_charge_source.png"
            if enemy_id in {"fallen_snowpriest", "thrower"} and row == 1:
                figure = keep_largest_component(figure)
            strip_limit = CELL - 64 if enemy_id == "rock_hornbeast" else CELL - 32
            if charge_strip is not None and row == 2 and (figure.width > strip_limit or figure.height > strip_limit):
                factor = min(strip_limit / figure.width, strip_limit / figure.height)
                figure = figure.resize((round(figure.width * factor), round(figure.height * factor)), Image.Resampling.LANCZOS)
            if figure.width > CELL - 32 or figure.height > CELL - 32:
                raise ValueError(f"{enemy_id}: oversized painted figure ({row}, {col}) {figure.size}")
            px = col * CELL + (CELL - figure.width) // 2
            py = row * CELL + 300 - figure.height
            board.alpha_composite(figure, (px, py))
            frames.append({"row": row, "col": col, "frame_source": frame_source, "source_bbox": [x0, y0, x1, y1], "size": list(figure.size)})
    out = HERE / f"{enemy_id}_action.png"
    board.save(out)
    subprocess.run([sys.executable, str(FIELD / "bake_n2.py"), str(out), enemy_id, str(rows)], check=True)
    if enemy_id == "thrower":
        clean_baked_thrower_start(HERE / f"{enemy_id}_action_64.png")
    lights = preserve_sami_lights(enemy_id, board, HERE / f"{enemy_id}_action_64.png", rows)
    return {"id": enemy_id, "rows": rows, "source_row_map": row_map, "source_grid_rows": grid_rows, "grid_crop_rows": grid_crops, "source": source_path.name, "source_size": list(source.size), "board_size": list(board.size), "light_stamps": lights, "frames": frames}


def main() -> None:
    targets = sys.argv[1:] or list(IDS)
    report_path = HERE / "action_build_report.json"
    records = {record["id"]: record for record in json.loads(report_path.read_text(encoding="utf-8"))} if report_path.exists() else {}
    for enemy_id in targets:
        if enemy_id not in ROWS_BY_ID:
            raise ValueError(f"unknown enemy id: {enemy_id}")
        records[enemy_id] = make_board(enemy_id)
    report_path.write_text(json.dumps([records[enemy_id] for enemy_id in IDS if enemy_id in records], indent=2), encoding="utf-8")
    print(f"built {len(targets)} action boards")


if __name__ == "__main__":
    main()
