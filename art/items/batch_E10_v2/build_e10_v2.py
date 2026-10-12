"""Reduce the four redrawn E10 paintings into a review-only v2 package."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
V1 = ROOT.parent / "batch_E10_v1"
sys.path.insert(0, str(V1))
from build_e10 import BACKGROUNDS, OUTLINE, RAMPS, metrics, old_icon, palette_for, smooth_spots  # noqa: E402

ITEMS = [
    ("mine_x18", "切尔文铜币", "copper rust", "vein_core", False),
    ("mi_slug_volatile_7", "不稳定虫腹", "rust canvas orange", "vein_core", True),
    ("mi_crossbow_1", "绞盘护腕", "leather steel", "originium_meter", False),
    ("mi_caster_5", "裸晶护腕", "cloth steel orange", "originium_meter", True),
]


def source(item_id: str) -> Image.Image:
    image = Image.open(ROOT / "sources" / f"{item_id}_raw.png").convert("RGBA")
    data = np.asarray(image).copy()
    data[:, :, 3] = np.where(data[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    image = Image.fromarray(data, "RGBA")
    bounds = image.getbbox()
    assert bounds, item_id
    image = image.crop(bounds)
    image.save(ROOT / "sources" / f"{item_id}_painted.png")
    return image


def reduce_v2(painting: Image.Image, groups: str) -> Image.Image:
    """Sample the painted details directly so small teeth, cracks and facets survive."""
    raw = np.asarray(painting.resize((30, 30), Image.Resampling.NEAREST))
    visible = raw[:, :, 3] >= 104
    palette, _ = palette_for(groups)
    distances = np.square(raw[:, :, :3].astype(np.int32)[:, :, None, :] - palette[None, None, :, :]).sum(axis=3)
    mapped = palette[np.argmin(distances, axis=2)].astype(np.uint8)
    inside = visible.copy()
    inside[1:, :] &= visible[:-1, :]
    inside[:-1, :] &= visible[1:, :]
    inside[:, 1:] &= visible[:, :-1]
    inside[:, :-1] &= visible[:, 1:]
    mapped[visible & ~inside] = OUTLINE
    for _ in range(3):
        mapped = smooth_spots(mapped, visible, visible & ~inside, "trinket")
    rgba = np.zeros((32, 32, 4), dtype=np.uint8)
    rgba[1:31, 1:31, :3] = mapped
    rgba[1:31, 1:31, 3] = visible.astype(np.uint8) * 255
    return Image.fromarray(rgba, "RGBA")


def detail_touchup(icon: Image.Image, item_id: str) -> tuple[Image.Image, Image.Image | None]:
    """Trace only the reviewed focal marks of the selected source painting."""
    image = icon.copy()
    pen = ImageDraw.Draw(image)
    glow_points: list[tuple[int, int]] = []
    if item_id == "mi_slug_volatile_7":
        pen.line([(5, 12), (7, 9), (9, 8)], fill=(*RAMPS["orange"][3], 255), width=2)
        cracks = [
            [(9, 10), (12, 12), (14, 15), (17, 17)],
            [(6, 18), (10, 16), (14, 15), (17, 17)],
            [(17, 17), (20, 19), (24, 21), (26, 24)],
        ]
        for points in cracks:
            pen.line(points, fill=(*RAMPS["rust"][0], 255), width=3, joint="curve")
            pen.line(points, fill=(*RAMPS["orange"][3], 255), width=1, joint="curve")
            glow_points.extend(points)
    elif item_id == "mi_crossbow_1":
        # The source has a top-side metal winch: reinforce its disc and crank.
        pen.ellipse((19, 6, 27, 14), fill=(*RAMPS["steel"][3], 255), outline=(*OUTLINE, 255), width=1)
        pen.arc((19, 6, 27, 14), 205, 320, fill=(*RAMPS["steel"][4], 255), width=2)
        pen.line([(11, 18), (16, 14), (18, 13)], fill=(*RAMPS["steel"][4], 255), width=2)
        pen.ellipse((21, 8, 25, 12), fill=(*RAMPS["steel"][1], 255))
        pen.point((22, 8), fill=(*RAMPS["steel"][4], 255))
        pen.line([(25, 11), (28, 14)], fill=(*RAMPS["steel"][3], 255), width=2)
        pen.point((29, 15), fill=(*RAMPS["steel"][4], 255))
    elif item_id == "mi_caster_5":
        # The three broad black painted facets get an orange core each.
        cores = [(8, 17), (16, 11), (24, 6)]
        for x, y in cores:
            pen.line([(x, y), (x + 1, y - 2)], fill=(*RAMPS["orange"][2], 255), width=1)
            glow_points.extend([(x, y), (x + 1, y - 1), (x + 1, y - 2)])

    if item_id not in ("mi_slug_volatile_7", "mi_caster_5"):
        return image, None
    data = np.asarray(image).copy()
    mask = np.zeros((32, 32), dtype=bool)
    if item_id == "mi_slug_volatile_7":
        for points in cracks:
            layer = Image.new("1", (32, 32))
            ImageDraw.Draw(layer).line(points, fill=1, width=1, joint="curve")
            mask |= np.asarray(layer, dtype=bool)
    else:
        for x, y in glow_points:
            mask[y, x] = True
    mask &= data[:, :, 3] > 0
    out = np.zeros_like(data)
    out[mask] = data[mask]
    return image, Image.fromarray(out, "RGBA")


def emit(icon: Image.Image, item_id: str) -> Image.Image:
    data = np.asarray(icon)
    rgb, alpha = data[:, :, :3], data[:, :, 3] > 0
    colours = RAMPS["orange"][2:]
    glow = np.zeros(alpha.shape, dtype=bool)
    for colour in colours:
        glow |= np.all(rgb == colour, axis=2)
    if item_id == "mi_slug_volatile_7":
        # Only inner yellow-orange fissures. Exclude broad surface highlights.
        glow &= np.isin(rgb[:, :, 0], [255])
    glow &= alpha
    assert glow.any(), item_id
    out = np.zeros_like(data)
    out[glow] = data[glow]
    return Image.fromarray(out, "RGBA")


def review(entries: list[dict]) -> None:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    sheet = Image.new("RGB", (592, 4 * 48), "#17191b")
    pen = ImageDraw.Draw(sheet)
    for row, entry in enumerate(entries):
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        y = row * 48
        pen.text((4, y + 13), entry["id"], font=font, fill="#f4f2ee")
        for col, bg in enumerate(BACKGROUNDS):
            x = 180 + col * 82
            pen.rectangle((x, y, x + 81, y + 47), fill=bg)
            sheet.paste(icon, (x + 25, y + 8), icon)
    sheet.save(ROOT / "contact_sheet.png")
    sheet.resize((1184, 384), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")

    compare = Image.new("RGB", (656, 4 * 130), "#17191b")
    pen = ImageDraw.Draw(compare)
    for row, entry in enumerate(entries):
        y = row * 130
        now = Image.open(ROOT / entry["file"]).convert("RGBA")
        prev = Image.open(V1 / entry["file"]).convert("RGBA")
        old = old_icon(entry["old_comparison"])
        pen.text((4, y + 4), f"{entry['id']}    v2 / v1 / old {entry['old_comparison']}", font=font, fill="#f4f2ee")
        for x, icon in zip((8, 104, 200), (now, prev, old)):
            enlarged = icon.resize((96, 96), Image.Resampling.NEAREST)
            compare.paste(enlarged, (x, y + 25), enlarged)
        pen.text((315, y + 43), f"h {entry['silhouette_height']}/{entry['v1_height']}/{entry['old_height']}", font=font, fill="#f4f2ee")
        pen.text((315, y + 70), f"opaque {entry['opaque_pixel_count']}/{entry['v1_opaque']}/{entry['old_opaque']}", font=font, fill="#f4f2ee")
    compare.save(ROOT / "fill_vs_old_3x.png")


def main() -> None:
    entries, qa = [], []
    for item_id, name, groups, comparison, has_emit in ITEMS:
        icon, emission = detail_touchup(reduce_v2(source(item_id), groups), item_id)
        icon.save(ROOT / f"{item_id}.png")
        icon.resize((256, 256), Image.Resampling.NEAREST).save(ROOT / f"{item_id}_8x.png")
        if has_emit:
            assert emission is not None
            emission.save(ROOT / f"{item_id}_emit.png")
        measure = metrics(icon)
        prev = metrics(Image.open(V1 / f"{item_id}.png").convert("RGBA"))
        old = metrics(old_icon(comparison))
        entry = {
            "id": item_id, "name": name, "file": f"{item_id}.png", "native_size": [32, 32],
            "has_emit": has_emit, "old_comparison": comparison,
            "silhouette_height": measure["silhouette_height"],
            "opaque_pixel_count": measure["opaque_pixel_count"],
            "v1_height": prev["silhouette_height"], "v1_opaque": prev["opaque_pixel_count"],
            "old_height": old["silhouette_height"], "old_opaque": old["opaque_pixel_count"],
        }
        entries.append(entry)
        qa.append({"id": item_id, **measure, "v1_opaque": prev["opaque_pixel_count"]})
    (ROOT / "manifest.json").write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "qa_report.json").write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review(entries)


if __name__ == "__main__":
    main()
