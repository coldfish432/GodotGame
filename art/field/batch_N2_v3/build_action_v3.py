"""Package the painted v3 hornbeast board, preserving accepted v2 side strikes."""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
V2 = FIELD / "batch_N2_v2"
sys.path.insert(0, str(V2))
from build_action_v2 import runs  # noqa: E402

CELL = 320
ROWS = 5
COLS = 8


def main() -> None:
    source_path = HERE / "source_paintings" / "rock_hornbeast_action_source.png"
    source = Image.open(source_path).convert("RGBA")
    alpha = np.asarray(source.getchannel("A")) > 128
    row_spans = runs(alpha.any(axis=1), 25)
    if len(row_spans) != ROWS:
        raise ValueError(f"expected {ROWS} row spans; got {row_spans}")
    board = Image.new("RGBA", (COLS * CELL, ROWS * CELL))
    records = []
    for row, (y0, y1) in enumerate(row_spans):
        cols = runs(alpha[y0:y1].any(axis=0), 25)
        if len(cols) != COLS:
            raise ValueError(f"row {row}: expected {COLS} pose columns; got {cols}")
        for col, (x0, x1) in enumerate(cols):
            pose = source.crop((x0, y0, x1, y1))
            bounds = pose.getchannel("A").point(lambda value: 255 if value > 128 else 0).getbbox()
            if bounds is None:
                raise ValueError(f"empty painted pose {row},{col}")
            pose = pose.crop(bounds)
            if pose.width > CELL - 32 or pose.height > CELL - 32:
                raise ValueError(f"oversize painted pose {row},{col}: {pose.size}")
            x = col * CELL + (CELL - pose.width) // 2
            y = row * CELL + 300 - pose.height
            board.alpha_composite(pose, (x, y))
            records.append({"row": row, "col": col, "source_bbox": [x0+bounds[0], y0+bounds[1], x0+bounds[2], y0+bounds[3]], "size": list(pose.size), "preserved_v2": False})

    # A separately painted, truly low-headed W charge supplies both mirror side views.
    side_path = HERE / "source_paintings" / "rock_hornbeast_side_charge_source.png"
    side_source = Image.open(side_path).convert("RGBA")
    side_bounds = side_source.getchannel("A").point(lambda value: 255 if value > 128 else 0).getbbox()
    if side_bounds is None:
        raise ValueError("side charge source is empty")
    side = side_source.crop(side_bounds).resize((220, 132), Image.Resampling.LANCZOS)
    for col, figure in ((2, side), (6, ImageOps.mirror(side))):
        area = (col * CELL, 2 * CELL, (col + 1) * CELL, 3 * CELL)
        board.paste(Image.new("RGBA", (CELL, CELL)), area)
        board.alpha_composite(figure, (col * CELL + (CELL - figure.width) // 2, 2 * CELL + 300 - figure.height))
        records[2 * COLS + col]["source_bbox"] = list(side_bounds)
        records[2 * COLS + col]["size"] = list(figure.size)
        records[2 * COLS + col]["side_charge_source"] = side_path.name

    # Front/rear charge and strike were painted separately to keep muzzle, horns
    # and fleece as three legible masses rather than one round silhouette.
    frontback_path = HERE / "source_paintings" / "rock_hornbeast_frontback_source.png"
    frontback = Image.open(frontback_path).convert("RGBA")
    fb_alpha = np.asarray(frontback.getchannel("A")) > 128
    fb_rows = runs(fb_alpha.any(axis=1), 25)
    if len(fb_rows) != ROWS:
        raise ValueError(f"front/rear source rows: {fb_rows}")
    for row in (2, 3):
        y0, y1 = fb_rows[row]
        fb_cols = runs(fb_alpha[y0:y1].any(axis=0), 25)
        if len(fb_cols) != 2:
            raise ValueError(f"front/rear source row {row} columns: {fb_cols}")
        for col, (x0, x1) in ((0, fb_cols[0]), (4, fb_cols[1])):
            figure = frontback.crop((x0, y0, x1, y1))
            bounds = figure.getchannel("A").point(lambda value: 255 if value > 128 else 0).getbbox()
            if bounds is None:
                raise ValueError(f"front/rear source empty {row},{col}")
            figure = figure.crop(bounds)
            figure.putalpha(figure.getchannel("A").point(lambda value: 255 if value > 128 else 0))
            figure = figure.resize((round(figure.width * 0.46), round(figure.height * 0.46)), Image.Resampling.LANCZOS)
            area = (col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL)
            board.paste(Image.new("RGBA", (CELL, CELL)), area)
            board.alpha_composite(figure, (col * CELL + (CELL - figure.width) // 2, row * CELL + 300 - figure.height))
            records[row * COLS + col]["source_bbox"] = [x0+bounds[0], y0+bounds[1], x0+bounds[2], y0+bounds[3]]
            records[row * COLS + col]["size"] = list(figure.size)
            records[row * COLS + col]["frontback_source"] = frontback_path.name

    # The v2 W/E upward horn hook was accepted explicitly by the v3 brief.
    accepted = Image.open(V2 / "rock_hornbeast_action.png").convert("RGBA")
    for col in (2, 6):
        area = (col * CELL, 3 * CELL, (col + 1) * CELL, 4 * CELL)
        board.paste(accepted.crop(area), area)
        records[3 * COLS + col]["preserved_v2"] = True

    out = HERE / "rock_hornbeast_action.png"
    board.save(out)
    subprocess.run([sys.executable, str(FIELD / "bake_n2.py"), str(out), "rock_hornbeast", str(ROWS)], check=True)
    baked_path = HERE / "rock_hornbeast_action_64.png"
    baked = Image.open(baked_path).convert("RGBA")
    baked_v2 = Image.open(V2 / "rock_hornbeast_action_64.png").convert("RGBA")
    for col in (2, 6):
        area = (col * 64, 3 * 64, (col + 1) * 64, 4 * 64)
        baked.paste(baked_v2.crop(area), area)
    baked.save(baked_path)
    baked.resize((COLS * 64 * 6, ROWS * 64 * 6), Image.Resampling.NEAREST).save(HERE / "rock_hornbeast_action_64_x6.png")
    report = {"source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(), "side_source_sha256": hashlib.sha256(side_path.read_bytes()).hexdigest(), "frontback_source_sha256": hashlib.sha256(frontback_path.read_bytes()).hexdigest(), "source_size": list(source.size), "board_size": list(board.size), "frames": records, "accepted_v2_strikes": [2, 6], "accepted_v2_baked_cells_copied": True}
    (HERE / "action_build_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("built rock_hornbeast v3 board")


if __name__ == "__main__":
    main()
