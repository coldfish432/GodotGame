"""Static delivery checks for the nine painted Lungmen textures."""

import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_city_textures import HERE, PALETTE, SPECS


def check() -> dict:
    findings = {}
    allowed = {tuple(v) for v in PALETTE.values()}
    for name, (size, _) in SPECS.items():
        path = HERE / f"{name}.png"
        preview_path = HERE / f"{name}_tile_3x3.png"
        with Image.open(path) as im:
            im.verify()
        with Image.open(preview_path) as im:
            im.verify()
        image = np.asarray(Image.open(path).convert("RGB"))
        preview = np.asarray(Image.open(preview_path).convert("RGB"))
        assert image.shape == (size[1], size[0], 3), name
        assert preview.shape == (size[1] * 3, size[0] * 3, 3), name
        assert np.array_equal(preview, np.tile(image, (3, 3, 1))), name
        colors = {tuple(x) for x in np.unique(image.reshape(-1, 3), axis=0)}
        assert 8 <= len(colors) <= 12, (name, len(colors))
        assert colors <= allowed, name
        seam = bool(np.array_equal(image[0], image[-1])
                    and np.array_equal(image[:, 0], image[:, -1]))
        if name != "city_signs":
            assert seam, name
        luminance = (image.astype(np.float32) * np.array([0.2126, 0.7152, 0.0722])).sum(2)
        rust_colors = {tuple(PALETTE[h]) for h in ("3e2a1c", "5a3420", "7a3e1c")}
        rust = sum(np.all(image == c, axis=2) for c in rust_colors) > 0
        findings[name] = {"size": list(size), "colors": len(colors),
                          "edge_pixels_match": seam,
                          "mean_luminance": round(float(luminance.mean()), 2),
                          "rust_fraction": round(float(rust.mean()), 4)}
    assert findings["city_road"]["mean_luminance"] < findings["city_pavement"]["mean_luminance"]
    assert findings["city_block_ground"]["mean_luminance"] < findings["city_pavement"]["mean_luminance"]
    assert (HERE / "city_signs.png").exists()
    (HERE / "validation.json").write_text(json.dumps(findings, indent=2) + "\n", encoding="utf-8")
    return findings


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
