"""Static image and delivery checks for E10 mine armour and trinkets."""

from __future__ import annotations

import json

import numpy as np
from PIL import Image

from build_e10 import ROOT, SPECS, metrics


def main() -> None:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    expected_ids = [spec[0] for spec in SPECS]
    assert len(manifest) == 26
    assert [entry["id"] for entry in manifest] == expected_ids
    assert sum(entry["form"] == "armour" for entry in manifest) == 10
    assert sum(entry["form"] == "trinket" for entry in manifest) == 16
    expected_pngs = {f"{item_id}{suffix}.png" for item_id in expected_ids for suffix in ("", "_8x")}
    expected_pngs.update(f"{item_id}_emit.png" for item_id, _, _, _, _, _, _, has_emit in SPECS if has_emit)
    expected_pngs.update({"contact_sheet.png", "contact_sheet_2x.png", "fill_vs_old_2x.png", "silhouette_check.png"})
    actual_pngs = {path.name for path in ROOT.glob("*.png")}
    assert actual_pngs == expected_pngs, (sorted(actual_pngs - expected_pngs), sorted(expected_pngs - actual_pngs))

    for entry in manifest:
        item_id, form = entry["id"], entry["form"]
        size = 72 if form == "armour" else 32
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        data = np.asarray(icon)
        assert icon.size == (size, size)
        assert set(np.unique(data[:, :, 3]).tolist()) <= {0, 255}
        assert not np.any(data[0, :, 3]) and not np.any(data[-1, :, 3])
        assert not np.any(data[:, 0, 3]) and not np.any(data[:, -1, 3])
        measure = metrics(icon)
        assert measure["colour_count"] <= 24, (item_id, measure)
        assert measure["bright_pixel_percent"] >= 15, (item_id, measure)
        assert measure["isolated_pixel_percent"] <= 10, (item_id, measure)
        if form == "armour":
            assert measure["silhouette_width"] >= 60 and measure["silhouette_height"] >= 60
            assert measure["opaque_pixel_count"] >= 2400
        else:
            assert measure["silhouette_width"] >= 27 and measure["silhouette_height"] >= 27
            assert measure["opaque_pixel_count"] >= 400
        assert measure["opaque_pixel_count"] == entry["opaque_pixel_count"]
        assert (ROOT / "sources" / f"{item_id}_raw.png").exists()
        assert (ROOT / "sources" / f"{item_id}_painted.png").exists()
        preview = np.asarray(Image.open(ROOT / f"{item_id}_8x.png").convert("RGBA"))
        assert np.array_equal(preview, np.repeat(np.repeat(data, 8, axis=0), 8, axis=1))
        if entry["has_emit"]:
            emit = np.asarray(Image.open(ROOT / f"{item_id}_emit.png").convert("RGBA"))
            visible = emit[:, :, 3] > 0
            assert emit.shape == data.shape and visible.any()
            assert visible.sum() <= (data[:, :, 3] > 0).sum() // 6
            assert np.array_equal(emit[visible], data[visible])

    assert (ROOT / "generation_prompts.md").exists()
    assert (ROOT / "README.md").exists()
    print("PASS_STATIC: 10 E10 armour + 16 E10 trinkets")


if __name__ == "__main__":
    main()
