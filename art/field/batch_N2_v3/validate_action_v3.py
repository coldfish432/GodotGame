"""Static N2 v3 action/FX contract checks; not a Godot runtime test."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
V2 = FIELD / "batch_N2_v2"
PALETTE = {(255, 255, 255), (230, 236, 242), (196, 204, 214), (154, 164, 176)}


def bounds(mask: np.ndarray) -> list[int] | None:
    yy, xx = np.where(mask)
    return [int(xx.min()), int(yy.min()), int(xx.max()), int(yy.max())] if len(xx) else None


def action_check() -> dict:
    errors: list[str] = []
    manifest = json.loads((HERE / "action_build_report.json").read_text(encoding="utf-8"))
    for key, filename in (
        ("source_sha256", "rock_hornbeast_action_source.png"),
        ("side_source_sha256", "rock_hornbeast_side_charge_source.png"),
        ("frontback_source_sha256", "rock_hornbeast_frontback_source.png"),
    ):
        path = HERE / "source_paintings" / filename
        if hashlib.sha256(path.read_bytes()).hexdigest() != manifest[key]:
            errors.append(f"source hash mismatch: {filename}")
    board = Image.open(HERE / "rock_hornbeast_action.png").convert("RGBA")
    baked = Image.open(HERE / "rock_hornbeast_action_64.png").convert("RGBA")
    preview = Image.open(HERE / "rock_hornbeast_action_64_x6.png").convert("RGBA")
    if board.size != (2560, 1600):
        errors.append(f"board dimensions {board.size}")
    if baked.size != (512, 320):
        errors.append(f"baked dimensions {baked.size}")
    if preview.size != (3072, 1920):
        errors.append(f"preview dimensions {preview.size}")
    if not np.array_equal(np.asarray(preview), np.asarray(baked.resize(preview.size, Image.Resampling.NEAREST))):
        errors.append("preview is not exact nearest-neighbour x6")
    pixels = np.asarray(baked)
    if not set(np.unique(pixels[..., 3])).issubset({0, 255}):
        errors.append("baked alpha is not binary")
    frame_bounds = {}
    for row in range(5):
        for col in range(8):
            mask = pixels[row*64:(row+1)*64, col*64:(col+1)*64, 3] > 0
            bbox = bounds(mask)
            frame_bounds[f"{row},{col}"] = bbox
            if bbox is None:
                errors.append(f"empty cell {row},{col}")
            elif bbox[0] == 0 or bbox[1] == 0 or bbox[2] == 63 or bbox[3] == 63:
                errors.append(f"boundary contact {row},{col}")
            if bbox and bbox[3] not in (50, 51):
                errors.append(f"feet line {row},{col} at y={bbox[3]}")
    side_metrics = {}
    for col, heading in ((2, "W"), (6, "E")):
        idle = frame_bounds[f"0,{col}"]
        charge = frame_bounds[f"2,{col}"]
        if idle and charge:
            advance = idle[0] - charge[0] if col == 2 else charge[2] - idle[2]
            if advance < 3:
                errors.append(f"{heading} charge forward horn advance {advance} < 3 px")
            front_x = np.arange(64) <= 24 if col == 2 else np.arange(64) >= 40
            tops = []
            for row in (0, 2):
                mask = pixels[row*64:(row+1)*64, col*64:(col+1)*64, 3] > 0
                yy, xx = np.where(mask & front_x)
                tops.append(int(yy.min()))
            head_drop = tops[1] - tops[0]
            if head_drop < 3:
                errors.append(f"{heading} charge head drop {head_drop} < 3 px")
            side_metrics[heading] = {"front_edge_advance_px": advance, "front_head_top_drop_px": head_drop, "idle_bbox": idle, "charge_bbox": charge}
        original = Image.open(V2 / "rock_hornbeast_action_64.png").convert("RGBA")
        area = (col * 64, 3 * 64, (col + 1) * 64, 4 * 64)
        if not np.array_equal(np.asarray(baked.crop(area)), np.asarray(original.crop(area))):
            errors.append(f"accepted v2 {heading} STRIKE changed")
    if not (HERE / "sami_action_review.png").exists():
        errors.append("Sami action review missing")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors, "cells": 40, "side_charge_metrics": side_metrics, "source_sha256": {key: manifest[key] for key in ("source_sha256", "side_source_sha256", "frontback_source_sha256")}, "visual_review": "S/N charge muzzle, horn curls and fleece separated; S/N strike tips lifted; W/E v2 strike cells preserved"}


def fx_check() -> dict:
    errors: list[str] = []
    strips = {"barrier_shell.png": 4, "barrier_cracked.png": 4, "barrier_break.png": 5}
    arrays = {}
    for filename, count in strips.items():
        image = Image.open(HERE / "fx" / filename).convert("RGBA")
        if image.size != (count * 64, 64):
            errors.append(f"{filename} dimensions {image.size}")
        a = np.asarray(image)
        arrays[filename] = a
        if not set(np.unique(a[..., 3])).issubset({0, 255}):
            errors.append(f"{filename} alpha not binary")
        colors = set(map(tuple, a[a[..., 3] > 0, :3]))
        if not colors.issubset(PALETTE):
            errors.append(f"{filename} invalid colors {colors - PALETTE}")
    if (HERE / "fx" / "barrier_hit.png").exists():
        errors.append("barrier_hit.png should not exist in v3")
    rim_image = Image.new("1", (64, 64))
    ImageDraw.Draw(rim_image).ellipse((12, 12, 52, 52), outline=1, width=1)
    rim = np.asarray(rim_image, dtype=bool)
    shell = arrays["barrier_shell.png"]
    cracked = arrays["barrier_cracked.png"]
    shell_rims = []
    cracked_rims = []
    shell_luminance = []
    cracked_luminance = []
    interior = np.zeros((64, 64), dtype=bool)
    interior[23:42, 23:42] = True
    for frame in range(4):
        clean = shell[:, frame*64:(frame+1)*64]
        damaged = cracked[:, frame*64:(frame+1)*64]
        clean_mask = clean[..., 3] > 0
        damaged_mask = damaged[..., 3] > 0
        if bounds(clean_mask) != [12, 12, 52, 52] or bounds(damaged_mask) != [12, 12, 52, 52]:
            errors.append(f"shell circle bounds frame {frame}")
        if np.any(clean_mask & interior):
            errors.append(f"intact shell has central interior lines frame {frame}")
        shell_rims.append(clean_mask & rim)
        cracked_rims.append(damaged_mask & rim)
        shell_luminance.append(int(clean[..., :3][clean_mask].sum()))
        cracked_luminance.append(int(damaged[..., :3][damaged_mask].sum()))
    if not all(np.array_equal(shell_rims[0], other) for other in shell_rims[1:]):
        errors.append("intact rim jitters")
    if not all(np.array_equal(cracked_rims[0], other) for other in cracked_rims[1:]):
        errors.append("cracked rim jitters")
    if len(set(shell_luminance)) != 1 or len(set(cracked_luminance)) != 1:
        errors.append("loop brightness changes between frames")
    if int((shell_rims[0] & ~cracked_rims[0]).sum()) < 2:
        errors.append("cracked rim gaps missing")
    if int((cracked[:, :64, 3] > 0).sum()) <= int((shell[:, :64, 3] > 0).sum()):
        errors.append("cracked state has no extra crack pixels")
    for filename in ("barrier_preview_x6.png", "barrier_sequences_x6.png"):
        if not (HERE / "fx" / filename).exists():
            errors.append(f"missing {filename}")
    return {"status": "PASS" if not errors else "FAIL", "errors": errors, "frames": strips, "circle_bounds": [12, 12, 52, 52], "intact_loop_luminance": shell_luminance, "cracked_loop_luminance": cracked_luminance, "palette": sorted('#%02x%02x%02x' % c for c in PALETTE)}


def main() -> None:
    action = action_check()
    fx = fx_check()
    success = action["status"] == "PASS" and fx["status"] == "PASS"
    report = {"result": "PASS" if success else "FAIL", "action": action, "fx": fx, "scope": "static asset checks and visual review; no Godot import or runtime playback"}
    (HERE / "action_qa_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(report["result"], action["cells"], "action cells", "FX", fx["status"])
    if action["errors"]:
        print("action", action["errors"])
    if fx["errors"]:
        print("FX", fx["errors"])
    if not success:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
