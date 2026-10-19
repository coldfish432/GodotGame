"""The sand table's hologram of Terra (基地建模改造案_v1 §八): drawn from
art/kit/textures/terra_map.json into art/kit/textures/base_terra_map.png. The
image is added light (black shows nothing): the sea a faint dot grid, the land
a blue fill with scan hatching, the coast bright cyan, the nations' borders
dim lines between their centres, mountains as chevrons, deserts and the
icefield in their own texture, the fog to the north a soft haze. No lettering.

    python tools/blender/base/make_terra_map.py
"""
import json
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(__file__)
TEX = os.path.join(HERE, "..", "..", "..", "art", "kit", "textures")
W = 1024


def main():
    data = json.load(open(os.path.join(TEX, "terra_map.json"), encoding="utf-8"))
    x0, y0, x1, y1 = data["crop"]
    aspect = data["aspect"]
    H = int(round(W * (y1 - y0) / ((x1 - x0) * aspect)))
    S = 2  # drawn at twice the size, then reduced, for clean lines

    def px(p):
        return ((p[0] - x0) / (x1 - x0) * W * S, (p[1] - y0) / (y1 - y0) * H * S)

    land = Image.new("L", (W * S, H * S), 0)
    dl = ImageDraw.Draw(land)
    dl.polygon([px(p) for p in data["coast"]], fill=255)
    for sea in data["seas"]:
        dl.polygon([px(p) for p in sea], fill=0)
    for (lx, ly, r) in data["lakes"]:
        cx, cy = px((lx, ly))
        rr = r / (x1 - x0) * W * S
        dl.ellipse([cx - rr, cy - rr * 0.7, cx + rr, cy + rr * 0.7], fill=0)
    # islands in the seas and lakes (拉特兰, 汐斯塔)
    for (ix_, iy_, r) in data.get("islands", []):
        cx, cy = px((ix_, iy_))
        rr = r / (x1 - x0) * W * S
        dl.ellipse([cx - rr, cy - rr * 0.8, cx + rr, cy + rr * 0.8], fill=255)

    # The nations' land (borders are drawn only here); the wilds beyond it
    # (北地, 西部荒地, 焚风热土) are unclaimed land running off the table.
    nation = land.copy()
    wild = Image.new("L", (W * S, H * S), 0)
    dw = ImageDraw.Draw(wild)
    wilds = data.get("wilds", {})
    for k, (n, wd) in enumerate(wilds.items()):
        dw.polygon([px(p) for p in wd["poly"]], fill=k + 1)
    wp = wild.load()
    np_ = nation.load()
    for y in range(H * S):
        for x in range(W * S):
            if wp[x, y] and not np_[x, y]:
                land.putpixel((x, y), 255)
            elif wp[x, y]:
                wild.putpixel((x, y), 0)
    wild_kind = [wd for wd in wilds.values()]

    out =Image.new("RGB", (W * S, H * S), (0, 0, 0))
    po = out.load()
    lp = land.load()
    random.seed(5)
    # Nation of each land pixel (nearest centre, aspect-corrected) for borders.
    names = list(data["nations"].keys())
    centres = [px(data["nations"][n]) for n in names]
    owner = {}
    step = 4
    for y in range(0, H * S, step):
        for x in range(0, W * S, step):
            if np_[x, y]:
                best, bd = 0, 1e18
                for k, (cx, cy) in enumerate(centres):
                    dd = (x - cx) ** 2 + (y - cy) ** 2
                    if dd < bd:
                        best, bd = k, dd
                owner[(x, y)] = best
    for y in range(H * S):
        for x in range(W * S):
            if wp[x, y]:
                wd = wild_kind[wp[x, y] - 1]
                # dimmer than the nations, fading towards the table's edge
                edge_fade = min(1.0, min(x, y, W * S - 1 - x, H * S - 1 - y) / (40.0 * S))
                if wd.get("ice"):
                    mark = (x * 3 + y) % 9 == 0
                    c = (60, 120, 150) if mark else (14, 36, 62)
                elif wd.get("dunes"):
                    mark = int(y + 6 * math.sin(x * 0.05)) % 10 == 0
                    c = (70, 110, 130) if mark else (16, 34, 56)
                else:
                    mark = (x // 3 + y // 3) % 11 == 0
                    c = (50, 90, 120) if mark else (14, 32, 54)
                po[x, y] = tuple(int(v * (0.35 + 0.65 * edge_fade)) for v in c)
            elif lp[x, y]:
                hatch = 1.0 if (x + y) // 3 % 4 == 0 else 0.0
                po[x, y] = (int(14 + 18 * hatch), int(46 + 30 * hatch), int(84 + 40 * hatch))
            elif x % 16 == 0 and y % 16 == 0:
                po[x, y] = (20, 56, 90)
    # borders: where the owner changes between neighbouring cells
    d = ImageDraw.Draw(out)
    for (x, y), k in owner.items():
        for (nx, ny) in ((x + step, y), (x, y + step)):
            if owner.get((nx, ny), k) != k:
                d.rectangle([x, y, x + 1, y + 1], fill=(60, 140, 190))
    # icefield and deserts as lighter textures, the fog as haze
    for (ax, ay, bx, by) in data["ice"]:
        a, b = px((ax, ay)), px((bx, by))
        for y in range(int(a[1]), int(b[1])):
            for x in range(int(a[0]), int(b[0])):
                if 0 <= x < W * S and 0 <= y < H * S and np_[x, y] and (x * 3 + y) % 7 == 0:
                    po[x, y] = (150, 210, 240)
    for (cx, cy, w, h) in data["deserts"]:
        a, b = px((cx - w / 2, cy - h / 2)), px((cx + w / 2, cy + h / 2))
        for y in range(int(a[1]), int(b[1])):
            for x in range(int(a[0]), int(b[0])):
                if 0 <= x < W * S and 0 <= y < H * S and lp[x, y] and (x // 2 + y // 2) % 5 == 0:
                    po[x, y] = (70, 120, 150)
    for chain in data["mountains"]:
        for p in chain:
            cx, cy = px(p)
            r = 10 * S
            d.line([(cx - r, cy + r * 0.6), (cx, cy - r * 0.6), (cx + r, cy + r * 0.6)], fill=(170, 230, 255), width=2 * S)
    # coast and inner seas' shores, bright
    # the coast, bright; the wilds' far edges are cut by the table, not shores
    edge = land.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 40 else 0)
    ep = edge.load()
    for y in range(H * S):
        for x in range(W * S):
            if ep[x, y] and 2 * S < x < W * S - 2 * S and 2 * S < y < H * S - 2 * S:
                po[x, y] = (110, 220, 255)
    # nation centres as small rings
    for (cx, cy) in centres:
        d.ellipse([cx - 4 * S, cy - 4 * S, cx + 4 * S, cy + 4 * S], outline=(120, 210, 255), width=S)
    # fog to the north, fading
    fy = px((0, data["fog"][0][3]))[1]
    for y in range(0, int(min(fy, H * S))):
        t = 1.0 - y / max(fy, 1)
        for x in range(0, W * S, 2):
            if random.random() < 0.25 * t:
                r, g, b = po[x, y]
                po[x, y] = (min(255, r + 25), min(255, g + 40), min(255, b + 55))
    img = out.resize((W, H), Image.LANCZOS)
    path = os.path.join(TEX, "base_terra_map.png")
    img.save(path)
    print("wrote", os.path.normpath(path), img.size)


if __name__ == "__main__":
    main()
