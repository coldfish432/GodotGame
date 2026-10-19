"""Pure palette and pixel metrics helpers derived from the prior painted-asset processor."""
import numpy as np
from PIL import Image

E6_PALETTE = '0b0c0d 15181a 1f2427 2c3236 3d4448 566064 737d82 98a2a6 c3cacc a9b2b3 d4dadb eef2f2 385878 5888a8 78b8e8 6e2f14 b8531f e0782a 0f3a40 2a8a92 5fd0d8 b8f4f6 6b5a1e b89a2a f4d73c'.split()

GROUPS = {k: set(v.split()) for k, v in dict(blue='385878 5888a8 78b8e8', orange='6e2f14 b8531f e0782a', cyan='0f3a40 2a8a92 5fd0d8 b8f4f6', yellow='6b5a1e b89a2a f4d73c').items()}

def rgb(h):
    return tuple(bytes.fromhex(h.lstrip('#')))

def map_palette(a, mask, palette):
    pal = np.array([rgb(h) for h in palette], dtype=np.int32)
    p = a[:, :, :3].astype(np.int32)
    dist = ((p[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(axis=3)
    out = pal[dist.argmin(axis=2)].astype('uint8')
    colors, counts = np.unique(out[mask], axis=0, return_counts=True)
    if len(colors) > 23:
        keep = colors[np.argsort(-counts)[:23]]
        ix = ((out[:, :, None, :].astype(int) - keep[None, None, :, :]) ** 2).sum(3).argmin(2)
        out = keep[ix]
    return out

def rim(mask):
    er = mask.copy()
    for dy, dx in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        n = np.roll(mask, (dy, dx), (0, 1))
        if dy == 1:
            n[0] = False
        if dy == -1:
            n[-1] = False
        if dx == 1:
            n[:, 0] = False
        if dx == -1:
            n[:, -1] = False
        er &= n
    return mask & ~er

def smooth(a, mask):
    border = rim(mask)
    for _ in range(4):
        b = a.copy()
        for y, x in zip(*np.where(mask)):
            neighbors = [tuple(a[y + dy, x + dx]) for dy, dx in [(1, 0), (-1, 0), (0, 1), (0, -1)] if 0 <= y + dy < a.shape[0] and 0 <= x + dx < a.shape[1] and mask[y + dy, x + dx]]
            if not neighbors:
                continue
            if tuple(a[y, x]) not in neighbors:
                c = min(neighbors, key=lambda n: np.linalg.norm(a[y, x].astype(float) - n) - 12 * neighbors.count(n))
                if np.linalg.norm(a[y, x].astype(float) - c) < 145:
                    b[y, x] = c
        a = b
    return a

def metrics(im):
    a = np.array(im)
    mask = a[:, :, 3] > 0
    n = int(mask.sum())
    p = a[:, :, :3]
    same = np.zeros(mask.shape, bool)
    for dy, dx in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        m = np.roll(mask, (dy, dx), (0, 1))
        c = np.roll(p, (dy, dx), (0, 1))
        same |= m & np.all(p == c, axis=2)
    bright = p.astype(float) @ np.array([0.2126, 0.7152, 0.0722]) >= 153
    unique, count = np.unique(p[mask], axis=0, return_counts=True)
    seen = np.zeros(mask.shape, bool)
    largest = 0
    for yy, xx in zip(*np.where(mask)):
        if seen[yy, xx]:
            continue
        todo = [(yy, xx)]
        seen[yy, xx] = True
        num = 0
        c = p[yy, xx]
        while todo:
            y, x = todo.pop()
            num += 1
            for dy, dx in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                ny, nx = (y + dy, x + dx)
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and (not seen[ny, nx]) and np.array_equal(p[ny, nx], c):
                    seen[ny, nx] = True
                    todo.append((ny, nx))
        largest = max(largest, num)
    accents = {k: round(100 * sum((int(t) for c, t in zip(unique, count) if bytes(c).hex() in group)) / n, 2) for k, group in GROUPS.items()}
    return dict(opaque_pixel_count=n, colour_count=len(unique), isolated_pixel_percent=round(100 * (mask & ~same).sum() / n, 2), bright_pixel_percent=round(100 * (mask & bright).sum() / n, 2), largest_flat_region_percent=round(100 * largest / n, 2), accent_percent=accents, accent_total_percent=round(sum(accents.values()), 2), binary_alpha=set(np.unique(a[:, :, 3]).tolist()) <= {0, 255}, bbox=list(im.getbbox()))
