"""Pixel-pack the painted sundial/fang motif into three ring states."""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
REFS = HERE.parent / "refs"
PAINTING = HERE / "source_analysis" / "lappland_ring_painting.png"
SIZE = 28
CENTRE = (14, 14)
GREY = (110, 113, 109, 255)
PALETTES = {
    "empty": {"outline": "#1c1a24", "body": "#4d5868", "highlight": "#4d5868"},
    "lit": {"outline": "#1c1a24", "body": "#8a9bb0", "highlight": "#e8ecf2"},
    "full": {"outline": "#1c1a24", "body": "#8e5cff", "highlight": "#cdb4ff"},
}


def rgb(hex_color: str) -> tuple[int, int, int, int]:
    return tuple(bytes.fromhex(hex_color[1:])) + (255,)


def motif_roles() -> np.ndarray:
    painting = Image.open(PAINTING).convert("RGBA")
    if painting.size != (1774, 887):
        raise ValueError("Unexpected painted-source dimensions")
    # The painting establishes the three faceted sundial blocks, fang on the
    # left, and tapered shadow on the right. Snap that study to the brief's
    # exact 9–13 px radii and 100-degree arc at this very small target size.
    mask = np.zeros((SIZE, SIZE), dtype=bool)
    for y in range(SIZE):
        for x in range(SIZE):
            dx, up = x - CENTRE[0], CENTRE[1] - y
            radius = math.hypot(dx, up)
            angle = math.degrees(math.atan2(dx, up))
            in_band = 9 <= radius <= 13 and abs(angle) <= 50
            hour_notch = abs(angle - 16.7) <= 2 or abs(angle + 16.7) <= 2
            mask[y, x] = in_band and not hour_notch
    mask[1, 13:16] = True  # a flat three-texel sundial crown, not a spike
    # Angular wolf fang and one-pixel sundial shadow tail.
    mask[6, 4] = True
    mask[6, 24] = True
    roles = np.zeros((SIZE, SIZE), dtype=np.uint8)
    # 0 transparent, 1 outline, 2 body, 3 highlight.
    roles[mask] = 2
    for x in range(4, 25):
        ys = np.where(mask[:, x])[0]
        if not len(ys):
            continue
        roles[ys.min(), x] = 1  # hard upper outline
        if x <= 23 and len(ys) >= 2:
            roles[ys.max(), x] = 3  # blade-white inner edge
    painted = np.asarray(
        painting.crop((137, 172, 1711, 689)).resize((21, 8), Image.Resampling.BOX)
    )
    for y in range(1, 9):
        for x in range(4, 25):
            red, green, blue, alpha = map(int, painted[y - 1, x - 4])
            if roles[y, x] == 2 and alpha >= 96 and (red + green + blue) / 3 >= 175:
                roles[y, x] = 3  # retain the painting's sparse faceted glints
    roles[6, 4] = 3  # leading fang; full state overrides to single white pixel
    roles[6, 24] = 1
    return roles


def render_state(roles: np.ndarray, state: str) -> Image.Image:
    colors = PALETTES[state]
    out = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    for value, name in ((1, "outline"), (2, "body"), (3, "highlight")):
        out[roles == value] = rgb(colors[name])
    if state == "full":
        out[6, 4] = rgb("#e8ecf2")
    return Image.fromarray(out, "RGBA")


def on_grey(sprite: Image.Image, scale: int) -> Image.Image:
    canvas = Image.new("RGBA", sprite.size, GREY)
    canvas.alpha_composite(sprite)
    return canvas.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST).convert("RGB")


def assemble(states: list[Image.Image]) -> Image.Image:
    if len(states) != 3:
        raise ValueError("Need one state per 120-degree position")
    canvas = Image.new("RGBA", (SIZE, SIZE))
    for angle, sprite in zip((0, 120, 240), states):
        rotated = sprite.rotate(angle, resample=Image.Resampling.NEAREST, center=CENTRE)
        canvas.alpha_composite(rotated)
    return canvas


def remove_old_ring(screenshot: Image.Image) -> Image.Image:
    """Inpaint only the old purple arc around Lappland for visual mock-ups."""
    original = np.asarray(screenshot.convert("RGB"))
    cleaned = original.copy()
    old = np.zeros(original.shape[:2], dtype=bool)
    for y in range(345, 399):
        for x in range(610, 675):
            red, green, blue = map(int, original[y, x])
            old[y, x] = red > 95 and blue - red > 34 and blue - green > 43
    for y, x in zip(*np.where(old)):
        for radius in (3, 6, 10):
            y0, y1 = max(0, y - radius), min(original.shape[0], y + radius + 1)
            x0, x1 = max(0, x - radius), min(original.shape[1], x + radius + 1)
            candidates = original[y0:y1, x0:x1][~old[y0:y1, x0:x1]]
            if len(candidates) >= 6:
                cleaned[y, x] = np.median(candidates, axis=0).astype(np.uint8)
                break
    return Image.fromarray(cleaned, "RGB").convert("RGBA")


def mockup(place: str, full_ring: Image.Image) -> None:
    screenshot = Image.open(REFS / f"ingame_ring_now_{place}.png").convert("RGBA")
    if screenshot.size != (1280, 720):
        raise ValueError(f"Unexpected screenshot size for {place}")
    clean = remove_old_ring(screenshot)
    ring_2x = full_ring.resize((56, 56), Image.Resampling.NEAREST)
    opacity = ring_2x.getchannel("A").point(lambda a: round(a * 0.55))
    # The screenshot already contains the player; keep her opaque foreground
    # in front of the newly composited ground ring.
    foreground = Image.new("L", screenshot.size)
    ImageDraw.Draw(foreground).polygon(
        [(635, 319), (648, 319), (660, 334), (665, 350), (663, 367),
         (656, 381), (650, 386), (631, 386), (622, 377), (619, 360),
         (624, 341)], fill=255
    )
    covered = foreground.crop((613, 342, 669, 398))
    opacity = np.asarray(opacity).copy()
    opacity[np.asarray(covered) > 0] = 0
    ring_2x.putalpha(Image.fromarray(opacity, "L"))
    clean.alpha_composite(ring_2x, (613, 342))
    clean.convert("RGB").save(HERE / f"lappland_ring_full_mockup_{place}.png")


def main() -> None:
    roles = motif_roles()
    sprites = {state: render_state(roles, state) for state in PALETTES}
    for state, sprite in sprites.items():
        sprite.save(HERE / f"lappland_ring_{state}.png")
        on_grey(sprite, 8).save(HERE / f"lappland_ring_{state}_8x.png")
        on_grey(assemble([sprite] * 3), 8).save(HERE / f"lappland_ring_{state}_assembled_8x.png")
    on_grey(assemble([sprites["lit"], sprites["empty"], sprites["empty"]]), 8).save(
        HERE / "lappland_ring_mixed_assembled_8x.png"
    )
    for place in ("mine", "snow"):
        mockup(place, assemble([sprites["full"]] * 3))
    manifest = {"segments": [
        {"file": f"lappland_ring_{state}.png", "state": state, "size": [SIZE, SIZE],
         "centre": [14, 14], "segment_centre_deg": 0, "span_deg": 100,
         "leading_end": "left"}
        for state in ("empty", "lit", "full")
    ]}
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    masks = [np.asarray(sprite.getchannel("A")) for sprite in sprites.values()]
    assert all(np.array_equal(masks[0], m) for m in masks[1:])
    assert set(np.unique(masks[0])) <= {0, 255}
    ys, xs = np.where(masks[0] == 255)
    radii = np.hypot(xs - CENTRE[0], ys - CENTRE[1])
    assert len(xs) == 75 and radii.min() == 9 and radii.max() <= 13.05
    full_pixels = np.asarray(sprites["full"])
    white_tip_count = int(np.count_nonzero(np.all(full_pixels[:, :, :3] == (232, 236, 242), axis=2)))
    assert white_tip_count == 1
    notes = ["Batch L1 v1 validation", "Canvas: 28 x 28 RGBA; centre: (14, 14); nominal outer/inner radii: 13/9 px.",
             "Segment: top, 100 degrees; counter-clockwise leading fang on left.",
             "All three silhouettes: pixel-identical.", "All alpha values: binary (0 or 255).", ""]
    notes.extend([f"Opaque pixels per state: {len(xs)}", 
                  f"Measured pixel-centre radius range: {radii.min():.2f}..{radii.max():.2f} px",
                  f"Full-state blade-white tip pixels: {white_tip_count}", ""])
    for state, sprite in sprites.items():
        arr = np.asarray(sprite)
        palette = sorted({"#" + bytes(color[:3]).hex() for color in arr.reshape(-1, 4) if color[3]})
        assert len(palette) <= 5
        notes.append(f"{state}: {', '.join(palette)} ({len(palette)} colours)")
    (HERE / "validation.txt").write_text("\n".join(notes) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
