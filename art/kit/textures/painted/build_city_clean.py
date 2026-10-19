"""Clean versions of Sol's C5 roof and C6 plaster for Lungmen's outer city
(用户 2026-10-16: 城区里的房子不应该是斑驳的，贫民窟应该是).

The outer city's buildings are kept up: painted render without the rain
stains, peeling and exposed brick; flat roofs without the patches and rust,
only the membrane seams. The slums keep Sol's weathered originals.

    python art/kit/textures/painted/build_city_clean.py

Writes city_plaster_clean.png and city_roof_clean.png beside the originals
(same size, colours a subset of the originals' palette, still seamless).
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def hx(code):
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


# Colour in the original -> colour in the clean version (anything not listed stays).
PLASTER = {c: hx("b8b6b0") for c in ("8d8a80", "a3a5a6", "6d7073", "7a3e1c", "7e8184", "5c6064", "5a3420")}
# The roof: one membrane tone with its seams (the two darkest tones) left in.
ROOF = {c: hx("5c6064") for c in ("4e5154", "6d7073", "3e2a1c", "7e8184", "8d8a80", "a3a5a6")}


def clean(name, mapping):
    im = Image.open(os.path.join(HERE, f"{name}.png")).convert("RGB")
    swap = {hx(k): v for k, v in mapping.items()}
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            px[x, y] = swap.get(px[x, y], px[x, y])
    out = os.path.join(HERE, f"{name}_clean.png")
    im.save(out)
    print(out, len(set(im.get_flattened_data())), "colours")


if __name__ == "__main__":
    clean("city_plaster", PLASTER)
    clean("city_roof", ROOF)
