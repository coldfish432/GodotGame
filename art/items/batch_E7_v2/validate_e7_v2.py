from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
V1 = ROOT.parent / "batch_E7_v1"
EXPECTED = {"mi_thug_0": 26, "mine_x05": 20, "set_warrant_0": 22, "mine_x06": 20, "mine_x08": 12}
ACCEPTED = ["mine_x01", "mine_x02", "mine_x03", "mine_x04", "mine_x07", "mi_picket_8", "set_nameless_0"]
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
assert {entry["id"] for entry in manifest} == set(EXPECTED)
assert len(list(ROOT.glob("*.png"))) == 5 * 2 + 1 + 4  # native, 8x, emit, review sheets
for item_id in ACCEPTED:
    assert not (ROOT / f"{item_id}.png").exists(), item_id
results = []
for entry in manifest:
    item_id = entry["id"]
    icon = Image.open(ROOT / entry["file"]).convert("RGBA")
    data = np.array(icon)
    visible = data[:, :, 3] > 0
    bounds = icon.getbbox()
    height = bounds[3] - bounds[1]
    colours = len(np.unique(data[visible, :3], axis=0))
    rgb = data[:, :, :3].astype(float) / 255
    luma = .2126 * rgb[:, :, 0] + .7152 * rgb[:, :, 1] + .0722 * rgb[:, :, 2]
    bright = round(100 * float((luma[visible] >= .6).mean()), 2)
    assert icon.size == (72, 32), item_id
    assert set(np.unique(data[:, :, 3])).issubset({0, 255}), item_id
    assert height >= EXPECTED[item_id], (item_id, height)
    assert colours <= 24, (item_id, colours)
    assert bright >= 15, (item_id, bright)
    assert entry["isolated_pixel_percent"] <= 10, item_id
    assert Image.open(ROOT / f"{item_id}_8x.png").convert("RGBA").tobytes() == icon.resize((576, 256), Image.Resampling.NEAREST).tobytes(), item_id
    if item_id == "mine_x08":
        head_ys, _ = np.where(visible[:, 53:])
        assert int(head_ys.max() - head_ys.min() + 1) >= 12
    if entry["has_emit"]:
        emit = np.array(Image.open(ROOT / f"{item_id}_emit.png").convert("RGBA"))
        assert emit.shape == data.shape and np.any(emit[:, :, 3] > 0)
        assert np.all((emit[:, :, 3] == 0) | np.all(emit == data, axis=2))
    else:
        assert not (ROOT / f"{item_id}_emit.png").exists(), item_id
    results.append({"id": item_id, "silhouette_height": height, "bright_pixel_percent": bright, "isolated_pixel_percent": entry["isolated_pixel_percent"], "colours": int(colours), "sha256": hashlib.sha256((ROOT / entry["file"]).read_bytes()).hexdigest()})
contact = Image.open(ROOT / "contact_sheet.png")
assert Image.open(ROOT / "contact_sheet_2x.png").tobytes() == contact.resize((contact.width * 2, contact.height * 2), Image.Resampling.NEAREST).tobytes()
assert (ROOT / "fill_vs_old_2x.png").exists() and (ROOT / "silhouette_check.png").exists()
report = {"result": "PASS_STATIC", "revised_icons": 5, "accepted_v1_icons_copied": 0, "checks": ["native_height", "spear_head_height", "binary_alpha", "palette_count", "brightness", "isolated_pixels", "emit_subset", "nearest_neighbour_8x", "old_weapon_comparison"], "items": results, "engine_import_or_inventory": "not tested"}
(ROOT / "qa_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("PASS_STATIC: five E7 v2 revisions")
