"""Stand-in deck plate for the modelled base floor (基地建模改造案_v1 §二), until
Sol's R1 swatch: one 2 m x 2 m plate at 16 px a metre, tiling. Dark ship steel,
a darker seam, a lighter bevel on the north/west edges, four rivets, faint
mottling. Writes art/kit/textures/base_deck_tile.png, and the medical bay's and
the store's plates (base_deck_med.png, base_deck_store.png).

    python tools/blender/base/make_deck_tile.py
"""
import os
import random
from PIL import Image

N = 32
BASE = (78, 86, 92)
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "art", "kit", "textures", "base_deck_tile.png")


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def main():
    plate(BASE, OUT)
    # 医疗部: pale medical-white tiles (R3 stand-in); 商店: warm grey plates.
    plate((176, 186, 190), OUT.replace("base_deck_tile", "base_deck_med"), diamonds=False)
    plate((104, 98, 92), OUT.replace("base_deck_tile", "base_deck_store"))


def plate(BASE, OUT, diamonds=True):
    random.seed(7)
    im = Image.new("RGB", (N, N), BASE)
    px = im.load()
    for x in range(N):
        for y in range(N):
            px[x, y] = shade(BASE, 0.95 + random.random() * 0.08)
    for i in range(N):
        px[i, 0] = shade(BASE, 0.62)      # seam
        px[0, i] = shade(BASE, 0.62)
        px[i, 1] = shade(BASE, 1.28)      # bevel catching the light
        px[1, i] = shade(BASE, 1.22)
        px[i, N - 1] = shade(BASE, 0.8)
        px[N - 1, i] = shade(BASE, 0.82)
    for (x, y) in ((4, 4), (N - 5, 4), (4, N - 5), (N - 5, N - 5)):
        px[x, y] = shade(BASE, 1.45)
        px[x + 1, y + 1] = shade(BASE, 0.7)
    # a faint anti-slip diamond pattern in the middle of the plate
    for x in range(8, N - 8, 4):
        for y in range(8, N - 8, 4):
            if diamonds:
                px[x, y] = shade(BASE, 1.12)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
