"""Package generated relic drafts for visual review and Godot import."""

import argparse
from collections import Counter
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

from reduce_generated import reduce_icon


ROOT = Path(__file__).resolve().parent
TEXT = (ROOT / "R_brief_v1.md").read_text(encoding="utf-8")
BATCH = ROOT / "batch_R1_v1"
ROWS = []


def select_batch(number: str) -> None:
    global BATCH, ROWS
    section = TEXT.split(f"### {number} —", 1)[1].split("### R", 1)[0]
    BATCH = ROOT / f"batch_{number}_v1"
    ROWS = []
    for line in section.splitlines():
        if not re.match(r"^\|\s*\d+\s*\|", line):
            continue
        cells = [cell.strip() for cell in line.split("|")]
        ROWS.append((cells[2].strip("`"), cells[3], cells[4]))
    if number == "R4" and (BATCH / "sources" / "is2_078.png").exists():
        r3_section = TEXT.split("### R3 —", 1)[1].split("### R4", 1)[0]
        for line in r3_section.splitlines():
            if "`is2_078`" in line:
                cells = [cell.strip() for cell in line.split("|")]
                ROWS.append((cells[2].strip("`"), cells[3], cells[4]))
                break


def metrics(image: Image.Image) -> dict:
    rgba = image.convert("RGBA")
    visible = [px for px in rgba.get_flattened_data() if px[3] > 0]
    bbox = rgba.getchannel("A").getbbox()
    colors = {px[:3] for px in visible}
    bright = sum(1 for r, g, b, _ in visible if 0.2126 * r + 0.7152 * g + 0.0722 * b >= 153)
    interior = [px for px in visible if px != (11, 12, 13, 255)]
    interior_colors = {px[:3] for px in interior}
    most = max((sum(1 for px in interior if px[:3] == color) for color in interior_colors), default=0)
    return {
        "opaque_colors": len(colors),
        "alpha_binary": set(rgba.getchannel("A").get_flattened_data()) <= {0, 255},
        "bbox": bbox,
        "bright_fraction": round(bright / len(visible), 3) if visible else 0,
        "largest_interior_color_fraction": round(most / len(interior), 3) if interior else 0,
    }


def clarify_savings_coin(path: Path) -> None:
    """Retain the painted coin accent after the stone hand's palette reduction."""
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    frequency = Counter(pixel for pixel in image.get_flattened_data() if pixel[3])
    keep = {color for color, _count in frequency.most_common(20)}
    for y in range(image.height):
        for x in range(image.width):
            color = pixels[x, y]
            if color[3] and color not in keep:
                pixels[x, y] = min(
                    keep,
                    key=lambda candidate: sum((color[channel] - candidate[channel]) ** 2 for channel in range(3)),
                )
    draw = ImageDraw.Draw(image)
    draw.ellipse((37, 19, 47, 26), fill="#4a3410")
    draw.ellipse((38, 20, 46, 25), fill="#a8822e")
    draw.ellipse((39, 20, 44, 22), fill="#dcb85a")
    draw.point(((40, 20), (41, 20)), fill="#f4e2a0")
    image.save(path)


def thicken_bracelet_links(path: Path) -> None:
    """Add one material pixel inside the accepted bracelet's dark contour."""
    image = Image.open(path).convert("RGBA")
    original = image.copy()
    pixels = image.load()
    src = original.load()
    outline = (11, 12, 13, 255)
    neighbors = ((0, -1), (-1, 0), (1, 0), (0, 1))
    for y in range(1, 71):
        for x in range(1, 71):
            if src[x, y] != outline:
                continue
            material = [src[x + dx, y + dy] for dx, dy in neighbors
                        if src[x + dx, y + dy][3] and src[x + dx, y + dy] != outline]
            if material:
                pixels[x, y] = max(material, key=lambda color: sum(color[:3]))
    for y in range(1, 71):
        for x in range(1, 71):
            if src[x, y][3]:
                continue
            if any(src[x + dx, y + dy][3] for dx, dy in neighbors):
                pixels[x, y] = outline
    image.save(path)


def build() -> None:
    BATCH.mkdir(exist_ok=True)
    (BATCH / ".gdignore").touch()
    (BATCH / "sources" / ".gdignore").touch()
    manifest = []
    report = [f"{BATCH.name} generated icon validation", ""]
    for id_, name, _rarity in ROWS:
        source = BATCH / "sources" / f"{id_}.png"
        if not source.exists():
            report.append(f"MISSING {id_}: source image absent")
            continue
        target = BATCH / f"{id_}.png"
        reduce_icon(source, target)
        if BATCH.name == "batch_R2_v1" and id_ == "is2_139":
            clarify_savings_coin(target)
        if BATCH.name == "batch_R4_v1" and id_ == "is2_078":
            thicken_bracelet_links(target)
        image = Image.open(target).convert("RGBA")
        image.resize((576, 576), Image.Resampling.NEAREST).save(BATCH / f"{id_}_8x.png")
        manifest.append({"id": id_, "name": name, "file": target.name, "size": [72, 72]})
        m = metrics(image)
        passed = (
            image.size == (72, 72)
            and m["alpha_binary"]
            and m["opaque_colors"] <= 24
            and m["bbox"] is not None
            and min(m["bbox"][0], m["bbox"][1], 72 - m["bbox"][2], 72 - m["bbox"][3]) >= 3
            and max(m["bbox"][2] - m["bbox"][0], m["bbox"][3] - m["bbox"][1]) >= 58
            and m["bright_fraction"] >= 0.15
            and m["largest_interior_color_fraction"] <= 0.25
        )
        report.append(f"{'PASS' if passed else 'REVIEW'} {id_}: {json.dumps(m, ensure_ascii=False)}")
    (BATCH / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    columns = 8
    groups = (len(ROWS) + columns - 1) // columns
    width = 8 * 164 + 16
    base_height = 20 + groups * 3 * 90
    height = base_height + 28 + groups * 168
    contact = Image.new("RGB", (width, height), "#0f1012")
    draw = ImageDraw.Draw(contact)
    for index, (id_, _name, _rarity) in enumerate(ROWS):
        path = BATCH / f"{id_}.png"
        if not path.exists():
            continue
        icon = Image.open(path).convert("RGBA")
        col, group = index % columns, index // columns
        x = 12 + col * 164
        for ri, line_color in enumerate(("#c9d3db", "#72b8ff", "#f3b04a")):
            y = 20 + group * 270 + ri * 90
            draw.rectangle((x, y, x + 71, y + 71), fill="#1b1b1b")
            contact.paste(icon, (x, y), icon)
            draw.rectangle((x, y + 69, x + 71, y + 71), fill=line_color)
            draw.text((x + 76, y + 28), id_, fill="#d0d0d0")
        x2 = 12 + col * 164
        y2 = base_height + 28 + group * 168
        draw.rectangle((x2, y2, x2 + 143, y2 + 143), fill="#1b1b1b")
        preview = icon.resize((144, 144), Image.Resampling.NEAREST)
        contact.paste(preview, (x2, y2), preview)
    contact.save(BATCH / "contact_sheet.png")
    (BATCH / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"Packaged {len(manifest)}/{len(ROWS)} {BATCH.name} icons")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("batch", nargs="?", choices=("R1", "R2", "R3", "R4"), default="R1")
    arguments = parser.parse_args()
    select_batch(arguments.batch)
    build()
