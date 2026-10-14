"""Build the reviewable P1 portraits from the retained imagegen paintings."""

from __future__ import annotations

import json
import hashlib
from pathlib import Path

from PIL import Image, ImageFilter


HERE = Path(__file__).resolve().parent
REFS = HERE.parent / "refs" / "in_game"
OUTLINE = (11, 12, 13, 255)
SPECS = (
    ("portrait_squad", (200, 300), 430, "gui-squad.png"),
    ("portrait_cannot", (170, 300), 360, "gui-trader.png"),
    ("portrait_closure", (170, 300), 380, "gui-camp.png"),
)


def quantize_opaque(image: Image.Image, mask: Image.Image) -> tuple[Image.Image, int]:
    pixels = list(image.get_flattened_data())
    visible = [rgb[:3] for rgb, a in zip(pixels, mask.get_flattened_data()) if a]
    row = Image.new("RGB", (len(visible), 1))
    row.putdata(visible)
    indexed = row.quantize(colors=47, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    reduced = list(indexed.convert("RGB").get_flattened_data())
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out = []
    k = 0
    for a in mask.get_flattened_data():
        if a:
            out.append((*reduced[k], 255))
            k += 1
        else:
            out.append((0, 0, 0, 0))
    result.putdata(out)
    return result, len(set(reduced))


def portrait(name: str, size: tuple[int, int]) -> tuple[Image.Image, dict]:
    source = Image.open(HERE / "source_paintings" / f"{name}_painting.png").convert("RGBA")
    source_mask = source.getchannel("A").point(lambda x: 255 if x >= 128 else 0)
    box = source_mask.getbbox()
    assert box is not None
    cropped = source.crop(box)
    max_width, max_height = size[0] - 8, size[1] - 4
    scale = min(max_width / cropped.width, max_height / cropped.height)
    target = (round(cropped.width * scale), round(cropped.height * scale))
    small = cropped.resize(target, Image.Resampling.NEAREST)
    small_mask = small.getchannel("A").point(lambda x: 255 if x >= 128 else 0)
    small, painted_colors = quantize_opaque(small, small_mask)
    x = (size[0] - target[0]) // 2
    y = size[1] - target[1]
    native = Image.new("RGBA", size, (0, 0, 0, 0))
    native.alpha_composite(small, (x, y))
    silhouette = native.getchannel("A")
    expanded = silhouette.filter(ImageFilter.MaxFilter(3))
    edge = Image.new("RGBA", size, OUTLINE)
    edge.putalpha(expanded)
    edge.alpha_composite(native)
    edge.save(HERE / f"{name}.png")
    edge.resize((size[0] * 2, size[1] * 2), Image.Resampling.NEAREST).save(
        HERE / f"{name}_2x.png"
    )
    colors = {p[:3] for p in edge.get_flattened_data() if p[3]}
    alpha = {p[3] for p in edge.get_flattened_data()}
    assert alpha <= {0, 255}, (name, alpha)
    assert len(colors) <= 48, (name, len(colors))
    assert expanded.getbbox()[1] >= 4, name
    return edge, {
        "source_size": list(source.size),
        "source_crop": list(box),
        "painted_colors": painted_colors,
        "final_colors": len(colors),
        "alpha_values": sorted(alpha),
        "top_clear_px": expanded.getbbox()[1],
        "visible_bbox_px": list(expanded.getbbox()),
    }


def panel_preview(name: str, portrait_image: Image.Image, panel_width: int, backdrop: str) -> str:
    base = Image.open(REFS / backdrop).convert("RGBA")
    controls = (
        [(box, base.crop(box)) for box in ((24, 592, 356, 657), (24, 663, 356, 706))]
        if name == "portrait_closure" else []
    )
    # Remove only the old circle/trapezoid placeholder from the reference capture.
    left, right = (85, 310) if name == "portrait_squad" else (70, 290)
    for y in range(210, 463):
        a = base.getpixel((left, y))
        b = base.getpixel((right, y))
        for x in range(left + 1, right):
            t = (x - left) / (right - left)
            base.putpixel((x, y), tuple(round(a[c] * (1 - t) + b[c] * t) for c in range(4)))
    shown = portrait_image.resize(
        (portrait_image.width * 2, portrait_image.height * 2), Image.Resampling.NEAREST
    )
    base.alpha_composite(shown, ((panel_width - shown.width) // 2, 120))
    for box, crop in controls:
        base.paste(crop, box[:2])
    filename = f"{name}_panel.png"
    base.save(HERE / filename)
    return filename


def main() -> None:
    manifest = []
    report = ["P1 v1 static validation", "Pipeline: retained imagegen painting -> nearest-neighbour resize -> 47-color opaque quantize -> 1 px #0b0c0d external outline."]
    for name, size, panel_width, backdrop in SPECS:
        image, metrics = portrait(name, size)
        composite = panel_preview(name, image, panel_width, backdrop)
        source_path = HERE / "source_paintings" / f"{name}_painting.png"
        manifest.append({
            "id": name,
            "file": f"{name}.png",
            "size": list(size),
            "display_scale": 2,
            "preview": f"{name}_2x.png",
            "panel_composite": composite,
            "source_painting": f"source_paintings/{name}_painting.png",
            "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
            "source_method": "OpenAI built-in imagegen painting; nearest-neighbour reduction and colour quantization",
            "metrics": metrics,
        })
        report.append(f"PASS {name}: {size[0]}x{size[1]}, binary alpha, {metrics['final_colors']} colors, {metrics['top_clear_px']} px clear at top, 2x preview and panel composite.")
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report.append("Visual review required: on-model details and readability in the supplied panel captures. Godot UI/runtime import was not tested.")
    (HERE / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
