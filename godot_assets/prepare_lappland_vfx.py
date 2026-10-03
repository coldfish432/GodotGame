"""Bake Lappland's painted attack effects into runtime textures (Pillow + numpy).

Run from any directory: python godot_assets/prepare_lappland_vfx.py

Inputs (godot_assets/lappland_vfx_originals/, not imported by Godot):
  连斩三段_像素.png  three pixel-art slashes: 1 horizontal sweep, 2 rising
                     reverse cut, 3 crossed double cut (the Sundial finisher).
  剑气_像素.png      the pixel sword wave: crescent with three fading echoes.
  剑气_概念原画.png  painted concept for the wave; reference only (soft glow,
                     not pixel art, so it is not baked).

The originals are pixel art drawn with large square blocks. Each is downsampled
by its block size so one block becomes one texel (the X at 70% of that, the
wave at 1.4 blocks per texel so it stays near its 1.2-unit hit strip), then every texel is snapped to the
art's own palette to keep crisp pixel colours. Outputs are rotated so the
attack direction points to the top of the texture; the game lays them flat on
the ground and turns them to face the swing. One texel is drawn at one world
pixel (1/15 unit), matching the rest of the 640x360 scene.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
SOURCES = ROOT / "lappland_vfx_originals"
SLASH_BLOCK = 12.5   # source pixels per art block in the slash sheet
WAVE_BLOCK = 20.7    # source pixels per art block in the wave sheet
WAVE_BLOCKS_PER_TEXEL = 1.4
# The Sundial X is baked smaller than the two sweeps (about 70%).
X_SCALE = 0.7
PALETTE_SIZE = 10


def crop(image: Image.Image) -> Image.Image:
    return image.crop(image.getbbox())


def palette(image: Image.Image) -> np.ndarray:
    """The art's dominant opaque colours."""
    pixels = np.array(image.convert("RGBA")).reshape(-1, 4)
    opaque = pixels[pixels[:, 3] >= 128][:, :3]
    quantized = Image.fromarray(opaque.reshape(1, -1, 3).astype(np.uint8), "RGB").quantize(PALETTE_SIZE)
    return np.array(quantized.getpalette()[:PALETTE_SIZE * 3]).reshape(-1, 3)


def bake(image: Image.Image, block: float, rotate: int) -> Image.Image:
    image = crop(image)
    colours = palette(image)
    size = (max(1, round(image.width / block)), max(1, round(image.height / block)))
    small = image.convert("RGBa").resize(size, Image.Resampling.BOX).convert("RGBA")
    data = np.array(small)
    solid = data[:, :, 3] >= 128
    rgb = data[:, :, :3].reshape(-1, 1, 3).astype(int)
    nearest = np.argmin(((rgb - colours[None, :, :]) ** 2).sum(2), axis=1)
    data[:, :, :3] = colours[nearest].reshape(data.shape[0], data.shape[1], 3)
    data[:, :, 3] = np.where(solid, 255, 0)
    # PIL rotates counter-clockwise; the goal is "attack direction = up".
    return Image.fromarray(data, "RGBA").rotate(rotate, expand=True, resample=Image.Resampling.NEAREST)


def blobs(alpha: np.ndarray) -> list[np.ndarray]:
    """8-connected opaque regions."""
    from collections import deque
    height, width = alpha.shape
    labels = np.zeros(alpha.shape, np.int32)
    found = []
    for y0, x0 in zip(*np.nonzero(alpha)):
        if labels[y0, x0]:
            continue
        index = len(found) + 1
        labels[y0, x0] = index
        queue = deque([(y0, x0)])
        while queue:
            y, x = queue.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < height and 0 <= xx < width and alpha[yy, xx] and not labels[yy, xx]:
                        labels[yy, xx] = index
                        queue.append((yy, xx))
        found.append(index)
    return [labels == index for index in found]


def pointed_forward(image: Image.Image) -> Image.Image:
    """The wave art draws its echoes on the crescent's pointed side, so no
    rotation gives "point forward, echoes behind". Mirror the art so the
    point faces right (the travel direction), then reflect every other piece
    (echoes, sparks) to the opposite side of the main crescent."""
    image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    pixels = np.array(image)
    parts = blobs(pixels[:, :, 3] >= 128)
    main = max(parts, key=lambda part: part.sum())
    main_x = np.nonzero(main.any(0))[0]
    pivot = (main_x.min() + main_x.max()) / 2.0
    others = [part for part in parts if part is not main]
    placed = [(main, 0)]
    for part in others:
        xs = np.nonzero(part.any(0))[0]
        centre = (xs.min() + xs.max()) / 2.0
        # Same shape (still pointing forward), moved to the mirror position.
        placed.append((part, int(round(2 * (pivot - centre)))))
    lo = min(np.nonzero(part.any(0))[0].min() + offset for part, offset in placed)
    hi = max(np.nonzero(part.any(0))[0].max() + offset for part, offset in placed)
    shift = 8 - lo
    canvas = np.zeros((image.height, hi - lo + 17, 4), np.uint8)
    for part, offset in placed:
        ys, xs = np.nonzero(part)
        canvas[ys, xs + offset + shift] = pixels[ys, xs]
    return Image.fromarray(canvas, "RGBA")


def panels(image: Image.Image) -> list[Image.Image]:
    """Split the slash sheet at its empty column gutters."""
    alpha = np.array(image.convert("RGBA"))[:, :, 3] >= 128
    filled = alpha.any(0)
    spans, start = [], None
    for x, value in enumerate(filled):
        if value and start is None:
            start = x
        # A gutter is a run of at least 30 empty columns.
        if not value and start is not None and not filled[x:x + 30].any():
            spans.append((start, x))
            start = None
    if start is not None:
        spans.append((start, len(filled)))
    assert len(spans) == 3, spans
    return [image.crop((a, 0, b, image.height)) for a, b in spans]


def main() -> None:
    slashes = panels(Image.open(SOURCES / "连斩三段_像素.png").convert("RGBA"))
    # 1: horizontal sweep drawn bulging downward -> turn 180 so it bulges forward.
    # 2: rising cut bulging right -> turn 90 so right becomes forward.
    # 3: crossed cut is symmetric enough to use as drawn.
    for index, (panel, rotate) in enumerate(zip(slashes, (180, 90, 0)), 1):
        out = bake(panel, SLASH_BLOCK / (X_SCALE if index == 3 else 1.0), rotate)
        out.save(ROOT / f"lappland_vfx_slash_{index}.png")
        print(f"slash {index}: {out.size}")
    # Wave: pointed (convex) side leading, echoes trailing -> travel right, turn 90.
    wave_art = pointed_forward(Image.open(SOURCES / "剑气_像素.png").convert("RGBA"))
    wave = bake(wave_art, WAVE_BLOCK * WAVE_BLOCKS_PER_TEXEL, 90)
    wave.save(ROOT / "lappland_vfx_wave.png")
    print(f"wave: {wave.size}")


if __name__ == "__main__":
    main()
