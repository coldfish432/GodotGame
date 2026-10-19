"""Bake painted Siracusa ground sources to the brief's pixel palette.

Only resampling, edge wrapping, palette indexing, previews and provenance are
done here. The paving and earth details come from source_paintings/*.png.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_city_textures import lab, seamless

HERE = Path(__file__).resolve().parent
SOURCES = HERE / "source_paintings"
SIZE = 256
SPECS = {
    "siracusa_road": "8c8272 9e937f afa48c bfb398 cdc1a4 4c443a 625a4c 735d44 8a7254 55633a 6e7f46",
    "siracusa_block_ground": "5e4c38 735d44 8a7254 55633a 6e7f46 9a907e 7c7466 8e4a30 ad6040 afa48c bfb398 4c443a",
}


def index_source(rgb: np.ndarray, colors: list[str]) -> np.ndarray:
    palette = np.array([tuple(bytes.fromhex(h)) for h in colors], dtype=np.uint8)
    src_lab = lab(rgb)
    pal_lab = lab(palette)
    delta = src_lab[:, :, None, :] - pal_lab[None, None, :, :]
    delta[..., 1:] *= 0.8
    choice = np.argmin(np.sum(delta * delta, axis=-1), axis=-1)
    return palette[choice]


def bake(name: str, palette_spec: str) -> dict:
    source = SOURCES / f"{name}_source.png"
    with Image.open(source) as im:
        rgb = np.asarray(im.convert("RGB").resize((SIZE, SIZE), Image.Resampling.BOX))
    rgb = seamless(rgb, 16)
    palette = palette_spec.split()
    indexed = index_source(rgb, palette)
    # Nearest-color indexing loses some muted olive and red source clusters.
    # Keep those *painted* areas by their hue, without adding new marks.
    a = rgb.astype(np.int16)
    if name == "siracusa_road":
        olive = (a[..., 1] - a[..., 0] > -12) & (a[..., 1] - a[..., 2] > 7) & (a[..., 1] < 130)
        indexed[olive] = tuple(bytes.fromhex("55633a"))
        indexed[olive & (a[..., 1] > 90)] = tuple(bytes.fromhex("6e7f46"))
    else:
        olive = (a[..., 1] - a[..., 0] > -13) & (a[..., 1] - a[..., 2] > 11)
        indexed[olive] = tuple(bytes.fromhex("55633a"))
        indexed[olive & (a[..., 1] > 104)] = tuple(bytes.fromhex("6e7f46"))
        terra = (a[..., 0] - a[..., 1] > 32) & (a[..., 0] - a[..., 2] > 43)
        indexed[terra] = tuple(bytes.fromhex("8e4a30"))
        indexed[terra & (a[..., 0] > 130)] = tuple(bytes.fromhex("ad6040"))
    # A matching one-pixel overlap ensures both seams meet exactly in Godot.
    indexed[-1] = indexed[0]
    indexed[:, -1] = indexed[:, 0]
    tile = Image.fromarray(indexed, "RGB")
    tile.save(HERE / f"{name}.png")
    preview = Image.new("RGB", (SIZE * 3, SIZE * 3))
    for y in range(3):
        for x in range(3):
            preview.paste(tile, (x * SIZE, y * SIZE))
    preview.save(HERE / f"{name}_tile_3x3.png")
    used = np.unique(indexed.reshape(-1, 3), axis=0)
    return {
        "source": source.relative_to(HERE).as_posix(),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "size": [SIZE, SIZE],
        "colors": len(used),
        "palette": [f"#{h}" for h in palette],
        "seam_exact": bool(np.array_equal(indexed[0], indexed[-1]) and np.array_equal(indexed[:, 0], indexed[:, -1])),
        "mean_luma": round(float(np.mean(indexed @ np.array([0.2126, 0.7152, 0.0722]))), 2),
    }


if __name__ == "__main__":
    report = {name: bake(name, spec) for name, spec in SPECS.items()}
    manifest_path = HERE / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    manifest.update(report)
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for name, item in report.items():
        print(name, item["size"], item["colors"], "colors", "seam", item["seam_exact"], "mean luma", item["mean_luma"])
