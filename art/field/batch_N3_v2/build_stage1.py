"""Crop the painted N3 v2 source and run the supplied N1 reduction preview."""

import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent


def main() -> None:
    source = Image.open(HERE / "source_painting.png").convert("RGBA")
    bounds = source.getchannel("A").point(lambda value: 255 if value > 128 else 0).getbbox()
    if bounds is None:
        raise ValueError("No visible figure in source painting")
    margin = 16
    crop = source.crop((max(0, bounds[0] - margin),
                        max(0, bounds[1] - margin),
                        min(source.width, bounds[2] + margin),
                        min(source.height, bounds[3] + margin)))
    crop.save(HERE / "identity.png")

    sys.path.insert(0, str(FIELD / "batch_N3_claude"))
    import preview_sentinel

    preview_sentinel.HERE = HERE
    sys.argv = [str(FIELD / "batch_N3_claude" / "preview_sentinel.py"),
                str(HERE / "identity.png")]
    preview_sentinel.main()
    print("identity", crop.size, "source bounds", bounds)


if __name__ == "__main__":
    main()
