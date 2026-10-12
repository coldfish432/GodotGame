"""Amiya (Guard) runtime sheets from Sol's batch A1 sources (Pillow + numpy).

Run from godot_assets/: python prepare_amiya_guard_atlas.py

Inputs: the walk source from art/characters/amiya/batch_A1_v1 and the combat
source from batch_A1_v2 (A1_revision_v2.md: S and NW rows, dash and finisher
redrawn), regular 256 px grids (walk 4x8, combat 16x5; rows as in A_brief_v1.md).
Outputs, replacing the stand-ins from prepare_amiya_placeholder.py:
  amiya_guard_walk_32.png    4x8 cells of 32
  amiya_guard_idle_32.png    2x8 cells of 32: Sol's standing idle (batch I1 v2,
      stand + breath, downsampled like the walk)
  amiya_guard_combat_64.png  16x5 cells of 64
  ../ui/art/amiya_guard_portrait.png  84x84 full-body portrait for the departure
      card, settlement and pack window, from the walk source's front passing
      frame. 84 is shown at exactly 2x (168) or 3x (252); the 32 px field frame
      scaled 5.25x looked blurry (用户 2026-10-10: 结算界面阿米娅好糊).

Same treatment as Lappland's: premultiplied BOX downsample, alpha thresholded
at 128. Combat frames are scaled per row so the standing body matches that
direction's walk height, and placed so feet and body centre land where the
walk frame's do inside a 64 cell that shares a 32 frame's centre
(prepare_combat_atlas.py), so switching sheets does not move her.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / "art" / "characters" / "amiya" / "batch_A1_v1"
COMBAT_SOURCE = ROOT.parent / "art" / "characters" / "amiya" / "batch_A1_v2"
# I1 v2: v1 with NW and NE redrawn back-facing to match her walk (I1_revision_v2.md).
IDLE_SOURCE = ROOT.parent / "art" / "characters" / "idle" / "batch_I1_v2" / "amiya_guard_idle_source.png"
# Rows that would keep the walk passing-frame idle; none since I1 v2.
IDLE_HOLD: set[int] = set()
SRC = 256
WALK = 32
CELL = 64
# Rows under this many opaque source pixels are sword or ear, not body.
BODY_ROW_PIXELS = 24
# Combat columns that are not an upright stance (lunge, dash, flurry,
# finisher, hurt), left out when measuring standing height.
NON_STANDING = {8, 9, 11, 12, 13, 14, 15}
PASSING = (1, 3)


def downsample(rgba: np.ndarray, size: int) -> np.ndarray:
	cell = Image.fromarray(rgba, "RGBA").convert("RGBa").resize((size, size), Image.Resampling.BOX).convert("RGBA")
	cell.putalpha(cell.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
	return np.array(cell)


def drop_hair_crumbs(cell: np.ndarray) -> np.ndarray:
	"""Remove detached brown specks (< 20 texels): hair the source cut off at a
	cell edge (A1 v2, NW cols 6-7). Detached blade tips are dark or cyan and stay."""
	from collections import deque
	solid = cell[:, :, 3] > 0
	seen = np.zeros_like(solid)
	parts = []
	for y0, x0 in zip(*np.nonzero(solid)):
		if seen[y0, x0]:
			continue
		queue, part = deque([(y0, x0)]), []
		seen[y0, x0] = True
		while queue:
			y, x = queue.popleft()
			part.append((y, x))
			for dy in (-1, 0, 1):
				for dx in (-1, 0, 1):
					yy, xx = y + dy, x + dx
					if 0 <= yy < solid.shape[0] and 0 <= xx < solid.shape[1] and solid[yy, xx] and not seen[yy, xx]:
						seen[yy, xx] = True
						queue.append((yy, xx))
		parts.append(part)
	biggest = max(len(part) for part in parts)
	for part in parts:
		if len(part) == biggest or len(part) >= 20:
			continue
		rgb = np.array([cell[y, x, :3] for y, x in part], float).mean(0)
		if rgb[0] > rgb[2] + 20:
			for y, x in part:
				cell[y, x] = 0
	return cell


def torso_x(alpha: np.ndarray) -> float:
	"""Median column of the torso band (35-70% down the figure), which ignores
	the sword, ponytail and ear tips that swing between walk frames."""
	ys = np.nonzero(alpha.any(1))[0]
	top, height = ys.min(), ys.max() - ys.min()
	band = alpha[top + int(height * 0.35):top + int(height * 0.7)]
	return float(np.median(np.nonzero(band)[1]))


def steady_walk(sheet: np.ndarray) -> np.ndarray:
	"""Shift each walk frame sideways so its torso sits on the row's median line.

	A1's W frame 3 sat 26 px (3 texels) behind the others, so walking left
	lurched back and forth (用户 2026-10-10: 向左走的时候前后顿挫感太强); E and
	NE drifted too. Legs, arms and hair still swing; only the body stops sliding.
	"""
	out = np.zeros_like(sheet)
	for r in range(8):
		frames = [sheet[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC] for c in range(4)]
		xs = [torso_x(f[:, :, 3] >= 128) for f in frames]
		target = float(np.median(xs))
		for c, frame in enumerate(frames):
			dx = int(round(target - xs[c]))
			moved = np.zeros_like(frame)
			if dx >= 0: moved[:, dx:] = frame[:, :SRC - dx]
			else: moved[:, :dx] = frame[:, -dx:]
			out[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC] = moved
	return out


def body_extent(alpha: np.ndarray) -> tuple[int, int, float]:
	rows = np.nonzero(alpha.sum(1) >= BODY_ROW_PIXELS)[0]
	body = alpha[rows.min():rows.max() + 1]
	return int(rows.min()), int(rows.max()), float(np.median(np.nonzero(body)[1]))


def cells(sheet: np.ndarray, cols: int, rows: int):
	for r in range(rows):
		for c in range(cols):
			yield r, c, sheet[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC]


def main() -> None:
	walk_src = steady_walk(np.array(Image.open(SOURCE / "amiya_guard_walk_source.png").convert("RGBA")))
	walk = np.zeros((8 * WALK, 4 * WALK, 4), np.uint8)
	for r, c, cell in cells(walk_src, 4, 8):
		walk[r * WALK:(r + 1) * WALK, c * WALK:(c + 1) * WALK] = downsample(cell, WALK)
	Image.fromarray(walk).save(ROOT / "amiya_guard_walk_32.png")

	idle = np.zeros((8 * WALK, 2 * WALK, 4), np.uint8)
	for r in range(8):
		def spread(c):
			a = walk[r * WALK:(r + 1) * WALK, c * WALK:(c + 1) * WALK, 3] > 0
			foot = np.nonzero(a.any(1))[0][-1]
			xs = np.nonzero(a[foot - 3:foot + 1].any(0))[0]
			return xs.max() - xs.min(), foot
		column = min(PASSING, key=lambda c: spread(c)[0])
		base = walk[r * WALK:(r + 1) * WALK, column * WALK:(column + 1) * WALK].copy()
		split = spread(column)[1] - 9
		breath = base.copy()
		breath[1:split + 1] = base[0:split]
		breath[0] = 0
		idle[r * WALK:(r + 1) * WALK, :WALK] = base
		idle[r * WALK:(r + 1) * WALK, WALK:] = breath
	if IDLE_SOURCE.exists():
		drawn = np.array(Image.open(IDLE_SOURCE).convert("RGBA"))
		for r in range(8):
			if r in IDLE_HOLD:
				continue
			for c in range(2):
				idle[r * WALK:(r + 1) * WALK, c * WALK:(c + 1) * WALK] = downsample(drawn[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC], WALK)
	Image.fromarray(idle).save(ROOT / "amiya_guard_idle_32.png")

	combat_src = np.array(Image.open(COMBAT_SOURCE / "amiya_guard_combat_source.png").convert("RGBA"))
	combat = np.zeros((5 * CELL, 16 * CELL, 4), np.uint8)
	to_runtime = WALK / SRC
	for r in range(5):
		walk_top, walk_foot, walk_x = body_extent(walk_src[r * SRC:(r + 1) * SRC, SRC:2 * SRC, 3] >= 128)
		row = [combat_src[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC] for c in range(16)]
		heights = [body_extent(cell[:, :, 3] >= 128) for c, cell in enumerate(row) if c not in NON_STANDING]
		scale = (walk_foot - walk_top) * to_runtime / float(np.median([foot - top for top, foot, _ in heights]))
		target_foot = CELL / 2 + (walk_foot + 1) * to_runtime - WALK / 2
		target_x = CELL / 2 + (walk_x + 0.5) * to_runtime - WALK / 2
		canvas_size = round(CELL / scale)
		actual = CELL / canvas_size
		for c, cell in enumerate(row):
			_, foot, centre = body_extent(cell[:, :, 3] >= 128)
			canvas = Image.new("RGBA", (canvas_size, canvas_size))
			canvas.paste(Image.fromarray(cell, "RGBA"), (round(target_x / actual - (centre + 0.5)), round(target_foot / actual - (foot + 1))))
			combat[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = drop_hair_crumbs(downsample(np.array(canvas), CELL))
		print(f"row {r}: scale {scale:.4f}, canvas {canvas_size}, feet {target_foot:.1f}, centre {target_x:.1f}")
	Image.fromarray(combat).save(ROOT / "amiya_guard_combat_64.png")

	PORTRAIT = 84
	front = walk_src[0:SRC, PASSING[0] * SRC:(PASSING[0] + 1) * SRC].copy()
	ys, xs = np.nonzero(front[:, :, 3] >= 128)
	figure = front[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
	# Fit the figure into the square with a 2 px margin, feet on the bottom margin.
	side = round(max(figure.shape[0], figure.shape[1]) * PORTRAIT / (PORTRAIT - 4))
	canvas = np.zeros((side, side, 4), np.uint8)
	top = side - round(side * 2 / PORTRAIT) - figure.shape[0]
	left = (side - figure.shape[1]) // 2
	canvas[top:top + figure.shape[0], left:left + figure.shape[1]] = figure
	Image.fromarray(downsample(canvas, PORTRAIT)).save(ROOT.parent / "ui" / "art" / "amiya_guard_portrait.png")


if __name__ == "__main__":
	main()
