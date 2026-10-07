"""Convert imagegen relic drafts to the 72 px binary-alpha game grid.

The source PNGs remain available alongside each batch for visual review.
"""

import argparse
from collections import Counter
from pathlib import Path

from PIL import Image


SIZE = 72
CONTENT = 64
OUTLINE = (11, 12, 13, 255)


def luminance(color: tuple[int, int, int]) -> float:
    r, g, b = color
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def lift_highlights(image: Image.Image) -> None:
    pixels = image.load()
    colors = Counter(
        pixels[x, y][:3]
        for y in range(SIZE)
        for x in range(SIZE)
        if pixels[x, y][3] and pixels[x, y] != OUTLINE
    )
    total = sum(1 for pixel in image.get_flattened_data() if pixel[3])
    bright = sum(count for color, count in colors.items() if luminance(color) >= 153)
    target = (total * 16 + 99) // 100
    changes = {}
    for color, count in sorted(colors.items(), key=lambda item: luminance(item[0]), reverse=True):
        if bright >= target:
            break
        light = luminance(color)
        if light >= 153:
            continue
        blend = (160 - light) / (255 - light)
        changes[color] = tuple(round(channel + (255 - channel) * blend) for channel in color)
        bright += count
    for y in range(SIZE):
        for x in range(SIZE):
            pixel = pixels[x, y]
            updated = changes.get(pixel[:3]) if pixel[3] else None
            if updated is not None:
                pixels[x, y] = (*updated, 255)


def reduce_icon(source: Path, target: Path) -> None:
    original = Image.open(source).convert("RGBA")
    mask = original.getchannel("A").point(lambda value: 255 if value >= 160 else 0)
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"No opaque pixels in {source}")
    cropped = original.crop(bounds)
    mask = mask.crop(bounds)
    ratio = min(CONTENT / cropped.width, CONTENT / cropped.height)
    dimensions = (max(1, round(cropped.width * ratio)), max(1, round(cropped.height * ratio)))
    cropped = cropped.resize(dimensions, Image.Resampling.NEAREST)
    mask = mask.resize(dimensions, Image.Resampling.NEAREST)

    # Quantize only visible RGB data, so transparent canvas pixels do not
    # consume the limited 24-color budget.
    visible = [pixel[:3] for pixel, opacity in zip(cropped.get_flattened_data(), mask.get_flattened_data()) if opacity]
    swatches = Image.new("RGB", (len(visible), 1))
    swatches.putdata(visible)
    palette = swatches.quantize(colors=23, method=Image.Quantize.MEDIANCUT)
    opaque = cropped.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGB")

    canvas = Image.new("RGBA", (SIZE, SIZE))
    x = (SIZE - dimensions[0]) // 2
    y = (SIZE - dimensions[1]) // 2
    colored = Image.merge("RGBA", (*opaque.split(), mask))
    canvas.alpha_composite(colored, (x, y))

    # A single dark outside edge remains legible on the UI's dark plate.
    alpha = canvas.getchannel("A")
    pixels = canvas.load()
    for py in range(1, SIZE - 1):
        for px in range(1, SIZE - 1):
            if alpha.getpixel((px, py)) and any(
                alpha.getpixel((px + dx, py + dy)) == 0
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1))
            ):
                pixels[px, py] = OUTLINE
    lift_highlights(canvas)
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(target)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    options = parser.parse_args()
    reduce_icon(options.source, options.target)
