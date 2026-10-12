from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
assert len(manifest) == 12
assert len({entry["id"] for entry in manifest}) == 12
results = []
for entry in manifest:
    item_id = entry["id"]
    icon = Image.open(ROOT / entry["file"]).convert("RGBA")
    arr = np.array(icon)
    mask = arr[:, :, 3] > 0
    rgb = arr[:, :, :3].astype(float) / 255
    lum = .2126 * rgb[:, :, 0] + .7152 * rgb[:, :, 1] + .0722 * rgb[:, :, 2]
    bright = round(100 * float((lum[mask] >= .6).mean()), 2)
    colors = int(len(np.unique(arr[mask, :3], axis=0)))
    assert icon.size == (72, 32), item_id
    assert set(np.unique(arr[:, :, 3])).issubset({0, 255}), item_id
    assert colors <= 24, item_id
    assert bright >= 15, (item_id, bright)
    assert entry["isolated_pixel_percent"] <= 10, item_id
    assert Image.open(ROOT / f"{item_id}_8x.png").convert("RGBA").tobytes() == icon.resize((576, 256), Image.Resampling.NEAREST).tobytes(), item_id
    if entry["has_emit"]:
        emit = np.array(Image.open(ROOT / f"{item_id}_emit.png").convert("RGBA"))
        assert emit.shape == arr.shape and np.any(emit[:, :, 3] > 0), item_id
        assert np.all((emit[:, :, 3] == 0) | np.all(emit == arr, axis=2)), item_id
    else:
        assert not (ROOT / f"{item_id}_emit.png").exists(), item_id
    results.append({"id": item_id, "bright_pixel_percent": bright, "isolated_pixel_percent": entry["isolated_pixel_percent"], "opaque_colours": colors})
contact = Image.open(ROOT / "contact_sheet.png")
assert Image.open(ROOT / "contact_sheet_2x.png").tobytes() == contact.resize((contact.width * 2, contact.height * 2), Image.Resampling.NEAREST).tobytes()
assert Image.open(ROOT / "silhouette_check.png").size == (720, 420)
report = {"result": "PASS_STATIC", "icons": len(results), "checks": ["native_size", "binary_alpha", "palette_count", "bright_pixel_floor", "isolated_pixel_budget", "nearest_neighbour_previews", "emit_overlap", "contact_sheet", "silhouette_sheet"], "items": results, "engine_import_or_playback": "not tested"}
(ROOT / "qa_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"PASS_STATIC: {len(results)} E7 icons")
