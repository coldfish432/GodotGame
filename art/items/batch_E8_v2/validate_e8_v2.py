"""Check the E8 pudao correction without resending accepted E8 icons."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / "batch_E8_v1"))
from build_e8 import metrics


def main() -> None:
    assert {p.name for p in ROOT.glob("*.png")} == {"city_x08.png", "city_x08_8x.png"}
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    assert len(manifest) == 1 and manifest[0]["id"] == "city_x08"
    image = Image.open(ROOT / "city_x08.png").convert("RGBA")
    assert image.size == (72, 32)
    data = np.asarray(image)
    assert set(np.unique(data[:, :, 3]).tolist()) <= {0, 255}
    measure = metrics(image)
    assert measure["opaque_pixel_count"] >= 550, measure
    assert measure["bright_pixel_percent"] >= 15, measure
    assert measure["isolated_pixel_percent"] <= 10, measure
    assert measure["colour_count"] <= 24, measure
    assert manifest[0]["previous_opaque_pixel_count"] == 357
    # On the rightmost 24 pixels, inspect the steel head alone (exclude tassel).
    yy, xx = np.indices(data.shape[:2])
    rgb = data[:, :, :3]
    steel = (data[:, :, 3] > 0) & (xx >= 47) & (rgb[:, :, 0] >= 42) & (rgb[:, :, 0] < 240)
    steel &= np.abs(rgb[:, :, 0].astype(int) - rgb[:, :, 1].astype(int)) < 25
    ys, xs = np.where(steel)
    assert xs.max() - xs.min() + 1 >= 22
    assert ys.max() - ys.min() + 1 >= 12
    preview = np.asarray(Image.open(ROOT / "city_x08_8x.png").convert("RGBA"))
    assert np.array_equal(preview, np.repeat(np.repeat(data, 8, axis=0), 8, axis=1))
    assert (ROOT / "generation_prompts.md").exists()
    print("PASS_STATIC: E8 v2 city_x08 only")


if __name__ == "__main__":
    main()
