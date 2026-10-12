"""Package only the five E7 weapons revised for native fill height."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parent
ITEMS = ROOT.parent
V1 = ITEMS / "batch_E7_v1"
sys.path.insert(0, str(V1))
from build_e7 import PALETTE_BASE, ORANGE, OUTLINE, isolated_percent, smooth_single_pixels, raise_highlight_floor

SIZE = (72, 32)
SPECS = [
    ("mi_thug_0", "暴徒的改刃", "exclusive", "blade", 27, ["modified_machete.png"]),
    ("mine_x05", "游击队旧式刺刀", "base", "blade", 21, ["proto_bayonet.jpg"]),
    ("set_warrant_0", "追缉令·钩刀", "set", "blade", 23, ["mine_x04.png"]),
    ("mine_x06", "施术短刃", "base", "blade", 21, ["proto_trench_knife.jpg"]),
    ("mine_x08", "帝国突击矛", "base", "polearm", 12, []),
]
BACKGROUNDS = ["#2c2e30", "#142538", "#352710", "#341e08", "#112e1f"]


def prepare_source(item_id: str) -> Image.Image:
    image = Image.open(ROOT / "sources" / f"{item_id}_raw.png").convert("RGBA")
    pixels = np.array(image)
    pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    image = Image.fromarray(pixels, "RGBA")
    bbox = image.getbbox()
    if bbox is None:
        raise ValueError(item_id)
    image = image.crop(bbox)
    image.save(ROOT / "sources" / f"{item_id}_painted.png")
    return image


def reduce_to_target(source: Image.Image, item_id: str, target_height: int) -> Image.Image:
    reduced = source.resize((70, target_height), Image.Resampling.BOX)
    raw = np.array(reduced)
    visible = raw[:, :, 3] >= 100
    palette = np.array(PALETTE_BASE + (ORANGE if item_id == "mine_x06" else []), dtype=np.int32)
    rgb = raw[:, :, :3].astype(np.int32)
    distances = np.square(rgb[:, :, None, :] - palette[None, None, :, :]).sum(axis=3)
    mapped = palette[np.argmin(distances, axis=2)].astype(np.uint8)
    interior = visible.copy()
    interior[1:, :] &= visible[:-1, :]
    interior[:-1, :] &= visible[1:, :]
    interior[:, 1:] &= visible[:, :-1]
    interior[:, :-1] &= visible[:, 1:]
    mapped[visible & ~interior] = OUTLINE
    output = np.zeros((32, 72, 4), dtype=np.uint8)
    left, top = 1, (32 - target_height) // 2
    output[top:top + target_height, left:71, :3] = mapped
    output[top:top + target_height, left:71, 3] = visible.astype(np.uint8) * 255
    output = smooth_single_pixels(output)
    if item_id == "mi_thug_0":
        # The source edit kept two strong welds; reinforce the third between them.
        for y in range(7, 24):
            if output[y, 45, 3]:
                output[y, 45, :3] = (125, 69, 41)
            if output[y, 46, 3] and y % 4 != 0:
                output[y, 46, :3] = (217, 149, 96)
    output = raise_highlight_floor(output)
    return Image.fromarray(output, "RGBA")


def make_emit(icon: Image.Image) -> Image.Image:
    raw = np.array(icon)
    emit = np.zeros_like(raw)
    warm = np.zeros(raw.shape[:2], dtype=bool)
    for colour in ORANGE:
        warm |= np.all(raw[:, :, :3] == colour, axis=2)
    # The indicator is the one warm blob at the top of the boxed grip.
    yy, xx = np.indices(warm.shape)
    warm &= (xx >= 21) & (xx <= 36) & (yy < 16) & (raw[:, :, 3] > 0)
    emit[warm] = raw[warm]
    if not warm.any():
        raise ValueError("mine_x06 crystal emit was lost")
    return Image.fromarray(emit, "RGBA")


def preview(manifest: list[dict]) -> None:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    width, row_h = 1670, 40
    sheet = Image.new("RGB", (width, len(manifest) * row_h + 96), "#17191b")
    draw = ImageDraw.Draw(sheet)
    for row, entry in enumerate(manifest):
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        draw.text((5, row * row_h + 10), entry["id"], font=font, fill="#f4f3ef")
        for col, bg in enumerate(BACKGROUNDS):
            x, y = 175 + col * 80, row * row_h
            draw.rectangle((x, y, x + 79, y + 39), fill=bg)
            sheet.paste(icon, (x + 4, y + 4), icon)
    old = Image.open(ITEMS / "batch_E1_v5" / "modified_machete.png").convert("RGBA")
    old_2x = old.resize((144, 64), Image.Resampling.NEAREST)
    y = len(manifest) * row_h
    draw.text((5, y + 8), "2x fill vs old", font=font, fill="#f4f3ef")
    for col, entry in enumerate(manifest):
        x = 160 + col * 300
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        new_2x = icon.resize((144, 64), Image.Resampling.NEAREST)
        draw.rectangle((x, y, x + 299, y + 95), fill="#2c2e30")
        sheet.paste(old_2x, (x + 3, y + 3), old_2x)
        sheet.paste(new_2x, (x + 152, y + 3), new_2x)
        draw.text((x + 4, y + 71), entry["id"], font=font, fill="#f4f3ef")
    sheet.save(ROOT / "contact_sheet.png")
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")
    sheet.crop((0, y, width, y + 96)).save(ROOT / "fill_vs_old_2x.png")
    silhouettes = Image.new("RGB", (5 * 180, 72), "#d2cbbb")
    pen = ImageDraw.Draw(silhouettes)
    for index, entry in enumerate(manifest):
        alpha = Image.open(ROOT / entry["file"]).convert("RGBA").getchannel("A")
        silhouettes.paste(Image.new("RGB", SIZE, "#111315"), (index * 180 + 50, 6), alpha)
        pen.text((index * 180 + 3, 45), entry["id"], font=font, fill="#222222")
    silhouettes.save(ROOT / "silhouette_check.png")


def main() -> None:
    manifest = []
    for item_id, name, kind, form, target_height, refs in SPECS:
        source = prepare_source(item_id)
        icon = reduce_to_target(source, item_id, target_height)
        icon.save(ROOT / f"{item_id}.png")
        icon.resize((576, 256), Image.Resampling.NEAREST).save(ROOT / f"{item_id}_8x.png")
        has_emit = item_id == "mine_x06"
        if has_emit:
            make_emit(icon).save(ROOT / f"{item_id}_emit.png")
        bounds = icon.getbbox()
        manifest.append({
            "id": item_id, "name": name, "kind": kind, "form": form,
            "file": f"{item_id}.png", "native_size": [72, 32],
            "has_emit": has_emit, "prototype_refs": refs,
            "target_height": target_height, "silhouette_height": bounds[3] - bounds[1],
            "isolated_pixel_percent": isolated_percent(icon),
            "supersedes": f"batch_E7_v1/{item_id}.png",
        })
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    preview(manifest)


if __name__ == "__main__":
    main()
