"""Reduce painted M1 sources and package native material icons."""

from collections import Counter
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
BATCH = ROOT / "batch_M1_v1"
BRIEF = (ROOT / "M_brief_v1.md").read_text(encoding="utf-8")
SECTION = BRIEF.split("## M1: PRTS materials", 1)[1].split("## M2:", 1)[0]
OUTLINE = (11, 12, 13, 255)
ORIGINIUM_RAMP = ((184, 90, 18), (238, 138, 36), (255, 179, 90), (255, 224, 168))
SIZE = 32
CONTENT = 28
ROWS = []
for line in SECTION.splitlines():
    if re.match(r"^\|\s*`[a-z0-9_]+`", line):
        cells = [cell.strip() for cell in line.split("|")]
        ROWS.append((cells[1].strip("`"), cells[2], int(cells[3])))


def luminance(color: tuple[int, int, int]) -> float:
    r, g, b = color
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def reduce_icon(source: Path, target: Path, originium: bool = False) -> None:
    original = Image.open(source).convert("RGBA")
    mask = original.getchannel("A").point(lambda value: 255 if value >= 160 else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"No opaque pixels in {source}")
    cropped = original.crop(bounds)
    mask = mask.crop(bounds)
    ratio = min(CONTENT / cropped.width, CONTENT / cropped.height)
    dimensions = (max(1, round(cropped.width * ratio)), max(1, round(cropped.height * ratio)))
    cropped = cropped.resize(dimensions, Image.Resampling.NEAREST)
    mask = mask.resize(dimensions, Image.Resampling.NEAREST)
    visible = [pixel[:3] for pixel, opacity in zip(cropped.get_flattened_data(), mask.get_flattened_data()) if opacity]
    swatches = Image.new("RGB", (len(visible), 1))
    swatches.putdata(visible)
    palette = swatches.quantize(colors=19 if originium else 23, method=Image.Quantize.MEDIANCUT)
    opaque = cropped.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")
    colored = Image.merge("RGBA", (*opaque.split(), mask))
    canvas = Image.new("RGBA", (SIZE, SIZE))
    x0 = (SIZE - dimensions[0]) // 2
    y0 = (SIZE - dimensions[1]) // 2
    canvas.alpha_composite(colored, (x0, y0))

    pixels = canvas.load()
    alpha = canvas.getchannel("A")
    if originium:
        source_pixels = cropped.load()
        for y in range(dimensions[1]):
            for x in range(dimensions[0]):
                r, g, b, a = source_pixels[x, y]
                if a < 160 or r < 115 or r < g * 1.28 or g < b * 1.35:
                    continue
                strength = luminance((r, g, b))
                ramp = 0 if strength < 100 else 1 if strength < 145 else 2 if strength < 195 else 3
                pixels[x + x0, y + y0] = (*ORIGINIUM_RAMP[ramp], 255)

    # Rebuild one hard contour pixel around every visible silhouette edge.
    for y in range(1, SIZE - 1):
        for x in range(1, SIZE - 1):
            if alpha.getpixel((x, y)) and any(
                alpha.getpixel((x + dx, y + dy)) == 0
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1))
            ):
                pixels[x, y] = OUTLINE

    # Lift the brightest existing palette colors for 32 px readability.
    counts = Counter(pixel[:3] for pixel in canvas.get_flattened_data() if pixel[3] and pixel != OUTLINE)
    total = sum(1 for pixel in canvas.get_flattened_data() if pixel[3])
    bright = sum(count for color, count in counts.items() if luminance(color) >= 153)
    wanted = (total * 16 + 99) // 100
    changes = {}
    for color, count in sorted(counts.items(), key=lambda item: luminance(item[0]), reverse=True):
        if bright >= wanted:
            break
        if color in ORIGINIUM_RAMP:
            continue
        light = luminance(color)
        if light >= 153:
            continue
        blend = (160 - light) / (255 - light)
        changes[color] = tuple(round(channel + (255 - channel) * blend) for channel in color)
        bright += count
    for y in range(SIZE):
        for x in range(SIZE):
            pixel = pixels[x, y]
            updated = changes.get(pixel[:3]) if pixel[3] else None
            if updated is not None:
                pixels[x, y] = (*updated, 255)
    if originium:
        # The painted hollow motif becomes subpixel noise at 32 px; restore
        # its five-pixel native silhouette and keep the empty center unlit.
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((12, 10, 18, 16), fill=(20, 20, 24, 255))
        draw.rectangle((13, 11, 17, 15), fill=(20, 20, 24, 255), outline=(*ORIGINIUM_RAMP[2], 255))
        draw.point((13, 11), fill=(*ORIGINIUM_RAMP[3], 255))
        draw.point((17, 15), fill=(*ORIGINIUM_RAMP[0], 255))
    canvas.save(target)


def make_emit(base: Path, target: Path) -> None:
    icon = Image.open(base).convert("RGBA")
    emit = Image.new("RGBA", icon.size)
    dst = emit.load()
    for y in range(icon.height):
        for x in range(icon.width):
            pixel = icon.getpixel((x, y))
            if pixel[3] and pixel[:3] in ORIGINIUM_RAMP:
                dst[x, y] = pixel
    emit.save(target)


def break_flat_device_face(path: Path) -> None:
    """Split a broad painted device face into two directional light clusters."""
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    colors = Counter(pixel for pixel in image.get_flattened_data() if pixel[3] and pixel != OUTLINE)
    if not colors:
        return
    dominant, count = colors.most_common(1)[0]
    if count / sum(colors.values()) <= 0.25:
        return
    positions = sorted(((x, y) for y in range(SIZE) for x in range(SIZE)
                        if pixels[x, y] == dominant), key=lambda point: point[0] + point[1])
    if luminance(dominant[:3]) < 153:
        subset = positions[: len(positions) // 2]
        replacement = tuple(min(255, value + 16) for value in dominant[:3]) + (255,)
    else:
        subset = positions[len(positions) // 2 :]
        replacement = tuple(max(0, value - 18) for value in dominant[:3]) + (255,)
    for x, y in subset:
        pixels[x, y] = replacement
    image.save(path)


def metrics(image: Image.Image) -> dict:
    rgba = image.convert("RGBA")
    visible = [pixel for pixel in rgba.get_flattened_data() if pixel[3]]
    interior = [pixel for pixel in visible if pixel != OUTLINE]
    counts = Counter(pixel[:3] for pixel in interior)
    bright = sum(luminance(pixel[:3]) >= 153 for pixel in visible)
    return {
        "opaque_colors": len({pixel[:3] for pixel in visible}),
        "alpha_binary": set(rgba.getchannel("A").get_flattened_data()) <= {0, 255},
        "bbox": rgba.getchannel("A").getbbox(),
        "bright_fraction": round(bright / len(visible), 3) if visible else 0,
        "largest_interior_color_fraction": round(max(counts.values(), default=0) / len(interior), 3) if interior else 0,
    }


def build() -> None:
    BATCH.mkdir(exist_ok=True)
    (BATCH / ".gdignore").touch()
    (BATCH / "sources" / ".gdignore").touch()
    manifest = []
    report = ["M1 material icon validation", ""]
    for id_, name, _stars in ROWS:
        source = BATCH / "sources" / f"{id_}.png"
        if not source.is_file():
            report.append(f"MISSING {id_}: source image absent")
            continue
        target = BATCH / f"{id_}.png"
        reduce_icon(source, target, id_ == "originium_shard")
        if id_ in {"device", "optimized_device"}:
            break_flat_device_face(target)
        icon = Image.open(target).convert("RGBA")
        icon.resize((256, 256), Image.Resampling.NEAREST).save(BATCH / f"{id_}_8x.png")
        emit_file = None
        if id_ == "originium_shard":
            emit_file = "originium_shard_emit.png"
            make_emit(target, BATCH / emit_file)
            Image.open(BATCH / emit_file).resize((256, 256), Image.Resampling.NEAREST).save(BATCH / "originium_shard_emit_8x.png")
        manifest.append({"id": id_, "name": name, "file": target.name, "size": [32, 32], "cells": [1, 1], "emit": emit_file})
        m = metrics(icon)
        margin = min(m["bbox"][0], m["bbox"][1], SIZE - m["bbox"][2], SIZE - m["bbox"][3])
        passed = (m["alpha_binary"] and m["opaque_colors"] <= 24 and margin >= 2
                  and m["bright_fraction"] >= 0.15 and m["largest_interior_color_fraction"] <= 0.25)
        report.append(f"{'PASS' if passed else 'REVIEW'} {id_}: {json.dumps(m, ensure_ascii=False)}")
    (BATCH / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    columns = 4
    column_width = 224
    groups = (len(ROWS) + columns - 1) // columns
    backgrounds = ("#2c2e30", "#142538", "#352710", "#381b0f")
    contact = Image.new("RGB", (columns * column_width + 12, groups * 4 * 44 + 12), "#111214")
    draw = ImageDraw.Draw(contact)
    for index, (id_, _name, _stars) in enumerate(ROWS):
        path = BATCH / f"{id_}.png"
        if not path.is_file():
            continue
        icon = Image.open(path).convert("RGBA")
        col, group = index % columns, index // columns
        for bi, bg in enumerate(backgrounds):
            x = 6 + col * column_width
            y = 6 + group * 176 + bi * 44
            draw.rectangle((x, y, x + 39, y + 39), fill=bg)
            contact.paste(icon, (x + 4, y + 4), icon)
            draw.rectangle((x + 28, y + 28, x + 39, y + 39), fill="#050607")
            draw.text((x + 28, y + 29), "10", fill="#f2ead2")
            draw.text((x + 44, y + 15), id_, fill="#d0d0d0")
    contact.save(BATCH / "contact_sheet.png")
    (BATCH / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"Packaged {len(manifest)}/{len(ROWS)} M1 icons")


if __name__ == "__main__":
    build()
