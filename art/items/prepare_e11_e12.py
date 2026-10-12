"""Extract the approved E11/E12 item descriptions for art provenance."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
brief = (ROOT / "E10_12_armour_trinkets_brief_v1.md").read_text(encoding="utf-8")
for batch in ("E11", "E12"):
    section = brief.split(f"### {batch} —", 1)[1]
    if batch == "E11":
        section = section.split("### E12 —", 1)[0]
    else:
        section = section.split("## Deliverables", 1)[0]
    form = None
    result = []
    for line in section.splitlines():
        if line.startswith("#### Armour"):
            form = "armour"
        elif line.startswith("#### Trinkets"):
            form = "trinket"
        elif line.startswith("| ") and not line.startswith(("| id", "|---")):
            cells = [re.sub(r"\*\*", "", c.strip()) for c in line.strip().strip("|").split("|")]
            if len(cells) != 4:
                raise ValueError((batch, line, cells))
            item_id, name, prototype, description = cells
            if not re.fullmatch(r"[a-z][a-z0-9_]+", item_id):
                continue
            result.append({
                "id": item_id, "name": name, "form": form,
                "kind": "set" if item_id.startswith("set_") else ("exclusive" if item_id.startswith("mi_") else "base"),
                "prototype": prototype, "description": description,
                "has_emit": "(emit)" in description,
            })
    expected = 22 if batch == "E11" else 29
    assert len(result) == expected, (batch, len(result))
    folder = ROOT / f"batch_{batch}_v1"
    folder.mkdir(exist_ok=True)
    (folder / "asset_specs.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(batch, len(result), sum(x["form"] == "armour" for x in result), sum(x["has_emit"] for x in result))
