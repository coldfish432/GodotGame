"""Static checks for the painted E11 and E12 review batches."""

from __future__ import annotations

import json
import hashlib
from pathlib import Path

import numpy as np
from PIL import Image


ITEMS = Path(__file__).resolve().parent
EXPECTED = {"E11": (22, 9, 13, 5), "E12": (29, 13, 16, 7)}


def check(batch: str) -> None:
    root = ITEMS / f"batch_{batch}_v1"
    specs = json.loads((root / "asset_specs.json").read_text(encoding="utf-8"))
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    qa = json.loads((root / "qa_report.json").read_text(encoding="utf-8"))
    count, armour, trinkets, emits = EXPECTED[batch]
    assert len(specs) == len(manifest) == len(qa) == count
    assert len({s["id"] for s in specs}) == count
    assert sum(s["form"] == "armour" for s in specs) == armour
    assert sum(s["form"] == "trinket" for s in specs) == trinkets
    assert sum(s["has_emit"] for s in specs) == emits
    assert {s["id"] for s in specs} == {s["id"] for s in manifest} == {s["id"] for s in qa}
    entries = {e["id"]: e for e in manifest}

    warnings = []
    for spec, report in zip(specs, qa):
        item_id = spec["id"]
        assert report["id"] == item_id
        size = (72, 72) if spec["form"] == "armour" else (32, 32)
        path = root / f"{item_id}.png"
        native = Image.open(path).convert("RGBA")
        data = np.asarray(native)
        assert native.size == size
        assert set(np.unique(data[:, :, 3])).issubset({0, 255})
        assert not data[0, :, 3].any() and not data[-1, :, 3].any()
        assert not data[:, 0, 3].any() and not data[:, -1, 3].any()
        assert len(np.unique(data[data[:, :, 3] > 0, :3], axis=0)) <= 24
        assert report["isolated_pixel_percent"] <= 10
        assert report["silhouette_height"] >= (60 if spec["form"] == "armour" else 27)
        preview = Image.open(root / f"{item_id}_8x.png")
        assert preview.size == (size[0] * 8, size[1] * 8)
        assert np.array_equal(np.asarray(preview.convert("RGBA")),
                              np.asarray(native.resize(preview.size, Image.Resampling.NEAREST)))
        assert (root / "sources" / f"{item_id}_raw.png").is_file()
        assert (root / "sources" / f"{item_id}_painted.png").is_file()
        source_path = root / entries[item_id]["painted_source"]
        assert hashlib.sha256(source_path.read_bytes()).hexdigest() == entries[item_id]["source_sha256"]
        emit_path = root / f"{item_id}_emit.png"
        assert emit_path.is_file() == spec["has_emit"]
        assert entries[item_id]["emit_file"] == (emit_path.name if spec["has_emit"] else None)
        if spec["has_emit"]:
            mask = np.asarray(Image.open(emit_path).convert("RGBA"))
            selected = mask[:, :, 3] > 0
            assert mask.shape == data.shape and selected.any()
            assert np.array_equal(mask[selected], data[selected])
            assert not (selected & (data[:, :, 3] == 0)).any()
            assert selected.sum() <= max(50, 0.05 * (data[:, :, 3] > 0).sum())
        if report["bright_pixel_percent"] < 15:
            warnings.append(f"{item_id}={report['bright_pixel_percent']}%")

    for name in ("contact_sheet.png", "contact_sheet_2x.png", "silhouette_check.png",
                 "fill_vs_old_2x.png", "emit_review.png", "generation_prompts.md"):
        assert (root / name).is_file(), name
    print(f"{batch}: {count} icons, {emits} localized masks, technical checks PASS")
    print(f"{batch}: brightness below 15% ({len(warnings)}): {', '.join(warnings) or 'none'}")


if __name__ == "__main__":
    for region in EXPECTED:
        check(region)
