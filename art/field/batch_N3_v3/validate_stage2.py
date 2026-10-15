"""Static checks for the clean N3 grids and 64 px bakes."""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from reduce_n1 import components  # noqa: E402


def bbox_size(comp: np.ndarray) -> tuple[int, int]:
    return (int(np.ptp(comp[:, 1]) + 1), int(np.ptp(comp[:, 0]) + 1))


def check(name: str, rows: int) -> dict:
    raw_path = HERE / f"sentinel_{name}.png"
    bake_path = HERE / f"sentinel_{name}_64.png"
    preview_path = HERE / f"sentinel_{name}_64_x6.png"
    raw = np.asarray(Image.open(raw_path).convert("RGBA"))
    baked = np.asarray(Image.open(bake_path).convert("RGBA"))
    assert raw.shape == (rows * 320, 2560, 4), raw.shape
    assert baked.shape == (rows * 64, 512, 4), baked.shape
    with Image.open(preview_path) as preview:
        assert preview.size == (3072, rows * 384)
    metrics = {"cells": 0, "max_colors": 0, "min_front_gold_bbox": [99, 99],
               "min_lamp_bbox": [99, 99], "back_gold_pixels": 0}
    masks = {}
    for row in range(rows):
        for col in range(8):
            source = raw[row * 320:(row + 1) * 320, col * 320:(col + 1) * 320]
            cell = baked[row * 64:(row + 1) * 64, col * 64:(col + 1) * 64]
            assert source[..., 3].max() > 0 and cell[..., 3].max() > 0
            assert not np.any(source[0, :, 3]) and not np.any(source[-1, :, 3])
            assert not np.any(source[:, 0, 3]) and not np.any(source[:, -1, 3])
            assert not np.any(cell[0, :, 3]) and not np.any(cell[-1, :, 3])
            assert not np.any(cell[:, 0, 3]) and not np.any(cell[:, -1, 3])
            mask = cell[..., 3] > 0
            masks[row, col] = mask
            colors = np.unique(cell[mask, :3], axis=0).shape[0]
            metrics["max_colors"] = max(metrics["max_colors"], int(colors))
            rgb = cell[..., :3].astype(np.int16)
            gold = mask & (rgb[..., 0] > 90) & (rgb[..., 0] > rgb[..., 1] * 1.15) & (rgb[..., 1] > rgb[..., 2] * 1.15)
            if col in (3, 4, 5):
                metrics["back_gold_pixels"] += int(gold.sum())
            else:
                gold_parts = components(gold)
                assert gold_parts, (name, row, col, "missing gold horn")
                largest = max(gold_parts, key=len)
                w, h = bbox_size(largest)
                assert w >= 3 and h >= 3, (name, row, col, "gold", w, h)
                metrics["min_front_gold_bbox"][0] = min(metrics["min_front_gold_bbox"][0], w)
                metrics["min_front_gold_bbox"][1] = min(metrics["min_front_gold_bbox"][1], h)
            teal = (mask & (rgb[..., 1] > 115) & (rgb[..., 2] > 100)
                    & (rgb[..., 1] - rgb[..., 0] > 25)
                    & (rgb[..., 2] - rgb[..., 0] > 25))
            parts = components(teal)
            assert parts, (name, row, col, "missing lamp")
            lamp_candidates = [part for part in parts if len(part) >= 4
                               and all(n >= 2 for n in bbox_size(part))]
            assert lamp_candidates, (name, row, col, "missing solid teal block")
            lamp = min(lamp_candidates, key=lambda part: int(part[:, 0].min()))
            w, h = bbox_size(lamp)
            assert int(lamp[:, 0].min()) < 40, (name, row, col, "lamp too low")
            assert w >= 2 and h >= 2, (name, row, col, "lamp", w, h)
            metrics["min_lamp_bbox"][0] = min(metrics["min_lamp_bbox"][0], w)
            metrics["min_lamp_bbox"][1] = min(metrics["min_lamp_bbox"][1], h)
            metrics["cells"] += 1
    assert metrics["back_gold_pixels"] == 0, (name, metrics["back_gold_pixels"])
    if name == "action":
        diffs = [int(np.count_nonzero(masks[2, c] & ~masks[0, c])) for c in range(8)]
        assert min(diffs) >= 4, (name, diffs)
        metrics["charge_outside_idle_by_direction"] = diffs
    else:
        diffs = [int(np.count_nonzero(masks[r, c] ^ masks[r + 1, c]))
                 for c in range(8) for r in range(3)]
        assert min(diffs) >= 4, (name, diffs)
        metrics["min_adjacent_silhouette_difference"] = min(diffs)
    return metrics


if __name__ == "__main__":
    report = {"action": check("action", 5), "walk": check("walk", 4)}
    (HERE / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
