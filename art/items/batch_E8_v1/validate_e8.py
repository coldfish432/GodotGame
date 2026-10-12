"""Static contract checks for the painted E8 weapon delivery."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from build_e8 import ROOT, SPECS, metrics


def main() -> None:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    expected_ids = [spec[0] for spec in SPECS]
    assert [row["id"] for row in manifest] == expected_ids
    assert len(manifest) == 13
    expected_pngs = {f"{item_id}{suffix}.png" for item_id in expected_ids for suffix in ("", "_8x")}
    expected_pngs.add("set_grey_order_0_emit.png")
    expected_pngs.update({"contact_sheet.png", "contact_sheet_2x.png", "silhouette_check.png", "fill_vs_old_2x.png"})
    actual_pngs = {p.name for p in ROOT.glob("*.png")}
    assert actual_pngs == expected_pngs, (sorted(actual_pngs - expected_pngs), sorted(expected_pngs - actual_pngs))
    for row in manifest:
        item_id = row["id"]
        icon = Image.open(ROOT / f"{item_id}.png").convert("RGBA")
        assert icon.size == (72, 32)
        data = np.asarray(icon)
        assert set(np.unique(data[:, :, 3]).tolist()) <= {0, 255}
        measure = metrics(icon)
        assert measure["colour_count"] <= 24, (item_id, measure)
        assert measure["bright_pixel_percent"] >= 15, (item_id, measure)
        assert measure["isolated_pixel_percent"] <= 10, (item_id, measure)
        assert 22 <= measure["silhouette_height"] <= 30, (item_id, measure)
        assert measure["silhouette_width"] >= 64, (item_id, measure)
        assert measure["silhouette_height"] >= row["old_height"] - 2, (item_id, measure, row)
        assert abs(measure["isolated_pixel_percent"] - row["isolated_pixel_percent"]) < 0.01
        assert (ROOT / "sources" / f"{item_id}_raw.png").exists()
        assert (ROOT / "sources" / f"{item_id}_painted.png").exists()
        preview = Image.open(ROOT / f"{item_id}_8x.png").convert("RGBA")
        assert preview.size == (576, 256)
        assert np.array_equal(np.asarray(preview), np.repeat(np.repeat(data, 8, axis=0), 8, axis=1))
        assert row["has_emit"] == (item_id == "set_grey_order_0")
    main_icon = np.asarray(Image.open(ROOT / "set_grey_order_0.png").convert("RGBA"))
    emit = np.asarray(Image.open(ROOT / "set_grey_order_0_emit.png").convert("RGBA"))
    assert emit.shape == main_icon.shape
    assert int((emit[:, :, 3] > 0).sum()) > 0
    assert np.array_equal(emit[emit[:, :, 3] > 0], main_icon[emit[:, :, 3] > 0])
    assert (ROOT / "generation_prompts.md").exists()
    assert (ROOT / "README.md").exists()
    print("PASS_STATIC: 13 E8 Lungmen weapon icons")


if __name__ == "__main__":
    main()
