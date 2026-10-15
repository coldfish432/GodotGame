"""Assemble painted eight-view sheets into clean N3 action and walk grids."""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent
SOURCES = HERE / "source_paintings"
sys.path.insert(0, str(HERE.parent))
from reduce_n1 import components  # noqa: E402
CELL = 320
FOOT = 292
FULL_IDLE_HEIGHT = 230

ACTION = ["idle", "start", "charge", "strike", "recover"]
WALK = ["walk_contact_a", "walk_pass_a", "walk_contact_b", "walk_pass_b"]

# Source sheets are four across, two down. Each tuple is (source slot, mirror).
# The generated back views are in slots 4/5. Mirroring slot 5 supplies the
# opposite rear diagonal without inventing a face or a second horn.
ACTION_MAP = [(0, False), (7, False), (6, True), (5, True),
              (4, False), (5, False), (6, False), (1, False)]
WALK_MAP = [(0, False), (7, False), (6, False), (5, True),
            (4, False), (5, False), (2, False), (1, False)]
LAMP_CORE = Image.open(SOURCES / "lamp_core.png").convert("RGBA").resize(
    (48, 36), Image.Resampling.LANCZOS)


def seam(counts: np.ndarray, approximate: int, radius: int) -> int:
    lo = max(1, approximate - radius)
    hi = min(len(counts) - 1, approximate + radius)
    return min(range(lo, hi + 1), key=lambda i: (int(counts[i]), abs(i - approximate)))


def cut_figures(path: Path) -> tuple[list[Image.Image], list[int]]:
    sheet = Image.open(path).convert("RGBA")
    alpha = np.asarray(sheet.getchannel("A")) > 128
    mid = seam(alpha.sum(axis=1), sheet.height // 2, 70)
    figures: list[Image.Image] = []
    seam_ink: list[int] = []
    for row, (y0, y1) in enumerate(((0, mid), (mid, sheet.height))):
        strip = alpha[y0:y1]
        counts = strip.sum(axis=0)
        splits = [0] + [seam(counts, round(sheet.width * i / 4), 55)
                        for i in (1, 2, 3)] + [sheet.width]
        seam_ink.extend(int(counts[x]) for x in splits[1:-1])
        for col in range(4):
            x0, x1 = splits[col], splits[col + 1]
            part = sheet.crop((x0, y0, x1, y1))
            box = part.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
            if box is None:
                raise ValueError(f"Missing painted figure: {path.name} slot {row * 4 + col}")
            margin = 3
            box = (max(0, box[0] - margin), max(0, box[1] - margin),
                   min(part.width, box[2] + margin), min(part.height, box[3] + margin))
            figures.append(part.crop(box))
    return figures, seam_ink


def make_board(names: list[str], mapping: list[tuple[int, bool]], output: str,
               scale: float) -> None:
    board = Image.new("RGBA", (8 * CELL, len(names) * CELL))
    for row, name in enumerate(names):
        figures, seam_ink = cut_figures(SOURCES / f"{name}_turnaround.png")
        if name in ("idle", "start"):
            clean = Image.open(SOURCES / f"rear_{name}_clean.png").convert("RGBA")
            box = clean.getchannel("A").point(lambda a: 255 if a > 128 else 0).getbbox()
            if box is None:
                raise ValueError(f"Empty corrected rear view for {name}")
            figures[5] = clean.crop(box).resize(figures[5].size, Image.Resampling.LANCZOS)
        print(name, "source heights", [f.height for f in figures],
              "seam ink", seam_ink)
        for col, (slot, mirror) in enumerate(mapping):
            figure = figures[slot]
            if mirror:
                figure = ImageOps.mirror(figure)
            size = (round(figure.width * scale), round(figure.height * scale))
            figure = figure.resize(size, Image.Resampling.LANCZOS)
            x = col * CELL + (CELL - figure.width) // 2
            y = row * CELL + FOOT - figure.height
            if x < col * CELL or x + figure.width > (col + 1) * CELL or y < row * CELL:
                raise ValueError(f"Figure leaves cell {output} r{row} c{col}: {size}")
            board.alpha_composite(figure, (x, y))
    # Reuse the painted teal lamp core from the accepted v2 identity. This
    # covers dark micro-bands in the generated turnarounds that reduce to
    # isolated bright pixels at 30 px. All caps/shafts stay painted sources.
    lamps = 0
    for row in range(len(names)):
        for col in range(8):
            cell = np.asarray(board.crop((col * CELL, row * CELL,
                                          (col + 1) * CELL, (row + 1) * CELL)))
            rgb = cell[..., :3]
            mask = ((cell[..., 3] > 128) & (rgb[..., 1] > 120) &
                    (rgb[..., 2] > 110) & (rgb[..., 1] > rgb[..., 0] * 1.5))
            candidates = [comp for comp in components(mask)
                          if len(comp) >= 80 and comp[:, 0].min() < 245]
            if not candidates:
                raise ValueError(f"No painted pole lamp in {output} r{row} c{col}")
            top = min(candidates, key=lambda comp: comp[:, 0].min())
            cx = round((int(top[:, 1].min()) + int(top[:, 1].max())) / 2)
            cy = round((int(top[:, 0].min()) + int(top[:, 0].max())) / 2)
            board.alpha_composite(LAMP_CORE,
                                  (col * CELL + cx - LAMP_CORE.width // 2,
                                   row * CELL + cy - LAMP_CORE.height // 2))
            lamps += 1
    board.save(HERE / output)
    print(output, board.size, "painted lamp cores", lamps)


def main() -> None:
    idle, _ = cut_figures(SOURCES / "idle_turnaround.png")
    scale = FULL_IDLE_HEIGHT / idle[0].height
    print("uniform painted-source scale", round(scale, 6))
    make_board(ACTION, ACTION_MAP, "sentinel_action.png", scale)
    make_board(WALK, WALK_MAP, "sentinel_walk.png", scale)


if __name__ == "__main__":
    main()
