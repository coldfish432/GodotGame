"""Reduce painted E10 mine armour/trinkets and assemble review material."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
ITEMS = ROOT.parent
OUTLINE = (11, 12, 13)
RAMPS = {
    "steel": [(42, 45, 51), (74, 80, 88), (125, 134, 142), (180, 190, 196), (238, 243, 245)],
    "rust": [(74, 42, 29), (125, 69, 41), (176, 106, 58), (217, 149, 96)],
    "canvas": [(90, 77, 58), (133, 117, 85), (179, 162, 124), (214, 200, 162)],
    "cloth": [(48, 49, 47), (77, 79, 76), (120, 124, 118), (170, 175, 168), (211, 216, 207)],
    "leather": [(46, 32, 24), (90, 61, 42), (134, 96, 63), (180, 138, 94), (214, 200, 162)],
    "army": [(47, 54, 45), (83, 94, 69), (130, 143, 104), (189, 198, 155)],
    "red": [(110, 22, 22), (156, 43, 37), (217, 72, 58)],
    "copper": [(110, 82, 32), (168, 130, 46), (220, 184, 90)],
    "yellow": [(121, 98, 22), (216, 165, 32)],
    "orange": [(184, 90, 18), (238, 138, 36), (255, 179, 90), (255, 224, 168)],
    "white": [(120, 121, 117), (179, 181, 175), (217, 218, 211), (244, 241, 232)],
    "warmwhite": [(170, 148, 103), (226, 204, 155), (255, 237, 197)],
}
SPECS = [
    # id, name, kind, form, palette groups, prototype refs, old comparison, emit
    ("mine_x09", "拼装轻甲", "base", "armour", "steel rust canvas", ["proto_scale_armour.jpg"], "miner_vest", False),
    ("mine_x10", "改装喷射背架", "base", "armour", "steel rust canvas red", [], "heavy_mine_suit", False),
    ("mine_x11", "整合运动术师兜袍", "base", "armour", "steel cloth red orange", ["prts_caster.png"], "reunion_coat", True),
    ("mine_x12", "伪装吉利服", "base", "armour", "rust canvas army", ["proto_ghillie_suit.jpg"], "reunion_coat", False),
    ("mine_x13", "游击队旧式军大衣", "base", "armour", "army cloth copper", ["proto_greatcoat.jpg"], "patrol_winter_coat", False),
    ("mine_x14", "复合护具", "base", "armour", "steel army canvas leather", ["prts_armed.png", "proto_gas_mask.jpg"], "heavy_mine_suit", False),
    ("mi_slug_2", "蜕下的虫壳", "exclusive", "armour", "rust cloth orange", ["prts_slug_volatile.png"], "miner_vest", True),
    ("mi_shield_6", "盾面背板", "exclusive", "armour", "steel canvas yellow", ["prts_shield.png"], "heavy_mine_suit", False),
    ("set_nameless_1", "无名者的外套", "set", "armour", "cloth steel red", ["reunion_coat.png"], "reunion_coat", False),
    ("set_warrant_1", "追缉令·皮大衣", "set", "armour", "leather steel", [], "reunion_coat", False),
    ("mine_x15", "头戴矿灯", "base", "trinket", "steel leather warmwhite", ["proto_headlamp.jpg"], "originium_meter", True),
    ("mine_x16", "军用止血带", "base", "trinket", "red steel canvas", ["proto_tourniquet.jpg"], "liquor_flask", False),
    ("mine_x17", "劳役编号牌", "base", "trinket", "steel rust", ["proto_dog_tag.jpg"], "originium_meter", False),
    ("mine_x18", "切尔文铜币", "base", "trinket", "copper rust", [], "vein_core", False),
    ("mine_x19", "纠察队手铐", "base", "trinket", "steel rust", [], "dust_mask", False),
    ("mine_x20", "游击队臂章", "base", "trinket", "army white", [], "reunion_mask", False),
    ("mine_x21", "高能虫囊", "base", "trinket", "rust canvas orange", ["prts_slug_volatile.png"], "vein_core", True),
    ("mine_x22", "拆下的施术单元", "base", "trinket", "steel rust orange", ["originium_meter.png"], "originium_meter", True),
    ("mi_crossbow_1", "绞盘护腕", "exclusive", "trinket", "leather steel", [], "originium_meter", False),
    ("mi_armed_3", "不明罐装呼吸器", "exclusive", "trinket", "steel canvas leather", ["proto_gas_mask.jpg", "prts_armed.png"], "dust_mask", False),
    ("mi_armed_4", "震荡护符", "exclusive", "trinket", "steel leather", [], "dust_mask", False),
    ("mi_caster_5", "裸晶护腕", "exclusive", "trinket", "cloth steel orange", ["prts_caster.png"], "originium_meter", True),
    ("mi_slug_volatile_7", "不稳定虫腹", "exclusive", "trinket", "rust canvas orange", ["prts_slug_volatile.png"], "vein_core", True),
    ("mi_picket_9", "赏金账簿", "exclusive", "trinket", "leather white steel", ["proto_notebook.jpg"], "liquor_flask", False),
    ("set_nameless_2", "无名者的面具", "set", "trinket", "white steel red", ["reunion_mask.png"], "reunion_mask", False),
    ("set_warrant_2", "追缉令·名单", "set", "trinket", "white canvas steel", [], "reunion_mask", False),
]
BACKGROUNDS = ["#2c2e30", "#142538", "#352710", "#341e08", "#112e1f"]
OLD_DIRS = [ITEMS / "batch_E1_v5", ITEMS / "batch_E4_v4"]


def old_icon(item_id: str) -> Image.Image:
    for folder in OLD_DIRS:
        path = folder / f"{item_id}.png"
        if path.exists():
            return Image.open(path).convert("RGBA")
    raise FileNotFoundError(item_id)


def crop_source(item_id: str) -> Image.Image:
    source_name = f"{item_id}_raw_broad.png" if item_id in ("mine_x19", "mi_armed_4", "mi_caster_5") else f"{item_id}_raw.png"
    image = Image.open(ROOT / "sources" / source_name).convert("RGBA")
    data = np.asarray(image).copy()
    data[:, :, 3] = np.where(data[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    image = Image.fromarray(data, "RGBA")
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError(item_id)
    image = image.crop(bounds)
    image.save(ROOT / "sources" / f"{item_id}_painted.png")
    return image


def palette_for(groups: str) -> tuple[np.ndarray, list[str]]:
    colours = [OUTLINE]
    names = ["outline"]
    for group in groups.split():
        colours.extend(RAMPS[group])
        names.extend([group] * len(RAMPS[group]))
    if len(colours) > 24:
        raise ValueError(f"Too many colours: {groups}")
    return np.asarray(colours, dtype=np.int32), names


def smooth_spots(mapped: np.ndarray, visible: np.ndarray, rim: np.ndarray, kind: str) -> np.ndarray:
    result = mapped.copy()
    protected = {tuple(colour) for group in ("red", "orange", "yellow") for colour in RAMPS[group]}
    h, w = visible.shape
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if not visible[y, x] or rim[y, x] or tuple(mapped[y, x]) in protected:
                continue
            patch = mapped[y - 1:y + 2, x - 1:x + 2]
            shown = visible[y - 1:y + 2, x - 1:x + 2]
            if int((np.all(patch == mapped[y, x], axis=2) & shown).sum()) > 1:
                continue
            neighbours = [tuple(mapped[ny, nx]) for ny, nx in
                          ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))
                          if visible[ny, nx] and tuple(mapped[ny, nx]) != OUTLINE]
            if neighbours:
                result[y, x] = max(set(neighbours), key=lambda colour: (neighbours.count(colour),
                    -sum((int(colour[k]) - int(mapped[y, x, k])) ** 2 for k in range(3))))
    return result


def reduce_icon(source: Image.Image, item_id: str, form: str, groups: str) -> Image.Image:
    size = 72 if form == "armour" else 32
    broad_trinkets = {"mine_x15", "mine_x17", "mine_x19", "mi_crossbow_1", "mi_armed_4", "mi_caster_5"}
    footprint = 66 if form == "armour" else (30 if item_id in broad_trinkets else 28)
    reduced = source.resize((footprint, footprint), Image.Resampling.BOX)
    raw = np.asarray(reduced)
    visible = raw[:, :, 3] >= 104
    palette, names = palette_for(groups)
    distances = np.square(raw[:, :, :3].astype(np.int32)[:, :, None, :] - palette[None, None, :, :]).sum(axis=3)
    indices = np.argmin(distances, axis=2)
    mapped = palette[indices].astype(np.uint8)
    interior = visible.copy()
    interior[1:, :] &= visible[:-1, :]
    interior[:-1, :] &= visible[1:, :]
    interior[:, 1:] &= visible[:, :-1]
    interior[:, :-1] &= visible[:, 1:]
    rim = visible & ~interior
    mapped[rim] = OUTLINE
    mapped = smooth_spots(mapped, visible, rim, form)

    luminance = np.tensordot(mapped.astype(float) / 255, [0.2126, 0.7152, 0.0722], axes=([2], [0]))
    need = max(0, int(np.ceil(0.155 * visible.sum())) - int((visible & (luminance >= 0.6)).sum()))
    yy, xx = np.indices(visible.shape)
    bright = visible & (luminance >= 0.6)
    neighbours = np.zeros(visible.shape, dtype=np.int32)
    neighbours[1:, :] += bright[:-1, :]
    neighbours[:-1, :] += bright[1:, :]
    neighbours[:, 1:] += bright[:, :-1]
    neighbours[:, :-1] += bright[:, 1:]
    score = luminance + 0.20 * neighbours - 0.10 * yy / footprint - 0.025 * xx / footprint
    candidates = np.flatnonzero(visible & ~rim & (luminance < 0.6))
    candidates = candidates[np.argsort(score.flat[candidates])[::-1]]
    for flat in candidates[:need]:
        y, x = np.unravel_index(flat, visible.shape)
        group = names[int(indices[y, x])]
        if group == "outline":
            group = "steel"
        if group == "red":
            group = "rust"
        if group == "yellow":
            group = "canvas"
        mapped[y, x] = RAMPS[group][-1]

    result = np.zeros((size, size, 4), dtype=np.uint8)
    offset = (size - footprint) // 2
    result[offset:offset + footprint, offset:offset + footprint, :3] = mapped
    result[offset:offset + footprint, offset:offset + footprint, 3] = visible.astype(np.uint8) * 255
    return Image.fromarray(result, "RGBA")


def metrics(icon: Image.Image) -> dict:
    data = np.asarray(icon)
    mask = data[:, :, 3] > 0
    rgb = data[:, :, :3]
    lum = (0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]) / 255
    isolated, eligible = 0, 0
    height, width = mask.shape
    for y, x in zip(*np.where(mask)):
        if tuple(rgb[y, x]) == OUTLINE:
            continue
        eligible += 1
        y0, y1, x0, x1 = max(0, y - 1), min(height, y + 2), max(0, x - 1), min(width, x + 2)
        if int((np.all(rgb[y0:y1, x0:x1] == rgb[y, x], axis=2) & mask[y0:y1, x0:x1]).sum()) <= 1:
            isolated += 1
    bounds = icon.getbbox()
    return {
        "silhouette_width": bounds[2] - bounds[0], "silhouette_height": bounds[3] - bounds[1],
        "opaque_pixel_count": int(mask.sum()),
        "bright_pixel_percent": round(100 * int((mask & (lum >= 0.6)).sum()) / int(mask.sum()), 2),
        "isolated_pixel_percent": round(100 * isolated / max(1, eligible), 2),
        "colour_count": len({tuple(c) for c in rgb[mask]}),
    }


def make_emit(icon: Image.Image, item_id: str) -> Image.Image:
    data = np.asarray(icon)
    rgb = data[:, :, :3]
    alpha = data[:, :, 3] > 0
    yy, xx = np.indices(alpha.shape)
    glow = np.zeros(alpha.shape, dtype=bool)
    if item_id == "mine_x15":
        # Headlamp lens, left of the leather headband.
        for colour in RAMPS["warmwhite"][1:]:
            glow |= np.all(rgb == colour, axis=2)
        glow &= (xx <= 17) & (yy >= 7) & (yy <= 25)
    else:
        if item_id in ("mine_x21", "mi_slug_volatile_7"):
            colours = RAMPS["orange"][2:]
        elif item_id == "mi_caster_5":
            colours = RAMPS["orange"]
        else:
            colours = RAMPS["orange"][1:]
        for colour in colours:
            glow |= np.all(rgb == colour, axis=2)
        if item_id == "mine_x11":
            glow &= (xx >= 25) & (xx <= 48) & (yy >= 14) & (yy <= 39)
        elif item_id == "mi_slug_2":
            glow &= (xx >= 6) & (xx <= 65) & (yy >= 8) & (yy <= 63)
        elif item_id == "mine_x22":
            glow &= (xx >= 9) & (xx <= 24) & (yy >= 8) & (yy <= 24)
        elif item_id == "mi_caster_5":
            glow &= (xx >= 5) & (xx <= 27) & (yy >= 4) & (yy <= 26)
        else:
            # Sacs: the bright inner material glows, never the exterior rim.
            glow &= (xx >= 5) & (xx <= 27) & (yy >= 5) & (yy <= 27)
    glow &= alpha
    if not glow.any():
        raise ValueError(f"Emit region missing: {item_id}")
    out = np.zeros_like(data)
    out[glow] = data[glow]
    return Image.fromarray(out, "RGBA")


def review_sheets(manifest: list[dict]) -> None:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    row_heights = [80 if entry["form"] == "armour" else 40 for entry in manifest]
    offsets = np.cumsum([0] + row_heights)
    contact = Image.new("RGB", (592, int(offsets[-1])), "#17191b")
    pen = ImageDraw.Draw(contact)
    for index, entry in enumerate(manifest):
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        y = int(offsets[index])
        slot = 80 if entry["form"] == "armour" else 40
        pen.text((4, y + slot // 2 - 6), entry["id"], font=font, fill="#f5f5f2")
        for col, bg in enumerate(BACKGROUNDS):
            x = 180 + col * 82
            pen.rectangle((x, y, x + 81, y + slot - 1), fill=bg)
            contact.paste(icon, (x + (82 - icon.width) // 2, y + (slot - icon.height) // 2), icon)
    contact.save(ROOT / "contact_sheet.png")
    contact.resize((1184, int(offsets[-1]) * 2), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")

    compare_heights = [164 if entry["form"] == "armour" else 92 for entry in manifest]
    compare_offsets = np.cumsum([0] + compare_heights)
    compare = Image.new("RGB", (590, int(compare_offsets[-1])), "#17191b")
    pen = ImageDraw.Draw(compare)
    for index, entry in enumerate(manifest):
        y = int(compare_offsets[index])
        old = old_icon(entry["old_comparison"])
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        pen.text((4, y + 3), f"{entry['id']} / {entry['old_comparison']}", font=font, fill="#f5f5f2")
        size = 144 if entry["form"] == "armour" else 64
        pen.rectangle((6, y + 18, 358, y + 21 + size), fill="#2c2e30")
        enlarged = icon.resize((size, size), Image.Resampling.NEAREST)
        old_enlarged = old.resize((size, size), Image.Resampling.NEAREST)
        compare.paste(enlarged, (15, y + 20), enlarged)
        compare.paste(old_enlarged, (197, y + 20), old_enlarged)
        pen.text((365, y + 29), f"h {entry['silhouette_height']}/{entry['old_height']} px", font=font, fill="#f5f5f2")
        pen.text((365, y + 53), f"opaque {entry['opaque_pixel_count']}/{entry['old_opaque_pixel_count']}", font=font, fill="#f5f5f2")
    compare.save(ROOT / "fill_vs_old_2x.png")

    old_armour = ["miner_vest", "reunion_coat", "patrol_winter_coat", "heavy_mine_suit"]
    old_trinkets = ["dust_mask", "liquor_flask", "reunion_mask", "originium_meter", "vein_core"]
    entries = [(item_id, old_icon(item_id)) for item_id in old_armour + old_trinkets]
    entries.extend((e["id"], Image.open(ROOT / e["file"]).convert("RGBA")) for e in manifest)
    silhouette = Image.new("RGB", (5 * 160, ((len(entries) + 4) // 5) * 105), "#d2cbbb")
    pen = ImageDraw.Draw(silhouette)
    for index, (item_id, icon) in enumerate(entries):
        x, y = index % 5 * 160, index // 5 * 105
        silhouette.paste(Image.new("RGB", icon.size, "#111315"), (x + 44, y + 6), icon.getchannel("A"))
        pen.text((x + 3, y + 83), item_id, font=font, fill="#222222")
    silhouette.save(ROOT / "silhouette_check.png")


def main() -> None:
    manifest, qa = [], []
    for item_id, name, kind, form, groups, refs, comparison, has_emit in SPECS:
        icon = reduce_icon(crop_source(item_id), item_id, form, groups)
        icon.save(ROOT / f"{item_id}.png")
        icon.resize((icon.width * 8, icon.height * 8), Image.Resampling.NEAREST).save(ROOT / f"{item_id}_8x.png")
        if has_emit:
            make_emit(icon, item_id).save(ROOT / f"{item_id}_emit.png")
        measure = metrics(icon)
        old_measure = metrics(old_icon(comparison))
        entry = {
            "id": item_id, "name": name, "kind": kind, "form": form,
            "file": f"{item_id}.png", "native_size": [icon.width, icon.height],
            "has_emit": has_emit, "prototype_refs": refs,
            "isolated_pixel_percent": measure["isolated_pixel_percent"],
            "old_comparison": comparison, "old_height": old_measure["silhouette_height"],
            "old_opaque_pixel_count": old_measure["opaque_pixel_count"],
            "silhouette_height": measure["silhouette_height"], "opaque_pixel_count": measure["opaque_pixel_count"],
        }
        manifest.append(entry)
        qa.append({"id": item_id, **measure, "old_comparison": comparison,
                   "old_height": old_measure["silhouette_height"],
                   "old_opaque_pixel_count": old_measure["opaque_pixel_count"]})
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "qa_report.json").write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review_sheets(manifest)


if __name__ == "__main__":
    main()
