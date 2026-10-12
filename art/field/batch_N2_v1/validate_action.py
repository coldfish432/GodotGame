"""Static contract checks for the painted and baked N2 action boards."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_action import ROWS_BY_ID
from build_walk import CELL, COLS, IDS

HERE = Path(__file__).resolve().parent


def bounds(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    yy, xx = np.where(mask)
    return (int(xx.min()), int(yy.min()), int(xx.max()), int(yy.max())) if len(xx) else None


def check(enemy_id: str) -> dict:
    rows = ROWS_BY_ID[enemy_id]
    source = Image.open(HERE / "source_paintings" / f"{enemy_id}_action_source.png").convert("RGBA")
    board = Image.open(HERE / f"{enemy_id}_action.png").convert("RGBA")
    baked = Image.open(HERE / f"{enemy_id}_action_64.png").convert("RGBA")
    preview = Image.open(HERE / f"{enemy_id}_action_64_x6.png").convert("RGBA")
    errors = []
    if source.getextrema()[3][0] != 0:
        errors.append("source lacks transparency")
    if board.size != (COLS * CELL, rows * CELL):
        errors.append(f"board dimensions {board.size}")
    if baked.size != (COLS * 64, rows * 64):
        errors.append(f"baked dimensions {baked.size}")
    if preview.size != (COLS * 64 * 6, rows * 64 * 6):
        errors.append(f"preview dimensions {preview.size}")
    a = np.asarray(baked)
    if preview.size == (COLS * 64 * 6, rows * 64 * 6) and not np.array_equal(np.asarray(preview), np.asarray(baked.resize(preview.size, Image.Resampling.NEAREST))):
        errors.append("preview is not an exact nearest-neighbour enlargement")
    if not set(np.unique(a[..., 3])).issubset({0, 255}):
        errors.append("baked alpha is not binary")
    empty = []
    clipped = []
    charge_metrics = []
    charge_threshold_exceptions = []
    light_counts = []
    for col in range(COLS):
        frames = [a[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64] for row in range(rows)]
        masks = [frame[..., 3] > 0 for frame in frames]
        for row, mask in enumerate(masks):
            box = bounds(mask)
            if box is None:
                empty.append([row, col])
            elif box[0] == 0 or box[1] == 0 or box[2] == 63 or box[3] == 63:
                clipped.append([row, col])
        idle = bounds(masks[0])
        charge = bounds(masks[2])
        if idle and charge:
            extent_change = max(abs(p - q) for p, q in zip(idle, charge))
            height_change = abs((idle[3] - idle[1]) - (charge[3] - charge[1]))
            changed = int(np.logical_xor(masks[0], masks[2]).sum())
            charge_metrics.append({"col": col, "extent_change_px": extent_change, "height_change_px": height_change, "silhouette_change_px": changed})
            if extent_change < 4 and height_change < 3:
                charge_threshold_exceptions.append(col)
            if changed < 8:
                errors.append(f"IDLE/CHARGE nearly identical direction {col}: {changed} pixels")
        if enemy_id in ("taint_husk", "distorted_caster", "fallen_snowpriest"):
            for row, frame in enumerate(frames):
                rgb = frame[..., :3].astype(int)
                if enemy_id == "fallen_snowpriest":
                    count = int(((rgb[..., 0] >= 150) & (rgb[..., 2] >= 240) & (rgb[..., 1] <= 230) & masks[row]).sum())
                else:
                    count = int(((rgb.min(axis=2) >= 240) & masks[row]).sum())
                light_counts.append({"row": row, "col": col, "pixels": count})
                if enemy_id == "fallen_snowpriest" and count < 1:
                    errors.append(f"violet orb missing row {row} direction {col}")
                if enemy_id != "fallen_snowpriest" and col in (0, 1, 2, 6, 7) and count < 1:
                    errors.append(f"white eye missing row {row} direction {col}")
    if empty:
        errors.append(f"empty cells {empty}")
    if clipped:
        errors.append(f"boundary contact {clipped}")
    return {"id": enemy_id, "status": "PASS" if not errors else "FAIL", "errors": errors, "rows": rows, "cells": rows * COLS, "charge_metrics": charge_metrics, "charge_threshold_exceptions": charge_threshold_exceptions, "light_counts": light_counts, "empty_cells": len(empty), "boundary_cells": len(clipped)}


def main() -> None:
    results = [check(enemy_id) for enemy_id in IDS]
    structural_pass = all(x["status"] == "PASS" for x in results)
    exceptions = {x["id"]: x["charge_threshold_exceptions"] for x in results if x["charge_threshold_exceptions"]}
    report = {"result": "FAIL" if not structural_pass else "PASS_WITH_NOTES" if exceptions else "PASS", "structural_result": "PASS" if structural_pass else "FAIL", "charge_threshold_exceptions": exceptions, "charge_metric_scope": "whole-sprite bounding-box extent change >=4 px or height change >=3 px; proxy for the brief's weapon/body signal, not isolated weapon tracking", "boards": len(results), "cells": sum(x["cells"] for x in results), "checks": results, "scope": "static asset and baked-frame checks only; no Godot import or playback"}
    (HERE / "action_qa_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(report["result"], report["boards"], "boards", report["cells"], "cells")
    for result in results:
        if result["errors"]:
            print(result["id"], result["errors"])
    if exceptions:
        print("charge threshold exceptions:", exceptions)
    if not structural_pass:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
