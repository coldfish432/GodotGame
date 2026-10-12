"""Static contract checks for the 17 painted N2 walking boards."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_walk import CELL, COLS, IDS, ROWS

HERE = Path(__file__).resolve().parent


def check(enemy_id: str) -> dict:
    source = Image.open(HERE / "source_paintings" / f"{enemy_id}_walk_source.png").convert("RGBA")
    board = Image.open(HERE / f"{enemy_id}_walk.png").convert("RGBA")
    baked = Image.open(HERE / f"{enemy_id}_walk_64.png").convert("RGBA")
    preview = Image.open(HERE / f"{enemy_id}_walk_64_x6.png").convert("RGBA")
    errors = []
    if source.getextrema()[3][0] != 0:
        errors.append("source lacks transparency")
    if board.size != (COLS * CELL, ROWS * CELL):
        errors.append(f"board dimensions {board.size}")
    if baked.size != (COLS * 64, ROWS * 64):
        errors.append(f"baked dimensions {baked.size}")
    if preview.size != (COLS * 64 * 6, ROWS * 64 * 6):
        errors.append(f"preview dimensions {preview.size}")
    a = np.asarray(baked)
    if preview.size == (COLS * 64 * 6, ROWS * 64 * 6) and not np.array_equal(np.asarray(preview), np.asarray(baked.resize(preview.size, Image.Resampling.NEAREST))):
        errors.append("preview is not an exact nearest-neighbour enlargement")
    if not set(np.unique(a[..., 3])).issubset({0, 255}):
        errors.append("baked alpha is not binary")
    empty = []
    clipped = []
    phase_changes = []
    for col in range(COLS):
        masks = []
        for row in range(ROWS):
            frame = a[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64]
            mask = frame[..., 3] > 0
            masks.append(mask)
            yy, xx = np.where(mask)
            if len(xx) == 0:
                empty.append([row, col])
            elif int(xx.min()) == 0 or int(xx.max()) == 63 or int(yy.min()) == 0 or int(yy.max()) == 63:
                clipped.append([row, col])
        phase_changes.extend(int(np.logical_xor(masks[row], masks[(row + 1) % ROWS]).sum()) for row in range(ROWS))
    if empty:
        errors.append(f"empty cells {empty}")
    if clipped:
        errors.append(f"boundary contact {clipped}")
    if phase_changes and min(phase_changes) == 0:
        errors.append("identical adjacent walking silhouette")
    lights = None
    if enemy_id in ("taint_husk", "distorted_caster"):
        lights = []
        for row in range(ROWS):
            row_counts = []
            for col in range(COLS):
                frame = a[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64]
                row_counts.append(int(((frame[..., :3].min(axis=2) >= 240) & (frame[..., 3] > 0)).sum()))
            lights.append(row_counts)
            if any(row_counts[col] < 1 for col in (0, 1, 2, 6, 7)) or any(row_counts[col] > 0 for col in (3, 4, 5)):
                errors.append(f"white eye-light row {row}: {row_counts}")
    elif enemy_id == "fallen_snowpriest":
        lights = []
        for row in range(ROWS):
            row_counts = []
            for col in range(COLS):
                frame = a[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64]
                rgb = frame[..., :3].astype(int)
                row_counts.append(int(((rgb[..., 0] >= 150) & (rgb[..., 2] >= 240) & (rgb[..., 1] <= 230) & (frame[..., 3] > 0)).sum()))
            lights.append(row_counts)
            if any(n < 1 for n in row_counts):
                errors.append(f"violet orb row {row}: {row_counts}")
    return {"id": enemy_id, "status": "PASS" if not errors else "FAIL", "errors": errors, "source_size": list(source.size), "board_size": list(board.size), "baked_size": list(baked.size), "empty_cells": len(empty), "boundary_cells": len(clipped), "min_adjacent_silhouette_change_px": min(phase_changes), "lights_by_row_direction": lights}


def main() -> None:
    results = [check(enemy_id) for enemy_id in IDS]
    summary = {"result": "PASS" if all(x["status"] == "PASS" for x in results) else "FAIL", "boards": len(results), "cells": len(results) * COLS * ROWS, "checks": results, "scope": "static asset and baked-frame checks only; no Godot import or playback"}
    (HERE / "qa_report.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(summary["result"], summary["boards"], "boards", summary["cells"], "cells")
    for x in results:
        if x["errors"]:
            print(x["id"], x["errors"])
    if summary["result"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
