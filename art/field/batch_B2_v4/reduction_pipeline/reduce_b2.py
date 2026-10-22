"""Straight reduction of a B2 painting to game size, the check the user asked
for (用户 2026-10-19: 缩图后要能认出是人).

The painting is cut to its figure (alpha > 128), box-downscaled with its
colour weighted by coverage (so the transparent surround does not grey it),
quantized to 16 colours with fast octree, thin parts grown 1 px, and given the
1 px inner outline of reduce_n1. No pixel is drawn by hand.

    python art/field/reduce_b2.py <painting.png> <height> <out.png>

Writes <out.png> and, beside it, <out>_on_ground_x6.png: the figure next to
the family soldier on the piazza ground (refs_B2/siracusa_arena_ingame.png).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reduce_n1 as r  # noqa: E402


def reduce(painting: Image.Image, height: int) -> Image.Image:
    arr = np.array(painting.convert("RGBA")).astype(float)
    ys, xs = np.where(arr[..., 3] > 128)
    arr = arr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    cover = (arr[..., 3] > 128).astype(float)
    width = round(arr.shape[1] * height / arr.shape[0])
    rgb = np.array(Image.fromarray(np.uint8(arr[..., :3] * cover[..., None])).resize((width, height), Image.BOX)).astype(float)
    alpha = np.array(Image.fromarray(np.uint8(cover * 255)).resize((width, height), Image.BOX)).astype(float) / 255.0
    rgb = (rgb / np.maximum(alpha[..., None], 1e-3)).clip(0, 255)
    solid = alpha > 0.5
    flat = np.array(Image.fromarray(np.uint8(rgb)).quantize(16, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB"))
    solid, flat = r.thicken_thin(np.pad(solid, 1), np.pad(flat, ((1, 1), (1, 1), (0, 0))))
    out = np.zeros((height + 2, width + 2, 4), np.uint8)
    out[..., :3] = flat
    out[..., 3] = np.where(solid, 255, 0)
    out[r.edge_of(solid)] = (*r.OUTLINE, 255)
    return Image.fromarray(out)


def main() -> None:
    painting, height, out = Image.open(sys.argv[1]), int(sys.argv[2]), Path(sys.argv[3])
    small = reduce(painting, height)
    small.save(out)
    soldier = Image.open(HERE / "enemy_dir_family_soldier_64.png").convert("RGBA").crop((64, 0, 128, 64))
    soldier = soldier.crop(soldier.getbbox())
    ground = Image.open(HERE / "refs_B2" / "siracusa_arena_ingame.png").convert("RGBA").crop((700, 250, 800, 300))
    ground.alpha_composite(small, (20, 47 - small.height))
    ground.alpha_composite(soldier, (60, 47 - soldier.height))
    ground.resize((ground.width * 6, ground.height * 6), Image.NEAREST).save(out.with_name(out.stem + "_on_ground_x6.png"))
    print("reduced", out, small.size)


if __name__ == "__main__":
    main()
