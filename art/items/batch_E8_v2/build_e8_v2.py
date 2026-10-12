"""Package the painted city_x08 broad-head correction only."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
E8_V1 = ROOT.parent / "batch_E8_v1"
sys.path.insert(0, str(E8_V1))
from build_e8 import metrics, reduce_icon


def main() -> None:
    raw = Image.open(ROOT / "sources" / "city_x08_raw_broad.png").convert("RGBA")
    data = np.asarray(raw).copy()
    data[:, :, 3] = np.where(data[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    painted = Image.fromarray(data, "RGBA")
    painted = painted.crop(painted.getbbox())
    painted.save(ROOT / "sources" / "city_x08_painted.png")

    icon = reduce_icon(painted, "city_x08", 29, "steel leather red")
    icon.save(ROOT / "city_x08.png")
    icon.resize((576, 256), Image.Resampling.NEAREST).save(ROOT / "city_x08_8x.png")
    before = Image.open(E8_V1 / "city_x08.png").convert("RGBA")
    old = metrics(before)
    new = metrics(icon)
    entry = {
        "id": "city_x08", "name": "炎式朴刀", "kind": "base", "form": "polearm",
        "file": "city_x08.png", "native_size": [72, 32], "has_emit": False,
        "prototype_refs": ["proto_pudao.jpg"],
        "supersedes": "batch_E8_v1/city_x08.png", "previous_opaque_pixel_count": old["opaque_pixel_count"],
        **new,
    }
    (ROOT / "manifest.json").write_text(json.dumps([entry], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    canvas = Image.new("RGB", (352, 105), "#2c2e30")
    pen = ImageDraw.Draw(canvas)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    canvas.paste(before.resize((144, 64), Image.Resampling.NEAREST), (2, 28), before.resize((144, 64), Image.Resampling.NEAREST))
    canvas.paste(icon.resize((144, 64), Image.Resampling.NEAREST), (183, 28), icon.resize((144, 64), Image.Resampling.NEAREST))
    pen.text((3, 5), f"v1: {old['opaque_pixel_count']} px", font=font, fill="#f5f5f2")
    pen.text((183, 5), f"v2: {new['opaque_pixel_count']} px", font=font, fill="#f5f5f2")
    (ROOT / "review").mkdir(exist_ok=True)
    canvas.save(ROOT / "review" / "city_x08_before_after_2x.png")
    print(json.dumps(entry, ensure_ascii=False))


if __name__ == "__main__":
    main()
