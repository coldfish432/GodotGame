"""Package painted M2/M3 sources as native pixel inventory icons."""

from collections import Counter
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
BRIEF = (ROOT / "M_brief_v1.md").read_text(encoding="utf-8")
OUTLINE = (11, 12, 13, 255)
BACKGROUND_COLORS = ("#2c2e30", "#142538", "#352710", "#381b0f")
ORIGINIUM_RAMP = {(184, 90, 18), (238, 138, 36), (255, 179, 90), (255, 224, 168)}


def rows_for(batch: str) -> list[tuple[str, str, tuple[int, int], tuple[int, int]]]:
    start = "## M2: Common supplies" if batch == "M2" else "## M3: Potions"
    end = "## M3:" if batch == "M2" else "## Game references"
    section = BRIEF.split(start, 1)[1].split(end, 1)[0]
    rows = []
    for line in section.splitlines():
        if not re.match(r"^\|\s*`[a-z0-9_]+`", line):
            continue
        fields = [field.strip() for field in line.split("|")]
        if batch == "M2":
            cells = tuple(map(int, fields[5].split("×")))
            size = tuple(map(int, fields[6].split("×")))
        else:
            cells, size = (1, 1), (32, 32)
        rows.append((fields[1].strip("`"), fields[2], cells, size))
    return rows


def luminance(color: tuple[int, int, int]) -> float:
    r, g, b = color
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def make_native(source: Path, target: Path, size: tuple[int, int]) -> None:
    original = Image.open(source).convert("RGBA")
    mask = original.getchannel("A").point(lambda value: 255 if value >= 160 else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"No visible source: {source}")
    crop = original.crop(bounds)
    mask = mask.crop(bounds)
    red_source = None
    if target.stem == "car_battery":
        red_source = Image.new("L", crop.size)
        red_pixels = red_source.load()
        source_pixels = crop.load()
        for y in range(crop.height):
            for x in range(crop.width):
                r, g, b, a = source_pixels[x, y]
                if a >= 160 and r > 100 and r > g * 1.45 and r > b * 1.45:
                    red_pixels[x, y] = 255
    content_w, content_h = size[0] - 4, size[1] - 4
    scale = min(content_w / crop.width, content_h / crop.height)
    dimensions = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    if red_source is not None:
        red_source = red_source.resize(dimensions, Image.Resampling.BOX)
    crop = crop.resize(dimensions, Image.Resampling.NEAREST)
    mask = mask.resize(dimensions, Image.Resampling.NEAREST)
    swatch_colors = [pixel[:3] for pixel, alpha in zip(crop.get_flattened_data(), mask.get_flattened_data()) if alpha]
    swatches = Image.new("RGB", (len(swatch_colors), 1))
    swatches.putdata(swatch_colors)
    palette = swatches.quantize(colors=21, method=Image.Quantize.MEDIANCUT)
    painted = crop.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")
    reduced = Image.merge("RGBA", (*painted.split(), mask))
    icon = Image.new("RGBA", size)
    offset = ((size[0] - dimensions[0]) // 2, (size[1] - dimensions[1]) // 2)
    icon.alpha_composite(reduced, offset)
    alpha = icon.getchannel("A")
    pixels = icon.load()

    for y in range(1, size[1] - 1):
        for x in range(1, size[0] - 1):
            if alpha.getpixel((x, y)) and any(
                alpha.getpixel((x + dx, y + dy)) == 0
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1))
            ):
                pixels[x, y] = OUTLINE

    visible = [p for p in icon.get_flattened_data() if p[3]]
    needed = max(0, (len(visible) * 16 + 99) // 100 - sum(luminance(p[:3]) >= 153 for p in visible))
    counts = Counter(p[:3] for p in visible if p != OUTLINE)
    changes = {}
    for color, count in sorted(counts.items(), key=lambda pair: luminance(pair[0]), reverse=True):
        if needed <= 0:
            break
        if luminance(color) >= 153:
            continue
        brightness = luminance(color)
        blend = (162 - brightness) / (255 - brightness)
        changes[color] = tuple(round(channel + (255 - channel) * blend) for channel in color)
        needed -= count
    for y in range(size[1]):
        for x in range(size[0]):
            p = pixels[x, y]
            if p[3] and p[:3] in changes:
                pixels[x, y] = (*changes[p[:3]], 255)

    # Split an oversized flat painted face into upper-left light and lower-right shade.
    interior = [p for p in icon.get_flattened_data() if p[3] and p != OUTLINE]
    if interior:
        dominant, count = Counter(interior).most_common(1)[0]
        if count / len(interior) > 0.25:
            positions = sorted(
                ((x, y) for y in range(size[1]) for x in range(size[0]) if pixels[x, y] == dominant),
                key=lambda point: point[0] + point[1],
            )
            subset = positions[: len(positions) // 2]
            replacement = tuple(min(255, value + 16) for value in dominant[:3]) + (255,)
            for x, y in subset:
                pixels[x, y] = replacement
    if red_source is not None:
        for y in range(dimensions[1]):
            for x in range(dimensions[0]):
                px, py = x + offset[0], y + offset[1]
                if red_source.getpixel((x, y)) > 48 and pixels[px, py][3] and pixels[px, py] != OUTLINE:
                    pixels[px, py] = ((235, 104, 91, 255) if x + y < 33 else (198, 49, 46, 255))
    icon.save(target)


def metrics(icon: Image.Image) -> dict:
    visible = [p for p in icon.get_flattened_data() if p[3]]
    interior = [p[:3] for p in visible if p != OUTLINE]
    components = Counter(interior)
    return {
        "size": list(icon.size),
        "binary_alpha": set(icon.getchannel("A").get_flattened_data()) == {0, 255},
        "opaque_colors": len({p[:3] for p in visible}),
        "bbox": icon.getchannel("A").getbbox(),
        "bright_fraction": round(sum(luminance(p[:3]) >= 153 for p in visible) / len(visible), 3),
        "largest_interior_color_fraction": round(max(components.values(), default=0) / len(interior), 3),
        "originium_ramp_pixels": sum(p[:3] in ORIGINIUM_RAMP for p in visible),
    }


def make_contact(batch: str, rows: list, folder: Path) -> None:
    # Every item appears at 1:1 on four inventory backgrounds; tiles scale by cell count.
    row_height = 100
    image = Image.new("RGB", (540, len(rows) * row_height + 8), "#101113")
    draw = ImageDraw.Draw(image)
    for index, (item_id, name, cells, size) in enumerate(rows):
        icon = Image.open(folder / f"{item_id}.png").convert("RGBA")
        y = 8 + index * row_height
        draw.text((8, y), f"{item_id}  {size[0]}x{size[1]}", fill="#e0e0e0")
        for slot, color in enumerate(BACKGROUND_COLORS):
            x = 8 + slot * 132
            tile = (cells[0] * 40, cells[1] * 40)
            draw.rectangle((x, y + 16, x + tile[0] - 1, y + 16 + tile[1] - 1), fill=color)
            image.paste(icon, (x + 4, y + 20), icon)
            badge_x, badge_y = x + tile[0] - 12, y + 16 + tile[1] - 12
            draw.rectangle((badge_x, badge_y, badge_x + 11, badge_y + 11), fill="#050607")
            draw.text((badge_x, badge_y + 1), "10", fill="#f2ead2")
    image.save(folder / "contact_sheet.png")


def build_batch(batch: str) -> None:
    rows = rows_for(batch)
    folder = ROOT / f"batch_{batch}_v1"
    folder.mkdir(exist_ok=True)
    (folder / ".gdignore").touch()
    (folder / "sources" / ".gdignore").touch()
    manifest, report = [], [f"{batch} static icon validation", ""]
    for item_id, name, cells, size in rows:
        source = folder / "sources" / f"{item_id}.png"
        if not source.is_file():
            report.append(f"MISSING {item_id}: source image absent")
            continue
        target = folder / f"{item_id}.png"
        make_native(source, target, size)
        icon = Image.open(target).convert("RGBA")
        icon.resize((size[0] * 8, size[1] * 8), Image.Resampling.NEAREST).save(folder / f"{item_id}_8x.png")
        manifest.append({"id": item_id, "name": name, "file": target.name, "size": list(size), "cells": list(cells), "emit": None})
        m = metrics(icon)
        box = m["bbox"]
        margin = min(box[0], box[1], size[0] - box[2], size[1] - box[3])
        passed = (m["binary_alpha"] and m["opaque_colors"] <= 24 and margin >= 2
                  and m["bright_fraction"] >= 0.15 and m["largest_interior_color_fraction"] <= 0.25
                  and m["originium_ramp_pixels"] == 0)
        report.append(f"{'PASS' if passed else 'REVIEW'} {item_id}: {json.dumps(m, ensure_ascii=False)}")
    (folder / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (folder / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    make_contact(batch, rows, folder)
    print(f"{batch}: packaged {len(manifest)}/{len(rows)} icons; {sum(x.startswith('PASS ') for x in report)} PASS")


if __name__ == "__main__":
    build_batch("M2")
    build_batch("M3")
