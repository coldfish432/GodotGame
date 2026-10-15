"""Reduce an N3 sentinel identity painting the N1 way and line it up with the cast.

  python art/field/batch_N3_claude/preview_sentinel.py <identity.png>

Writes, next to this script: sentinel_native.png (bake_n2.EXTRA_HEIGHTS tall to the pole tip,
reduce_n1.reduce: box downscale, 16 colours (octree, bake_n2.QUANTIZE), crumbs dropped, thin parts grown,
1 px outline), sentinel_vs_cast_x8.png (beside 暴徒, 弩手, 术师, 歪曲施法者, ×8)
and sentinel_on_grounds_x6.png (the same line on the mine, Lungmen and Sami
grounds, ×6). Judge the sentinel at these sizes, never on the painting.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
sys.path.insert(0, str(FIELD))
from bake_n2 import EXTRA_HEIGHTS, QUANTIZE  # noqa: E402
from reduce_n1 import reduce  # noqa: E402


def trim(img: Image.Image) -> Image.Image:
    a = np.array(img)
    ys, xs = np.where(a[..., 3] > 128 if a[..., 3].max() > 1 else a[..., 3] > 0)
    return img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def first_cell(path: Path) -> Image.Image:
    return trim(Image.open(path).convert("RGBA").crop((0, 0, 64, 64)))


def main() -> None:
    src = Image.open(sys.argv[1]).convert("RGBA")
    sentinel = reduce(trim(src), EXTRA_HEIGHTS["sentinel"], method=QUANTIZE["sentinel"])
    sentinel.save(HERE / "sentinel_native.png")
    cast = [first_cell(FIELD / "enemy_dir_thug_64.png"), first_cell(FIELD / "enemy_dir_crossbow_64.png"),
            Image.open(FIELD / "batch_N1_claude/native/caster.png").convert("RGBA"),
            Image.open(FIELD / "batch_N1_claude/native/distorted_caster.png").convert("RGBA"), sentinel]
    width = sum(s.width + 6 for s in cast) + 6
    height = 42

    def line(ground: Image.Image) -> Image.Image:
        out = ground.copy()
        x = 6
        for s in cast:
            out.alpha_composite(s, (x, height - s.height - 3))
            x += s.width + 6
        return out

    plain = line(Image.new("RGBA", (width, height), (48, 50, 54, 255)))
    plain.resize((width * 8, height * 8), Image.NEAREST).save(HERE / "sentinel_vs_cast_x8.png")
    rows = []
    for name in ("mine", "city", "snow"):
        bg = Image.open(FIELD / f"background_{name}_v1.png").convert("RGBA")
        tile = bg.resize((bg.width // 6, bg.height // 6), Image.BOX).crop((0, 0, width, height))
        rows.append(line(tile).resize((width * 6, height * 6), Image.NEAREST))
    sheet = Image.new("RGBA", (width * 6, height * 6 * 3))
    for i, r in enumerate(rows): sheet.alpha_composite(r, (0, i * height * 6))
    sheet.save(HERE / "sentinel_on_grounds_x6.png")
    print("native", sentinel.size)


if __name__ == "__main__":
    main()
