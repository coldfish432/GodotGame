"""Independent package checks for the delivered M1 material icons."""

from collections import Counter
import json
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
BATCH = ROOT / "batch_M1_v1"
brief = (ROOT / "M_brief_v1.md").read_text(encoding="utf-8")
section = brief.split("## M1: PRTS materials", 1)[1].split("## M2:", 1)[0]
expected = []
for line in section.splitlines():
    if re.match(r"^\|\s*`[a-z0-9_]+`", line):
        fields = [field.strip() for field in line.split("|")]
        expected.append((fields[1].strip("`"), fields[2]))

manifest = json.loads((BATCH / "manifest.json").read_text(encoding="utf-8"))
assert len(expected) == len(manifest) == 33
assert [(entry["id"], entry["name"]) for entry in manifest] == expected
assert len({entry["id"] for entry in manifest}) == 33
assert (BATCH / ".gdignore").is_file()
assert (BATCH / "sources" / ".gdignore").is_file()
assert (BATCH / "contact_sheet.png").is_file()

ramp = {(184, 90, 18), (238, 138, 36), (255, 179, 90), (255, 224, 168)}
for entry in manifest:
    item_id = entry["id"]
    assert set(entry) == {"id", "name", "file", "size", "cells", "emit"}, item_id
    assert entry["file"] == f"{item_id}.png", item_id
    assert entry["size"] == [32, 32] and entry["cells"] == [1, 1], item_id
    assert (BATCH / "sources" / f"{item_id}.png").is_file(), item_id
    image = Image.open(BATCH / entry["file"]).convert("RGBA")
    preview = Image.open(BATCH / f"{item_id}_8x.png").convert("RGBA")
    assert image.size == (32, 32), item_id
    assert preview.size == (256, 256), item_id
    assert preview.tobytes() == image.resize((256, 256), Image.Resampling.NEAREST).tobytes(), item_id
    alpha = set(image.getchannel("A").get_flattened_data())
    assert alpha == {0, 255}, item_id
    visible = [pixel for pixel in image.get_flattened_data() if pixel[3]]
    assert len({pixel[:3] for pixel in visible}) <= 24, item_id
    assert image.getchannel("A").getbbox() is not None, item_id
    bright = sum(0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2] >= 153 for p in visible)
    assert bright / len(visible) >= 0.15, item_id
    interior = [p[:3] for p in visible if p[:3] != (11, 12, 13)]
    assert max(Counter(interior).values()) / len(interior) <= 0.25, item_id
    if item_id == "originium_shard":
        assert entry["emit"] == "originium_shard_emit.png"
        emit = Image.open(BATCH / entry["emit"]).convert("RGBA")
        emit_preview = Image.open(BATCH / "originium_shard_emit_8x.png").convert("RGBA")
        assert emit.size == (32, 32) and emit_preview.size == (256, 256)
        assert emit_preview.tobytes() == emit.resize((256, 256), Image.Resampling.NEAREST).tobytes()
        assert set(emit.getchannel("A").get_flattened_data()) == {0, 255}
        assert any(p[3] for p in emit.get_flattened_data())
        assert all(e[:3] in ramp and e == b for e, b in zip(emit.get_flattened_data(), image.get_flattened_data()) if e[3])
    else:
        assert entry["emit"] is None, item_id
        assert not any(p[:3] in ramp for p in visible), item_id

report = (BATCH / "validation.txt").read_text(encoding="utf-8")
assert report.count("PASS ") == 33 and "REVIEW" not in report and "MISSING" not in report
print("PASS: 33 brief/manifest/source/native/preview/palette/alpha checks; emit subset; report and package files")
