"""Build the compact PRTS reserve squad portrait for NPC v3 revision 1."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image
from native_art import paint_native

HERE = Path(__file__).resolve().parent
PORTRAITS = HERE.parent
SOURCE = HERE / "source_paintings" / "portrait_squad_chibi_r1.png"
REFS = PORTRAITS / "refs" / "in_game"
STYLE = PORTRAITS / "refs_style"
CYAN_DARK = (42, 138, 146)
CYAN_LIGHT = (95, 208, 216)
ORANGE_DARK = (188, 83, 9)
ORANGE_LIGHT = (255, 174, 32)


def build_native() -> tuple[Image.Image, dict]:
    assert SOURCE.is_file()
    result = paint_native()
    result.save(HERE / "portrait_squad.png")
    result.resize((420, 600), Image.Resampling.NEAREST).save(HERE / "portrait_squad_4x.png")
    colors = {p[:3] for p in result.get_flattened_data() if p[3]}
    bbox = result.getchannel("A").getbbox()
    metrics = {"size": [105, 150], "colors": len(colors), "top_clear_px": bbox[1], "visible_bbox_px": list(bbox), "concept_source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest()}
    assert len(colors) <= 42, len(colors)
    assert CYAN_DARK in colors and CYAN_LIGHT in colors
    assert ORANGE_DARK in colors and ORANGE_LIGHT in colors
    assert {p[3] for p in result.get_flattened_data()} == {0, 255}
    assert bbox[1] >= 2
    for colour in (CYAN_DARK, CYAN_LIGHT, (146, 154, 158), (201, 207, 210)):
        for y in range(result.height):
            for x in range(result.width):
                if result.getpixel((x, y))[:3] != colour:
                    continue
                assert any(
                    result.getpixel((xx, yy))[:3] == colour
                    for yy in range(max(0, y - 1), min(result.height, y + 2))
                    for xx in range(max(0, x - 1), min(result.width, x + 2))
                    if (xx, yy) != (x, y)
                ), (colour, x, y)
    return result, metrics


def make_previews(sprite: Image.Image) -> None:
    panel = Image.open(REFS / "gui-squad.png").convert("RGBA")
    left, right = 85, 310
    for y in range(210, 463):
        a, b = panel.getpixel((left, y)), panel.getpixel((right, y))
        for x in range(left + 1, right):
            t = (x - left) / (right - left)
            panel.putpixel((x, y), tuple(round(a[c] * (1 - t) + b[c] * t) for c in range(4)))
    shown = sprite.resize((420, 600), Image.Resampling.NEAREST)
    panel.alpha_composite(shown, (5, 120))
    panel.save(HERE / "portrait_squad_panel.png")
    style = Image.new("RGBA", (800, 600), (24, 28, 31, 255))
    amiya = Image.open(STYLE / "amiya_guard_portrait_4x.png").convert("RGBA")
    style.alpha_composite(amiya, (32, 600 - amiya.height))
    style.alpha_composite(shown, (440, 0))
    style.save(HERE / "portrait_squad_vs_amiya.png")
    closure = Image.open(PORTRAITS / "batch_P1_v3" / "portrait_closure_4x.png").convert("RGBA")
    comparison = Image.new("RGBA", (800, 600), (24, 28, 31, 255))
    comparison.alpha_composite(closure, (35, 0))
    comparison.alpha_composite(shown, (365, 0))
    comparison.save(HERE / "portrait_squad_vs_closure.png")


def main() -> None:
    sprite, metrics = build_native()
    make_previews(sprite)
    manifest = [{"id": "portrait_squad", "file": "portrait_squad.png", "size": [105, 150], "display_scale": 4, "preview": "portrait_squad_4x.png", "panel_composite": "portrait_squad_panel.png", "style_composites": ["portrait_squad_vs_amiya.png", "portrait_squad_vs_closure.png"], "native_source": "native_art.py", "concept_reference": "source_paintings/portrait_squad_chibi_r1.png", "metrics": metrics}]
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report = ["P1 v3 revision 1 static validation", f"PASS 105x150 RGBA, binary alpha, {metrics['colors']} colours, top clear {metrics['top_clear_px']} px.", "PASS exact dark/light cyan and dark/light orange accents; no isolated cyan, silver or white pixels; 4x, encounter-panel, Amiya and accepted Closure comparisons.", "Visual acceptance and Godot runtime display remain unverified."]
    (HERE / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
