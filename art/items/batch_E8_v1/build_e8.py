"""Reduce the thirteen painted Lungmen weapon sources and build review sheets."""

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
    "leather": [(46, 32, 24), (90, 61, 42), (134, 96, 63), (180, 138, 94), (214, 200, 162)],
    "navy": [(20, 31, 48), (36, 57, 90), (61, 96, 136), (111, 156, 198), (181, 210, 234)],
    "red": [(110, 22, 22), (168, 42, 34), (217, 72, 58), (240, 122, 98)],
    "brass": [(110, 82, 32), (168, 130, 46), (220, 184, 90), (248, 221, 137)],
    "reflective": [(128, 143, 45), (200, 216, 96)],
    "violet": [(70, 50, 88), (122, 92, 154), (183, 153, 211), (224, 208, 240)],
}
SPECS = [
    # id, Chinese name, kind, form, height, palette groups, prototype refs, old comparison
    ("city_x01", "拆迁大锤", "base", "heavy", 27, "steel leather red", ["proto_sledgehammer.jpg"], "pickhaft_blade"),
    ("city_x02", "铜指虎", "base", "fist", 28, "brass steel", ["proto_brass_knuckles.jpg"], "finger_blade"),
    ("city_x03", "消防斧", "base", "heavy", 28, "steel leather red brass", [], "pickhaft_blade"),
    ("city_x04", "蝴蝶双刀", "base", "blade", 29, "steel leather brass", ["proto_butterfly_sword.jpg"], "gang_machete"),
    ("city_x05", "护卫铁尺", "base", "fist", 27, "steel navy red", ["proto_sai.svg"], "finger_blade"),
    ("city_x06", "警用链锤", "base", "heavy", 26, "steel navy reflective", ["proto_flail.jpg"], "pickhaft_blade"),
    ("city_x07", "炎式苗刀", "base", "blade", 25, "steel leather red brass", ["proto_miao_dao.jpg"], "yan_ring_saber"),
    ("city_x08", "炎式朴刀", "base", "polearm", 25, "steel leather red", ["proto_pudao.jpg"], "yan_ring_saber"),
    ("mi_greytail_lord_13", "香主铁骨扇", "exclusive", "fist", 26, "steel navy red", ["proto_war_fan.jpg", "prts_greytail_lord.png"], "finger_blade"),
    ("mi_avenger_16", "换手刃", "exclusive", "blade", 28, "steel leather red", ["prts_avenger.png"], "gang_machete"),
    ("mi_breacher_17", "攻坚重锤", "exclusive", "heavy", 28, "steel navy", ["prts_breacher.png"], "pickhaft_blade"),
    ("set_inspectors_0", "督察组定制长刀", "set", "blade", 25, "steel navy red", ["lgd_knife.png"], "lgd_knife"),
    ("set_grey_order_0", "琉璃骨尺", "set", "fist", 27, "steel navy red violet", ["city_x05.png"], "finger_blade"),
]
BACKGROUNDS = ["#2c2e30", "#142538", "#352710", "#341e08", "#112e1f"]
OLD_DIRS = [ITEMS / "batch_E2_v3", ITEMS / "batch_E1_v5", ITEMS / "batch_E4_v4"]


def source_crop(item_id: str) -> Image.Image:
    source = Image.open(ROOT / "sources" / f"{item_id}_raw.png").convert("RGBA")
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
    colour_group = ["outline"]
    for group in groups.split():
        colours.extend(RAMPS[group])
        colour_group.extend([group] * len(RAMPS[group]))
    if len(colours) > 24:
        raise ValueError(f"Palette exceeds 24 colours: {groups}")
    return np.asarray(colours, dtype=np.int32), colour_group


def smooth_spots(mapped: np.ndarray, visible: np.ndarray, rim: np.ndarray) -> np.ndarray:
    """Merge single-pixel interior tone noise, retaining red and glass accents."""
    result = mapped.copy()
    protected = {tuple(c) for group in ("red", "violet") for c in RAMPS[group]}
    height, width = visible.shape
    for y in range(1, height - 1):
        for x in range(1, width - 1):
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
                result[y, x] = max(set(neighbours), key=lambda c: (neighbours.count(c),
                    -sum((int(c[k]) - int(mapped[y, x, k])) ** 2 for k in range(3))))
    return result


def reduce_icon(source: Image.Image, item_id: str, height: int, groups: str) -> Image.Image:
    # Deliberate 70 px horizontal fill; these painted sources are already wide.
    reduced = source.resize((70, height), Image.Resampling.BOX)
    data = np.array(reduced)
    visible = data[:, :, 3] >= 104
    palette, colour_group = palette_for(groups)
    rgb = data[:, :, :3].astype(np.int32)
    distances = np.square(rgb[:, :, None, :] - palette[None, None, :, :]).sum(axis=3)
    indices = np.argmin(distances, axis=2)
    mapped = palette[indices].astype(np.uint8)

    # Preserve a one-pixel rim from the painted silhouette.
    interior = visible.copy()
    interior[1:, :] &= visible[:-1, :]
    interior[:-1, :] &= visible[1:, :]
    interior[:, 1:] &= visible[:, :-1]
    interior[:, :-1] &= visible[:, 1:]
    rim = visible & ~interior
    mapped[rim] = OUTLINE
    mapped = smooth_spots(mapped, visible, rim)

    # Extend existing lit planes when the tiny icon lacks the 15% light floor.
    light = np.tensordot(mapped.astype(float) / 255, [0.2126, 0.7152, 0.0722], axes=([2], [0]))
    candidates = visible & ~rim & (light < 0.6)
    need = max(0, int(np.ceil(0.155 * visible.sum())) - int((visible & (light >= 0.6)).sum()))
    yy, xx = np.indices(visible.shape)
    bright_neighbour = np.zeros(visible.shape, dtype=np.int32)
    already_bright = visible & (light >= 0.6)
    bright_neighbour[1:, :] += already_bright[:-1, :]
    bright_neighbour[:-1, :] += already_bright[1:, :]
    bright_neighbour[:, 1:] += already_bright[:, :-1]
    bright_neighbour[:, :-1] += already_bright[:, 1:]
    score = light + 0.20 * bright_neighbour - 0.10 * yy / height - 0.025 * xx / 70
    ordered = np.flatnonzero(candidates)
    ordered = ordered[np.argsort(score.flat[ordered])[::-1]]
    for flat in ordered[:need]:
        y, x = np.unravel_index(flat, visible.shape)
        group = colour_group[int(indices[y, x])]
        if group == "outline":
            group = "steel"
        bright = RAMPS[group][-1]
        # Red's lightest palette step has sub-60% luminance; use a warm
        # steel highlight on lit metal/paint chips instead.
        if group == "red":
            bright = RAMPS["steel"][-2]
        mapped[y, x] = bright

    result = np.zeros((SIZE[1], SIZE[0], 4), dtype=np.uint8)
    top = (SIZE[1] - height) // 2
    result[top:top + height, 1:71, :3] = mapped
    result[top:top + height, 1:71, 3] = visible.astype(np.uint8) * 255
    if item_id == "city_x08":
        # The painted pudao shaft shrinks to a mostly one-pixel dark line.
        # Keep its brown lit plane continuous on the navy inventory slot.
        result[12, 14:44, :3] = (90, 61, 42)
        result[12, 14:44, 3] = 255
        result[13, 14:44, :3] = (180, 138, 94)
        result[13, 14:44, 3] = 255
        result[13, 16:22, :3] = (214, 200, 162)
        result[14, 14:44, :3] = OUTLINE
        result[14, 14:44, 3] = 255
    return Image.fromarray(result, "RGBA")


def old_icon(item_id: str) -> Image.Image:
    for folder in OLD_DIRS:
        path = folder / f"{item_id}.png"
        if path.exists():
            return Image.open(path).convert("RGBA")
    raise FileNotFoundError(item_id)


def metrics(icon: Image.Image) -> dict:
    data = np.array(icon)
    mask = data[:, :, 3] > 0
    rgb = data[:, :, :3]
    lum = (0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]) / 255
    isolated = 0
    eligible = 0
    for y, x in zip(*np.where(mask)):
        if tuple(rgb[y, x]) == OUTLINE:
            continue
        eligible += 1
        y0, y1, x0, x1 = max(0, y - 1), min(32, y + 2), max(0, x - 1), min(72, x + 2)
        neighbours = np.all(rgb[y0:y1, x0:x1] == rgb[y, x], axis=2) & mask[y0:y1, x0:x1]
        if int(neighbours.sum()) <= 1:
            isolated += 1
    bbox = icon.getbbox()
    return {
        "silhouette_height": bbox[3] - bbox[1],
        "silhouette_width": bbox[2] - bbox[0],
        "bright_pixel_percent": round(100 * int((mask & (lum >= 0.6)).sum()) / int(mask.sum()), 2),
        "isolated_pixel_percent": round(100 * isolated / max(1, eligible), 2),
        "opaque_pixel_count": int(mask.sum()),
        "colour_count": len({tuple(v) for v in rgb[mask]}),
    }


def make_emit(icon: Image.Image) -> Image.Image:
    data = np.array(icon)
    rgb, alpha = data[:, :, :3], data[:, :, 3] > 0
    violet = np.zeros(alpha.shape, dtype=bool)
    for colour in RAMPS["violet"][1:]:
        violet |= np.all(rgb == colour, axis=2)
    violet &= alpha
    if not violet.any():
        raise ValueError("Glass glow missing")
    result = np.zeros_like(data)
    result[violet] = data[violet]
    return Image.fromarray(result, "RGBA")


def review_sheets(manifest: list[dict]) -> None:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    sheet = Image.new("RGB", (580, len(manifest) * 40), "#17191b")
    pen = ImageDraw.Draw(sheet)
    for row, entry in enumerate(manifest):
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        pen.text((4, row * 40 + 10), entry["id"], font=font, fill="#f5f5f2")
        for col, bg in enumerate(BACKGROUNDS):
            x, y = 175 + col * 80, row * 40
            pen.rectangle((x, y, x + 79, y + 39), fill=bg)
            sheet.paste(icon, (x + 4, y + 4), icon)
    sheet.save(ROOT / "contact_sheet.png")
    sheet.resize((1160, len(manifest) * 80), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")

    compare = Image.new("RGB", (520, len(manifest) * 92), "#17191b")
    pen = ImageDraw.Draw(compare)
    for row, entry in enumerate(manifest):
        y = row * 92
        pen.text((4, y + 2), f"{entry['id']} / {entry['old_comparison']}", font=font, fill="#f5f5f2")
        pen.rectangle((6, y + 22, 358, y + 89), fill="#2c2e30")
        old = old_icon(entry["old_comparison"]).resize((144, 64), Image.Resampling.NEAREST)
        new = Image.open(ROOT / entry["file"]).convert("RGBA").resize((144, 64), Image.Resampling.NEAREST)
        compare.paste(new, (15, y + 24), new)
        compare.paste(old, (197, y + 24), old)
        pen.text((365, y + 43), f"{entry['silhouette_height']} / {entry['old_height']} px", font=font, fill="#eae9e4")
    compare.save(ROOT / "fill_vs_old_2x.png")

    # Existing Lungmen silhouettes provide a read-only style/shape baseline.
    old_ids = ["finger_blade", "gang_machete", "lgd_knife", "courier_dagger", "yan_ring_saber", "lord_blade"]
    entries = [(x, old_icon(x)) for x in old_ids]
    entries.extend((e["id"], Image.open(ROOT / e["file"]).convert("RGBA")) for e in manifest)
    silhouette = Image.new("RGB", (4 * 180, ((len(entries) + 3) // 4) * 70), "#d2cbbb")
    pen = ImageDraw.Draw(silhouette)
    for index, (item_id, icon) in enumerate(entries):
        x, y = (index % 4) * 180, (index // 4) * 70
        silhouette.paste(Image.new("RGB", SIZE, "#111315"), (x + 52, y + 5), icon.getchannel("A"))
        pen.text((x + 4, y + 44), item_id, font=font, fill="#222222")
    silhouette.save(ROOT / "silhouette_check.png")


def main() -> None:
    manifest = []
    qa = []
    for item_id, name, kind, form, height, groups, refs, comparison in SPECS:
        source = source_crop(item_id)
        icon = reduce_icon(source, item_id, height, groups)
        icon.save(ROOT / f"{item_id}.png")
        icon.resize((576, 256), Image.Resampling.NEAREST).save(ROOT / f"{item_id}_8x.png")
        has_emit = item_id == "set_grey_order_0"
        if has_emit:
            make_emit(icon).save(ROOT / f"{item_id}_emit.png")
        measure = metrics(icon)
        old_height = old_icon(comparison).getbbox()[3] - old_icon(comparison).getbbox()[1]
        manifest.append({
            "id": item_id, "name": name, "kind": kind, "form": form,
            "file": f"{item_id}.png", "native_size": list(SIZE), "has_emit": has_emit,
            "prototype_refs": refs, "isolated_pixel_percent": measure["isolated_pixel_percent"],
            "old_comparison": comparison, "old_height": old_height,
            "silhouette_height": measure["silhouette_height"],
        })
        qa.append({"id": item_id, **measure, "old_comparison": comparison, "old_height": old_height})
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "qa_report.json").write_text(json.dumps(qa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review_sheets(manifest)


if __name__ == "__main__":
    main()
