"""Reduce twelve painted Sami weapon sources into native inventory icons."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
ITEMS = ROOT.parent
SIZE = (72, 32)
OUTLINE = (11, 12, 13)
RAMPS = {
    "steel": [(42, 45, 51), (74, 80, 88), (125, 134, 142), (180, 190, 196), (238, 243, 245)],
    "wood": [(63, 42, 26), (107, 74, 46), (154, 112, 72), (214, 192, 145)],
    "leather": [(46, 32, 24), (90, 61, 42), (134, 96, 63), (180, 138, 94), (214, 200, 162)],
    "bone": [(82, 76, 64), (142, 132, 112), (185, 174, 149), (230, 223, 204), (251, 248, 238)],
    "fur": [(72, 57, 42), (110, 88, 65), (166, 140, 108), (216, 203, 181)],
    "ice": [(61, 106, 138), (93, 143, 176), (156, 200, 224), (228, 244, 251)],
    "orange": [(154, 68, 24), (208, 102, 42), (242, 154, 90)],
    "band": [(176, 58, 46), (217, 164, 58), (63, 111, 168)],
}
SPECS = [
    # id, name, kind, form, target height, palette groups, prototype refs, same-form old comparator
    ("snow_x01", "染污短刀", "base", "blade", 27, "steel wood bone", ["proto_leuku.jpg"], "skinning_knife"),
    ("snow_x02", "伐木斧", "base", "heavy", 28, "steel wood orange", ["proto_felling_axe.jpg"], "pickhaft_blade"),
    ("snow_x03", "兽颚指虎", "base", "fist", 28, "bone leather", ["proto_tekko.jpg"], "finger_blade"),
    ("snow_x04", "凿冰长刀", "base", "blade", 27, "steel ice leather", ["proto_seax.jpg"], "icebreaker_knife"),
    ("snow_x05", "科考冰镐", "base", "heavy", 28, "steel orange leather", ["proto_ice_axe.jpg"], "pickhaft_blade"),
    ("snow_x06", "岩角战锤", "base", "heavy", 28, "bone wood band", [], "pickhaft_blade"),
    ("snow_x07", "裂骨拳刃", "base", "fist", 28, "bone leather", ["proto_katar.jpg"], "finger_blade"),
    ("snow_x08", "林线猎矛", "base", "polearm", 27, "bone wood band", ["proto_boar_spear.jpg"], "yan_ring_saber"),
    ("mi_ice_warrior_18", "劈冰者", "exclusive", "heavy", 28, "steel ice fur leather", ["icebreaker_knife.png"], "pickhaft_blade"),
    ("mi_shattered_champion_25", "折角", "exclusive", "fist", 28, "bone leather", ["prts_shattered_champion.png"], "finger_blade"),
    ("set_clean_snow_0", "洁雪仪刃", "set", "blade", 29, "bone steel ice", ["snowpriest_blade.png"], "snowpriest_blade"),
    ("set_fire_watch_0", "守望者战斧", "set", "heavy", 28, "steel wood fur orange", ["proto_felling_axe.jpg"], "pickhaft_blade"),
]
BACKGROUNDS = ["#2c2e30", "#142538", "#352710", "#341e08", "#112e1f"]
OLD_DIRS = [ITEMS / "batch_E3_v3", ITEMS / "batch_E2_v3", ITEMS / "batch_E1_v5", ITEMS / "batch_E4_v4"]


def old_icon(item_id: str) -> Image.Image:
    for folder in OLD_DIRS:
        path = folder / f"{item_id}.png"
        if path.exists():
            return Image.open(path).convert("RGBA")
    raise FileNotFoundError(item_id)


def source_crop(item_id: str) -> Image.Image:
    source_name = f"{item_id}_raw_broad.png" if item_id == "set_clean_snow_0" else f"{item_id}_raw.png"
    source = Image.open(ROOT / "sources" / source_name).convert("RGBA")
    pixels = np.array(source)
    pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    source = Image.fromarray(pixels, "RGBA")
    bbox = source.getbbox()
    if bbox is None:
        raise ValueError(f"Empty source: {item_id}")
    source = source.crop(bbox)
    source.save(ROOT / "sources" / f"{item_id}_painted.png")
    return source


def palette_for(groups: str) -> tuple[np.ndarray, list[str]]:
    colours = [OUTLINE]
    names = ["outline"]
    for group in groups.split():
        colours.extend(RAMPS[group])
        names.extend([group] * len(RAMPS[group]))
    if len(colours) > 24:
        raise ValueError(f"Palette too large: {groups}")
    return np.asarray(colours, dtype=np.int32), names


def smooth_spots(mapped: np.ndarray, visible: np.ndarray, rim: np.ndarray) -> np.ndarray:
    output = mapped.copy()
    protected = {tuple(c) for group in ("band", "orange") for c in RAMPS[group]}
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
                output[y, x] = max(set(neighbours), key=lambda c: (neighbours.count(c),
                    -sum((int(c[k]) - int(mapped[y, x, k])) ** 2 for k in range(3))))
    return output


def reduce_icon(source: Image.Image, item_id: str, height: int, groups: str) -> Image.Image:
    reduced = source.resize((70, height), Image.Resampling.BOX)
    data = np.array(reduced)
    visible = data[:, :, 3] >= 104
    palette, names = palette_for(groups)
    distances = np.square(data[:, :, :3].astype(np.int32)[:, :, None, :] - palette[None, None, :, :]).sum(axis=3)
    indices = np.argmin(distances, axis=2)
    mapped = palette[indices].astype(np.uint8)
    interior = visible.copy()
    interior[1:, :] &= visible[:-1, :]
    interior[:-1, :] &= visible[1:, :]
    interior[:, 1:] &= visible[:, :-1]
    interior[:, :-1] &= visible[:, 1:]
    rim = visible & ~interior
    mapped[rim] = OUTLINE
    mapped = smooth_spots(mapped, visible, rim)

    light = np.tensordot(mapped.astype(float) / 255, [0.2126, 0.7152, 0.0722], axes=([2], [0]))
    need = max(0, int(np.ceil(0.155 * visible.sum())) - int((visible & (light >= 0.6)).sum()))
    yy, xx = np.indices(visible.shape)
    bright = visible & (light >= 0.6)
    neighbour = np.zeros(visible.shape, dtype=np.int32)
    neighbour[1:, :] += bright[:-1, :]
    neighbour[:-1, :] += bright[1:, :]
    neighbour[:, 1:] += bright[:, :-1]
    neighbour[:, :-1] += bright[:, 1:]
    score = light + 0.20 * neighbour - 0.10 * yy / height - 0.025 * xx / 70
    candidates = np.flatnonzero(visible & ~rim & (light < 0.6))
    candidates = candidates[np.argsort(score.flat[candidates])[::-1]]
    for flat in candidates[:need]:
        y, x = np.unravel_index(flat, visible.shape)
        group = names[int(indices[y, x])]
        if group in ("outline", "band", "orange"):
            group = "steel" if group == "outline" else ("bone" if group == "band" else "wood")
        mapped[y, x] = RAMPS[group][-1]

    result = np.zeros((32, 72, 4), dtype=np.uint8)
    top = (32 - height) // 2
    result[top:top + height, 1:71, :3] = mapped
    result[top:top + height, 1:71, 3] = visible.astype(np.uint8) * 255
    if item_id == "set_fire_watch_0":
        # The source's tiny coal at the left pouch mouth is lost to BOX
        # reduction. Restore that single painted accent at native size.
        result[18, 8, :3] = RAMPS["orange"][-1]
        result[18, 8, 3] = 255
    return Image.fromarray(result, "RGBA")


def metrics(icon: Image.Image) -> dict:
    data = np.asarray(icon)
    mask = data[:, :, 3] > 0
    rgb = data[:, :, :3]
    luminance = (0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]) / 255
    isolated = 0
    eligible = 0
    for y, x in zip(*np.where(mask)):
        if tuple(rgb[y, x]) == OUTLINE:
            continue
        eligible += 1
        y0, y1, x0, x1 = max(0, y - 1), min(32, y + 2), max(0, x - 1), min(72, x + 2)
        if int((np.all(rgb[y0:y1, x0:x1] == rgb[y, x], axis=2) & mask[y0:y1, x0:x1]).sum()) <= 1:
            isolated += 1
    bbox = icon.getbbox()
    return {
        "silhouette_height": bbox[3] - bbox[1], "silhouette_width": bbox[2] - bbox[0],
        "opaque_pixel_count": int(mask.sum()),
        "bright_pixel_percent": round(100 * int((mask & (luminance >= 0.6)).sum()) / int(mask.sum()), 2),
        "isolated_pixel_percent": round(100 * isolated / max(1, eligible), 2),
        "colour_count": len({tuple(c) for c in rgb[mask]}),
    }


def make_emit(icon: Image.Image) -> Image.Image:
    data = np.asarray(icon)
    rgb = data[:, :, :3]
    yy, xx = np.indices(data.shape[:2])
    orange = np.zeros(data.shape[:2], dtype=bool)
    for colour in RAMPS["orange"][1:]:
        orange |= np.all(rgb == colour, axis=2)
    orange &= (data[:, :, 3] > 0) & (xx < 19) & (yy >= 12)
    if not orange.any():
        raise ValueError("Tinder pouch ember did not survive reduction")
    out = np.zeros_like(data)
    out[orange] = data[orange]
    return Image.fromarray(out, "RGBA")


def review_sheets(manifest: list[dict]) -> None:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    contact = Image.new("RGB", (580, len(manifest) * 40), "#17191b")
    pen = ImageDraw.Draw(contact)
    for row, entry in enumerate(manifest):
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        pen.text((4, row * 40 + 10), entry["id"], font=font, fill="#f5f5f2")
        for col, bg in enumerate(BACKGROUNDS):
            x, y = 175 + col * 80, row * 40
            pen.rectangle((x, y, x + 79, y + 39), fill=bg)
            contact.paste(icon, (x + 4, y + 4), icon)
    contact.save(ROOT / "contact_sheet.png")
    contact.resize((1160, len(manifest) * 80), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")

    compare = Image.new("RGB", (620, len(manifest) * 92), "#17191b")
    pen = ImageDraw.Draw(compare)
    for row, entry in enumerate(manifest):
        y = row * 92
        pen.text((4, y + 2), f"{entry['id']} / {entry['old_comparison']}", font=font, fill="#f5f5f2")
        pen.rectangle((6, y + 22, 358, y + 89), fill="#2c2e30")
        new = Image.open(ROOT / entry["file"]).convert("RGBA").resize((144, 64), Image.Resampling.NEAREST)
        old = old_icon(entry["old_comparison"]).resize((144, 64), Image.Resampling.NEAREST)
        compare.paste(new, (15, y + 24), new)
        compare.paste(old, (197, y + 24), old)
        pen.text((365, y + 28), f"h {entry['silhouette_height']}/{entry['old_height']} px", font=font, fill="#f5f5f2")
        pen.text((365, y + 51), f"opaque {entry['opaque_pixel_count']}/{entry['old_opaque_pixel_count']}", font=font, fill="#f5f5f2")
    compare.save(ROOT / "fill_vs_old_2x.png")

    old_ids = ["icebreaker_knife", "skinning_knife", "antler_hunter_knife", "expedition_machete", "snowpriest_blade", "twin_fang", "ember_fang", "moon_edge"]
    entries = [(item_id, old_icon(item_id)) for item_id in old_ids]
    entries.extend((e["id"], Image.open(ROOT / e["file"]).convert("RGBA")) for e in manifest)
    silhouette = Image.new("RGB", (4 * 180, ((len(entries) + 3) // 4) * 70), "#d2cbbb")
    pen = ImageDraw.Draw(silhouette)
    for index, (item_id, icon) in enumerate(entries):
        x, y = index % 4 * 180, index // 4 * 70
        silhouette.paste(Image.new("RGB", SIZE, "#111315"), (x + 52, y + 5), icon.getchannel("A"))
        pen.text((x + 4, y + 44), item_id, font=font, fill="#222222")
    silhouette.save(ROOT / "silhouette_check.png")


def main() -> None:
    manifest = []
    qa = []
    for item_id, name, kind, form, height, groups, refs, comparison in SPECS:
        icon = reduce_icon(source_crop(item_id), item_id, height, groups)
        icon.save(ROOT / f"{item_id}.png")
        icon.resize((576, 256), Image.Resampling.NEAREST).save(ROOT / f"{item_id}_8x.png")
        has_emit = item_id == "set_fire_watch_0"
        if has_emit:
            make_emit(icon).save(ROOT / f"{item_id}_emit.png")
        measure = metrics(icon)
        old_measure = metrics(old_icon(comparison))
        manifest.append({
            "id": item_id, "name": name, "kind": kind, "form": form, "file": f"{item_id}.png",
            "native_size": list(SIZE), "has_emit": has_emit, "prototype_refs": refs,
            "isolated_pixel_percent": measure["isolated_pixel_percent"],
            "old_comparison": comparison, "old_height": old_measure["silhouette_height"],
            "old_opaque_pixel_count": old_measure["opaque_pixel_count"],
            "silhouette_height": measure["silhouette_height"], "opaque_pixel_count": measure["opaque_pixel_count"],
        })
        qa.append({"id": item_id, **measure, "old_comparison": comparison,
                   "old_height": old_measure["silhouette_height"],
                   "old_opaque_pixel_count": old_measure["opaque_pixel_count"]})
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "qa_report.json").write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review_sheets(manifest)


if __name__ == "__main__":
    main()
