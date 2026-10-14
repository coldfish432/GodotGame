"""Build the v3 chibi portraits from retained pixel-art source drawings."""

from __future__ import annotations

import colorsys
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageFilter


HERE = Path(__file__).resolve().parent
PORTRAITS = HERE.parent
REFS = PORTRAITS / "refs" / "in_game"
STYLE = PORTRAITS / "refs_style"
OUTLINE = (11, 12, 13, 255)
SPECS = (
    ("portrait_squad", (105, 150), (99, 132), 150, 430, "gui-squad.png"),
    ("portrait_cannot", (85, 150), (79, 132), 150, 360, "gui-trader.png"),
    ("portrait_closure", (85, 150), (79, 102), 140, 380, "gui-camp.png"),
)


def stylize_signal(name: str, original: tuple[int, int, int], reduced: tuple[int, int, int], xy: tuple[int, int]) -> tuple[int, int, int]:
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in original))
    if name == "portrait_squad" and .47 <= h <= .58 and s >= .28 and v >= .48:
        return (95, 208, 216) if v >= .75 else (42, 138, 146)
    if name == "portrait_squad" and 53 <= xy[0] <= 68 and 33 <= xy[1] <= 40 and .04 <= h <= .14 and s >= .70 and original[0] > original[1] * 1.3 and original[1] > original[2] * 1.3:
        return (255, 174, 32) if v >= .65 else (188, 83, 9)
    if name == "portrait_cannot" and .07 <= h <= .16 and s >= .40 and v >= .55:
        return (230, 194, 90) if v >= .72 else (153, 116, 43)
    if name == "portrait_closure" and .08 <= h <= .18 and s >= .7 and v >= .5:
        return (244, 193, 46) if v >= .8 else (177, 122, 18)
    return reduced


def quantize_visible(image: Image.Image, mask: Image.Image, name: str) -> Image.Image:
    visible = [p[:3] for p, a in zip(image.get_flattened_data(), mask.get_flattened_data()) if a]
    positions = [(i % image.width, i // image.width) for i, a in enumerate(mask.get_flattened_data()) if a]
    row = Image.new("RGB", (len(visible), 1))
    row.putdata(visible)
    reduced = row.quantize(colors=39, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    colors = [
        stylize_signal(name, original, reduced_color, xy)
        for original, reduced_color, xy in zip(visible, reduced.convert("RGB").get_flattened_data(), positions)
    ]
    output = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out = []
    k = 0
    for a in mask.get_flattened_data():
        if a:
            out.append((*colors[k], 255))
            k += 1
        else:
            out.append((0, 0, 0, 0))
    output.putdata(out)
    return output


def build_native(name: str, canvas: tuple[int, int], content: tuple[int, int], foot: int) -> tuple[Image.Image, dict]:
    source_path = HERE / "source_paintings" / f"{name}_chibi.png"
    source = Image.open(source_path).convert("RGBA")
    mask = source.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    box = mask.getbbox()
    assert box is not None
    small = source.crop(box).resize(content, Image.Resampling.NEAREST)
    small_mask = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    small = quantize_visible(small, small_mask, name)
    native = Image.new("RGBA", canvas, (0, 0, 0, 0))
    x = (canvas[0] - content[0]) // 2
    y = foot - content[1]
    native.alpha_composite(small, (x, y))
    outline_mask = native.getchannel("A").filter(ImageFilter.MaxFilter(3))
    result = Image.new("RGBA", canvas, OUTLINE)
    result.putalpha(outline_mask)
    result.alpha_composite(native)
    result.save(HERE / f"{name}.png")
    result.resize((canvas[0] * 4, canvas[1] * 4), Image.Resampling.NEAREST).save(HERE / f"{name}_4x.png")
    alpha = {p[3] for p in result.get_flattened_data()}
    colors = {p[:3] for p in result.get_flattened_data() if p[3]}
    assert alpha == {0, 255}
    assert outline_mask.getbbox()[1] >= 2
    assert len(colors) <= 48, (name, len(colors))
    if name == "portrait_squad":
        assert (95, 208, 216) in colors and (42, 138, 146) in colors
        assert (255, 174, 32) in colors and (188, 83, 9) in colors
    elif name == "portrait_cannot":
        assert (230, 194, 90) in colors
    else:
        assert (244, 193, 46) in colors
    metrics = {
        "source_size": list(source.size),
        "source_crop": list(box),
        "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "visible_bbox_px": list(outline_mask.getbbox()),
        "top_clear_px": outline_mask.getbbox()[1],
        "colors": len(colors),
        "alpha_values": sorted(alpha),
    }
    return result, metrics


def panel_preview(name: str, sprite: Image.Image, panel_width: int, backdrop: str) -> str:
    panel = Image.open(REFS / backdrop).convert("RGBA")
    controls = (
        [(box, panel.crop(box)) for box in ((24, 592, 356, 657), (24, 663, 356, 706))]
        if name == "portrait_closure" else []
    )
    left, right = (85, 310) if name == "portrait_squad" else (70, 290)
    for y in range(210, 463):
        a, b = panel.getpixel((left, y)), panel.getpixel((right, y))
        for x in range(left + 1, right):
            t = (x - left) / (right - left)
            panel.putpixel((x, y), tuple(round(a[c] * (1 - t) + b[c] * t) for c in range(4)))
    shown = sprite.resize((sprite.width * 4, sprite.height * 4), Image.Resampling.NEAREST)
    panel.alpha_composite(shown, ((panel_width - shown.width) // 2, 120))
    for box, crop in controls:
        panel.paste(crop, box[:2])
    output = f"{name}_panel.png"
    panel.save(HERE / output)
    return output


def style_preview(name: str, sprite: Image.Image) -> str:
    result = Image.new("RGBA", (800, 600), (24, 28, 31, 255))
    amiya = Image.open(STYLE / "amiya_guard_portrait_4x.png").convert("RGBA")
    result.alpha_composite(amiya, (32, 600 - amiya.height))
    shown = sprite.resize((sprite.width * 4, sprite.height * 4), Image.Resampling.NEAREST)
    result.alpha_composite(shown, (440 + (340 - shown.width) // 2, 0))
    filename = f"{name}_vs_amiya.png"
    result.save(HERE / filename)
    return filename


def main() -> None:
    manifest = []
    report = ["P1 v3 static validation", "Source: generated chibi pixel drawing, processed at native canvas with nearest-neighbour sampling, binary alpha, no dithering, 1 px #0b0c0d outer outline."]
    for name, canvas, content, foot, panel_width, backdrop in SPECS:
        sprite, metrics = build_native(name, canvas, content, foot)
        panel_file = panel_preview(name, sprite, panel_width, backdrop)
        style_file = style_preview(name, sprite)
        manifest.append({
            "id": name,
            "file": f"{name}.png",
            "size": list(canvas),
            "display_scale": 4,
            "preview": f"{name}_4x.png",
            "panel_composite": panel_file,
            "style_composite": style_file,
            "source_painting": f"source_paintings/{name}_chibi.png",
            "model_note": (
                "Three distinct PRTS reserve operators; sniper orange goggles pinned at native scale."
                if name == "portrait_squad" else
                "Sleeveless white inner top per latest user direction; supersedes the v3 long-sleeve note."
                if name == "portrait_closure" else None
            ),
            "metrics": metrics,
        })
        report.append(f"PASS {name}: {canvas[0]}x{canvas[1]}, binary alpha, {metrics['colors']} colors, top clear {metrics['top_clear_px']} px, 4x and panel/style previews.")
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report.append("Manual panel review: squad sniper's orange goggles read in the real encounter panel; all three reserve models are distinct.")
    report.append("Manual panel review: Closure's head, hands, yellow chest device and drone remain visible above the camp buttons. Sleeveless shoulders follow the latest user direction.")
    report.append("Visual acceptance pending: character model and style. Godot runtime import/display was not tested.")
    (HERE / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
