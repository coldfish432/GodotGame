"""Reduce painted E3 sources to native sprites and build review exports.

Source geometry is painted in sources/. This script resizes, quantizes, resolves
isolated palette choices, validates the palette, and makes previews and masks.
"""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PALETTE = [
    "#0b0c0d",  # outline
    "#2a2d33", "#4a5058", "#7d868e", "#b4bec4", "#eef3f5",  # steel / stone
    "#2e2018", "#5a3d2a", "#86603f", "#b48a5e",  # leather
    "#3f2a1a", "#6b4a2e", "#9a7048",  # wood
    "#8e8470", "#b9ae95", "#e6dfcc", "#fbf8ee",  # bone
    "#6e5a45", "#a68c6c", "#d8cbb5",  # fur
    "#3d6a8a", "#5d8fb0", "#9cc8e0", "#e4f4fb",  # ice / emit
    "#b03a2e", "#d9a43a", "#3f6fa8",  # woven bands
    "#9a4418", "#d0662a", "#f29a5a",  # expedition orange
]
COLORS = [tuple(bytes.fromhex(c[1:])) for c in PALETTE]
STEEL = tuple(range(1, 6))
LEATHER = tuple(range(6, 10))
WOOD = tuple(range(10, 13))
BONE = tuple(range(13, 17))
FUR = tuple(range(17, 20))
ICE = tuple(range(20, 24))
BANDS = (24, 25, 26)
ORANGE = (27, 28, 29)
ITEMS = [
    ("icebreaker_knife", "破冰刀", "weapon"),
    ("skinning_knife", "猎刀", "weapon"),
    ("antler_hunter_knife", "角柄猎刀", "weapon"),
    ("expedition_machete", "科考队开路刀", "weapon"),
    ("snowpriest_blade", "雪祀礼刃", "weapon"),
    ("tundra_fur_coat", "冰原毛皮外套", "armor"),
    ("sled_patrol_cloak", "雪橇巡逻队斗篷", "armor"),
    ("expedition_parka", "科考队防寒服", "armor"),
    ("bone_lamellar", "骨片札甲", "armor"),
    ("bone_amulet", "骨制护符", "trinket"),
    ("antler_flute", "角兽骨笛", "trinket"),
    ("bone_drumstick", "兽骨鼓槌", "trinket"),
    ("cipher_fragment", "密文板残片", "trinket"),
]
PROTOTYPES = {
    "icebreaker_knife": ["https://en.wikipedia.org/wiki/Seax"],
    "skinning_knife": ["https://en.wikipedia.org/wiki/Puukko"],
    "antler_hunter_knife": ["https://en.wikipedia.org/wiki/Leuku", "https://en.wikipedia.org/wiki/Duodji"],
    "expedition_machete": ["https://en.wikipedia.org/wiki/Machete"],
    "snowpriest_blade": ["https://en.wikipedia.org/wiki/Leuku", "https://en.wikipedia.org/wiki/Duodji"],
    "tundra_fur_coat": ["https://en.wikipedia.org/wiki/Parka"],
    "sled_patrol_cloak": ["https://en.wikipedia.org/wiki/G%C3%A1kti"],
    "expedition_parka": ["https://en.wikipedia.org/wiki/Parka"],
    "bone_lamellar": ["https://en.wikipedia.org/wiki/Lamellar_armour"],
    "bone_amulet": ["https://en.wikipedia.org/wiki/Amulet"],
    "antler_flute": ["https://en.wikipedia.org/wiki/Bone_flute"],
    "bone_drumstick": ["https://en.wikipedia.org/wiki/S%C3%A1mi_drum"],
    "cipher_fragment": ["https://en.wikipedia.org/wiki/Runestone"],
}
SIZES = {"weapon": (72, 32), "armor": (72, 72), "trinket": (32, 32)}
FIT = {"weapon": (70, 30), "armor": (66, 68), "trinket": (30, 30)}
BACKGROUNDS = ("#2c2e30", "#142538", "#352710")
EXPOSURE: dict[str, int] = {"icebreaker_knife": 30}


def luminance(c: tuple[int, int, int]) -> float:
    return .2126 * c[0] + .7152 * c[1] + .0722 * c[2]


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return 2 * (a[0] - b[0]) ** 2 + 4 * (a[1] - b[1]) ** 2 + 3 * (a[2] - b[2]) ** 2


def candidates(key: str, x: int, rgb: tuple[int, int, int]) -> tuple[int, ...]:
    r, g, b = rgb
    saturated = max(rgb) - min(rgb) > 75
    blue_ice = b > r + 15 and b >= g + 4
    if key == "icebreaker_knife":
        return LEATHER + (0, 1, 2) if x < 26 else STEEL + (ICE if blue_ice else ())
    if key == "skinning_knife":
        return WOOD + BONE + LEATHER + (0,) if x < 35 else STEEL
    if key == "antler_hunter_knife":
        return BONE + LEATHER + WOOD + (BANDS if saturated else ()) if x < 33 else STEEL
    if key == "expedition_machete":
        return ORANGE + (0, 1, 2) if x < 25 else STEEL
    if key == "snowpriest_blade":
        if x < 24:
            return BONE + (0, 1, 2, 3) + (BANDS if saturated else ())
        return STEEL + (ICE if blue_ice else ())
    if key == "tundra_fur_coat":
        return LEATHER + FUR + (16, 0)
    if key == "sled_patrol_cloak":
        return BONE + ICE + (0,) + (BANDS if saturated else ())
    if key == "expedition_parka":
        return ORANGE + FUR + STEEL + LEATHER + (0,)
    if key == "bone_lamellar":
        return BONE + LEATHER + (0,)
    if key == "bone_amulet":
        return BONE + LEATHER + (0,)
    if key == "antler_flute":
        return BONE + LEATHER + (0,) + (BANDS if saturated else ())
    if key == "bone_drumstick":
        return BONE + LEATHER + FUR + (0,)
    if key == "cipher_fragment":
        return STEEL + (ICE if blue_ice else ()) + (0,)
    raise ValueError(key)


def quantize(image: Image.Image, key: str) -> Image.Image:
    """Select E3 material swatches without changing painted alpha or geometry."""
    source = image.load()
    out = Image.new("RGBA", image.size)
    dst = out.load()
    cache: dict[tuple[int, int, int, bool], int] = {}
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = source[x, y]
            if a < 128:
                continue
            sample = (r, g, b)
            ck = (r, g, b, x < 26 if key == "icebreaker_knife" else x < 35 if key == "skinning_knife" else x < 33 if key == "antler_hunter_knife" else x < 25 if key == "expedition_machete" else x < 24 if key == "snowpriest_blade" else False)
            if ck not in cache:
                cand = candidates(key, x, sample)
                exp = EXPOSURE.get(key, 0)
                lit = tuple(min(255, c + exp) for c in sample)
                cache[ck] = min(cand, key=lambda i: distance(lit, COLORS[i]))
            index = cache[ck]
            if (key == "antler_hunter_knife" and x < 8 and 16 <= y <= 22
                    and b >= r + 18 and b >= g + 12):
                index = 26  # reduced blue fibers in the painted pommel wrap
            if key == "snowpriest_blade" and 21 <= x <= 23 and 9 <= y <= 20:
                if x == 21 and r > 3*g and r > 3*b:
                    index = 24
                elif x == 22 and r > g and g > 1.5*b:
                    index = 25
                elif x == 23 and b > 1.4*g and b > 1.8*r:
                    index = 26
            if key == "cipher_fragment" and index in ICE:
                index = 23 if luminance(sample) >= 190 else 22
            dst[x, y] = (*COLORS[index], 255)
    balance_painted_tones(out, image, key)
    # The imagegen source already contains a hard contour. At native scale its
    # outermost reduced pixel gets the standard one-pixel outline.
    alpha = out.getchannel("A").load()
    edge = [(x, y) for y in range(image.height) for x in range(image.width)
            if alpha[x, y] and any(xx < 0 or yy < 0 or xx >= image.width or yy >= image.height
                                or not alpha[xx, yy] for xx, yy in
                                ((x-1, y), (x+1, y), (x, y-1), (x, y+1)))]
    for x, y in edge:
        prior = dst[x, y][:3]
        if ((key == "snowpriest_blade" and 21 <= x <= 23)
                or (key == "antler_hunter_knife" and x < 8 and 16 <= y <= 22)) and prior in {COLORS[i] for i in BANDS}:
            continue  # the painted three narrow woven root bands
        if key == "bone_amulet" and y < 11 and x < 14:
            dst[x, y] = (*COLORS[8], 255)  # lit leather side of the cord loop
            continue
        if key == "bone_drumstick" and y < 16 and x < 10:
            dst[x, y] = (*COLORS[13], 255)  # lit antler edge at top left
            continue
        if luminance(prior) >= 170 and (x < image.width // 2 or y < image.height // 2):
            continue
        dst[x, y] = (*COLORS[0], 255)
    cleaned = spatial_quantization_cleanup(out, image)
    if key == "cipher_fragment":
        carve_cipher_grooves(cleaned)
    return cleaned


def carve_cipher_grooves(icon: Image.Image) -> None:
    """Native-grid cleanup of the painted stone grooves after 32px reduction.

    Reduction broke the source's blue strokes into dots. These four separate
    paths follow its straight-cut/arc layout while restoring continuous cuts.
    The alpha silhouette and unrelated stone pixels are left in place.
    """
    px = icon.load()
    for y in range(icon.height):
        for x in range(icon.width):
            if px[x, y][3] and px[x, y][:3] in {COLORS[i] for i in ICE}:
                value = luminance(px[x, y][:3])
                px[x, y] = (*COLORS[4 if value >= 153 else 3], 255)
    grooves = [
        ([(x, 14) for x in range(10, 15)] + [(14, 15)]
         + [(x, 15) for x in range(15, 19)] + [(18, 16)]
         + [(x, 16) for x in range(19, 22)]),  # long shallow cut
        [(19, 11), (20, 11), (20, 10), (21, 10),
         (22, 10), (22, 11), (23, 11), (23, 12)],  # gentle arc
        [(14+i, 7) for i in range(3)],  # upper short cut
        [(12+i, 24) for i in range(3)],  # lower short cut
    ]
    for path in grooves:
        assert all(px[x, y-1][3] and px[x, y][3] and px[x, y+1][3]
                   for x, y in path), "cipher groove escaped stone face"
        for x, y in path:
            px[x, y-1] = (*COLORS[1], 255)  # 1px recessed edge
            px[x, y+1] = (*COLORS[4], 255)  # 1px lower-right bevel
    for path in grooves:
        for i, (x, y) in enumerate(path):
            px[x, y] = (*COLORS[23 if i % 4 == 0 else 22], 255)


def balance_painted_tones(icon: Image.Image, source: Image.Image, key: str) -> None:
    """Use the source's value planes when close palette swatches collapse.

    This changes swatches within a material only. It never changes the painted
    silhouette or inserts a new feature.
    """
    dst, src = icon.load(), source.load()

    def ranked(indices: tuple[int, ...]) -> list[tuple[int, int]]:
        colors = {COLORS[i] for i in indices}
        coords = [(x,y) for y in range(icon.height) for x in range(icon.width)
                  if dst[x,y][3] and dst[x,y][:3] in colors]
        return sorted(coords, key=lambda xy: (luminance(src[xy[0],xy[1]][:3]),
                                               -(xy[0]+xy[1])))

    if key == "expedition_parka":
        pixels = ranked(ORANGE)
        for rank,(x,y) in enumerate(pixels):
            index = ORANGE[min(2,3*rank//len(pixels))]
            dst[x,y] = (*COLORS[index],255)
    elif key == "sled_patrol_cloak":
        pixels = ranked((15,))
        for x,y in pixels[:250]:
            dst[x,y] = (*COLORS[14],255)
        for x,y in ranked((16,))[:40]:
            dst[x,y] = (*COLORS[15],255)
    elif key == "bone_amulet":
        pixels = ranked((15,))
        for x,y in pixels[:12]:
            dst[x,y] = (*COLORS[14],255)
    elif key == "expedition_machete":
        pixels = ranked((4,))
        for x,y in pixels[-60:]:
            dst[x,y] = (*COLORS[5],255)
    elif key == "antler_flute":
        pixels = ranked((14,))
        for x,y in pixels[:12]:
            dst[x,y] = (*COLORS[13],255)
    elif key == "cipher_fragment":
        pixels = ranked((1,2,3,4,5))
        for rank,(x,y) in enumerate(pixels):
            index = (1,2,3,4)[min(3,4*rank//len(pixels))]
            dst[x,y] = (*COLORS[index],255)


def spatial_quantization_cleanup(icon: Image.Image, original: Image.Image) -> Image.Image:
    """Merge singleton palette choices with neighbors, preserving alpha."""
    protected = {COLORS[i] for i in BANDS + ICE}
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
                if len(neighbors) < 4 or any(c[3] == 0 for c in neighbors) or current in neighbors:
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
    bbox = source.getchannel("A").point(lambda a: 255 if a >= 32 else 0).getbbox()
    if not bbox:
        raise ValueError(f"empty source: {key}")
    source = source.crop(bbox)
    tw, th = SIZES[kind]
    fw, fh = FIT[kind]
    if kind == "weapon":
        rw = fw
        minimum = {"icebreaker_knife": 22, "skinning_knife": 20,
                   "antler_hunter_knife": 25, "expedition_machete": 24,
                   "snowpriest_blade": 19}[key]
        rh = min(fh, max(minimum, round(source.height * rw / source.width)))
    elif kind == "armor":
        rw, rh = fw, fh
    else:
        scale = min(fw / source.width, fh / source.height)
        rw, rh = max(1, round(source.width * scale)), max(1, round(source.height * scale))
        if key == "bone_amulet":
            rw = max(rw, 17)  # wider carved face keeps three notches readable
    reduced = source.resize((rw, rh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (tw, th))
    canvas.paste(reduced, ((tw-rw)//2, (th-rh)//2))
    return quantize(canvas, key)


def isolated_pixel_percent(image: Image.Image) -> float:
    px = image.load()
    total = isolated = 0
    for y in range(image.height):
        for x in range(image.width):
            if px[x, y][3] == 0:
                continue
            total += 1
            isolated += not any(0 <= nx < image.width and 0 <= ny < image.height
                                and px[nx, ny] == px[x, y]
                                for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)))
    return round(100 * isolated / total, 2)


def make_contact() -> None:
    font = ImageFont.load_default()
    width = 482
    heights = [90 if kind == "armor" else 50 for _, _, kind in ITEMS]
    out = Image.new("RGB", (width, sum(heights)+30), "#20242b")
    draw = ImageDraw.Draw(out)
    draw.text((5,6), "E3 v3 / 1x, 40px grid / common  fine  rare", fill="#eef3f5", font=font)
    y = 30
    for (key, _, kind), height in zip(ITEMS, heights):
        icon = Image.open(ROOT / f"{key}.png").convert("RGBA")
        cw = 80 if kind != "trinket" else 40
        ch = 80 if kind == "armor" else 40
        draw.text((5,y+3), key, fill="#eef3f5", font=font)
        for j,bg in enumerate(BACKGROUNDS):
            x = 152+j*106
            draw.rectangle((x,y,x+cw-1,y+ch-1), fill=bg, outline="#7d868e", width=1)
            if cw == 80:
                draw.line((x+40,y+1,x+40,y+ch-2), fill="#34404c", width=1)
            if ch == 80:
                draw.line((x+1,y+40,x+cw-2,y+40), fill="#34404c", width=1)
            out.paste(icon,(x+(cw-icon.width)//2,y+(ch-icon.height)//2),icon)
        y += height
    out.save(ROOT / "contact_sheet.png")
    out.resize((out.width*2,out.height*2),Image.Resampling.NEAREST).save(ROOT / "contact_sheet_2x.png")


def make_silhouette() -> None:
    heights = [152 if kind == "armor" else 72 for _, _, kind in ITEMS]
    out = Image.new("RGB",(310,sum(heights)+16),"#d9d6cc")
    draw = ImageDraw.Draw(out)
    y = 8
    for (key, _, kind),height in zip(ITEMS,heights):
        icon = Image.open(ROOT / f"{key}.png").convert("RGBA")
        black = Image.new("RGB",icon.size,"#0b0c0d")
        black.putalpha(icon.getchannel("A"))
        black = black.resize((icon.width*2,icon.height*2),Image.Resampling.NEAREST)
        out.paste(black,(4,y+(height-black.height)//2),black)
        draw.text((154,y+height//2-4),key,fill="#0b0c0d")
        y += height
    out.save(ROOT / "silhouette_check.png")


def main() -> None:
    rows = []
    for key,name,kind in ITEMS:
        icon = make_icon(key,kind)
        icon.save(ROOT / f"{key}.png")
        icon.resize((icon.width*8,icon.height*8),Image.Resampling.NEAREST).save(ROOT / f"{key}_8x.png")
        has_emit = key in {"snowpriest_blade","cipher_fragment"}
        if has_emit:
            emit = Image.new("RGBA",icon.size)
            src,dst = icon.load(),emit.load()
            for y in range(icon.height):
                for x in range(icon.width):
                    if src[x,y][:3] in {COLORS[i] for i in ICE} and src[x,y][3]:
                        dst[x,y] = src[x,y]
            emit.save(ROOT / f"{key}_emit.png")
        opaque = [p[:3] for p in icon.getdata() if p[3]]
        count = Counter(opaque)
        rows.append({"id":key,"name":name,"kind":kind,"file":f"{key}.png",
                     "preview":f"{key}_8x.png","native_size":list(icon.size),
                     "has_emit":has_emit,"emit_file":f"{key}_emit.png" if has_emit else None,
                     "source":f"sources/{key}_source.png","prototype_urls":PROTOTYPES[key],
                     "isolated_pixel_percent":isolated_pixel_percent(icon),
                     "bright_pixel_percent":round(100*sum(luminance(c)>=153 for c in opaque)/len(opaque),2),
                     "largest_color_percent":round(100*max(count.values())/len(opaque),2)})
    make_contact()
    make_silhouette()
    (ROOT / "manifest.json").write_text(json.dumps({
        "batch":"E3","version":3,"source_brief":"../E3_brief_v1.md",
        "revision_brief":"../E3_revision_v3.md",
        "reference_board":"../E_reference_board.md","display_scale":1,"preview_scale":8,
        "contact_sheet":"contact_sheet.png","contact_sheet_2x":"contact_sheet_2x.png",
        "silhouette_check":"silhouette_check.png","generation_prompts":"generation_prompts.md",
        "items":rows},ensure_ascii=False,indent=2),encoding="utf-8")


if __name__ == "__main__":
    main()
