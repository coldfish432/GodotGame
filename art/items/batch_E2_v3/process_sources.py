"""Resize and quantize individually painted E2 source art, then build previews.

Source PNGs in sources/ were painted with image_gen. This script does not draw
sprite geometry or details. Run with Python and Pillow from any directory.
"""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = [
    "#0b0c0d",  # exterior outline
    "#2a2d33", "#4a5058", "#7d868e", "#b4bec4", "#eef3f5",  # steel
    "#2e2018", "#5a3d2a", "#86603f", "#b48a5e",  # leather
    "#141f30", "#24395a", "#3d6088", "#6f9cc6", "#b5d2ea",  # police navy
    "#6e1616", "#a82a22", "#d9483a", "#f07a62",  # vermilion
    "#6e5220", "#a8822e", "#dcb85a",  # brass
    "#c8d860",  # reflective yellow-green
    "#68d848",  # indicator green
]
COLORS = [tuple(bytes.fromhex(x[1:])) for x in PALETTE]
ITEMS = [
    ("finger_blade", "指刃", "weapon"),
    ("gang_machete", "帮派砍刀", "weapon"),
    ("lgd_knife", "近卫局警用刀", "weapon"),
    ("courier_dagger", "押运短刃", "weapon"),
    ("yan_ring_saber", "炎式环首刀", "weapon"),
    ("lgd_vest", "近卫局制式护甲", "armor"),
    ("fire_suit", "消防署隔热服", "armor"),
    ("courier_vest", "押运防弹背心", "armor"),
    ("inspector_armor", "特别督察组战术护甲", "armor"),
    ("tactical_charm", "战术挂饰", "trinket"),
    ("lgd_radio", "近卫局对讲机", "trinket"),
    ("lungmen_wallet", "龙门币钱夹", "trinket"),
    ("yan_talisman", "炎式平安符", "trinket"),
]
PROTOTYPES = {
    "finger_blade": ["https://en.wikipedia.org/wiki/Mark_I_trench_knife"],
    "gang_machete": ["https://en.wikipedia.org/wiki/Dadao"],
    "lgd_knife": ["https://en.wikipedia.org/wiki/Combat_knife"],
    "courier_dagger": ["https://en.wikipedia.org/wiki/Butterfly_sword"],
    "yan_ring_saber": ["https://zh.wikipedia.org/wiki/環首刀"],
    "lgd_vest": ["https://en.wikipedia.org/wiki/Bulletproof_vest"],
    "fire_suit": ["https://en.wikipedia.org/wiki/Fire_proximity_suit", "https://en.wikipedia.org/wiki/Bunker_gear"],
    "courier_vest": ["https://en.wikipedia.org/wiki/Plate_carrier"],
    "inspector_armor": ["https://en.wikipedia.org/wiki/Plate_carrier"],
    "tactical_charm": ["https://en.wikipedia.org/wiki/D-ring"],
    "lgd_radio": ["https://en.wikipedia.org/wiki/Walkie-talkie"],
    "lungmen_wallet": ["https://en.wikipedia.org/wiki/Coin_purse"],
    "yan_talisman": ["https://zh.wikipedia.org/wiki/香囊"],
}
SIZES = {"weapon": (72, 32), "armor": (72, 72), "trinket": (32, 32)}
FIT = {"weapon": (70, 30), "armor": (66, 68), "trinket": (30, 30)}
BACKGROUNDS = ("#2c2e30", "#142538", "#352710")
# Exposure affects palette choice only; tune per source after native-size QA.
EXPOSURE: dict[str, int] = {}
HIGHLIGHT_QUOTA: dict[str, float] = {
    "finger_blade": .18, "gang_machete": .19, "courier_dagger": .18,
    "lgd_vest": .18, "courier_vest": .17, "inspector_armor": .19,
    "tactical_charm": .18, "lgd_radio": .19,
}


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return 2 * (a[0] - b[0]) ** 2 + 4 * (a[1] - b[1]) ** 2 + 3 * (a[2] - b[2]) ** 2


def quantize(image: Image.Image, key: str, exposure: int,
             highlight_quota: float = 0.0) -> Image.Image:
    """Quantize opaque pixels to the approved palette, capped at 24 colors."""
    nearest = {}
    for c in set((r, g, b) for r, g, b, a in image.getdata() if a >= 128):
        sample = tuple(min(255, channel + exposure) for channel in c)
        nearest[c] = min(range(len(COLORS)), key=lambda i: distance(sample, COLORS[i]))
    counts = {}
    for r, g, b, a in image.getdata():
        if a >= 128:
            idx = nearest[r, g, b]
            counts[idx] = counts.get(idx, 0) + 1
    reserved = {0}
    if key == "lgd_radio":
        reserved.add(23)  # green LED
    if len(counts) > 24:
        keep = reserved | set(sorted(counts, key=counts.get, reverse=True)[:24 - len(reserved)])
        remap = {i: (i if i in keep else min(keep, key=lambda j: distance(COLORS[i], COLORS[j]))) for i in counts}
    else:
        remap = {i: i for i in counts}
    out = Image.new("RGBA", image.size)
    src, dst = image.load(), out.load()
    brightest = set()
    if highlight_quota:
        ranked = sorted(((0.2126 * src[x,y][0] + 0.7152 * src[x,y][1] + 0.0722 * src[x,y][2], x, y)
                         for y in range(image.height) for x in range(image.width) if src[x,y][3] >= 128), reverse=True)
        brightest = {(x,y) for _,x,y in ranked[:round(len(ranked)*highlight_quota)]}
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = src[x, y]
            if a >= 128:
                chosen = COLORS[remap[nearest[r, g, b]]]
                if key == "lgd_radio" and g > 45 and g > 1.5 * r and g > 1.2 * b:
                    chosen = COLORS[23]  # retain the painted LED hue at native size
                if key == "lgd_vest":
                    if g >= r and g > 1.4 * b and r > 130:
                        chosen = COLORS[22]  # painted reflective strip
                    elif chosen == COLORS[23]:
                        chosen = COLORS[22]  # LED green is emit-only
                    elif chosen in {COLORS[i] for i in (*range(6, 10), *range(19, 22))}:
                        chosen = COLORS[19]  # painted dark-brass underside line
                if key == "courier_vest":
                    chosen = min(COLORS[:6], key=lambda c: distance((r,g,b), c))
                    if 0.2126*r + 0.7152*g + 0.0722*b >= 75 and chosen == COLORS[2]:
                        chosen = COLORS[3]  # lit mid-grey webbing and edge planes
                if key == "yan_ring_saber" and x < 10 and y < 15 and chosen == COLORS[22]:
                    chosen = COLORS[21]
                if key == "lgd_knife":
                    if x < 6 and r >= 160 and g >= 130 and b >= 70 and r > 1.12*g:
                        chosen = COLORS[21]  # three painted pommel rivets
                    elif x < 24:
                        chosen = min(COLORS[:3], key=lambda c: distance((r,g,b), c))
                    else:
                        chosen = min(COLORS[1:6], key=lambda c: distance((r,g,b), c))
                if (key in {"lungmen_wallet", "yan_talisman"} and g >= 100
                        and r > 1.1 * g and g > 1.3 * b):
                    chosen = COLORS[21]  # lit brass clasp, trim and round motif
                if ((x,y) in brightest and chosen not in {COLORS[i] for i in range(15, 24)}
                        and 0.2126*chosen[0]+0.7152*chosen[1]+0.0722*chosen[2] < 153):
                    options = ([COLORS[14]] if key in {"lgd_vest", "inspector_armor", "lgd_radio"}
                               else [COLORS[4], COLORS[5]])
                    chosen = min(options, key=lambda c: distance((r,g,b),c))
                dst[x, y] = (*chosen, 255)
    # Boundary-aware quantization retains the painted contour's one-pixel
    # near-black swatch after reduction from the high-resolution source.
    alpha = out.getchannel("A").load()
    edge = [(x,y) for y in range(image.height) for x in range(image.width)
            if alpha[x,y] and any(xx < 0 or yy < 0 or xx >= image.width or yy >= image.height
                                or not alpha[xx,yy] for xx,yy in
                                ((x-1,y),(x+1,y),(x,y-1),(x,y+1)))]
    for x,y in edge:
        prior = dst[x,y][:3]
        if key == "yan_ring_saber" and x < 10 and y < 15:
            dst[x,y] = (*COLORS[21 if x < 5 or y < 9 else 19],255)
            continue  # painted open brass loop, with a two-tone brass edge
        if key == "yan_ring_saber" and x < 10 and y >= 15:
            r,g,b,_ = src[x,y]
            if r > 80 and r > 1.5*g and r > 1.5*b:
                dst[x,y] = (*COLORS[17 if r >= 180 else 16],255)
                continue  # preserve the painted separate red strands
        lit = 0.2126*prior[0]+0.7152*prior[1]+0.0722*prior[2]
        if lit >= 170 and (x < image.width // 2 or y < image.height // 2):
            continue  # selective lit edge from the painted source
        dst[x,y] = (*COLORS[0],255)
    return spatial_quantization_cleanup(out, image)


def spatial_quantization_cleanup(icon: Image.Image, original: Image.Image) -> Image.Image:
    """Resolve singleton swatches during quantization using nearby swatches.

    This changes palette choices only; it never draws shapes or changes alpha.
    Source color proximity breaks ties, retaining the painted folds and metal edge.
    """
    protected = {COLORS[21], COLORS[22], COLORS[23]}  # lit brass, reflective bands and LED
    for _ in range(5):
        src = icon.load()
        target = icon.copy()
        dst = target.load()
        changes = 0
        for y in range(icon.height):
            for x in range(icon.width):
                current = src[x, y]
                if current[3] == 0 or current[:3] in protected:
                    continue
                neighbors = [src[nx, ny] for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1))
                             if 0 <= nx < icon.width and 0 <= ny < icon.height]
                if len(neighbors) < 4 or any(c[3] == 0 for c in neighbors):
                    continue  # retain the one-pixel exterior outline
                if current in neighbors:
                    continue
                options = Counter(c for c in neighbors if c[:3] not in protected)
                if not options:
                    continue
                source_rgb = original.getpixel((x, y))[:3]
                choice = min(options, key=lambda c: distance(source_rgb, c[:3]) - 900 * options[c])
                if choice != current:
                    dst[x, y] = choice
                    changes += 1
        icon = target
        if not changes:
            break
    return icon


def make_icon(key: str, kind: str) -> Image.Image:
    source = Image.open(ROOT / "sources" / f"{key}_source.png").convert("RGBA")
    alpha = source.getchannel("A").point(lambda a: 255 if a >= 32 else 0)
    bbox = alpha.getbbox()
    if not bbox:
        raise ValueError(f"empty source: {key}")
    source = source.crop(bbox)
    tw, th = SIZES[kind]
    fw, fh = FIT[kind]
    if kind == "weapon":
        rw = fw
        minimum = {"finger_blade": 26, "gang_machete": 28,
                   "lgd_knife": 20, "courier_dagger": 24,
                   "yan_ring_saber": 24}[key]
        rh = min(fh, max(minimum, round(source.height * rw / source.width)))
    elif kind == "trinket":
        # Preserve the radio and hanging charm proportions in square slots.
        scale = min(fw / source.width, fh / source.height)
        rw, rh = max(1, round(source.width * scale)), max(1, round(source.height * scale))
    else:
        rw, rh = fw, fh
    resized = source.resize((rw, rh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (tw, th))
    canvas.paste(resized, ((tw - rw) // 2, (th - rh) // 2))
    return quantize(canvas, key, EXPOSURE.get(key, 0),
                    HIGHLIGHT_QUOTA.get(key, 0.0))


def isolated_pixel_percent(image: Image.Image) -> float:
    """Opaque pixels whose RGB value matches none of four opaque neighbors."""
    pixels = image.convert("RGBA").load()
    total = isolated = 0
    for y in range(image.height):
        for x in range(image.width):
            rgb = pixels[x, y]
            if rgb[3] == 0:
                continue
            total += 1
            matches = any(0 <= nx < image.width and 0 <= ny < image.height
                          and pixels[nx, ny] == rgb
                          for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
            isolated += not matches
    return round(100 * isolated / total, 2)


def make_contact(rows: list[tuple[str, str, str]]) -> None:
    font = ImageFont.load_default()
    width = 482
    heights = [90 if kind == "armor" else 50 for _, _, kind in rows]
    out = Image.new("RGB", (width, sum(heights) + 30), "#20242b")
    draw = ImageDraw.Draw(out)
    draw.text((5, 6), "E2 v3 / 1x, 40px grid / common  fine  rare", fill="#eef3f5", font=font)
    y = 30
    for (key, _, kind), h in zip(rows, heights):
        icon = Image.open(ROOT / f"{key}.png").convert("RGBA")
        cell_w = 80 if kind != "trinket" else 40
        cell_h = 80 if kind == "armor" else 40
        draw.text((5, y + 3), key, fill="#eef3f5", font=font)
        for j, bg in enumerate(BACKGROUNDS):
            x = 152 + j * 106
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), fill=bg, outline="#7d868e", width=1)
            if cell_w == 80:
                draw.line((x + 40, y + 1, x + 40, y + cell_h - 2), fill="#34404c", width=1)
            if cell_h == 80:
                draw.line((x + 1, y + 40, x + cell_w - 2, y + 40), fill="#34404c", width=1)
            out.paste(icon, (x + (cell_w - icon.width) // 2, y + (cell_h - icon.height) // 2), icon)
        y += h
    out.save(ROOT / "contact_sheet.png")
    out.resize((out.width * 2, out.height * 2), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")


def make_silhouette(rows: list[tuple[str, str, str]]) -> None:
    heights = [152 if kind == "armor" else 72 for _, _, kind in rows]
    out = Image.new("RGB", (310, sum(heights) + 16), "#d9d6cc")
    draw = ImageDraw.Draw(out)
    y = 8
    for (key, _, kind), height in zip(rows, heights):
        icon = Image.open(ROOT / f"{key}.png").convert("RGBA")
        black = Image.new("RGB", icon.size, "#0b0c0d")
        black.putalpha(icon.getchannel("A"))
        black = black.resize((icon.width * 2, icon.height * 2), Image.Resampling.NEAREST)
        out.paste(black, (4, y + (height - black.height) // 2), black)
        draw.text((154, y + height // 2 - 4), key, fill="#0b0c0d")
        y += height
    out.save(ROOT / "silhouette_check.png")


def main() -> None:
    manifest = []
    for key, name, kind in ITEMS:
        icon = make_icon(key, kind)
        icon.save(ROOT / f"{key}.png")
        icon.resize((icon.width * 8, icon.height * 8), Image.Resampling.NEAREST).save(ROOT / f"{key}_8x.png")
        has_emit = key in {"tactical_charm", "lgd_radio"}
        if has_emit:
            emit = Image.new("RGBA", icon.size)
            src, dst = icon.load(), emit.load()
            for yy in range(icon.height):
                for xx in range(icon.width):
                    color = src[xx, yy]
                    if key == "lgd_radio" and color[:3] == COLORS[23]:
                        dst[xx, yy] = color
                    elif (key == "tactical_charm" and yy >= icon.height * 0.70
                          and icon.width * 0.25 <= xx <= icon.width * 0.75
                          and color[:3] in {COLORS[4], COLORS[5]}):
                        dst[xx, yy] = color
            emit.save(ROOT / f"{key}_emit.png")
        manifest.append({"id": key, "name": name, "kind": kind, "file": f"{key}.png",
                         "preview": f"{key}_8x.png", "native_size": list(icon.size),
                         "has_emit": has_emit, "emit_file": f"{key}_emit.png" if has_emit else None,
                         "source": f"sources/{key}_source.png",
                         "prototype_urls": PROTOTYPES[key],
                         "isolated_pixel_percent": isolated_pixel_percent(icon)})
    make_contact(ITEMS)
    make_silhouette(ITEMS)
    (ROOT / "manifest.json").write_text(json.dumps({"batch": "E2", "version": 3,
        "source_brief": "../E2_brief_v1.md",
        "revision_brief": "../E2_revision_v3.md",
        "reference_board": "../E_reference_board.md", "display_scale": 1,
        "preview_scale": 8, "contact_sheet": "contact_sheet.png",
        "contact_sheet_2x": "contact_sheet_2x.png",
        "silhouette_check": "silhouette_check.png",
        "generation_prompts": "generation_prompts.md",
        "isolated_pixel_definition": "Percent of opaque pixels whose RGBA value matches none of four opaque orthogonal neighbors",
        "items": manifest}, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
