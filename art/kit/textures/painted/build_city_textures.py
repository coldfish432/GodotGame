"""Reduce painted C1-C9 sources to the Lungmen palette and review tiles."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SOURCES = HERE / "source_paintings"
PALETTE = {
    h: tuple(bytes.fromhex(h)) for h in (
        "22262a 2f3438 454e54 5c6064 7e8184 a3a5a6 4e5154 6d7073 "
        "8d8a80 3e2a1c 5a3420 7a3e1c b8b6b0 d0cec8 c23b2c 2e6fb0 "
        "e0b030 d04a8a 3fae6a c8b880"
    ).split()
}
SPECS = {
    "city_road": ((256, 256), "22262a 2f3438 454e54 4e5154 5c6064 6d7073 3e2a1c 5a3420 7a3e1c"),
    "city_pavement": ((128, 128), "454e54 4e5154 5c6064 6d7073 7e8184 8d8a80 a3a5a6 3e2a1c 5a3420 3fae6a"),
    "city_wall": ((256, 256), "454e54 4e5154 5c6064 6d7073 7e8184 8d8a80 a3a5a6 3e2a1c 5a3420 7a3e1c"),
    "city_block_ground": ((256, 256), "22262a 2f3438 454e54 4e5154 5c6064 6d7073 7e8184 8d8a80 3e2a1c 5a3420 3fae6a"),
    "city_roof": ((256, 256), "2f3438 454e54 4e5154 5c6064 6d7073 7e8184 8d8a80 a3a5a6 3e2a1c 3fae6a"),
    "city_plaster": ((256, 256), "5c6064 6d7073 7e8184 8d8a80 a3a5a6 b8b6b0 d0cec8 3e2a1c 5a3420 7a3e1c"),
    "city_corrugated": ((128, 128), "2f3438 454e54 4e5154 5c6064 6d7073 7e8184 8d8a80 3e2a1c 5a3420 7a3e1c"),
    "city_shutter": ((128, 128), "2f3438 454e54 4e5154 5c6064 6d7073 7e8184 8d8a80 3e2a1c 5a3420 7a3e1c c23b2c 2e6fb0 e0b030"),
    "city_signs": ((512, 256), "22262a 454e54 5c6064 7e8184 b8b6b0 d0cec8 3e2a1c c23b2c 2e6fb0 e0b030 d04a8a 3fae6a"),
}


def lab(rgb: np.ndarray) -> np.ndarray:
    x = np.asarray(rgb, dtype=np.float32) / 255.0
    x = np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
    xyz = x @ np.array([[0.4124564, 0.2126729, 0.0193339],
                        [0.3575761, 0.7151522, 0.1191920],
                        [0.1804375, 0.0721750, 0.9503041]], dtype=np.float32)
    xyz /= np.array([0.95047, 1.0, 1.08883], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack((116 * f[..., 1] - 16,
                     500 * (f[..., 0] - f[..., 1]),
                     200 * (f[..., 1] - f[..., 2])), axis=-1)


def seamless(rgb: np.ndarray, band: int) -> np.ndarray:
    """Wrap the painted edges through a narrow blended border before indexing."""
    a = rgb.astype(np.float32).copy()
    h, w = a.shape[:2]
    for x in range(band):
        left = a[:, x].copy()
        right = a[:, w - 1 - x].copy()
        join = (left + right) * 0.5
        t = x / band
        a[:, x] = join * (1 - t) + left * t
        a[:, w - 1 - x] = join * (1 - t) + right * t
    for y in range(band):
        top = a[y].copy()
        bottom = a[h - 1 - y].copy()
        join = (top + bottom) * 0.5
        t = y / band
        a[y] = join * (1 - t) + top * t
        a[h - 1 - y] = join * (1 - t) + bottom * t
    return np.uint8(np.clip(np.rint(a), 0, 255))


def index_palette(rgb: np.ndarray, colors: list[str]) -> np.ndarray:
    pal = np.array([PALETTE[h] for h in colors], dtype=np.uint8)
    pal_lab = lab(pal)
    src_lab = lab(rgb)
    # Weighted Lab distance keeps flat value differences more important than
    # tiny hue differences from the source painting's texture grain.
    delta = src_lab[:, :, None, :] - pal_lab[None, None, :, :]
    delta[..., 1:] *= 0.68
    idx = np.argmin(np.sum(delta * delta, axis=-1), axis=-1)
    return pal[idx]


def build(name: str, size: tuple[int, int], palette: str) -> dict:
    source = SOURCES / f"{name}_source.png"
    with Image.open(source) as im:
        im = im.convert("RGB")
        if name == "city_corrugated":
            # The painted sheet has more ribs than the specified 0.15 m pitch.
            # Take a centered 2/3-width swatch to retain roughly 20 ribs.
            width = round(im.width * 0.67)
            left = (im.width - width) // 2
            im = im.crop((left, 0, left + width, im.height))
        im = im.resize(size, Image.Resampling.BOX)
        rgb = np.asarray(im)
    if name != "city_signs":
        rgb = seamless(rgb, max(8, size[0] // 16))
    if name == "city_road":
        # Keep the asphalt legible under the city's cool lighting while it
        # remains well below the pavement's value range.
        rgb = np.uint8(np.clip(np.rint(rgb.astype(np.float32) * 1.15), 0, 255))
    indexed = index_palette(rgb, palette.split())
    if name == "city_road":
        # The painted rust has more warm variation than the nearest-color
        # mapping retained. Keep its warmest source clusters as the second
        # palette brown so the road meets the requested 8-color minimum.
        dark_rust = np.all(indexed == PALETTE["3e2a1c"], axis=2)
        warmth = rgb[..., 0].astype(np.int16) - rgb[..., 1].astype(np.int16)
        cut = np.percentile(warmth[dark_rust], 78)
        indexed[dark_rust & (warmth >= cut)] = PALETTE["5a3420"]
    if name == "city_pavement":
        # Retain only the actual painted grass flecks, whose muted source
        # green otherwise collapses into neutral gray at this tiny size.
        a = rgb.astype(np.int16)
        grass = ((a[..., 1] - a[..., 0] >= 5)
                 & (a[..., 1] - a[..., 2] >= 8)
                 & (a[..., 1] < 150))
        indexed[grass] = PALETTE["3fae6a"]
    if name == "city_corrugated":
        # Preserve the actual painted rust extent; Lab nearest-color alone
        # collapses its muted orange fringes into gray (only ~16% rust).
        a = rgb.astype(np.int16)
        warmth = a[..., 0] - a[..., 1]
        rusty = (warmth >= 8) & (a[..., 0] - a[..., 2] >= 10)
        indexed[rusty & (warmth < 18)] = PALETTE["3e2a1c"]
        indexed[rusty & (warmth >= 18) & (warmth < 30)] = PALETTE["5a3420"]
        indexed[rusty & (warmth >= 30)] = PALETTE["7a3e1c"]
    if name == "city_shutter":
        # Keep the source painting's yellowed lower slats; they disappear in
        # neutral-gray nearest-color reduction.
        a = rgb.astype(np.int16)
        yellowed = ((a[..., 0] > 130) & (a[..., 1] > 95)
                    & (a[..., 1] - a[..., 2] > 25)
                    & (a[..., 0] - a[..., 1] < 70))
        yellow_strength = a[..., 0] + a[..., 1] - a[..., 2]
        cut = np.percentile(yellow_strength[yellowed], 80)
        indexed[yellowed] = PALETTE["8d8a80"]
        indexed[yellowed & (yellow_strength >= cut)] = PALETTE["e0b030"]
    if name != "city_signs":
        indexed[-1, :, :] = indexed[0, :, :]
        indexed[:, -1, :] = indexed[:, 0, :]
    final = Image.fromarray(indexed, "RGB")
    final.save(HERE / f"{name}.png")
    preview = Image.new("RGB", (size[0] * 3, size[1] * 3))
    for y in range(3):
        for x in range(3):
            preview.paste(final, (x * size[0], y * size[1]))
    preview.save(HERE / f"{name}_tile_3x3.png")
    colors = np.unique(indexed.reshape(-1, 3), axis=0)
    return {"source": str(source.relative_to(HERE)),
            "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "size": list(size), "colors": int(len(colors)),
            "palette": [f"#{h}" for h in palette.split()],
            "seam_exact": name == "city_signs" or
                bool(np.array_equal(indexed[0], indexed[-1]) and
                     np.array_equal(indexed[:, 0], indexed[:, -1]))}


def contact(source: bool) -> None:
    names = list(SPECS)
    page = Image.new("RGB", (1050, 1050), "#16191d")
    pen = ImageDraw.Draw(page)
    for i, name in enumerate(names):
        path = (SOURCES / f"{name}_source.png") if source else (HERE / f"{name}.png")
        with Image.open(path) as im:
            thumb = im.convert("RGB").resize((330, 320), Image.Resampling.NEAREST)
        x, y = (i % 3) * 350, (i // 3) * 350
        page.paste(thumb, (x, y + 25))
        pen.text((x + 5, y + 5), f"C{i + 1} {name[5:]}", fill="white")
    page.save(HERE / ("source_contact.png" if source else "final_contact.png"))


if __name__ == "__main__":
    report = {name: build(name, *spec) for name, spec in SPECS.items()}
    contact(True)
    contact(False)
    (HERE / "manifest.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for name, info in report.items():
        print(name, info["size"], info["colors"], "colors", "seam", info["seam_exact"])
