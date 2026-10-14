"""NPC portraits and field sprites from Sol's chibi paintings (NPC_brief_v3.md).

The user accepted Sol's v3 paintings but not the reduced pixels (2026-10-13:
the native redraw "好丑…不像了"), so the game art is made here the way
Lappland's and Amiya's is (godot_assets/prepare_amiya_guard_atlas.py):
premultiplied BOX downsample of the painting, alpha thresholded at 50 %, no
palette reduction. The field sprites also get a 1 px dark outline and lose
crumbs of fewer than 4 texels.

The 4-frame idles are made on the painting before the downsample, so the
motion lands as sub-pixel shading rather than whole-pixel jumps:
- squad: one strip per operator (melee, sniper, logistics), each breathing
  (a 2.4 % squash from the feet at most); the logistics case's cyan latch is
  dark in frame 3 (on, on, off, on). The game stands them in a random
  triangle and starts each on its own frame, so they breathe out of step;
- 坎诺特: the coat's lower third sways, the helm stays still;
- 可露希尔: she breathes, the twin tails sway, the drone bobs a texel.

Outputs (next to this script):
  npc_squad_portrait.png 105x150, npc_cannot_portrait.png 85x150,
  npc_closure_portrait.png 85x150 (Sol's accepted P1 v3 pixels, copied),
  npc_squad_{melee,sniper,logistics}_idle.png, npc_cannot_idle.png 256x64,
  npc_closure_idle.png 256x64 (4 frames each, 3 fps, feet 2 px above the
  frame bottom, centred), preview_*_8x.png.

Run: python art/characters/npc/prepare_npc.py
"""
import math
import os
import shutil

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(os.path.dirname(HERE))
P1 = os.path.join(ART, "portraits", "batch_P1_v3")
F1 = os.path.join(ART, "field", "batch_F1C_v1", "source_paintings")
OUTLINE = (11, 12, 13, 255)
FRAMES = 4


def load(path):
    image = Image.open(path).convert("RGBA")
    return image.crop(image.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox())


def downsample(image, size):
    cell = image.convert("RGBa").resize(size, Image.Resampling.BOX).convert("RGBA")
    cell.putalpha(cell.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    return cell


def outlined(cell, crumbs=4):
    """Drop islands under `crumbs` texels, then ring the figure with OUTLINE."""
    padded = Image.new("RGBA", (cell.width + 2, cell.height + 2))
    padded.alpha_composite(cell, (1, 1))
    a = np.array(padded)
    mask = a[..., 3] > 0
    h, w = mask.shape
    seen = np.zeros_like(mask)
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]: continue
            stack, part = [(y, x)], []
            seen[y, x] = True
            while stack:
                cy, cx = stack.pop()
                part.append((cy, cx))
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(part) < crumbs:
                for p in part: mask[p] = False
    a[~mask, 3] = 0
    m = np.pad(mask, 1)
    ring = (m[1:-1, 1:-1] | m[:-2, 1:-1] | m[2:, 1:-1] | m[1:-1, :-2] | m[1:-1, 2:]) & ~mask
    a[ring] = OUTLINE
    return Image.fromarray(a, "RGBA")


def sprite(painting, height):
    """The painting at `height` texels including the outline."""
    inner = height - 2
    return outlined(downsample(painting, (max(1, round(painting.width * inner / painting.height)), inner)))


# --- motion on the painting ------------------------------------------------------

def breathe(painting, amount):
    """Squash towards the feet by `amount` of the height."""
    h = max(1, round(painting.height * (1.0 - amount)))
    out = Image.new("RGBA", painting.size)
    out.alpha_composite(painting.resize((painting.width, h), Image.Resampling.LANCZOS), (0, painting.height - h))
    return out


def shear_rows(painting, shift_of_row, columns=None):
    """Shift each row sideways by shift_of_row(y / height) pixels; only the
    columns `columns(x / width)` is true for move (the rest stay)."""
    src = np.array(painting)
    out = src.copy()
    h, w = src.shape[:2]
    xs = np.arange(w)
    keep = np.ones(w, bool) if columns is None else np.array([columns(x / w) for x in xs])
    for y in range(h):
        s = shift_of_row(y / h)
        if abs(s) < 0.5: continue
        moved = np.zeros_like(src[y])
        si = int(round(s))
        lo, hi = max(0, si), min(w, w + si)
        moved[lo:hi] = src[y, lo - si:hi - si]
        row = out[y]
        row[keep] = 0
        take = keep[np.clip(xs - si, 0, w - 1)] & (xs - si >= 0) & (xs - si < w)
        row[take] = moved[take]
        # what stays put is drawn over what moved (the body over the tails)
        still = ~keep & (src[y, :, 3] > 0)
        row[still] = src[y][still]
    return Image.fromarray(out, "RGBA")


def smooth(a, b, t):
    t = min(1.0, max(0.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)


def move_region(painting, box, dy):
    """Lift the pixels inside `box` (fractions l, t, r, b) by dy pixels."""
    w, h = painting.size
    l, t, r, b = int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)
    part = painting.crop((l, t, r, b))
    out = painting.copy()
    out.paste(Image.new("RGBA", part.size), (l, t))
    out.alpha_composite(part, (l, t + dy))
    return out


def dim_cyan(painting, box):
    """The case's latch off: cyan pixels inside `box` go dark grey."""
    a = np.array(painting).astype(np.int32)
    h, w = a.shape[:2]
    l, t, r, b = int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)
    region = a[t:b, l:r]
    cyan = (region[..., 2] > 150) & (region[..., 1] > 130) & (region[..., 0] < 120) & (region[..., 3] > 0)
    region[cyan, 0:3] = (58, 66, 70)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


# --- the three NPCs -----------------------------------------------------------------

SQUAD = ("melee", "sniper", "logistics")  # left to right in Sol's lineup


def squad_frames():
    """Each operator's own idle (the game stands them in a random triangle)."""
    lineup = load(os.path.join(F1, "squad_field_lineup.png"))
    alpha = np.array(lineup.getchannel("A")) >= 128
    filled = alpha.any(0)
    runs, start = [], None
    for x, f in enumerate(list(filled) + [False]):
        if f and start is None: start = x
        if not f and start is not None:
            if x - start > 60: runs.append((start, x))
            start = None
    figures = [load_part(lineup, r) for r in runs]
    out = {}
    for i, fig in enumerate(figures):
        frames = []
        for f in range(FRAMES):
            body = breathe(fig, (0.0, 0.012, 0.024, 0.012)[f])
            if SQUAD[i] == "logistics" and f == 2: body = dim_cyan(body, (0.6, 0.62, 1.0, 1.0))
            frames.append(lay_out([sprite(body, 28)], (64, 64)))
        out[SQUAD[i]] = frames
    return out


def load_part(lineup, run):
    part = lineup.crop((run[0], 0, run[1], lineup.height))
    return part.crop(part.getchannel("A").getbbox())


def cannot_frames():
    painting = load(os.path.join(P1, "source_paintings", "portrait_cannot_chibi.png"))
    amp = painting.width / 20.0 * 0.9  # about one texel at 20 texels wide
    frames = []
    for f in range(FRAMES):
        s = (0, 1, 0, -1)[f]
        swayed = shear_rows(painting, lambda t: s * amp * smooth(0.6, 0.86, t) * (1 - smooth(0.9, 0.97, t)))
        frames.append(lay_out([sprite(swayed, 35)], (64, 64)))
    return frames


def closure_frames():
    painting = load(os.path.join(P1, "source_paintings", "portrait_closure_chibi.png"))
    amp = painting.width / 24.0 * 0.8
    frames = []
    for f in range(FRAMES):
        s = (0, 1, 0, -1)[f]
        body = breathe(painting, (0.0, 0.006, 0.012, 0.006)[f])
        # tails: the outer columns below the head
        body = shear_rows(body, lambda t: s * amp * smooth(0.35, 0.8, t), columns=lambda u: u < 0.3 or 0.66 < u < 0.82)
        # drone: right of her head, a texel up and down
        body = move_region(body, (0.72, 0.12, 1.0, 0.42), round((0, -1, 0, 1)[f] * painting.height / 26.0))
        frames.append(lay_out([sprite(body, 28)], (64, 64)))
    return frames


def lay_out(cells, size, gap=0):
    """Cells side by side, centred, feet 2 px above the frame bottom."""
    frame = Image.new("RGBA", size)
    total = sum(c.width for c in cells) + gap * (len(cells) - 1)
    x = (size[0] - total) // 2
    for c in cells:
        frame.alpha_composite(c, (x, size[1] - 2 - c.height))
        x += c.width + gap
    return frame


def strip(frames, name):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames): out.alpha_composite(f, (i * w, 0))
    out.save(os.path.join(HERE, f"{name}.png"))
    preview = Image.new("RGBA", out.size, (33, 37, 43, 255))
    preview.alpha_composite(out)
    preview.resize((out.width * 8, out.height * 8), Image.Resampling.NEAREST).save(os.path.join(HERE, f"preview_{name}_8x.png"))
    gif = [Image.alpha_composite(Image.new("RGBA", f.size, (33, 37, 43, 255)), f).resize((w * 6, h * 6), Image.Resampling.NEAREST) for f in frames]
    gif[0].save(os.path.join(HERE, f"preview_{name}.gif"), save_all=True, append_images=gif[1:], duration=333, loop=0)


def portraits():
    painting = load(os.path.join(P1, "source_paintings", "portrait_squad_chibi.png"))
    scale = min(103 / painting.width, 146 / painting.height)
    cell = downsample(painting, (round(painting.width * scale), round(painting.height * scale)))
    canvas = Image.new("RGBA", (105, 150))
    canvas.alpha_composite(cell, ((105 - cell.width) // 2, 150 - cell.height))
    canvas.save(os.path.join(HERE, "npc_squad_portrait.png"))
    shutil.copyfile(os.path.join(P1, "portrait_cannot.png"), os.path.join(HERE, "npc_cannot_portrait.png"))
    shutil.copyfile(os.path.join(P1, "portrait_closure.png"), os.path.join(HERE, "npc_closure_portrait.png"))


if __name__ == "__main__":
    portraits()
    for member, frames in squad_frames().items(): strip(frames, f"npc_squad_{member}_idle")
    strip(cannot_frames(), "npc_cannot_idle")
    strip(closure_frames(), "npc_closure_idle")
    for name in [f"npc_squad_{m}_idle" for m in SQUAD] + ["npc_cannot_idle", "npc_closure_idle"]:
        image = Image.open(os.path.join(HERE, f"{name}.png"))
        w = image.width // FRAMES
        boxes = [image.crop((i * w, 0, (i + 1) * w, image.height)).getbbox() for i in range(FRAMES)]
        print(name, image.size, "figure", [b[3] - b[1] for b in boxes], "bottom", [image.height - b[3] for b in boxes])
