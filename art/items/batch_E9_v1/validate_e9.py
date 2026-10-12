"""Static image and handoff checks for the twelve E9 Sami weapons."""

from __future__ import annotations

import json

import numpy as np
from PIL import Image

from build_e9 import OUTLINE, ROOT, SPECS, metrics


def main() -> None:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    expected_ids = [spec[0] for spec in SPECS]
    assert [row["id"] for row in manifest] == expected_ids
    assert len(manifest) == 12
    expected_pngs = {f"{item_id}{suffix}.png" for item_id in expected_ids for suffix in ("", "_8x")}
    expected_pngs |= {"set_fire_watch_0_emit.png", "contact_sheet.png", "contact_sheet_2x.png",
                      "fill_vs_old_2x.png", "silhouette_check.png"}
    assert {p.name for p in ROOT.glob("*.png")} == expected_pngs
    for row in manifest:
        item_id = row["id"]
        image = Image.open(ROOT / f"{item_id}.png").convert("RGBA")
        assert image.size == (72, 32)
        data = np.asarray(image)
        assert set(np.unique(data[:, :, 3]).tolist()) <= {0, 255}
        assert not np.any(data[0, :, 3]) and not np.any(data[-1, :, 3])
        measure = metrics(image)
        assert measure["opaque_pixel_count"] >= 395, (item_id, measure)
        assert measure["bright_pixel_percent"] >= 15, (item_id, measure)
        assert measure["isolated_pixel_percent"] <= 10, (item_id, measure)
        assert measure["colour_count"] <= 24, (item_id, measure)
        assert measure["silhouette_width"] >= 64, (item_id, measure)
        assert measure["silhouette_height"] >= row["old_height"] - 2, (item_id, measure, row)
        assert measure["opaque_pixel_count"] == row["opaque_pixel_count"]
        assert (ROOT / "sources" / f"{item_id}_raw.png").exists()
        assert (ROOT / "sources" / f"{item_id}_painted.png").exists()
        preview = np.asarray(Image.open(ROOT / f"{item_id}_8x.png").convert("RGBA"))
        assert preview.shape == (256, 576, 4)
        assert np.array_equal(preview, np.repeat(np.repeat(data, 8, axis=0), 8, axis=1))
        assert row["has_emit"] == (item_id == "set_fire_watch_0")
    icon = np.asarray(Image.open(ROOT / "set_fire_watch_0.png").convert("RGBA"))
    emit = np.asarray(Image.open(ROOT / "set_fire_watch_0_emit.png").convert("RGBA"))
    visible = emit[:, :, 3] > 0
    assert visible.sum() == 1, int(visible.sum())
    assert np.array_equal(icon[visible], emit[visible])
    assert tuple(icon[18, 8, :3]) != OUTLINE
    assert (ROOT / "generation_prompts.md").exists()
    assert (ROOT / "README.md").exists()
    print("PASS_STATIC: 12 E9 Sami weapon icons")


if __name__ == "__main__":
    main()
