"""Static checks for the two painted Siracusa terrain swatches."""

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_siracusa_textures import HERE, SIZE, SPECS


def check() -> dict:
    manifest = json.loads((HERE / "manifest.json").read_text(encoding="utf-8"))
    findings = {}
    for name, spec in SPECS.items():
        path = HERE / f"{name}.png"
        preview_path = HERE / f"{name}_tile_3x3.png"
        for item in (path, preview_path):
            with Image.open(item) as im:
                im.verify()
        rgb = np.asarray(Image.open(path).convert("RGB"))
        preview = np.asarray(Image.open(preview_path).convert("RGB"))
        assert rgb.shape == (SIZE, SIZE, 3), name
        assert preview.shape == (SIZE * 3, SIZE * 3, 3), name
        assert np.array_equal(preview, np.tile(rgb, (3, 3, 1))), name
        used = {tuple(v) for v in np.unique(rgb.reshape(-1, 3), axis=0)}
        allowed = {tuple(bytes.fromhex(h)) for h in spec.split()}
        assert 8 <= len(used) <= 12, (name, len(used))
        assert used <= allowed, name
        seam = bool(np.array_equal(rgb[0], rgb[-1]) and np.array_equal(rgb[:, 0], rgb[:, -1]))
        assert seam, name
        source = HERE / manifest[name]["source"]
        assert hashlib.sha256(source.read_bytes()).hexdigest() == manifest[name]["source_sha256"], name
        assert manifest[name]["size"] == [SIZE, SIZE], name
        assert manifest[name]["colors"] == len(used), name
        assert manifest[name]["seam_exact"] == seam, name
        luma = float(np.mean(rgb @ np.array([0.2126, 0.7152, 0.0722])))
        findings[name] = {"size": [SIZE, SIZE], "colors": len(used),
                          "edge_pixels_match": seam, "mean_luminance": round(luma, 2),
                          "source_sha256_match": True, "preview_exact_3x3": True}
    assert findings["siracusa_road"]["mean_luminance"] > findings["siracusa_block_ground"]["mean_luminance"]
    (HERE / "validation_siracusa.json").write_text(json.dumps(findings, indent=2) + "\n", encoding="utf-8")
    return findings


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
