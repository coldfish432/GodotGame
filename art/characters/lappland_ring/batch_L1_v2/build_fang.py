"""Pack a painted wolf tooth into the exact L1 v2 ground-ring geometry."""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


HERE = Path(__file__).resolve().parent
REFS = HERE.parent / "refs"
PAINTING = HERE / "source_paintings" / "lappland_fang_painting.png"
SIZE = 42
CENTRE = (21, 21)
PREVIEW_GREY = (110, 113, 109, 255)
PALETTES = {
    "empty": {"outline": "#1c1a24", "body": "#4d5868", "highlight": "#4d5868"},
    "lit": {"outline": "#1c1a24", "body": "#8a9bb0", "highlight": "#e8ecf2"},
    "full": {"outline": "#1c1a24", "body": "#8e5cff", "highlight": "#cdb4ff"},
}


def rgba(hex_color: str) -> tuple[int, int, int, int]:
    return tuple(bytes.fromhex(hex_color[1:])) + (255,)


def painted_fang_roles() -> np.ndarray:
    """Return 0 transparent, 1 outline, 2 enamel, 3 painted highlight."""
    painting = Image.open(PAINTING).convert("RGBA")
    if painting.size != (1536, 1024):
        raise ValueError("Unexpected painted source size")
    # The source image is a painted study of this specific left-pointing
    # tooth. Sample its broad enamel glint and dark root facet at native size.
    sample = np.asarray(
        painting.crop((63, 257, 1445, 731)).resize((24, 9), Image.Resampling.BOX)
    )
    mask = np.zeros((SIZE, SIZE), dtype=bool)
    for y in range(SIZE):
        for x in range(SIZE):
            dx, up = x - CENTRE[0], CENTRE[1] - y
            radius = math.hypot(dx, up)
            angle = math.degrees(math.atan2(dx, up))
            t = (angle + 35) / 70
            if 0 <= t <= 1 and 20 - 6 * math.sqrt(t) <= radius <= 20:
                mask[y, x] = True
    # Pixel-grid finishing: a three-pixel flat crown and one enamel point.
    mask[1, 20:23] = True
    mask[5, 10] = True
    roles = np.zeros((SIZE, SIZE), dtype=np.uint8)
    roles[mask] = 2
    for y in range(SIZE):
        for x in range(SIZE):
            if not mask[y, x]:
                continue
            if any(
                ny < 0 or ny >= SIZE or nx < 0 or nx >= SIZE or not mask[ny, nx]
                for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))
            ):
                roles[y, x] = 1
    # One-pixel outer enamel glint, from the squared root toward two-thirds
    # of the arc. Its bright samples come from the painted fang, not a gradient.
    for x in range(17, 32):
        ys = np.where(mask[:, x])[0]
        if len(ys) < 3:
            continue
        y = int(ys.min()) + 1
        if roles[y, x] != 2:
            continue
        red, green, blue, alpha = map(int, sample[y - 1, x - 10])
        if alpha >= 128 and (red + green + blue) / 3 >= 150:
            roles[y, x] = 3
    # The painted dark angular facet near the broad root survives reduction.
    for x, y in ((27, 5), (28, 6)):
        if roles[y, x] == 2:
            roles[y, x] = 1
    roles[5, 10] = 3
    return roles


def render_state(roles: np.ndarray, state: str) -> Image.Image:
    out = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    for value, name in ((1, "outline"), (2, "body"), (3, "highlight")):
        out[roles == value] = rgba(PALETTES[state][name])
    if state == "full":
        out[5, 10] = rgba("#e8ecf2")
    return Image.fromarray(out, "RGBA")


def preview(sprite: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", sprite.size, PREVIEW_GREY)
    canvas.alpha_composite(sprite)
    return canvas.resize((sprite.width * 8, sprite.height * 8), Image.Resampling.NEAREST).convert("RGB")


def assemble(states: list[Image.Image]) -> Image.Image:
    if len(states) != 3:
        raise ValueError("Need three 120-degree positions")
    canvas = Image.new("RGBA", (SIZE, SIZE))
    for angle, sprite in zip((0, 120, 240), states):
        canvas.alpha_composite(sprite.rotate(angle, resample=Image.Resampling.NEAREST, center=CENTRE))
    return canvas


def remove_old_ring(screenshot: Image.Image) -> Image.Image:
    original = np.asarray(screenshot.convert("RGB"))
    clean = original.copy()
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
                clean[y, x] = np.median(candidates, axis=0).astype(np.uint8)
                break
    return Image.fromarray(clean, "RGB").convert("RGBA")


def mockup(place: str, full_ring: Image.Image) -> None:
    original = Image.open(REFS / f"ingame_ring_now_{place}.png").convert("RGBA")
    if original.size != (1280, 720):
        raise ValueError(f"Unexpected {place} screenshot size")
    background = remove_old_ring(original)
    composite = background.copy()
    ring = full_ring.resize((84, 84), Image.Resampling.NEAREST)
    ring.putalpha(ring.getchannel("A").point(lambda alpha: round(alpha * 0.65)))
    composite.alpha_composite(ring, (599, 328))  # screen centre (641, 370)
    # The two reference screenshots share the exact same player sprite but
    # different floors. Their equal pixels isolate her actual silhouette,
    # letting us redraw her on top without masking extra ground around her.
    mine = np.asarray(Image.open(REFS / "ingame_ring_now_mine.png").convert("RGB"))
    snow = np.asarray(Image.open(REFS / "ingame_ring_now_snow.png").convert("RGB"))
    equal = np.all(mine == snow, axis=2)
    player_mask = np.zeros(equal.shape, dtype=np.uint8)
    player_mask[319:389, 616:669] = equal[319:389, 616:669] * 255
    player_mask = Image.fromarray(player_mask, "L").filter(ImageFilter.MaxFilter(3))
    composite.paste(background, (0, 0), player_mask)
    composite.convert("RGB").save(HERE / f"lappland_fang_full_mockup_{place}.png")


def main() -> None:
    roles = painted_fang_roles()
    sprites = {state: render_state(roles, state) for state in PALETTES}
    for state, sprite in sprites.items():
        sprite.save(HERE / f"lappland_fang_{state}.png")
        preview(sprite).save(HERE / f"lappland_fang_{state}_8x.png")
        preview(assemble([sprite] * 3)).save(HERE / f"lappland_fang_{state}_assembled_8x.png")
    preview(assemble([sprites["lit"], sprites["empty"], sprites["empty"]])).save(
        HERE / "lappland_fang_mixed_assembled_8x.png"
    )
    for place in ("mine", "snow"):
        mockup(place, assemble([sprites["full"]] * 3))
    manifest = {"segments": [
        {"file": f"lappland_fang_{state}.png", "state": state, "size": SIZE,
         "centre": [21, 21], "outer_radius": 20, "root_radius": 14,
         "span_deg": 70, "tip": "left"}
        for state in ("empty", "lit", "full")
    ]}
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    alphas = [np.asarray(sprite.getchannel("A")) for sprite in sprites.values()]
    assert all(np.array_equal(alphas[0], alpha) for alpha in alphas[1:])
    assert set(np.unique(alphas[0])) <= {0, 255}
    ys, xs = np.where(alphas[0] == 255)
    radii = np.hypot(xs - CENTRE[0], ys - CENTRE[1])
    assert radii.max() <= 20.05 and radii.min() >= 13.9
    thirds = [0, 0, 0]
    for y, x in zip(ys, xs):
        angle = math.degrees(math.atan2(x - CENTRE[0], CENTRE[1] - y))
        t = (angle + 35) / 70
        thirds[min(2, max(0, int(t * 3)))] += 1
    assert thirds[0] < thirds[1] < thirds[2]
    full = np.asarray(sprites["full"])
    white_count = int(np.count_nonzero(np.all(full[:, :, :3] == (232, 236, 242), axis=2)))
    assert white_count == 1
    notes = ["Batch L1 v2 validation", "Canvas: 42 x 42 RGBA; centre: (21, 21).",
             "Outer radius: 20 px; root radius: 14 px; arc span: 70 degrees; left leading tip.",
             "All three silhouettes: pixel-identical.", "All alpha values: binary (0 or 255).",
             f"Opaque pixels per state: {len(xs)}",
             f"Measured pixel-centre radius range: {radii.min():.2f}..{radii.max():.2f} px",
             f"Opaque pixels tip/middle/root thirds: {thirds[0]}/{thirds[1]}/{thirds[2]}",
             f"Full-state blade-white tip pixels: {white_count}", ""]
    for state, sprite in sprites.items():
        arr = np.asarray(sprite)
        colors = sorted({"#" + bytes(color[:3]).hex() for color in arr.reshape(-1, 4) if color[3]})
        assert len(colors) <= (4 if state == "full" else 3)
        notes.append(f"{state}: {', '.join(colors)} ({len(colors)} colours)")
    (HERE / "validation.txt").write_text("\n".join(notes) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
