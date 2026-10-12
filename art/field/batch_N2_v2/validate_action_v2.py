"""Static geometry and packaging checks for the six N2 action revisions and shield FX."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_action_v2 import COLS, HERE, IDS, ROWS

PALETTE = {(255, 255, 255), (230, 236, 242), (196, 204, 214), (154, 164, 176)}


def box(mask: np.ndarray) -> list[int] | None:
    yy, xx = np.where(mask)
    return [int(xx.min()), int(yy.min()), int(xx.max()), int(yy.max())] if len(xx) else None


def board_check(enemy_id: str, manifest: dict) -> dict:
    rows = ROWS[enemy_id]
    errors: list[str] = []
    source_path = HERE / "source_paintings" / f"{enemy_id}_action_source.png"
    source = Image.open(source_path).convert("RGBA")
    board = Image.open(HERE / f"{enemy_id}_action.png").convert("RGBA")
    baked = Image.open(HERE / f"{enemy_id}_action_64.png").convert("RGBA")
    preview = Image.open(HERE / f"{enemy_id}_action_64_x6.png").convert("RGBA")
    if hashlib.sha256(source_path.read_bytes()).hexdigest() != manifest["source_sha256"]:
        errors.append("source hash differs from build manifest")
    if source.getextrema()[3][0] != 0:
        errors.append("source background is opaque")
    for title, image, expected in (
        ("board", board, (2560, rows * 320)),
        ("baked", baked, (512, rows * 64)),
        ("preview", preview, (3072, rows * 384)),
    ):
        if image.size != expected:
            errors.append(f"{title} dimensions {image.size}, expected {expected}")
    if not np.array_equal(np.asarray(preview), np.asarray(baked.resize(preview.size, Image.Resampling.NEAREST))):
        errors.append("preview differs from exact nearest-neighbour x6")
    pixels = np.asarray(baked)
    if not set(np.unique(pixels[..., 3])).issubset({0, 255}):
        errors.append("baked alpha is not binary")
    frame_boxes = []
    charge_metrics = []
    for row in range(rows):
        for col in range(COLS):
            mask = pixels[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64, 3] > 0
            bbox = box(mask)
            frame_boxes.append(bbox)
            if bbox is None:
                errors.append(f"empty cell row {row} col {col}")
            elif 0 in bbox[:2] or 63 in bbox[2:]:
                errors.append(f"boundary contact row {row} col {col}")
    for col in range(COLS):
        idle = frame_boxes[col]
        charge = frame_boxes[2 * COLS + col]
        if idle and charge:
            idle_height = idle[3] - idle[1] + 1
            charge_height = charge[3] - charge[1] + 1
            idle_width = idle[2] - idle[0] + 1
            charge_width = charge[2] - charge[0] + 1
            height_delta = charge_height - idle_height
            width_ratio = round(charge_width / idle_width, 3)
            charge_metrics.append({"direction": col, "height_delta_px": height_delta, "width_ratio": width_ratio})
            if enemy_id == "slug_volatile" and height_delta < 4:
                errors.append(f"slug charge height gain under 4 px in direction {col}")
            if enemy_id in ("caster", "distorted_caster", "rock_hornbeast") and width_ratio > 1.25:
                errors.append(f"charge figure grows too wide in direction {col}: {width_ratio}")
            if enemy_id in ("distorted_caster", "rock_hornbeast") and height_delta > 4:
                errors.append(f"charge figure grows too tall in direction {col}: {height_delta}")
    if enemy_id == "distorted_caster":
        eye_counts = []
        for row in range(rows):
            for col in (0, 1, 2, 6, 7):
                cell = pixels[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64]
                count = int(((cell[..., :3].min(axis=2) >= 240) & (cell[..., 3] > 0)).sum())
                eye_counts.append(count)
                if count < 1:
                    errors.append(f"face light missing row {row} direction {col}")
    else:
        eye_counts = []
    return {"id": enemy_id, "rows": rows, "cells": COLS * rows, "status": "PASS" if not errors else "FAIL", "errors": errors, "charge_metrics": charge_metrics, "eye_light_min_px": min(eye_counts) if eye_counts else None}


def fx_check() -> dict:
    errors: list[str] = []
    names = {"barrier_shell.png": 4, "barrier_break.png": 5, "barrier_hit.png": 2}
    assets = {}
    for name, frames in names.items():
        image = Image.open(HERE / "fx" / name).convert("RGBA")
        array = np.asarray(image)
        if image.size != (frames * 64, 64):
            errors.append(f"{name} dimensions {image.size}")
        if not set(np.unique(array[..., 3])).issubset({0, 255}):
            errors.append(f"{name} alpha is not binary")
        colors = set(map(tuple, array[array[..., 3] > 0, :3]))
        if not colors.issubset(PALETTE):
            errors.append(f"{name} has colors outside neutral palette: {colors - PALETTE}")
        assets[name] = {"frames": frames, "visible_colors": sorted('#%02x%02x%02x' % c for c in colors)}
    shell = np.asarray(Image.open(HERE / "fx" / "barrier_shell.png").convert("RGBA"))
    from PIL import ImageDraw
    rim_image = Image.new("1", (64, 64))
    ImageDraw.Draw(rim_image).ellipse((17, 13, 47, 53), outline=1, width=1)
    rim = np.asarray(rim_image, dtype=bool)
    y, x = np.ogrid[:64, :64]
    inside = ((x - 32) / 13) ** 2 + ((y - 33) / 18) ** 2 < 1
    coverages = []
    rim_masks = []
    for col in range(4):
        mask = shell[:, col * 64:(col + 1) * 64, 3] > 0
        bbox = box(mask)
        if bbox != [17, 13, 47, 53]:
            errors.append(f"shell {col} bounds {bbox}")
        rim_masks.append(mask & rim)
        coverages.append(round(float((mask & inside).sum() / inside.sum()), 3))
        if not 0.15 <= coverages[-1] <= 0.20:
            errors.append(f"shell {col} interior coverage {coverages[-1]}")
    if not all(np.array_equal(rim_masks[0], other) for other in rim_masks[1:]):
        errors.append("shell rim pixels jitter between loop frames")
    preview = Image.open(HERE / "fx" / "barrier_preview_x6.png")
    if preview.width < 6 * 64 * 3 or preview.height < 6 * 64 * 2:
        errors.append("barrier preview too small for six overlaid poses")
    concept = HERE / "source_paintings" / "barrier_concept.png"
    if not concept.exists():
        errors.append("barrier painted concept missing")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors, "assets": assets, "shell_interior_coverage": coverages, "rim_static": not any(error.startswith("shell rim") for error in errors), "concept_sha256": hashlib.sha256(concept.read_bytes()).hexdigest() if concept.exists() else None}


def main() -> None:
    manifest = {item["id"]: item for item in json.loads((HERE / "action_build_report.json").read_text(encoding="utf-8"))}
    checks = [board_check(enemy_id, manifest[enemy_id]) for enemy_id in IDS]
    fx = fx_check()
    reviews = {region: (HERE / f"{region}_action_review.png").exists() for region in ("mine", "city", "sami")}
    success = all(check["status"] == "PASS" for check in checks) and fx["status"] == "PASS" and all(reviews.values())
    report = {"result": "PASS" if success else "FAIL", "boards": len(checks), "cells": sum(check["cells"] for check in checks), "checks": checks, "fx": fx, "reviews": reviews, "scope": "static pixel-art asset checks and visual review; no Godot import or runtime playback"}
    (HERE / "action_qa_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(report["result"], report["boards"], "boards", report["cells"], "cells", "FX", fx["status"])
    for check in checks:
        if check["errors"]:
            print(check["id"], check["errors"])
    if fx["errors"]:
        print("FX", fx["errors"])
    if not success:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
