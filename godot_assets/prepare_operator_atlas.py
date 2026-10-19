"""Runtime sheets for the recruitable operators from Sol's batch <CODE>1 sources
(干员寻访策划案 §10; briefs art/characters/<id>/<CODE>_brief_v1.md), the same
treatment as Amiya's (prepare_amiya_guard_atlas.py): premultiplied BOX
downsample, alpha thresholded at 128; then a 1 px dark outline like Lappland's.

    python godot_assets/prepare_operator_atlas.py [id ...]

Per operator, from art/characters/<id>/batch_<CODE>1_v1/:
  <id>_walk_32.png    4x8 cells of 32, each row's frames steadied on the torso
  <id>_idle_32.png    2x8 cells of 32
  <id>_combat_64.png  Nx5 cells of 64; each row scaled so its standing frames
      match that direction's walk height, feet and body centre where the walk
      frame's are (a 64 cell sharing a 32 frame's centre)
  ../ui/art/<id>_portrait.png  84x84, from the walk's front passing frame
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_amiya_guard_atlas import body_extent, downsample, drop_hair_crumbs, steady_walk  # noqa: E402

ROOT = Path(__file__).resolve().parent
CHARS = ROOT.parent / "art" / "characters"
OPERATORS = {"hellagur": "HG", "hoshiguma": "HS", "typhon": "TY", "rosa": "RS", "lin": "LN", "santalla": "SN", "texas": "TX"}
SRC = 256
WALK = 32
CELL = 64
PASSING = (1, 3)
PORTRAIT = 84
# Standing height of the front walk frame in texels (寻访干员美术需求总表_v1 §6
# 第 4 条: PRTS heights compressed, Lappland's body = 1.00, her frame 30). Sol
# drew all seven at one height (28), so the sources are scaled about the feet
# to these before the downsample.
HEIGHT = {"hellagur": 31, "hoshiguma": 31, "rosa": 31, "lin": 30, "santalla": 30, "texas": 30, "typhon": 29}


# A 1 px dark outline round each figure, outside its own pixels, like
# Lappland's sheets (用户 2026-10-16: 给 7 名干员烘焙时加 1 px 深色描边（和拉普
# 兰德一致）); the colour is the one N1 enemies and item icons use.
OUTLINE = (11, 12, 13, 255)


def outline(sheet: np.ndarray, cell: int) -> np.ndarray:
	"""Cell by cell, so a figure's outline never spills into its neighbour."""
	out = sheet.copy()
	for y in range(0, sheet.shape[0], cell):
		for x in range(0, sheet.shape[1], cell):
			solid = sheet[y:y + cell, x:x + cell, 3] > 0
			pad = np.pad(solid, 1)
			ring = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~solid
			out[y:y + cell, x:x + cell][ring] = OUTLINE
	return out


def grow(sheet: np.ndarray, factor: float, cols: int, rows: int) -> np.ndarray:
	"""Every SRC cell scaled by `factor` about its bottom centre."""
	if abs(factor - 1.0) < 1e-3: return sheet
	out = np.zeros_like(sheet)
	size = round(SRC * factor)
	for r in range(rows):
		for c in range(cols):
			cell = Image.fromarray(sheet[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC], "RGBA").convert("RGBa")
			big = cell.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
			canvas = Image.new("RGBA", (SRC, SRC))
			canvas.paste(big, ((SRC - size) // 2, SRC - size))
			out[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC] = np.array(canvas)
	return out


def front_height(walk_src: np.ndarray) -> int:
	cell = downsample(walk_src[0:SRC, SRC:2 * SRC], WALK)
	ys = np.nonzero((cell[:, :, 3] > 0).any(1))[0]
	return int(ys.max() - ys.min() + 1)


def build(op: str) -> dict:
	batch = CHARS / op / f"batch_{OPERATORS[op]}1_v1"
	sheets = {s["kind"]: s for s in json.loads((batch / "manifest.json").read_text(encoding="utf-8"))["sheets"]}
	walk_src = steady_walk(np.array(Image.open(batch / sheets["walk"]["file"]).convert("RGBA")))
	factor = HEIGHT.get(op, front_height(walk_src)) / front_height(walk_src)
	walk_src = grow(walk_src, factor, 4, 8)
	walk = np.zeros((8 * WALK, 4 * WALK, 4), np.uint8)
	for r in range(8):
		for c in range(4):
			walk[r * WALK:(r + 1) * WALK, c * WALK:(c + 1) * WALK] = downsample(walk_src[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC], WALK)
	Image.fromarray(outline(walk, WALK)).save(ROOT / f"{op}_walk_32.png")

	idle_src = grow(np.array(Image.open(batch / sheets["idle"]["file"]).convert("RGBA")), factor, 2, 8)
	idle = np.zeros((8 * WALK, 2 * WALK, 4), np.uint8)
	for r in range(8):
		for c in range(2):
			idle[r * WALK:(r + 1) * WALK, c * WALK:(c + 1) * WALK] = downsample(idle_src[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC], WALK)
	Image.fromarray(outline(idle, WALK)).save(ROOT / f"{op}_idle_32.png")

	cols = int(sheets["combat"]["cols"])
	combat_src = np.array(Image.open(batch / sheets["combat"]["file"]).convert("RGBA"))
	combat = np.zeros((5 * CELL, cols * CELL, 4), np.uint8)
	to_runtime = WALK / SRC
	scales = []
	for r in range(5):
		walk_top, walk_foot, walk_x = body_extent(walk_src[r * SRC:(r + 1) * SRC, SRC:2 * SRC, 3] >= 128)
		row = [combat_src[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC] for c in range(cols)]
		# The standing frames are the tallest; lunges, crouches and the hurt
		# frame are shorter, so the upper half of the heights is the stance.
		heights = sorted(foot - top for top, foot, _ in (body_extent(cell[:, :, 3] >= 128) for cell in row))
		stance = float(np.median(heights[len(heights) // 2:]))
		scale = (walk_foot - walk_top) * to_runtime / stance
		target_foot = CELL / 2 + (walk_foot + 1) * to_runtime - WALK / 2
		target_x = CELL / 2 + (walk_x + 0.5) * to_runtime - WALK / 2
		canvas_size = round(CELL / scale)
		actual = CELL / canvas_size
		for c, cell in enumerate(row):
			_, foot, centre = body_extent(cell[:, :, 3] >= 128)
			canvas = Image.new("RGBA", (canvas_size, canvas_size))
			canvas.paste(Image.fromarray(cell, "RGBA"), (round(target_x / actual - (centre + 0.5)), round(target_foot / actual - (foot + 1))))
			combat[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = drop_hair_crumbs(downsample(np.array(canvas), CELL))
		scales.append(round(scale, 4))
	Image.fromarray(outline(combat, CELL)).save(ROOT / f"{op}_combat_64.png")

	front = walk_src[0:SRC, PASSING[0] * SRC:(PASSING[0] + 1) * SRC].copy()
	ys, xs = np.nonzero(front[:, :, 3] >= 128)
	figure = front[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
	side = round(max(figure.shape[0], figure.shape[1]) * PORTRAIT / (PORTRAIT - 4))
	canvas = np.zeros((side, side, 4), np.uint8)
	top = side - round(side * 2 / PORTRAIT) - figure.shape[0]
	left = (side - figure.shape[1]) // 2
	canvas[top:top + figure.shape[0], left:left + figure.shape[1]] = figure
	Image.fromarray(outline(downsample(canvas, PORTRAIT), PORTRAIT)).save(ROOT.parent / "ui" / "art" / f"{op}_portrait.png")
	a = walk[0:WALK, WALK:2 * WALK, 3] > 0
	ys = np.nonzero(a.any(1))[0]
	return {"walk_S_height": int(ys.max() - ys.min() + 1), "combat_cols": cols, "row_scales": scales}


if __name__ == "__main__":
	for op in sys.argv[1:] or list(OPERATORS):
		print(op, build(op))
