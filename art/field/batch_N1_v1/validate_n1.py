from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
old = Image.open(ROOT.parent / "refs_N" / "style_enemies_identity_v1.png").convert("RGBA")
new = Image.open(ROOT / "identity_sheet.png").convert("RGBA")
combined = Image.open(ROOT / "identity_sheet_with_old_cast.png").convert("RGBA")
assert new.size == (1254, 2508)
assert combined.size == (2508, 2508)
old_pixels = np.asarray(old)
combined_old = np.asarray(combined.crop((0, 0, 1254, 1254)))
new_pixels = np.asarray(new)
combined_new = np.asarray(combined.crop((1254, 0, 2508, 2508)))
assert np.array_equal(combined_old[:, :, 3], old_pixels[:, :, 3])
assert np.array_equal(combined_old[old_pixels[:, :, 3] > 0, :3], old_pixels[old_pixels[:, :, 3] > 0, :3])
assert np.array_equal(combined_new[:, :, 3], new_pixels[:, :, 3])
assert np.array_equal(combined_new[new_pixels[:, :, 3] > 0, :3], new_pixels[new_pixels[:, :, 3] > 0, :3])
assert set(np.unique(np.asarray(new)[:, :, 3])).issubset({0, 255})
occupied = []
for row in range(6):
    for column in range(3):
        alpha = np.asarray(new.crop((column * 418, row * 418, (column + 1) * 418, (row + 1) * 418)))[:, :, 3]
        if np.any(alpha):
            occupied.append((column, row))
assert len(occupied) == 17
assert (2, 1) not in occupied  # mine region has five designs
assert len((ROOT / "manifest.txt").read_text(encoding="utf-8").splitlines()) == 17
assert Image.open(ROOT / "ground_check.png").size == (1700, 390)
report = {"result": "PASS_STATIC", "figures": 17, "new_sheet": list(new.size), "comparison_sheet": list(combined.size), "binary_alpha": True, "old_cast_visible_pixels_preserved": True, "ground_check": "all 17 on supplied mine/city/snow backgrounds", "engine_import_or_animation": "not tested", "stage_2": "awaiting identity approval"}
(ROOT / "qa_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("PASS_STATIC: 17 N1 identity figures")
