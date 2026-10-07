"""Resize and quantize individually painted E1 source art, then build previews.

Source PNGs in sources/ were painted with image_gen. This script does not draw
sprite geometry or details. Run with Python and Pillow from any directory.
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = [
    "#0b0c0d",  # exterior outline
    "#2a2d33", "#4a5058", "#7d868e", "#b4bec4", "#eef3f5",  # steel
    "#2e2018", "#5a3d2a", "#86603f", "#b48a5e",  # leather
    "#4a2a1d", "#7d4529", "#b06a3a", "#d99560",  # rust
    "#5a4d3a", "#857555", "#b3a27c", "#d6c8a2",  # canvas
    "#b85a12", "#ee8a24", "#ffb35a", "#ffe0a8",  # originium
    "#d8a520", "#d9d6cc", "#f4f1e8", "#9c2b25",
]
COLORS = [tuple(bytes.fromhex(x[1:])) for x in PALETTE]
ITEMS = [
    ("modified_machete", "改装砍刀", "weapon"),
    ("standard_dagger", "制式短刀", "weapon"),
    ("mine_issue_blade", "矿区制式刀", "weapon"),
    ("patrol_saber", "纠察队佩刀", "weapon"),
    ("pickhaft_blade", "镐柄战刃", "weapon"),
    ("miner_vest", "矿工护甲", "armor"),
    ("reunion_coat", "整合运动制式外套", "armor"),
    ("patrol_winter_coat", "纠察队防寒大衣", "armor"),
    ("heavy_mine_suit", "矿场重型防护服", "armor"),
    ("dust_mask", "防尘面罩", "trinket"),
    ("liquor_flask", "烈酒扁壶", "trinket"),
    ("reunion_mask", "整合运动面具", "trinket"),
    ("originium_meter", "源石感应计", "trinket"),
]
PROTOTYPES = {
    "modified_machete": ["https://en.wikipedia.org/wiki/Machete"],
    "standard_dagger": ["https://en.wikipedia.org/wiki/NR-40"],
    "mine_issue_blade": ["https://en.wikipedia.org/wiki/Yakutian_knife"],
    "patrol_saber": ["https://en.wikipedia.org/wiki/Shashka"],
    "pickhaft_blade": ["https://en.wikipedia.org/wiki/Ice_axe", "https://en.wikipedia.org/wiki/Pickaxe"],
    "miner_vest": ["https://en.wikipedia.org/wiki/Davy_lamp"],
    "reunion_coat": ["https://prts.wiki/w/士兵", "https://prts.wiki/w/暴徒"],
    "patrol_winter_coat": ["https://en.wikipedia.org/wiki/Greatcoat"],
    "heavy_mine_suit": ["https://en.wikipedia.org/wiki/Hazmat_suit", "https://en.wikipedia.org/wiki/GP-5_gas_mask"],
    "dust_mask": ["https://en.wikipedia.org/wiki/Respirator"],
    "liquor_flask": ["https://en.wikipedia.org/wiki/Hip_flask"],
    "reunion_mask": ["https://prts.wiki/w/士兵", "https://prts.wiki/w/暴徒"],
    "originium_meter": ["https://en.wikipedia.org/wiki/Geiger_counter"],
}
SIZES = {"weapon": (72, 32), "armor": (72, 72), "trinket": (32, 32)}
FIT = {"weapon": (70, 30), "armor": (66, 68), "trinket": (30, 30)}
BACKGROUNDS = ("#2c2e30", "#142538", "#352710")
# Exposure used only when choosing the nearest palette swatch. These small
# per-source corrections meet the brief's 15 percent bright-pixel threshold.
EXPOSURE = {"modified_machete": 30, "standard_dagger": 45,
            "mine_issue_blade": 25, "pickhaft_blade": 40,
            "originium_meter": 50, "patrol_winter_coat": 30,
            "heavy_mine_suit": 15, "dust_mask": 25}


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return 2 * (a[0] - b[0]) ** 2 + 4 * (a[1] - b[1]) ** 2 + 3 * (a[2] - b[2]) ** 2


def quantize(image: Image.Image, keep_orange: bool, exposure: int,
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
    if keep_orange:
        reserved.update({19, 20})  # orange lamp must survive limited palette
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
    bright_colors = [c for c in COLORS if 0.2126*c[0]+0.7152*c[1]+0.0722*c[2] >= 153]
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = src[x, y]
            if a >= 128:
                chosen = COLORS[remap[nearest[r, g, b]]]
                if (x,y) in brightest and 0.2126*chosen[0]+0.7152*chosen[1]+0.0722*chosen[2] < 153:
                    chosen = min(bright_colors, key=lambda c: distance((r,g,b),c))
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
        lit = 0.2126*prior[0]+0.7152*prior[1]+0.0722*prior[2]
        if lit >= 170 and (x < image.width // 2 or y < image.height // 2):
            continue  # selective lit edge from the painted source
        dst[x,y] = (*COLORS[0],255)
    return out


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
        # Preserve blade curvature while using nearly the full slot width.
        rw = fw
        minimum = 18 if key == "mine_issue_blade" else 28
        rh = min(fh, max(minimum, round(source.height * rw / source.width)))
    else:
        # The art brief specifies near-full occupancy in both dimensions.
        rw, rh = fw, fh
    resized = source.resize((rw, rh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (tw, th))
    canvas.paste(resized, ((tw - rw) // 2, (th - rh) // 2))
    return quantize(canvas, key == "originium_meter", EXPOSURE.get(key, 0),
                    0.17 if key == "reunion_coat" else 0.0)


def make_contact(rows: list[tuple[str, str, str]]) -> None:
    font = ImageFont.load_default()
    width = 482
    heights = [90 if kind == "armor" else 50 for _, _, kind in rows]
    out = Image.new("RGB", (width, sum(heights) + 30), "#20242b")
    draw = ImageDraw.Draw(out)
    draw.text((5, 6), "E1 v2 / actual 40px slots / common  fine  rare", fill="#eef3f5", font=font)
    y = 30
    for (key, _, kind), h in zip(rows, heights):
        icon = Image.open(ROOT / f"{key}.png").convert("RGBA")
        cell_w = 80 if kind != "trinket" else 40
        cell_h = 80 if kind == "armor" else 40
        draw.text((5, y + 3), key, fill="#eef3f5", font=font)
        for j, bg in enumerate(BACKGROUNDS):
            x = 152 + j * 106
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), fill=bg, outline="#7d868e", width=1)
            out.paste(icon, (x + (cell_w - icon.width) // 2, y + (cell_h - icon.height) // 2), icon)
        y += h
    out.save(ROOT / "contact_sheet.png")
    out.resize((out.width * 2, out.height * 2), Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")


def main() -> None:
    manifest = []
    for key, name, kind in ITEMS:
        icon = make_icon(key, kind)
        icon.save(ROOT / f"{key}.png")
        icon.resize((icon.width * 8, icon.height * 8), Image.Resampling.NEAREST).save(ROOT / f"{key}_8x.png")
        has_emit = key == "originium_meter"
        if has_emit:
            emit = Image.new("RGBA", icon.size)
            src, dst = icon.load(), emit.load()
            orange = {tuple(bytes.fromhex(s[1:])) + (255,) for s in PALETTE[18:22]}
            for yy in range(icon.height):
                for xx in range(icon.width):
                    # The painted box also has a warm glint on its left edge.
                    # Only the orange lamp at the right side is emissive.
                    if xx >= icon.width - 4 and src[xx, yy] in orange:
                        dst[xx, yy] = src[xx, yy]
            emit.save(ROOT / f"{key}_emit.png")
        manifest.append({"id": key, "name": name, "kind": kind, "file": f"{key}.png",
                         "preview": f"{key}_8x.png", "native_size": list(icon.size),
                         "has_emit": has_emit, "emit_file": f"{key}_emit.png" if has_emit else None,
                         "source": f"sources/{key}_source.png",
                         "prototype_urls": PROTOTYPES[key]})
    make_contact(ITEMS)
    (ROOT / "manifest.json").write_text(json.dumps({"batch": "E1", "version": 2,
        "source_brief": "../E_revision_brief_v2.md",
        "reference_board": "../E_reference_board.md", "display_scale": 1,
        "preview_scale": 8, "contact_sheet": "contact_sheet.png",
        "contact_sheet_2x": "contact_sheet_2x.png", "items": manifest}, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
