"""Turn the N1 identity designs into native pixel sprites (Claude, 2026-10-11).

Sol's N1 v1 kept the designs right but the rendering was painted, not pixel
(用户: 感觉不是很像素). Sol is off this batch (用户: 不让他出了); this reduces each
design to the game's own size and grid, the plain way the user picked
(用户 2026-10-11: 要这种的):

1. Crop the figure from `batch_N1_v1/identity_sheet.png` (3 × 6 cells of 418 px).
2. Box-downscale to its in-game height (FIGURES: people 26–34, 暴徒 is 28;
   the slug, the box and the hornbeast their own), hard alpha cut.
3. Quantize to 16 colours without dithering.
4. Drop detached crumbs under 25 px; thin parts (weapons) grow 1 px each side.
5. Outline: the body's own outermost pixels become `#0b0c0d` (1 px, inside
   the silhouette). An outer ring on top of the painting's dark edge read as
   2 px (用户 2026-10-11: 描边有点粗，细一点).
6. Stamp the Sami eye-lights by hand (用户: 萨米敌人的亮眼尽量保留): a source
   sparkle is too small to survive averaging, so each is found in the source
   and redrawn as a 3×3 light at the matching native pixel.

Outputs in `batch_N1_claude/`: native/<id>.png, identity_sheet.png (×8),
identity_sheet_with_old_cast.png, ingame_check.png.
Run: python art/field/reduce_n1.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
SRC = HERE / "batch_N1_v1" / "identity_sheet.png"
OUT = HERE / "batch_N1_claude"
CELL = 418
OUTLINE = (11, 12, 13)

# id: (col, row, native height, colours)
FIGURES = {
    # Heights vary by build (用户 2026-10-11: 体型应该有小有大), but people stay
    # close to one another (用户: 人形的之间不要差距太大): humans 26–34, 暴徒 is 28,
    # elites at the top end. Only the beasts and the box go far outside that.
    # Each is the S-facing standing height; every frame stays inside 64×64.
    "armed": (0, 0, 32, 16), "caster": (1, 0, 26, 14), "shield": (2, 0, 29, 14),
    "slug_volatile": (0, 1, 20, 12), "picket": (1, 1, 29, 14),
    "greytail": (0, 2, 28, 14), "greytail_lord": (1, 2, 31, 16), "thrower": (2, 2, 26, 14),
    "bully": (0, 3, 33, 16), "avenger": (1, 3, 30, 16), "breacher": (2, 3, 32, 16),
    "taint_husk": (0, 4, 29, 14), "distorted_caster": (1, 4, 31, 14), "shattered_champion": (2, 4, 34, 16),
    "shell_vine": (0, 5, 22, 14), "rock_hornbeast": (1, 5, 28, 16), "fallen_snowpriest": (2, 5, 30, 16),
}
REGIONS = {"mine": ["armed", "caster", "shield", "slug_volatile", "picket"],
           "city": ["greytail", "greytail_lord", "thrower", "bully", "avenger", "breacher"],
           "snow": ["taint_husk", "distorted_caster", "shattered_champion", "shell_vine", "rock_hornbeast", "fallen_snowpriest"]}


def crop(sheet: Image.Image, col: int, row: int) -> Image.Image:
    cell = sheet.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
    a = np.array(cell)
    ys, xs = np.where(a[..., 3] > 128)
    return cell.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def luminance(rgb: np.ndarray) -> np.ndarray:
    return (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255.0


def components(mask: np.ndarray) -> list[np.ndarray]:
    """4-connected components of a boolean mask, as arrays of (y, x)."""
    seen = np.zeros_like(mask)
    out = []
    h, w = mask.shape
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]: continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        pts = []
        while stack:
            y, x = stack.pop()
            pts.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        out.append(np.array(pts))
    return out


def reduce(fig: Image.Image, height: int, colours: int = 16) -> Image.Image:
    width = max(1, round(fig.width * height / fig.height))
    small = fig.resize((width, height), Image.BOX)
    a = np.array(small)
    alpha = a[..., 3] > 140
    # Drop detached crumbs (a loose chain link, a spark) under 25 px.
    for comp in components(alpha):
        if len(comp) < 25: alpha[comp[:, 0], comp[:, 1]] = False
    rgb = np.array(Image.fromarray(a[..., :3]).quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB"))
    alpha, rgb = thicken_thin(np.pad(alpha, 1), np.pad(rgb, ((1, 1), (1, 1), (0, 0))))
    canvas = np.zeros((height + 2, width + 2, 4), np.uint8)
    canvas[..., :3] = rgb
    canvas[..., 3] = np.where(alpha, 255, 0)
    canvas[edge_of(alpha)] = (*OUTLINE, 255)
    return Image.fromarray(canvas)


def _shift(a: np.ndarray, dy: int, dx: int) -> np.ndarray:
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    out[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)] = a[max(0, -dy):h + min(0, -dy), max(0, -dx):w + min(0, -dx)]
    return out


def thicken_thin(alpha: np.ndarray, rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Weapons and other thin parts grow 1 px on each side (用户 2026-10-11:
    武器都加粗), so after the 1 px outline they keep a lit core. Thin = what a
    3×3 opening removes; the grown pixels take the colour of the thin pixel
    beside them. Arrays come in padded by 1 so nothing grows off the canvas."""
    eroded = alpha.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1): eroded &= _shift(alpha, dy, dx)
    opened = eroded.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1): opened |= _shift(eroded, dy, dx)
    thin = alpha & ~opened
    alpha = alpha.copy()
    rgb = rgb.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        src = _shift(thin, dy, dx)
        grow = src & ~alpha
        rgb[grow] = _shift(rgb, dy, dx)[grow]
        alpha |= grow
    return alpha, rgb


def edge_of(alpha: np.ndarray) -> np.ndarray:
    """Body pixels with a transparent 4-neighbour: the 1 px inner outline."""
    pad = np.pad(alpha, 1)
    inside = pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    return alpha & ~inside


# Hand-designed eye-lights at native size (用户: 萨米敌人的亮眼尽量保留). Each
# entry: (how to find it in the source, stamp). Found as the centroid of the
# largest matching spot in the given part of the figure (fractions of its box).
EYES = {
    "taint_husk": [("white", (0.0, 0.5, 0.2, 0.8), "star")],
    "distorted_caster": [("white", (0.1, 0.55, 0.2, 0.8), "star")],
    "fallen_snowpriest": [("violet", (0.05, 0.45, 0.15, 0.65), "orb"), ("violet", (0.0, 0.35, 0.65, 1.0), "orb_small")],
}
STAMPS = {
    # centre, cross arms, corners (None = leave)
    "star": ((255, 255, 255), (196, 222, 240), (18, 20, 28)),
    "orb": ((255, 250, 255), (168, 120, 255), (52, 34, 92)),
    "orb_small": ((240, 225, 255), (150, 104, 246), None),
}


def find_light(src: np.ndarray, kind: str, box: tuple) -> tuple[float, float] | None:
    h, w = src.shape[:2]
    y0, y1, x0, x1 = int(box[0] * h), int(box[1] * h), int(box[2] * w), int(box[3] * w)
    part = src[y0:y1, x0:x1]
    rgb = part[..., :3].astype(int)
    opaque = part[..., 3] > 128
    if kind == "white":
        mask = opaque & (luminance(rgb.astype(float)) > 0.85)
    else:
        mask = opaque & (rgb[..., 2] > rgb[..., 1] + 40) & (rgb[..., 2] > 150)
    comps = components(mask)
    if not comps: return None
    best = max(comps, key=len)
    cy, cx = best.mean(axis=0)
    return y0 + cy, x0 + cx


def stamp(img: Image.Image, at: tuple[int, int], style: str) -> None:
    px = img.load()
    centre, arm, corner = STAMPS[style]
    y, x = at
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            yy, xx = y + dy, x + dx
            if not (0 <= yy < img.height and 0 <= xx < img.width) or px[xx, yy][3] == 0: continue
            if dy == 0 and dx == 0: px[xx, yy] = (*centre, 255)
            elif dy == 0 or dx == 0: px[xx, yy] = (*arm, 255)
            elif corner is not None and px[xx, yy][:3] != OUTLINE: px[xx, yy] = (*corner, 255)


def main() -> None:
    sheet = Image.open(SRC).convert("RGBA")
    (OUT / "native").mkdir(parents=True, exist_ok=True)
    natives = {}
    for eid, (col, row, height, colours) in FIGURES.items():
        fig = crop(sheet, col, row)
        sprite = reduce(fig, height).copy()
        src = np.array(fig)
        for kind, box, style in EYES.get(eid, []):
            hit = find_light(src, kind, box)
            if hit is None:
                print("no light found", eid, kind)
                continue
            # +1 for the transparent margin around the native body.
            ny = int(hit[0] * height / src.shape[0]) + 1
            nx = int(hit[1] * (sprite.width - 2) / src.shape[1]) + 1
            stamp(sprite, (ny, nx), style)
        sprite.save(OUT / "native" / f"{eid}.png")
        natives[eid] = sprite
    # ×8 identity sheet in the v1 layout (3 × 6 cells).
    k = 8
    grid = Image.new("RGBA", (3 * 52 * k, 6 * 52 * k), (0, 0, 0, 0))
    for eid, (col, row, _, _) in FIGURES.items():
        big = natives[eid].resize((natives[eid].width * k, natives[eid].height * k), Image.NEAREST)
        x = col * 52 * k + (52 * k - big.width) // 2
        y = row * 52 * k + (48 * k - big.height)
        grid.alpha_composite(big, (x, max(0, y)))
    grid.save(OUT / "identity_sheet.png")
    old = Image.open(HERE / "enemies_v1.png").convert("RGBA")
    both = Image.new("RGBA", (old.width + grid.width, max(old.height, grid.height)), (0, 0, 0, 0))
    both.alpha_composite(old, (0, 0))
    both.alpha_composite(grid, (old.width, 0))
    both.save(OUT / "identity_sheet_with_old_cast.png")
    # In-game check: each region's new enemies beside the old thug, 1:1 and ×6, on its ground.
    thug = Image.open(HERE / "enemy_dir_thug_64.png").convert("RGBA").crop((0, 0, 64, 64))
    a = np.array(thug)
    ys, xs = np.where(a[..., 3] > 0)
    thug = thug.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    grounds = {"mine": "background_mine_v1.png", "city": "background_city_v1.png", "snow": "background_snow_v1.png"}
    rows = []
    for region, ids in REGIONS.items():
        sprites = [thug] + [natives[i] for i in ids]
        w1 = sum(s.width + 4 for s in sprites) + 4
        h1 = 40
        ground = Image.open(HERE / grounds[region]).convert("RGBA")
        tile = ground.resize((ground.width // 6, ground.height // 6), Image.BOX)
        strip = Image.new("RGBA", (w1, h1))
        for x in range(0, w1, tile.width):
            for y in range(0, h1, tile.height): strip.alpha_composite(tile, (x, y))
        x = 4
        for s in sprites:
            strip.alpha_composite(s, (x, h1 - s.height - 3))
            x += s.width + 4
        rows.append(strip)
    k = 6
    width = max(r.width for r in rows)
    check = Image.new("RGBA", (width * (k + 1) + 20, sum(r.height for r in rows) * k + 10 * len(rows)), (20, 20, 22, 255))
    y = 0
    for r in rows:
        check.alpha_composite(r, (0, y))
        check.alpha_composite(r.resize((r.width * k, r.height * k), Image.NEAREST), (width + 20, y))
        y += r.height * k + 10
    check.save(OUT / "ingame_check.png")
    print("wrote", len(natives), "sprites to", OUT)


if __name__ == "__main__":
    main()
