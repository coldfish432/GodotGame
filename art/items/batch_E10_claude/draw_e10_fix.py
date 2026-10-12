"""Hand-built 32×32 redraws of four E10 trinkets, after Sol's painted sources."""
import math
import numpy as np
from PIL import Image, ImageDraw

OUT = str(__import__("pathlib").Path(__file__).resolve().parent) + "/"
OUTLINE = (11, 12, 13)
STEEL = [(42, 45, 51), (74, 80, 88), (125, 134, 142), (180, 190, 196), (238, 243, 245)]
RUST = [(74, 42, 29), (125, 69, 41), (176, 106, 58), (217, 149, 96)]
COPPER = [(110, 82, 32), (168, 130, 46), (220, 184, 90)]
LEATHER = [(46, 32, 24), (90, 61, 42), (134, 96, 63), (180, 138, 94), (214, 200, 162)]
ORANGE = [(184, 90, 18), (238, 138, 36), (255, 179, 90), (255, 224, 168)]
CLOTH = [(120, 121, 117), (179, 181, 175), (217, 218, 211), (244, 241, 232)]
N = 32


def mask_of(draw_fn) -> np.ndarray:
    im = Image.new("L", (N, N), 0)
    draw_fn(ImageDraw.Draw(im))
    return np.array(im) > 127


def ellipse(cx, cy, rx, ry):
    return mask_of(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255))


def poly(points):
    return mask_of(lambda d: d.polygon(points, fill=255))


def shade(mask, ramp, light=(0.0, 0.0), spread=1.0, bias=0.0):
    """Ramp index from a top-left light: brighter toward `light` (in 0..1 of the
    mask's bounding box)."""
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    yy, xx = np.indices(mask.shape)
    u = (xx - x0) / max(1, x1 - x0 - 1)
    v = (yy - y0) / max(1, y1 - y0 - 1)
    dist = np.hypot(u - light[0], v - light[1]) / (1.4 * spread)
    level = np.clip(1.0 - dist + bias, 0, 0.999)
    idx = (level * len(ramp)).astype(int)
    out = np.zeros(mask.shape + (3,), np.uint8)
    for i, c in enumerate(ramp):
        out[(idx == i) & mask] = c
    return out


class Canvas:
    def __init__(self):
        self.rgb = np.zeros((N, N, 3), np.uint8)
        self.alpha = np.zeros((N, N), bool)
        self.emit = np.zeros((N, N), bool)

    def paint(self, mask, colours):
        """colours: an (N, N, 3) array or one colour."""
        if isinstance(colours, tuple):
            self.rgb[mask] = colours
        else:
            self.rgb[mask] = colours[mask]
        self.alpha |= mask

    def px(self, points, colour, emit=False):
        for x, y in points:
            if 0 <= x < N and 0 <= y < N:
                self.rgb[y, x] = colour
                self.alpha[y, x] = True
                if emit: self.emit[y, x] = True

    def line(self, a, b, colour, emit=False):
        (x0, y0), (x1, y1) = a, b
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        self.px([(round(x0 + (x1 - x0) * t / steps), round(y0 + (y1 - y0) * t / steps)) for t in range(steps + 1)], colour, emit)

    def outline(self):
        a = self.alpha
        inner = a.copy()
        inner[1:] &= a[:-1]; inner[:-1] &= a[1:]; inner[:, 1:] &= a[:, :-1]; inner[:, :-1] &= a[:, 1:]
        edge = a & ~inner
        self.rgb[edge] = OUTLINE
        self.emit &= ~edge

    def image(self):
        out = np.zeros((N, N, 4), np.uint8)
        out[..., :3] = self.rgb
        out[..., 3] = self.alpha * 255
        return Image.fromarray(out)

    def emit_image(self):
        out = np.zeros((N, N, 4), np.uint8)
        out[..., :3] = self.rgb
        out[..., 3] = (self.emit & self.alpha) * 255
        return Image.fromarray(out)


def coin():
    c = Canvas()
    # The edge band: the same disc shifted down-right, so the coin shows its thickness.
    face = ellipse(14.5, 13.5, 13, 11)
    back = ellipse(17, 17, 13, 11)
    band = back & ~face
    c.paint(back | face, RUST[1])
    # Reeded edge: dark ridges every other column on the band.
    yy, xx = np.indices((N, N))
    c.paint(band & ((xx + yy) % 2 == 0), RUST[0])
    c.paint(band & ((xx + yy) % 2 == 1) & (yy < 22), RUST[2])
    c.paint(face, shade(face, [RUST[1], RUST[2], RUST[2], RUST[3]], light=(0.15, 0.1), spread=1.2, bias=0.25))
    # A flat worn centre so the toothed ring frames it.
    c.paint(ellipse(15, 14, 6.5, 5) & face, RUST[2])
    c.px([(12, 15), (16, 11), (18, 14), (14, 17)], RUST[1])
    # The ring of fine teeth near the rim: alternating light and dark.
    pts = []
    for k in range(64):
        t = 2 * math.pi * k / 64
        pts.append((round(14.5 + 10.2 * math.cos(t)), round(13.5 + 8.4 * math.sin(t))))
    seen = []
    for p in pts:
        if p not in seen: seen.append(p)
    for k, p in enumerate(seen):
        c.px([p], RUST[0] if k % 2 else RUST[3])
    # Worn flat centre and a bright highlight top left.
    c.px([(8, 8), (9, 7), (10, 7), (11, 6), (12, 6)], (240, 190, 140))
    c.px([(7, 9), (8, 9)], RUST[3])
    c.px([(13, 12), (14, 12), (17, 16), (18, 16)], RUST[3])
    c.outline()
    return c


def sac():
    c = Canvas()
    body = ellipse(16, 16.5, 13, 10.5) | ellipse(11, 11, 8, 7) | ellipse(21, 22, 8, 6.5)
    # Small nubs on the stretched skin.
    body |= ellipse(29.5, 13, 1.5, 1.5) | ellipse(25, 4.5, 1.5, 1.5) | ellipse(3, 21, 1.5, 1.5)
    c.paint(body, shade(body, [RUST[0], RUST[1], RUST[1], RUST[2], ORANGE[0]], light=(0.2, 0.15), spread=1.0, bias=0.1))
    # Cracks: dark lips with hot light inside (the only glow).
    cracks = [
        [(6, 10), (10, 13), (13, 12), (17, 15), (21, 14), (25, 17)],
        [(13, 12), (12, 7), (15, 5)],
        [(17, 15), (16, 20), (19, 24), (18, 28)],
        [(10, 18), (13, 21), (11, 26)],
        [(21, 14), (23, 9), (27, 8)],
    ]
    for path in cracks:
        for a, b in zip(path, path[1:]):
            c.line((a[0], a[1] + 1), (b[0], b[1] + 1), RUST[0])
    for path in cracks:
        for a, b in zip(path, path[1:]):
            c.line((a[0], a[1] - 1), (b[0], b[1] - 1), ORANGE[1], emit=True)
            c.line(a, b, ORANGE[3], emit=True)
    c.px([(17, 15), (13, 12), (21, 14), (10, 13)], ORANGE[3], emit=True)
    # Skin sheen top left.
    c.px([(7, 7), (8, 6), (9, 6), (6, 8)], ORANGE[2])
    c.outline()
    return c


def winch_bracer():
    c = Canvas()
    tube = poly([(3, 14), (27, 12), (29, 14), (29, 25), (27, 27), (3, 28), (1, 26), (1, 16)])
    c.paint(tube, shade(tube, LEATHER[1:4], light=(0.3, 0.0), spread=0.9, bias=0.1))
    yy, xx = np.indices((N, N))
    # Open end on the left: a dark mouth.
    mouth = ellipse(3, 21, 2.5, 6.5) & tube
    c.paint(mouth, LEATHER[0])
    c.px([(4, 16), (4, 17)], LEATHER[2])
    # Two straps with steel buckles.
    for x in (9, 24):
        strap = tube & (xx >= x) & (xx <= x + 1)
        c.paint(strap, LEATHER[1])
        c.px([(x, 18), (x + 1, 18), (x, 19), (x + 1, 19)], STEEL[3])
    # A groove along the top toward the right end.
    c.line((14, 15), (27, 14), LEATHER[0])
    # The winch: a steel drum with wound cord, side plates and a crank.
    plates = poly([(11, 6), (13, 6), (13, 15), (11, 15)]) | poly([(20, 6), (22, 6), (22, 15), (20, 15)])
    drum = poly([(13, 7), (20, 7), (20, 14), (13, 14)])
    base = poly([(10, 14), (23, 14), (23, 16), (10, 16)])
    c.paint(base, STEEL[1])
    c.paint(plates, STEEL[2])
    c.px([(11, 6), (20, 6), (11, 7), (20, 7)], STEEL[4])
    c.paint(drum, COPPER[1])
    for y in (8, 10, 12):
        c.line((13, y), (20, y), COPPER[2])
    for y in (9, 11, 13):
        c.line((13, y), (20, y), COPPER[0])
    c.px([(16, 6), (16, 5), (17, 4), (18, 4), (19, 4), (24, 4), (25, 4), (25, 5)], STEEL[3])
    c.line((19, 4), (24, 4), STEEL[3])
    c.px([(26, 4), (26, 5), (27, 5), (26, 6), (27, 6)], STEEL[2])
    c.outline()
    return c


def crystal_bracer():
    c = Canvas()
    # The wrapped bracer, tilted up to the right.
    tube = poly([(2, 20), (24, 9), (29, 10), (31, 15), (31, 18), (9, 29), (4, 29), (1, 25)])
    c.paint(tube, shade(tube, CLOTH, light=(0.2, 0.1), spread=0.95, bias=0.1))
    yy, xx = np.indices((N, N))
    # Diagonal wraps.
    for k in range(-30, 40, 5):
        c.paint(tube & (np.abs((xx * 0.6 + yy) - (k + 20)) < 0.7), CLOTH[0])
    # Leather cuff at the wrist end.
    cuff = tube & (xx <= 6)
    c.paint(cuff, LEATHER[2])
    c.paint(cuff & (xx <= 3), LEATHER[1])
    # Three black originium crystals bursting through the cloth.
    for bx, by, h, w in ((9, 18, 9, 7), (16, 15, 12, 8), (24, 11, 9, 7)):
        tip = (bx + 1, by - h)
        shard = poly([(bx - w // 2, by + 1), tip, (bx + w // 2 + 1, by + 1)])
        c.paint(shard, STEEL[0])
        right = shard & (xx > tip[0])
        c.paint(right, OUTLINE)
        c.line((tip[0], tip[1] + 1), (tip[0], by - 1), STEEL[2])
        c.px([(tip[0] - 1, tip[1] + 3)], STEEL[4])
        # Orange light inside each crystal and in the torn cloth at its root.
        c.line((tip[0] + 1, tip[1] + 3), (tip[0] + 1, by), ORANGE[1], emit=True)
        c.line((tip[0] + 2, tip[1] + 5), (tip[0] + 2, by), ORANGE[2], emit=True)
        c.px([(bx - w // 2 - 1, by + 2), (bx + w // 2 + 2, by + 2)], ORANGE[1], emit=True)
        c.px([(tip[0] + 1, by - 4)], ORANGE[3], emit=True)
    c.outline()
    return c


if __name__ == "__main__":
    makers = {"mine_x18": coin, "mi_slug_volatile_7": sac, "mi_crossbow_1": winch_bracer, "mi_caster_5": crystal_bracer}
    sheet = Image.new("RGBA", (4 * 136, 2 * 136 + 40), (44, 46, 48, 255))
    for k, (name, fn) in enumerate(makers.items()):
        cv = fn()
        im = cv.image()
        im.save(OUT + name + ".png")
        if cv.emit.any(): cv.emit_image().save(OUT + name + "_emit.png")
        sheet.alpha_composite(im.resize((128, 128), Image.NEAREST), (k * 136 + 4, 4))
        sheet.alpha_composite(im, (k * 136 + 4, 2 * 136 + 4))
        a = np.array(im)[..., 3] > 0
        print(name, int(a.sum()), round(a.mean() * 100), len({tuple(p) for p in np.array(im)[..., :3][a]}))
    sheet.save(OUT + "draw.png")
