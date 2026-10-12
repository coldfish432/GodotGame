"""Package the six selected painted N2 v2 action sources into clean grids."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
V1 = FIELD / "batch_N2_v1"
sys.path.insert(0, str(V1))
from build_walk import preserve_sami_lights  # noqa: E402

IDS = ("slug_volatile", "rock_hornbeast", "caster", "distorted_caster", "greytail", "greytail_lord")
COLS = 8
CELL = 320
ROWS = {enemy_id: 6 if enemy_id == "distorted_caster" else 5 for enemy_id in IDS}


def runs(values: np.ndarray, minimum: int) -> list[tuple[int, int]]:
    starts = np.where(values & ~np.r_[False, values[:-1]])[0]
    ends = np.where(values & ~np.r_[values[1:], False])[0] + 1
    return [(int(a), int(b)) for a, b in zip(starts, ends) if b - a >= minimum]


def build(enemy_id: str) -> dict:
    source_path = HERE / "source_paintings" / f"{enemy_id}_action_source.png"
    source = Image.open(source_path).convert("RGBA")
    alpha = np.asarray(source.getchannel("A")) > 128
    row_spans = runs(alpha.any(axis=1), 25)
    rows = ROWS[enemy_id]
    if len(row_spans) != rows:
        raise ValueError(f"{enemy_id}: expected {rows} rows, found {row_spans}")
    board = Image.new("RGBA", (COLS * CELL, rows * CELL))
    frames = []
    for row, (y0, y1) in enumerate(row_spans):
        col_spans = runs(alpha[y0:y1].any(axis=0), 25)
        grid_crop = len(col_spans) != COLS
        if grid_crop:
            col_spans = [(round(col * source.width / COLS), round((col + 1) * source.width / COLS)) for col in range(COLS)]
        for col, (x0, x1) in enumerate(col_spans):
            figure = source.crop((x0, y0, x1, y1))
            bounds = figure.getchannel("A").point(lambda value: 255 if value > 128 else 0).getbbox()
            if bounds is None:
                raise ValueError(f"{enemy_id}: empty pose ({row}, {col})")
            figure = figure.crop(bounds)
            if figure.width > CELL - 32 or figure.height > CELL - 32:
                raise ValueError(f"{enemy_id}: oversized pose ({row}, {col}) {figure.size}")
            px = col * CELL + (CELL - figure.width) // 2
            py = row * CELL + 300 - figure.height
            board.alpha_composite(figure, (px, py))
            frames.append({"row": row, "col": col, "source_bbox": [x0 + bounds[0], y0 + bounds[1], x0 + bounds[2], y0 + bounds[3]], "size": list(figure.size), "grid_crop": grid_crop})
    output = HERE / f"{enemy_id}_action.png"
    board.save(output)
    subprocess.run([sys.executable, str(FIELD / "bake_n2.py"), str(output), enemy_id, str(rows)], check=True)
    lights = preserve_sami_lights(enemy_id, board, HERE / f"{enemy_id}_action_64.png", rows)
    return {"id": enemy_id, "rows": rows, "source": source_path.name, "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(), "source_size": list(source.size), "board_size": list(board.size), "light_stamps": lights, "frames": frames}


def main() -> None:
    targets = sys.argv[1:] or list(IDS)
    report_path = HERE / "action_build_report.json"
    existing = {record["id"]: record for record in json.loads(report_path.read_text(encoding="utf-8"))} if report_path.exists() else {}
    for enemy_id in targets:
        if enemy_id not in IDS:
            raise ValueError(f"unknown v2 id: {enemy_id}")
        existing[enemy_id] = build(enemy_id)
    report_path.write_text(json.dumps([existing[enemy_id] for enemy_id in IDS if enemy_id in existing], indent=2), encoding="utf-8")
    print(f"built {len(targets)} v2 action boards")


if __name__ == "__main__":
    main()
