"""Assemble the approved-source N3 identity and cast comparison."""

from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
SOURCE = HERE / "source_painting.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    solid = source.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    bounds = solid.getbbox()
    if bounds is None:
        raise ValueError("Source painting has no opaque figure")
    margin = 24
    bounds = (
        max(0, bounds[0] - margin),
        max(0, bounds[1] - margin),
        min(source.width, bounds[2] + margin),
        min(source.height, bounds[3] + margin),
    )
    figure = source.crop(bounds)
    figure.save(HERE / "identity.png")

    cast = Image.open(FIELD / "batch_N1_claude" / "overview_x6.png").convert("RGBA")
    target_height = 192
    target_width = round(figure.width * target_height / figure.height)
    small = figure.resize((target_width, target_height), Image.Resampling.LANCZOS)
    x = 1475
    y = 25
    if x + target_width > cast.width:
        raise ValueError("Sentinel does not fit beside the first cast row")
    cast.alpha_composite(small, (x, y))
    cast.save(HERE / "identity_with_cast.png")

    # A provisional native-size legibility check. The final N1 pixelisation
    # and N2 bake remain separate work after the identity is approved.
    mini_height = 34
    mini_width = round(figure.width * mini_height / figure.height)
    mini = figure.resize((mini_width, mini_height), Image.Resampling.LANCZOS)
    checks = []
    for name in ("mine", "city", "snow"):
        ground = Image.open(FIELD / f"background_{name}_v1.png").convert("RGBA")
        half = min(ground.size) // 2
        ground = ground.crop((half - 192, half - 192, half + 192, half + 192))
        ground = ground.resize((64, 64), Image.Resampling.LANCZOS)
        ground.alpha_composite(mini, ((64 - mini_width) // 2, 51 - mini_height))
        checks.append(ground.resize((384, 384), Image.Resampling.NEAREST))
    strip = Image.new("RGBA", (384 * len(checks), 384))
    for index, check in enumerate(checks):
        strip.alpha_composite(check, (384 * index, 0))
    strip.save(HERE / "identity_ground_preview.png")

    print(f"source={source.size} opaque_bbox={solid.getbbox()}")
    print(f"identity={figure.size} cast_figure={(target_width, target_height)} at {(x, y)}")
    print(f"provisional mini={mini.size} on mine/city/snow")


if __name__ == "__main__":
    main()
