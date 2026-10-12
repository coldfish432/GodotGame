"""Reduce painted E11/E12 sources and assemble region review packages."""

from __future__ import annotations

import json
import hashlib
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ITEMS = Path(__file__).resolve().parent
sys.path.insert(0, str(ITEMS / "batch_E10_v1"))
from build_e10 import BACKGROUNDS, OUTLINE, metrics, old_icon, smooth_spots  # noqa: E402

COMPARE = {
    "E11": {
        "city_x09": "reunion_coat", "city_x10": "reunion_coat", "city_x11": "heavy_mine_suit",
        "city_x12": "reunion_coat", "city_x13": "reunion_coat", "city_x14": "heavy_mine_suit",
        "mi_bully_15": "miner_vest", "set_inspectors_1": "miner_vest", "set_grey_order_1": "reunion_coat",
        "city_x15": "liquor_flask", "city_x16": "liquor_flask", "city_x17": "vein_core",
        "city_x18": "liquor_flask", "city_x19": "originium_meter", "city_x20": "originium_meter",
        "city_x21": "vein_core", "mi_brawler_10": "dust_mask", "mi_crossbow_leader_11": "reunion_mask",
        "mi_greytail_12": "vein_core", "mi_thrower_14": "liquor_flask",
        "set_inspectors_2": "originium_meter", "set_grey_order_2": "vein_core",
    },
    "E12": {
        "snow_x09": "patrol_winter_coat", "snow_x10": "miner_vest", "snow_x11": "miner_vest",
        "snow_x12": "miner_vest", "snow_x13": "miner_vest", "snow_x14": "heavy_mine_suit",
        "snow_x15": "reunion_coat", "mi_ice_warrior_19": "miner_vest", "mi_taint_husk_22": "reunion_coat",
        "mi_shattered_champion_24": "miner_vest", "mi_rock_hornbeast_27": "patrol_winter_coat",
        "set_clean_snow_1": "reunion_coat", "set_fire_watch_1": "miner_vest",
        "snow_x16": "originium_meter", "snow_x17": "vein_core", "snow_x18": "vein_core",
        "snow_x19": "reunion_mask", "snow_x20": "originium_meter", "snow_x21": "liquor_flask",
        "snow_x22": "vein_core", "snow_x23": "originium_meter", "mi_ice_hunter_20": "originium_meter",
        "mi_ice_hunter_21": "vein_core", "mi_distorted_caster_23": "vein_core",
        "mi_shell_vine_26": "vein_core", "mi_fallen_snowpriest_28": "vein_core",
        "mi_fallen_snowpriest_29": "liquor_flask", "set_clean_snow_2": "reunion_mask",
        "set_fire_watch_2": "vein_core",
    },
}


def crop_source(root: Path, item_id: str) -> Image.Image:
    image = Image.open(root / "sources" / f"{item_id}_raw.png").convert("RGBA")
    data = np.asarray(image).copy()
    data[:, :, 3] = np.where(data[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    image = Image.fromarray(data, "RGBA")
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError(item_id)
    image = image.crop(bounds)
    image.save(root / "sources" / f"{item_id}_painted.png")
    return image


def reduce_icon(source: Image.Image, form: str) -> Image.Image:
    size = 72 if form == "armour" else 32
    footprint = 66 if form == "armour" else 30
    resized = source.resize((footprint, footprint), Image.Resampling.BOX if form == "armour" else Image.Resampling.NEAREST)
    raw = np.asarray(resized)
    visible = raw[:, :, 3] >= 104
    # Quantize the painting itself to retain glass, navy and ice hues across regions.
    quantized = resized.quantize(colors=22, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA")
    mapped = np.asarray(quantized)[:, :, :3].copy()
    inside = visible.copy()
    inside[1:, :] &= visible[:-1, :]
    inside[:-1, :] &= visible[1:, :]
    inside[:, 1:] &= visible[:, :-1]
    inside[:, :-1] &= visible[:, 1:]
    rim = visible & ~inside
    mapped[rim] = OUTLINE
    for _ in range(2 if form == "armour" else 3):
        mapped = smooth_spots(mapped, visible, rim, form)
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    offset = (size - footprint) // 2
    rgba[offset:offset + footprint, offset:offset + footprint, :3] = mapped
    rgba[offset:offset + footprint, offset:offset + footprint, 3] = visible.astype(np.uint8) * 255
    return Image.fromarray(rgba, "RGBA")


EMIT_POINTS = {
    "city_x16": [(21, 7, 2)],
    "city_x19": [(18, 13, 1)],
    "city_x21": [(15, 23, 3)],
    "mi_greytail_12": [(16, 11, 2), (17, 15, 2), (18, 20, 2)],
    "set_grey_order_2": [(13, 17, 3)],
    "snow_x13": [(43, 30, 2)],
    "snow_x20": [(16, 12, 1)],
    "snow_x22": [(9, 5, 2), (26, 12, 2), (23, 24, 2)],
    "mi_distorted_caster_23": [(28, 4, 2)],
    "mi_fallen_snowpriest_28": [(13, 21, 2)],
    "mi_fallen_snowpriest_29": [(19, 24, 3)],
    "set_fire_watch_2": [(18, 14, 1)],
}


def finish_icon(icon: Image.Image, item_id: str) -> Image.Image:
    # Restore tiny painted indicator accents lost at native scale.
    pixels = {
        "city_x19": [(18, 13, (123, 245, 148, 255))],
        "snow_x20": [(16, 12, (139, 243, 152, 255))],
        "set_fire_watch_2": [(18, 14, (255, 160, 57, 255))],
    }
    if item_id in pixels:
        icon = icon.copy()
        for x, y, colour in pixels[item_id]:
            icon.putpixel((x, y), colour)
    return icon


def emit_mask(icon: Image.Image, item_id: str) -> Image.Image:
    data = np.asarray(icon)
    yy, xx = np.indices(data.shape[:2])
    keep = np.zeros(data.shape[:2], dtype=bool)
    for x, y, radius in EMIT_POINTS[item_id]:
        keep |= (xx - x) ** 2 + (yy - y) ** 2 <= radius ** 2
    keep &= data[:, :, 3] > 0
    out = np.zeros_like(data)
    out[keep] = data[keep]
    return Image.fromarray(out, "RGBA")


def review(root: Path, entries: list[dict]) -> None:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    heights = [80 if e["form"] == "armour" else 40 for e in entries]
    offsets = np.cumsum([0] + heights)
    sheet = Image.new("RGB", (592, int(offsets[-1])), "#17191b")
    pen = ImageDraw.Draw(sheet)
    for row, entry in enumerate(entries):
        icon = Image.open(root / entry["file"]).convert("RGBA")
        y, h = int(offsets[row]), heights[row]
        pen.text((4, y + h // 2 - 7), entry["id"], font=font, fill="#f4f2ee")
        for col, bg in enumerate(BACKGROUNDS):
            x = 180 + col * 82
            pen.rectangle((x, y, x + 81, y + h - 1), fill=bg)
            sheet.paste(icon, (x + (82 - icon.width) // 2, y + (h - icon.height) // 2), icon)
    sheet.save(root / "contact_sheet.png")
    sheet.resize((1184, sheet.height * 2), Image.Resampling.NEAREST).save(root / "contact_sheet_2x.png")

    rows = [164 if e["form"] == "armour" else 92 for e in entries]
    offsets = np.cumsum([0] + rows)
    compare = Image.new("RGB", (590, int(offsets[-1])), "#17191b")
    pen = ImageDraw.Draw(compare)
    for row, entry in enumerate(entries):
        y = int(offsets[row])
        old = old_icon(entry["old_comparison"])
        icon = Image.open(root / entry["file"]).convert("RGBA")
        scale = 144 if entry["form"] == "armour" else 64
        pen.text((4, y + 3), f"{entry['id']} / {entry['old_comparison']}", font=font, fill="#f4f2ee")
        pen.rectangle((6, y + 18, 358, y + 21 + scale), fill="#2c2e30")
        for x, original in ((15, icon), (197, old)):
            enlarged = original.resize((scale, scale), Image.Resampling.NEAREST)
            compare.paste(enlarged, (x, y + 20), enlarged)
        pen.text((365, y + 29), f"h {entry['silhouette_height']}/{entry['old_height']} px", font=font, fill="#f4f2ee")
        pen.text((365, y + 53), f"opaque {entry['opaque_pixel_count']}/{entry['old_opaque']}", font=font, fill="#f4f2ee")
    compare.save(root / "fill_vs_old_2x.png")

    old_ids = ["miner_vest", "reunion_coat", "patrol_winter_coat", "heavy_mine_suit",
               "dust_mask", "liquor_flask", "reunion_mask", "originium_meter", "vein_core"]
    icons = [(item_id, old_icon(item_id)) for item_id in old_ids]
    icons.extend((e["id"], Image.open(root / e["file"]).convert("RGBA")) for e in entries)
    silhouette = Image.new("RGB", (800, ((len(icons) + 4) // 5) * 105), "#d2cbbb")
    pen = ImageDraw.Draw(silhouette)
    for idx, (item_id, icon) in enumerate(icons):
        x, y = idx % 5 * 160, idx // 5 * 105
        silhouette.paste(Image.new("RGB", icon.size, "#111315"), (x + 44, y + 6), icon.getchannel("A"))
        pen.text((x + 3, y + 83), item_id, font=font, fill="#222222")
    silhouette.save(root / "silhouette_check.png")


def build(batch: str) -> None:
    root = ITEMS / f"batch_{batch}_v1"
    specs = json.loads((root / "asset_specs.json").read_text(encoding="utf-8"))
    assert set(COMPARE[batch]) == {s["id"] for s in specs}
    entries, qa = [], []
    for spec in specs:
        item_id = spec["id"]
        icon = finish_icon(reduce_icon(crop_source(root, item_id), spec["form"]), item_id)
        icon.save(root / f"{item_id}.png")
        icon.resize((icon.width * 8, icon.height * 8), Image.Resampling.NEAREST).save(root / f"{item_id}_8x.png")
        if spec["has_emit"]:
            emit_mask(icon, item_id).save(root / f"{item_id}_emit.png")
        measure = metrics(icon)
        comparison = COMPARE[batch][item_id]
        old = metrics(old_icon(comparison))
        source_path = root / "sources" / f"{item_id}_raw.png"
        entry = {**spec, "file": f"{item_id}.png", "native_size": list(icon.size),
                 "painted_source": f"sources/{item_id}_raw.png",
                 "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
                 "emit_file": f"{item_id}_emit.png" if spec["has_emit"] else None,
                 "old_comparison": comparison, "silhouette_height": measure["silhouette_height"],
                 "opaque_pixel_count": measure["opaque_pixel_count"],
                 "old_height": old["silhouette_height"], "old_opaque": old["opaque_pixel_count"]}
        entries.append(entry)
        qa.append({"id": item_id, **measure, "old_comparison": comparison,
                   "old_height": old["silhouette_height"], "old_opaque": old["opaque_pixel_count"]})
    (root / "manifest.json").write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (root / "qa_report.json").write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review(root, entries)
    print(f"BUILT {batch}: {len(entries)} icons")


if __name__ == "__main__":
    for batch in sys.argv[1:] or ["E11", "E12"]:
        build(batch)

