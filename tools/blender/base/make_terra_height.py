"""Relief of Terra for the 3D hologram sand table (基地建模改造案_v1 §九; 用户
2026-10-18: 根据各地区的地形建模). From art/kit/textures/terra_map.json:

- art/kit/textures/base_terra_height.png  heightmap over the table's crop
- the relief as hexagonal columns, like the PRTS map of Terra (用户
  2026-10-18 给出萌娘百科「泰拉大陆」的官方图), in base_terra_features.json:
  [x, height, z, u, v] in the hall's local axes (x west, z north, metres on
  the table, centred) and the map coordinates of the column
- art/kit/textures/base_terra_features.json  where the forests' trees, the
                                          capitals and the mobile cities stand,
                                          and each place's height (TerraMap)

Each nation's land takes its own character (terrain_map.json "terrain"):
tundra and grassland flat, hills rolling at their own scale, Kjerag and
Minos high and broken, the Victorian basin low; deserts rippled with dunes,
Columbia's wilds stepped into mesas, Rim Billiton pitted with mines. Mountain
chains are ridges, the Leithanien volcano a cone, the icefield a plateau;
rivers cut their valleys. Forests become trees, scattered by their share.

    python tools/blender/base/make_terra_height.py
"""
import json
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..", "..", "..")
TEX = os.path.join(ROOT, "art", "kit", "textures")
W = 560            # heightmap columns
MESH_STEP = 2      # one mesh vertex every MESH_STEP heightmap pixels
TABLE_W = 31.0     # metres the map spans across the table (用户: 表现力不够就扩大地图面积)
HEX = 0.18         # hexagonal column radius on the table (metres)
PEAK = 1.4         # a mountain peak's height above its column (metres)
SEA_TOP = 0.05     # the sea's columns: this tall off the coast,
SEA_DROP = 0.035   # this much lower far out
TOP = 3.0          # metres for height 1.0 (exaggerated, so the relief reads from above)


def blur(a, r):
    img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def noise(shape, scale, amp, seed):
    h, w = shape
    g = np.random.default_rng(seed).random((max(2, h // scale + 2), max(2, w // scale + 2))).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return (np.asarray(img, np.float32) / 255.0 - 0.5) * 2 * amp


def main():
    d = json.load(open(os.path.join(TEX, "terra_map.json"), encoding="utf-8"))
    x0, y0, x1, y1 = d["crop"]
    H = int(round(W * (y1 - y0) / ((x1 - x0) * d["aspect"])))
    table_h = TABLE_W * H / W

    def px(p):
        return ((p[0] - x0) / (x1 - x0) * W, (p[1] - y0) / (y1 - y0) * H)

    mask = Image.new("L", (W, H), 0)
    dm = ImageDraw.Draw(mask)
    dm.polygon([px(p) for p in d["coast"]], fill=255)
    for sea in d["seas"]:
        dm.polygon([px(p) for p in sea], fill=0)
    for (lx, ly, r) in d["lakes"]:
        cx, cy = px((lx, ly))
        rr = r / (x1 - x0) * W
        dm.ellipse([cx - rr, cy - rr * 0.7, cx + rr, cy + rr * 0.7], fill=0)
    # islands in the seas and lakes (拉特兰, 汐斯塔)
    for (ix_, iy_, r) in d.get("islands", []):
        cx, cy = px((ix_, iy_))
        rr = r / (x1 - x0) * W
        dm.ellipse([cx - rr, cy - rr * 0.8, cx + rr, cy + rr * 0.8], fill=255)
    nation_land = np.asarray(mask, np.float32) / 255.0
    # The unclaimed wilds beyond the nations (萌娘百科：北端北地、西部荒地、
    # 南端焚风热土), running off the table's edges.
    wilds = d.get("wilds", {})
    wmask = Image.new("L", (W, H), 0)
    dw = ImageDraw.Draw(wmask)
    for k, wd in enumerate(wilds.values()):
        dw.polygon([px(p) for p in wd["poly"]], fill=k + 1)
    wild_id = np.asarray(wmask, np.int32)
    wild_id = np.where(nation_land > 0.5, 0, wild_id)
    land = np.maximum(nation_land, (wild_id > 0).astype(np.float32))
    inland = blur(land, 9)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)

    # Which nation each pixel belongs to (nearest centre, as on the 2D map);
    # the wilds are their own profiles after the nations'.
    nations = list(d["terrain"].keys())
    names = nations + list(wilds.keys())
    profiles = dict(d["terrain"], **wilds)
    centres = np.array([px(d["nations"][n]) for n in nations], np.float32)
    dist = np.stack([(xx - cx) ** 2 + (yy - cy) ** 2 for cx, cy in centres])
    owner = np.argmin(dist, axis=0)
    owner = np.where(wild_id > 0, len(nations) + wild_id - 1, owner)

    # Per-nation parameters, softened across borders.
    def field(key, default=0.0):
        a = np.zeros((H, W), np.float32)
        for k, n in enumerate(names):
            a[owner == k] = float(profiles[n].get(key, default))
        return blur(a, 5) if key in ("base", "hills") else a

    base = field("base")
    hills_amp = field("hills")
    h = np.zeros((H, W), np.float32)
    # hills at each nation's own scale
    for k, n in enumerate(names):
        t = profiles[n]
        here = blur((owner == k).astype(np.float32), 4)
        h += here * noise((H, W), int(t.get("scale", 10)), 1.0, 100 + k) * float(t.get("hills", 0.05))
    h += base * (0.4 + 0.6 * inland)
    # Columbia's mesas: hills stepped into flat tops
    for k, n in enumerate(names):
        t = profiles[n]
        here = owner == k
        if t.get("mesas"):
            m = np.maximum(noise((H, W), 9, 1.0, 300 + k), 0)
            h = np.where(here, h + np.floor(m * 4) / 4 * 0.12, h)
        if t.get("dunes"):
            west = here & (xx < px((t.get("east_forest", 1.0), 0))[0])
            h = np.where(west, h + 0.025 * np.sin(xx * 0.8 + np.sin(yy * 0.25) * 3.0), h)
        if t.get("craters"):
            rng = np.random.default_rng(400 + k)
            ys, xs = np.nonzero(here)
            for _ in range(8):
                i = rng.integers(len(xs))
                r = np.hypot(xx - xs[i], yy - ys[i])
                h -= np.clip(1 - r / 4.0, 0, 1) * 0.06
    for (cx, cy, w, hh) in d["deserts"]:
        a, b = px((cx - w / 2, cy - hh / 2)), px((cx + w / 2, cy + hh / 2))
        inside = ((xx > a[0]) & (xx < b[0]) & (yy > a[1]) & (yy < b[1])).astype(np.float32)
        h += inside * 0.03 * np.sin(xx * 0.9 + np.sin(yy * 0.3) * 3)
    # mountain chains as ridges
    for c, chain in enumerate(d["mountains"]):
        pts = [px(p) for p in chain]
        ridge = np.zeros((H, W), np.float32)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            vx, vy = bx - ax, by - ay
            L2 = vx * vx + vy * vy + 1e-6
            t = np.clip(((xx - ax) * vx + (yy - ay) * vy) / L2, 0, 1)
            dd = np.hypot(xx - (ax + t * vx), yy - (ay + t * vy))
            ridge = np.maximum(ridge, np.exp(-(dd / 8.0) ** 2))
        peaks = 0.6 + noise((H, W), 6, 0.35, 7 + c)
        h += ridge * np.clip(peaks, 0.2, 1.1) * 0.7
    for (vx, vy) in d.get("volcanoes", []):
        cx, cy = px((vx, vy))
        r = np.hypot(xx - cx, yy - cy)
        h += np.clip(1 - r / 13, 0, 1) ** 1.5 * 0.55 - np.clip(1 - r / 3, 0, 1) * 0.22
    for (ax, ay, bx, by) in d["ice"]:
        a, b = px((ax, ay)), px((bx, by))
        inside = blur(((xx > a[0]) & (xx < b[0]) & (yy > a[1]) & (yy < b[1])).astype(np.float32), 6)
        h += inside * (0.16 + noise((H, W), 6, 0.02, 21))
    # rivers cut valleys
    river = np.zeros((H, W), np.float32)
    for line in d.get("rivers", []):
        pts = [px(p) for p in line]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            vx, vy = bx - ax, by - ay
            L2 = vx * vx + vy * vy + 1e-6
            t = np.clip(((xx - ax) * vx + (yy - ay) * vy) / L2, 0, 1)
            dd = np.hypot(xx - (ax + t * vx), yy - (ay + t * vy))
            river = np.maximum(river, np.exp(-(dd / 2.2) ** 2))
    h = h * (1 - 0.7 * river)
    # rifts cut deep (东国常暗裂谷)
    for line in d.get("rifts", []):
        pts = [px(p) for p in line]
        cut = np.zeros((H, W), np.float32)
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            vx, vy = bx - ax, by - ay
            L2 = vx * vx + vy * vy + 1e-6
            t = np.clip(((xx - ax) * vx + (yy - ay) * vy) / L2, 0, 1)
            dd = np.hypot(xx - (ax + t * vx), yy - (ay + t * vy))
            cut = np.maximum(cut, np.exp(-(dd / 1.6) ** 2))
        h = h * (1 - 0.9 * cut)
    # the wilds: the north frozen into an ice sheet; all of them sink towards
    # the table's edge, as if running on beyond it
    for k, n in enumerate(names):
        if profiles[n].get("ice"):
            here = blur((owner == k).astype(np.float32), 5)
            h += here * (0.1 + noise((H, W), 5, 0.03, 31))
    edge = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy))
    h = np.where(wild_id > 0, h * np.clip(0.35 + edge / 30.0, 0, 1), h)
    h = np.where(land > 0.5, np.maximum(h, 0.03), 0.0)
    h = np.clip(h, 0, 1).astype(np.float32)
    Image.fromarray((h * 65535).astype(np.uint16)).save(os.path.join(TEX, "base_terra_height.png"))

    # --- the relief as hexagonal columns (the PRTS sand table's look) ----------
    def local(ix, iy):
        u, v = ix / (W - 1), iy / (H - 1)
        # x west (layout east is world -x), z north
        return (float(-(u - 0.5) * TABLE_W), float(h[iy, ix] * TOP), float((0.5 - v) * table_h), u, v)

    hexes = []
    # The sea as its own low columns (用户 2026-10-18: 海也建模): shallow
    # shelves along the coasts, deeper out; [x, height, z, u, v, depth 0–1].
    shelf = blur(land, 7)
    sea = []
    cells = {}                            # (row, col) -> (x, top, z, region)
    pitch = HEX * math.sqrt(3.0)          # centre to centre along a row
    row_h = HEX * 1.5                     # pointy-top rows
    zrow = 0
    zz = -table_h / 2 + HEX
    while zz < table_h / 2:
        xx0 = -TABLE_W / 2 + HEX + (pitch / 2 if zrow % 2 else 0.0)
        xw = xx0
        col = 0
        while xw < TABLE_W / 2:
            u = 0.5 - xw / TABLE_W
            v = 0.5 - zz / table_h
            ix = int(np.clip(round(u * (W - 1)), 0, W - 1))
            iy = int(np.clip(round(v * (H - 1)), 0, H - 1))
            if land[iy, ix] > 0.5:
                hexes.append([round(xw, 3), round(float(h[iy, ix] * TOP), 3), round(zz, 3), round(u, 4), round(v, 4)])
                cells[(zrow, col)] = (xw, float(h[iy, ix] * TOP), zz, int(owner[iy, ix]))
            else:
                depth = float(np.clip(1.0 - shelf[iy, ix] * 2.2, 0, 1))
                sea.append([round(xw, 3), round(SEA_TOP - SEA_DROP * depth, 3), round(zz, 3), round(u, 4), round(v, 4), round(depth, 3)])
            xw += pitch
            col += 1
        zz += row_h
        zrow += 1

    # Borders between the regions (用户 2026-10-18: 用分割线分出各区域): the
    # shared edge of every pair of neighbouring land columns owned by different
    # regions, [x, top, z, along_x, along_z, kind]; kind 1 where a nation
    # meets the unclaimed wilds.
    borders = []
    wild_from = len(nations)
    for (r, c), (ax, ah, az, ao) in cells.items():
        odd = r % 2
        for (nr, nc) in ((r, c + 1), (r + 1, c - 1 + odd), (r + 1, c + odd)):
            other = cells.get((nr, nc))
            if other is None or other[3] == ao:
                continue
            bx, bh, bz, bo = other
            dx, dz = bx - ax, bz - az
            n = math.hypot(dx, dz)
            kind = 1 if (ao >= wild_from) != (bo >= wild_from) else 0
            if ao >= wild_from and bo >= wild_from:
                kind = 1
            borders.append([round((ax + bx) / 2, 3), round(max(ah, bh), 3), round((az + bz) / 2, 3),
                            round(-dz / n, 4), round(dx / n, 4), kind])

    # --- each region's own landscape (用户 2026-10-18: 根据各地区自然环境各自建模) --
    rng = np.random.default_rng(9)
    F = lambda a: [round(float(v), 3) for v in a]

    def scatter(mask, per_px, cap=10 ** 6):
        ys, xs = np.nonzero(mask)
        out = []
        if len(xs) == 0:
            return out
        for _ in range(min(cap, int(len(xs) * per_px))):
            k = rng.integers(len(xs))
            out.append((int(xs[k]), int(ys[k])))
        return out

    on_land = (land > 0.5) & (river < 0.3)
    forests = {"conifer": [], "broadleaf": [], "rainforest": []}
    for k, n in enumerate(names):
        t = profiles[n]
        kind = t.get("forest_kind", "broadleaf")
        here = (owner == k) & on_land & (h < 0.45)
        east = t.get("east_forest")
        if east:
            ex = px((east, 0))[0]
            for (ix, iy) in scatter(here & (xx > ex), 1 / 30):
                forests["rainforest"].append(F(local(ix, iy)[:3]))
            here = here & (xx <= ex)
        if t.get("west_forest"):  # 雷姆必拓：西部有森林，大部分国土荒漠化
            here = here & (xx < px((t["west_forest"], 0))[0])
        for (ix, iy) in scatter(here, float(t.get("forest", 0.0)) / 40):
            forests[kind].append(F(local(ix, iy)[:3]))
    # peaks along every chain; snow on the high northern and Kjerag ones
    peaks = []
    for c, chain in enumerate(d["mountains"]):
        pts = [px(p) for p in chain]
        snowy = c in d.get("snowy_chains", [])
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            steps = max(2, int(math.hypot(bx - ax, by - ay) / 5))
            for s_ in range(steps):
                t_ = s_ / steps
                ix = int(np.clip(ax + (bx - ax) * t_ + rng.normal(0, 2.5), 0, W - 1))
                iy = int(np.clip(ay + (by - ay) * t_ + rng.normal(0, 2.5), 0, H - 1))
                if land[iy, ix] < 0.5:
                    continue
                x_, y_, z_, _, _ = local(ix, iy)
                peaks.append(F([x_, y_, z_, rng.uniform(0.6, 1.3) * PEAK, 1 if snowy else 0]))
    for k, n in enumerate(names):
        sp = profiles[n].get("spires")
        if sp:
            for (ix, iy) in scatter((owner == k) & on_land, sp / 400):
                x_, y_, z_, _, _ = local(ix, iy)
                peaks.append(F([x_, y_, z_, rng.uniform(0.25, 0.6) * PEAK, 1]))
    # dunes: crescent ridges across the deserts and the dune nations
    dune_mask = np.zeros((H, W), bool)
    for (cx, cy, w, hh) in d["deserts"]:
        a, b = px((cx - w / 2, cy - hh / 2)), px((cx + w / 2, cy + hh / 2))
        dune_mask |= (xx > a[0]) & (xx < b[0]) & (yy > a[1]) & (yy < b[1])
    for k, n in enumerate(names):
        t = profiles[n]
        if t.get("dunes"):
            m = owner == k
            if t.get("east_forest"):
                m &= xx <= px((t["east_forest"], 0))[0]
            dune_mask |= m
    dunes = [F(list(local(ix, iy)[:3]) + [rng.uniform(-0.4, 0.4)]) for (ix, iy) in scatter(dune_mask & on_land, 1 / 55)]
    # mesas: flat-topped buttes in the wild west
    mesas = []
    for k, n in enumerate(names):
        if profiles[n].get("mesas"):
            for (ix, iy) in scatter((owner == k) & on_land, 1 / 160):
                mesas.append(F(list(local(ix, iy)[:3]) + [rng.uniform(0.25, 0.55), rng.uniform(0.3, 0.6)]))
    rivers = []
    for line in d.get("rivers", []):
        pts = []
        for p in line:
            ix = int(np.clip(round(px(p)[0]), 0, W - 1))
            iy = int(np.clip(round(px(p)[1]), 0, H - 1))
            pts.append(F(local(ix, iy)[:3]))
        rivers.append(pts)
    volcanoes = []
    for p in d.get("volcanoes", []):
        ix = int(np.clip(round(px(p)[0]), 0, W - 1))
        iy = int(np.clip(round(px(p)[1]), 0, H - 1))
        volcanoes.append(F(local(ix, iy)[:3]))
    trees = sum(forests.values(), [])
    # crystal fields (雷姆必拓南部：晶体遍布的沿海无人区)
    crystals = []
    for p in d.get("crystals", []):
        cx_, cy_ = px(p)
        for _ in range(7):
            ix = int(np.clip(cx_ + rng.normal(0, 4), 0, W - 1))
            iy = int(np.clip(cy_ + rng.normal(0, 4), 0, H - 1))
            if land[iy, ix] > 0.5:
                crystals.append(F(list(local(ix, iy)[:3]) + [rng.uniform(0.25, 0.6), rng.uniform(-0.5, 0.5)]))

    def at(p):
        ix = int(np.clip(round(px(p)[0]), 0, W - 1))
        iy = int(np.clip(round(px(p)[1]), 0, H - 1))
        return [round(v, 4) for v in local(ix, iy)[:3]]

    features = {
        "table": [TABLE_W, round(table_h, 4)], "top": TOP, "hex": HEX,
        "hexes": hexes, "sea": sea, "borders": borders,
        "forests": forests, "peaks": peaks, "dunes": dunes, "mesas": mesas,
        "rivers": rivers, "volcanoes": volcanoes, "crystals": crystals,
        "capitals": {n: at(p) for n, p in d["capitals"].items()},
        "mobile_cities": {n: at(p) for n, p in d["mobile_cities"].items()},
        "places": {n: at(p) for n, p in d["nations"].items()},
    }
    json.dump(features, open(os.path.join(TEX, "base_terra_features.json"), "w", encoding="utf-8"), ensure_ascii=False)
    prev = Image.fromarray((h * 255).astype(np.uint8))
    prev.save(os.path.join(os.environ.get("TEMP", "."), "terra_height_preview.png"))
    print("relief", len(hexes), "hex;", len(sea), "sea;", len(borders), "border edges;", {k: len(v) for k, v in forests.items()}, "peaks", len(peaks), "dunes", len(dunes),
          "mesas", len(mesas), "table", TABLE_W, "x", round(table_h, 2))


if __name__ == "__main__":
    main()
