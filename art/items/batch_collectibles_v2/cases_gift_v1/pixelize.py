"""整理箱与礼包像素化 (用户 2026-10-26: 把整理箱像素化; 礼包图标也用同样的方法像素化).

Sol's painted case and gift icons (icons/) turned into the pixel style of the other item
icons in art/items/runtime/: the same canvas, drawn in 2×2 texels (TEXEL), hard
alpha, a small palette with no dithering that keeps the small coloured marks
(octree, not median cut), and a closed dark outline one texel wide. Writes
pixel_v1/<id>.png and, with --runtime, copies them over art/items/runtime/.
Sol's originals in icons/ are left as they are.

    python pixelize.py [--runtime]
"""
import glob
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "pixel_v1")
RUNTIME = os.path.join(HERE, "..", "..", "runtime")
OUTLINE = (20, 20, 24, 255)
TEXEL = 2


## Per file: palette method and size where the default blurs it. The gift's
## brown box and gold ribbon are close hues: median cut at 16 keeps them apart.
SPECIAL = {"gift_pack.png": (Image.Quantize.MEDIANCUT, 16)}


def colours_for(size):
    """Bigger icons keep a few more colours, as the big gear icons do."""
    side = max(size)
    return 20 if side <= 72 else (26 if side <= 152 else 32)


def pixelize(path):
    method, colours = SPECIAL.get(os.path.basename(path), (Image.Quantize.FASTOCTREE, 0))
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    # Down to texels (box average), then everything below happens per texel.
    small = im.resize((w // TEXEL, h // TEXEL), Image.BOX)
    sw, sh = small.size
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    # Quantize the opaque part only (transparent texels must not take a slot).
    flat = Image.new("RGB", (sw, sh), (0, 0, 0))
    flat.paste(small.convert("RGB"), mask=alpha)
    q = flat.quantize(colors=colours or colours_for((w, h)), method=method, kmeans=2, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(alpha)
    px = q.load()
    a = alpha.load()
    # Close the outline: a transparent texel touching the shape becomes dark.
    edge = []
    for y in range(sh):
        for x in range(sw):
            if a[x, y]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < sw and 0 <= ny < sh and a[nx, ny]:
                    edge.append((x, y))
                    break
    for x, y in edge: px[x, y] = OUTLINE
    # Back up to the canvas, each texel a 2×2 block.
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(q.resize((sw * TEXEL, sh * TEXEL), Image.NEAREST), (0, 0))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(HERE, "icons", "case_*.png"))) + [os.path.join(HERE, "icons", "gift_pack.png")]:
        name = os.path.basename(path)
        pixelize(path).save(os.path.join(OUT, name))
        if "--runtime" in sys.argv: shutil.copyfile(os.path.join(OUT, name), os.path.join(RUNTIME, name))
        print(name)


if __name__ == "__main__":
    main()
