"""Reduce painted E7 sources and package native Godot inventory icons."""

from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parent
ITEMS = ROOT.parent
SIZE = (72, 32)
OUTLINE = (11, 12, 13)
PALETTE_BASE = [
    OUTLINE,
    (42, 45, 51), (74, 80, 88), (125, 134, 142), (180, 190, 196), (238, 243, 245),
    (46, 32, 24), (90, 61, 42), (134, 96, 63), (180, 138, 94),
    (74, 42, 29), (125, 69, 41), (176, 106, 58), (217, 149, 96),
    (90, 77, 58), (133, 117, 85), (179, 162, 124), (214, 200, 162),
    (216, 165, 32), (156, 43, 37), (217, 72, 58),
]
ORANGE = [(184, 90, 18), (238, 138, 36), (255, 179, 90)]
ITEMS_META = [
    ("a", 0, "mine_x01", "工兵锹", "base", "heavy", ["proto_entrenching_tool.jpg"]),
    ("a", 1, "mine_x02", "大号管钳", "base", "heavy", ["proto_pipe_wrench.jpg"]),
    ("a", 2, "mine_x03", "缠链指虎", "base", "fist", ["proto_brass_knuckles.jpg"]),
    ("a", 3, "mine_x04", "纠察队钩刀", "base", "blade", ["proto_billhook.jpg"]),
    ("b", 0, "mine_x05", "游击队旧式刺刀", "base", "blade", ["proto_bayonet.jpg"]),
    ("b", 1, "mine_x06", "施术短刃", "base", "blade", ["proto_trench_knife.jpg"]),
    ("b", 2, "mine_x07", "攻坚破门锤", "base", "heavy", []),
    ("b", 3, "mine_x08", "帝国突击矛", "base", "polearm", []),
    ("c", 0, "mi_thug_0", "暴徒的改刃", "exclusive", "blade", ["modified_machete.png"]),
    ("c", 1, "mi_picket_8", "纠察官的套索", "exclusive", "blade", ["prts_picket.png", "mine_x04.png"]),
    ("c", 2, "set_nameless_0", "无名者的砍刀", "set", "blade", ["proto_machete.jpg"]),
    ("c", 3, "set_warrant_0", "追缉令·钩刀", "set", "blade", ["mine_x04.png"]),
]
BACKGROUNDS = ["#2c2e30", "#142538", "#352710", "#341e08", "#112e1f"]


def source_crop(sheet: Image.Image, quadrant: int) -> Image.Image:
    width, height = sheet.size
    half_w, half_h = width // 2, height // 2
    left, top = (quadrant % 2) * half_w, (quadrant // 2) * half_h
    right, bottom = (width if quadrant % 2 else half_w), (height if quadrant // 2 else half_h)
    crop = sheet.crop((left, top, right, bottom)).convert("RGBA")
    pixels = np.array(crop)
    pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    crop = Image.fromarray(pixels, "RGBA")
    bbox = crop.getbbox()
    if bbox is None:
        raise ValueError(f"Empty source quadrant {quadrant}")
    return crop.crop(bbox)


def reduce_icon(source: Image.Image, enemy_id: str) -> Image.Image:
    scale = min(70 / source.width, 28 / source.height)
    reduced = source.resize((max(1, round(source.width * scale)), max(1, round(source.height * scale))), Image.Resampling.BOX)
    original = np.array(reduced)
    alpha = original[:, :, 3] >= 120
    # Colour averaging is only preparation for mapping to the established
    # 4-5-step game palette. All final channels are snapped to exact colours.
    palette = np.array(PALETTE_BASE + (ORANGE if enemy_id == "mine_x06" else []), dtype=np.int32)
    rgb = original[:, :, :3].astype(np.int32)
    distances = ((rgb[:, :, None, :] - palette[None, None, :, :]) ** 2).sum(axis=3)
    out_rgb = palette[np.argmin(distances, axis=2)].astype(np.uint8)
    # Force a continuous dark pixel rim around the painted silhouette.
    interior = alpha.copy()
    interior[1:, :] &= alpha[:-1, :]
    interior[:-1, :] &= alpha[1:, :]
    interior[:, 1:] &= alpha[:, :-1]
    interior[:, :-1] &= alpha[:, 1:]
    out_rgb[alpha & ~interior] = OUTLINE
    out = np.zeros((SIZE[1], SIZE[0], 4), dtype=np.uint8)
    x = (SIZE[0] - reduced.width) // 2
    y = (SIZE[1] - reduced.height) // 2
    out[y:y + reduced.height, x:x + reduced.width, :3] = out_rgb
    out[y:y + reduced.height, x:x + reduced.width, 3] = alpha.astype(np.uint8) * 255
    if enemy_id == "mine_x08":
        # The source spear shaft is thinner than one target pixel in places.
        # Rejoin its painted shaft between the visible grip and spearhead.
        out[14, 12:57, :3] = (125, 134, 142)
        out[14, 12:57, 3] = 255
        out[15, 12:57, :3] = OUTLINE
        out[15, 12:57, 3] = 255
    if enemy_id == "set_warrant_0":
        # A few pixels from the upper source quadrant touched this crop.
        out[:7, :, 3] = 0
    out = smooth_single_pixels(out)
    if enemy_id == "mine_x05":
        # The small ring socket at the bayonet root needs a native-pixel hole.
        ring = Image.fromarray(out, "RGBA")
        pen = ImageDraw.Draw(ring)
        pen.ellipse((13, 8, 19, 15), fill=OUTLINE)
        pen.ellipse((14, 9, 18, 13), outline=(180, 190, 196), fill=(0, 0, 0, 0))
        out = np.array(ring)
    if enemy_id == "mi_thug_0":
        # Clarify the third weld seam in the painted machete's steel face.
        out[10:21, 46, :3] = (125, 69, 41)
        out[11:20, 47, :3] = (217, 149, 96)
    out = raise_highlight_floor(out)
    if enemy_id == "mine_x08":
        # Consolidate tiny alternating source flecks on the narrow grip.
        out[15, 3:12, :3] = (214, 200, 162)
        out[16, 9:13, :3] = (90, 61, 42)
    return Image.fromarray(out, "RGBA")


def smooth_single_pixels(data: np.ndarray) -> np.ndarray:
    """Remove stray one-pixel tone noise while keeping contour and wear."""
    result = data.copy()
    for y in range(1, SIZE[1] - 1):
        for x in range(1, SIZE[0] - 1):
            if data[y, x, 3] == 0 or tuple(data[y, x, :3]) == OUTLINE:
                continue
            neighbourhood = data[y - 1:y + 2, x - 1:x + 2]
            same = np.all(neighbourhood[:, :, :3] == data[y, x, :3], axis=2) & (neighbourhood[:, :, 3] > 0)
            if int(same.sum()) != 1:
                continue
            neighbours = [tuple(data[ny, nx, :3]) for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))
                          if data[ny, nx, 3] > 0 and tuple(data[ny, nx, :3]) != OUTLINE]
            if neighbours:
                result[y, x, :3] = max(set(neighbours), key=neighbours.count)
    return result


def raise_highlight_floor(data: np.ndarray) -> np.ndarray:
    """Extend existing top-left material highlights to the 15% spec floor."""
    result = data.copy()
    mask = data[:, :, 3] > 0
    rgb = data[:, :, :3].astype(float)
    luminance = (0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]) / 255
    bright = mask & (luminance >= 0.6)
    target = int(np.ceil(0.155 * int(mask.sum())))
    need = max(0, target - int(bright.sum()))
    if need == 0:
        return result
    yy, xx = np.indices(mask.shape)
    candidates = mask & ~bright & (np.any(data[:, :, :3] != OUTLINE, axis=2))
    # Prefer already-lit paint on upper-facing planes; never alter the rim.
    score = luminance - 0.14 * (yy / SIZE[1]) - 0.04 * (xx / SIZE[0])
    choices = np.flatnonzero(candidates)
    chosen = choices[np.argsort(score.flat[choices])[-need:]]
    for flat in chosen:
        y, x = np.unravel_index(flat, mask.shape)
        r, g, b = map(int, data[y, x, :3])
        if max(r, g, b) - min(r, g, b) < 26:
            colour = (180, 190, 196)  # steel light
        elif r > g * 1.25:
            colour = (217, 149, 96)  # rust/copper light
        else:
            colour = (214, 200, 162)  # canvas/leather light
        result[y, x, :3] = colour
    return result


def isolated_percent(image: Image.Image) -> float:
    data = np.array(image)
    rgb, alpha = data[:, :, :3], data[:, :, 3] > 0
    count = 0
    isolated = 0
    for y in range(1, SIZE[1] - 1):
        for x in range(1, SIZE[0] - 1):
            if not alpha[y, x] or tuple(rgb[y, x]) == OUTLINE:
                continue
            count += 1
            neighbours = rgb[y - 1:y + 2, x - 1:x + 2]
            visible = alpha[y - 1:y + 2, x - 1:x + 2]
            same = np.all(neighbours == rgb[y, x], axis=2) & visible
            if int(same.sum()) <= 1:
                isolated += 1
    return round(100 * isolated / max(count, 1), 2)


def emit_for_crystal(image: Image.Image) -> Image.Image:
    data = np.array(image)
    emit = np.zeros_like(data)
    orange = np.zeros(data.shape[:2], dtype=bool)
    for colour in ORANGE:
        orange |= np.all(data[:, :, :3] == colour, axis=2)
    orange &= data[:, :, 3] > 0
    # The source's indicator sits above the boxed grip, at the left-middle.
    orange &= np.indices(orange.shape)[0] < 17
    emit[orange] = data[orange]
    if not orange.any():
        raise ValueError("mine_x06 has no orange indicator pixels")
    return Image.fromarray(emit, "RGBA")


def draw_contacts(manifest: list[dict]) -> None:
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    slot_w, slot_h, label_w = 80, 40, 160
    contact = Image.new("RGB", (label_w + len(BACKGROUNDS) * slot_w, len(manifest) * slot_h), "#17191b")
    draw = ImageDraw.Draw(contact)
    for row, entry in enumerate(manifest):
        icon = Image.open(ROOT / entry["file"]).convert("RGBA")
        draw.text((4, row * slot_h + 11), entry["id"], font=font, fill="#e8e8e4")
        for col, bg in enumerate(BACKGROUNDS):
            x, y = label_w + col * slot_w, row * slot_h
            draw.rectangle((x, y, x + slot_w - 1, y + slot_h - 1), fill=bg)
            contact.paste(icon, (x + 4, y + 4), icon)
    contact.save(ROOT / "contact_sheet.png")
    contact.resize((contact.width * 2, contact.height * 2), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")

    old_ids = ["modified_machete", "standard_dagger", "mine_issue_blade", "patrol_saber", "pickhaft_blade", "crystal_edge"]
    rows = [(old_id, ITEMS / ("batch_E4_v4" if old_id == "crystal_edge" else "batch_E1_v5") / f"{old_id}.png") for old_id in old_ids]
    rows += [(entry["id"], ROOT / entry["file"]) for entry in manifest]
    silhouette = Image.new("RGB", (3 * 240, 6 * 70), "#d0c8b8")
    silhouette_draw = ImageDraw.Draw(silhouette)
    for index, (item_id, path) in enumerate(rows):
        x, y = index % 3 * 240, index // 3 * 70
        icon = Image.open(path).convert("RGBA")
        mask = icon.getchannel("A")
        shape = Image.new("RGB", icon.size, "#111315")
        silhouette.paste(shape, (x + 80, y + 8), mask)
        silhouette_draw.text((x + 6, y + 42), item_id, font=font, fill="#252525")
    silhouette.save(ROOT / "silhouette_check.png")


def main() -> None:
    sheets = {name: Image.open(ROOT / "sources" / f"{name}_raw.png") for name in "abc"}
    manifest = []
    for group, quadrant, item_id, name, kind, form, prototypes in ITEMS_META:
        crop = source_crop(sheets[group], quadrant)
        crop.save(ROOT / "sources" / f"{item_id}_painted.png")
        icon = reduce_icon(crop, item_id)
        icon.save(ROOT / f"{item_id}.png")
        icon.resize((SIZE[0] * 8, SIZE[1] * 8), Image.Resampling.NEAREST).save(ROOT / f"{item_id}_8x.png")
        has_emit = item_id == "mine_x06"
        if has_emit:
            emit_for_crystal(icon).save(ROOT / f"{item_id}_emit.png")
        manifest.append({
            "id": item_id, "name": name, "kind": kind, "form": form,
            "file": f"{item_id}.png", "native_size": list(SIZE), "has_emit": has_emit,
            "prototype_refs": prototypes, "isolated_pixel_percent": isolated_percent(icon),
        })
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    draw_contacts(manifest)


if __name__ == "__main__":
    main()
