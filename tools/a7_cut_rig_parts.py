"""A7 Step 4: cut Lappland's wave-release cutout-rig parts from her combat sheet.

Source: godot_assets/lappland_combat_64.png (read only, never written).
Cell:   row "west" (row index 2 of COMBAT_ROWS, lappland_animator_3d.gd:39),
        column 10 (first column of ACTIONS.wave = [10, 3], :43), 64x64 px.
Output: animations/lappland_rig/{body,blade_back,blade_front}.png, each a
        64x64 RGBA image in the cell's own coordinates: every pixel is either
        copied unchanged from the cell or fully transparent. No recolouring,
        no palette or colour-count change: parts are cut by masks only.

Stdlib only (zlib + struct), so it runs under `python -I`.
Run from the project root:  python -I tools/a7_cut_rig_parts.py
It also prints the cell as text (one char per pixel) and each part's
bounding box, so the masks below can be reviewed against the sheet.
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "godot_assets", "lappland_combat_64.png")
OUT_DIR = os.path.join(ROOT, "animations", "lappland_rig")
CELL = 64
ROW = 2      # "west"
COLUMN = 10  # ACTIONS.wave[0]

# Masks in cell coordinates: lists of (x0, y0, x1, y1), half-open.
# A pixel goes to the first part whose mask contains it; the rest is body.
# Facing west, the front blade is the one held out ahead of her (left of the
# body, tip at (15, 32), hilt at her front hand near (24, 37)); the back blade
# trails behind her (right, hilt at her rear hand near (42, 39), tip at
# (55, 43)). Read from the text dump this script prints.
BLADE_FRONT = [(15, 32, 24, 38)]
BLADE_BACK = [(45, 40, 56, 44), (42, 39, 46, 40)]
# Arm pivots (cell coordinates) for the rig scene: the hands holding the hilts.
PIVOT_FRONT = (24, 37)
PIVOT_BACK = (42, 39)


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos = 8
    idat = b""
    palette = None
    trns = None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, depth, ctype, _comp, _filt, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
    if depth != 8 or interlace != 0 or ctype not in (2, 3, 6):
        raise ValueError("unsupported PNG: depth %d type %d interlace %d" % (depth, ctype, interlace))
    bpp = {2: 3, 3: 1, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows = []
    prev = bytearray(stride)
    i = 0
    for _y in range(h):
        ftype = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if ftype == 1:
                line[x] = (line[x] + a) & 255
            elif ftype == 2:
                line[x] = (line[x] + b) & 255
            elif ftype == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif ftype == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line)
        prev = line
    pixels = []
    for line in rows:
        out = []
        for x in range(w):
            if ctype == 6:
                out.append(tuple(line[x * 4:x * 4 + 4]))
            elif ctype == 2:
                out.append(tuple(line[x * 3:x * 3 + 3]) + (255,))
            else:
                idx = line[x]
                alpha = trns[idx] if trns is not None and idx < len(trns) else 255
                out.append(palette[idx] + (alpha,))
        pixels.append(out)
    return w, h, pixels


def write_png(path, pixels):
    h = len(pixels)
    w = len(pixels[0])
    raw = bytearray()
    for line in pixels:
        raw.append(0)
        for p in line:
            raw.extend(p)
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def inside(masks, x, y):
    return any(x0 <= x < x1 and y0 <= y < y1 for (x0, y0, x1, y1) in masks)


def glyph(p):
    r, g, b, a = p
    if a == 0:
        return "."
    lum = (r * 299 + g * 587 + b * 114) // 1000
    if lum >= 200:
        return "W"
    if lum >= 140:
        return "o"
    if lum >= 80:
        return "+"
    return "#"


def main():
    w, h, sheet = read_png(SHEET)
    print("sheet %dx%d" % (w, h))
    ox, oy = COLUMN * CELL, ROW * CELL
    cell = [sheet[oy + y][ox:ox + CELL] for y in range(CELL)]
    print("cell row %d col %d at (%d, %d); x tens/units:" % (ROW, COLUMN, ox, oy))
    print("    " + "".join(str(x // 10) for x in range(CELL)))
    print("    " + "".join(str(x % 10) for x in range(CELL)))
    for y in range(CELL):
        print("%3d " % y + "".join(glyph(p) for p in cell[y]))
    clear = (0, 0, 0, 0)
    parts = {"blade_front": BLADE_FRONT, "blade_back": BLADE_BACK}
    images = {name: [[clear] * CELL for _ in range(CELL)] for name in list(parts) + ["body"]}
    for y in range(CELL):
        for x in range(CELL):
            p = cell[y][x]
            if p[3] == 0:
                continue
            target = "body"
            for name, masks in parts.items():
                if inside(masks, x, y):
                    target = name
                    break
            images[target][y][x] = p
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for name, img in images.items():
        xs = [x for y in range(CELL) for x in range(CELL) if img[y][x][3] > 0]
        ys = [y for y in range(CELL) for x in range(CELL) if img[y][x][3] > 0]
        count = len(xs)
        total += count
        box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1) if xs else None
        write_png(os.path.join(OUT_DIR, name + ".png"), img)
        print("%s.png: %d opaque px, bbox %s" % (name, count, box))
    print("pivots: front %s, back %s" % (PIVOT_FRONT, PIVOT_BACK))
    source = sum(1 for y in range(CELL) for x in range(CELL) if cell[y][x][3] > 0)
    print("pixels: cell %d, parts %d (%s)" % (source, total, "match" if source == total else "MISMATCH"))
    return 0 if source == total else 1


if __name__ == "__main__":
    sys.exit(main())
