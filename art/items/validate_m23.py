"""Independent delivery checks for M2 supplies and M3 potions."""

from collections import Counter
import json
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
BRIEF = (ROOT / "M_brief_v1.md").read_text(encoding="utf-8")
RAMP = {(184, 90, 18), (238, 138, 36), (255, 179, 90), (255, 224, 168)}
BACKGROUNDS = ((44, 46, 48), (20, 37, 56), (53, 39, 16), (56, 27, 15))


def expected_rows(batch: str):
    if batch == "M2":
        section = BRIEF.split("## M2: Common supplies", 1)[1].split("## M3: Potions", 1)[0]
    else:
        section = BRIEF.split("## M3: Potions", 1)[1].split("## Game references", 1)[0]
    expected = []
    for line in section.splitlines():
        if not re.match(r"^\|\s*`[a-z0-9_]+`", line):
            continue
        parts = [p.strip() for p in line.split("|")]
        cells = list(map(int, parts[5].split("×"))) if batch == "M2" else [1, 1]
        size = list(map(int, parts[6].split("×"))) if batch == "M2" else [32, 32]
        expected.append((parts[1].strip("`"), parts[2], cells, size))
    return expected


for batch, required_count in (("M2", 22), ("M3", 3)):
    folder = ROOT / f"batch_{batch}_v1"
    expected = expected_rows(batch)
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    assert len(expected) == len(manifest) == required_count, batch
    assert len({row[0] for row in expected}) == required_count, batch
    assert [(e["id"], e["name"], e["cells"], e["size"]) for e in manifest] == expected, batch
    assert (folder / ".gdignore").read_bytes() == b"", batch
    assert (folder / "sources" / ".gdignore").read_bytes() == b"", batch
    assert len(list((folder / "sources").glob("*.png"))) == required_count, batch
    contact = Image.open(folder / "contact_sheet.png").convert("RGB")
    assert contact.size == (540, required_count * 100 + 8), batch
    for row_index, entry in enumerate(manifest):
        item_id = entry["id"]
        assert set(entry) == {"id", "name", "file", "size", "cells", "emit"}, item_id
        assert entry["file"] == f"{item_id}.png" and entry["emit"] is None, item_id
        assert (folder / "sources" / f"{item_id}.png").is_file(), item_id
        native = Image.open(folder / entry["file"]).convert("RGBA")
        preview = Image.open(folder / f"{item_id}_8x.png").convert("RGBA")
        width, height = entry["size"]
        assert native.size == (width, height) and preview.size == (width * 8, height * 8), item_id
        assert preview.tobytes() == native.resize(preview.size, Image.Resampling.NEAREST).tobytes(), item_id
        assert set(native.getchannel("A").get_flattened_data()) == {0, 255}, item_id
        box = native.getchannel("A").getbbox()
        assert box and min(box[0], box[1], width - box[2], height - box[3]) >= 2, item_id
        visible = [p for p in native.get_flattened_data() if p[3]]
        assert len({p[:3] for p in visible}) <= 24, item_id
        assert not any(p[:3] in RAMP for p in visible), item_id
        bright = sum(0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2] >= 153 for p in visible)
        assert bright / len(visible) >= 0.15, item_id
        interior = [p[:3] for p in visible if p[:3] != (11, 12, 13)]
        assert max(Counter(interior).values()) / len(interior) <= 0.25, item_id
        tile_width, tile_height = [c * 40 for c in entry["cells"]]
        for slot, background in enumerate(BACKGROUNDS):
            x, y = 8 + slot * 132, 8 + row_index * 100 + 16
            assert contact.getpixel((x, y)) == background, (item_id, slot)
            assert contact.getpixel((x + tile_width - 12, y + tile_height - 12)) == (5, 6, 7), (item_id, slot)
    report = (folder / "validation.txt").read_text(encoding="utf-8")
    assert report.count("PASS ") == required_count and "REVIEW" not in report and "MISSING" not in report, batch
    print(f"PASS {batch}: {required_count} exact brief rows, sources, native/preview sizes, palette/alpha, four slot backgrounds, badge")
