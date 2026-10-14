"""Build the NPC v3 material swatches from the retained painted source atlas."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "source_paintings" / "encounter_swatch_atlas.png"
RHODES_LOGO = HERE.parents[3] / "rhodes" / "batch2_v2" / "rhodes_logo_L_gray_v2.png"
SPECS = (
    ("rhodes_case", 0, 0, "case plastic"),
    ("rhodes_trim_glow", 1, 0, "cyan display and latch"),
    ("rhodes_pennant", 2, 0, "field cloth"),
    ("trader_canvas", 0, 1, "patched canvas"),
    ("trader_rug", 1, 1, "woven rug"),
    ("trader_lantern_glow", 2, 1, "lantern glass"),
)
MAIN_COLOURS = {
    "rhodes_case": ("#c9cfd2", "#8e979b", "#5b6366"),
    "rhodes_trim_glow": ("#5fd0d8", "#2a8a92"),
    "rhodes_pennant": ("#1a1d1f", "#2b3033", "#2a8a92"),
    "trader_canvas": ("#5e5646", "#8a7f66", "#a8997a"),
    "trader_rug": ("#5a2a24", "#7a5a2a", "#3a3530"),
    "trader_lantern_glow": ("#e6c25a", "#ffe9a6"),
}


def pin_palette(im: Image.Image, name: str) -> Image.Image:
    """Reduce incidental imagegen shades and retain the brief's exact anchors."""
    reduced = im.quantize(colors=32, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    palette = set(reduced.get_flattened_data())
    mapping = {}
    for hex_colour in MAIN_COLOURS[name]:
        target = tuple(bytes.fromhex(hex_colour[1:]))
        candidate = min((p for p in palette if p not in mapping), key=lambda p: sum((p[i] - target[i]) ** 2 for i in range(3)))
        mapping[candidate] = target
    reduced.putdata([mapping.get(p, p) for p in reduced.get_flattened_data()])
    return reduced


def periodic_edges(im: Image.Image, margin: int = 16) -> Image.Image:
    """Join opposed edge strips so the painted square repeats without seams."""
    im = im.convert("RGB")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for d in range(margin):
            a = px[d, y]
            b = px[w - 1 - d, y]
            edge = tuple(round((a[c] + b[c]) / 2) for c in range(3))
            t = d / margin
            px[d, y] = tuple(round(edge[c] * (1 - t) + a[c] * t) for c in range(3))
            px[w - 1 - d, y] = tuple(round(edge[c] * (1 - t) + b[c] * t) for c in range(3))
    for x in range(w):
        for d in range(margin):
            a = px[x, d]
            b = px[x, h - 1 - d]
            edge = tuple(round((a[c] + b[c]) / 2) for c in range(3))
            t = d / margin
            px[x, d] = tuple(round(edge[c] * (1 - t) + a[c] * t) for c in range(3))
            px[x, h - 1 - d] = tuple(round(edge[c] * (1 - t) + b[c] * t) for c in range(3))
    # Force the actual terminal pixels equal after both passes, including corners.
    for y in range(h):
        colour = tuple(round((px[0, y][c] + px[w - 1, y][c]) / 2) for c in range(3))
        px[0, y] = px[w - 1, y] = colour
    for x in range(w):
        colour = tuple(round((px[x, 0][c] + px[x, h - 1][c]) / 2) for c in range(3))
        px[x, 0] = px[x, h - 1] = colour
    return im


def tile_preview(im: Image.Image, name: str) -> str:
    preview = Image.new(im.mode, (im.width * 3, im.height * 3))
    for y in range(3):
        for x in range(3):
            preview.paste(im, (x * im.width, y * im.height))
    filename = f"{name}_tile_3x3.png"
    preview.save(HERE / filename)
    return filename


def build_logo() -> Image.Image:
    source = Image.open(RHODES_LOGO).convert("RGBA")
    assert source.size == (64, 64)
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for y in range(64):
        for x in range(64):
            if source.getpixel((x, y))[3] >= 128:
                out.putpixel((x, y), (232, 236, 236, 255))
    # The existing Rhodes triangular mark remains exact; cyan accents the
    # negative-space cross and makes a two-colour set-piece decal.
    d = ImageDraw.Draw(out)
    d.rectangle((30, 25, 33, 36), fill=(42, 138, 146, 255))
    d.rectangle((25, 29, 38, 32), fill=(42, 138, 146, 255))
    return out


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    assert source.size == (1536, 1024), source.size
    manifest = []
    report = ["NPC v3 Part C static validation", "Painted source: source_paintings/encounter_swatch_atlas.png"]
    for name, col, row, use in SPECS:
        swatch = source.crop((col * 512, row * 512, (col + 1) * 512, (row + 1) * 512))
        swatch = swatch.resize((256, 256), Image.Resampling.NEAREST)
        swatch = periodic_edges(swatch)
        swatch = pin_palette(swatch, name)
        swatch.save(HERE / f"{name}.png")
        preview = tile_preview(swatch, name)
        px = swatch.load()
        assert all(px[0, y] == px[255, y] for y in range(256))
        assert all(px[x, 0] == px[x, 255] for x in range(256))
        assert all(tuple(bytes.fromhex(c[1:])) in set(swatch.get_flattened_data()) for c in MAIN_COLOURS[name])
        manifest.append({"id": name, "file": f"{name}.png", "size": [256, 256], "use": use, "tile_preview": preview, "source_crop": [col * 512, row * 512, 512, 512]})
        report.append(f"PASS {name}: 256x256 RGB, {len(set(swatch.get_flattened_data()))} colours including exact palette anchors, matching opposite-edge pixels, 3x3 tile preview.")
    logo = build_logo()
    logo.save(HERE / "rhodes_logo_decal.png")
    tile_preview(logo, "rhodes_logo_decal")
    assert logo.size == (64, 64) and logo.getpixel((0, 0))[3] == 0
    manifest.insert(3, {"id": "rhodes_logo_decal", "file": "rhodes_logo_decal.png", "size": [64, 64], "use": "Rhodes pennant and case", "tile_preview": "rhodes_logo_decal_tile_3x3.png", "source": str(RHODES_LOGO.relative_to(HERE.parents[4])).replace("\\", "/")})
    report.append("PASS rhodes_logo_decal: 64x64 RGBA, transparent surround, derived from existing Rhodes mark.")
    report.append("Static file checks only. Blender projection, AO bake, and Godot display were not tested.")
    (HERE / "manifest.json").write_text(json.dumps({"source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "assets": manifest}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (HERE / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
