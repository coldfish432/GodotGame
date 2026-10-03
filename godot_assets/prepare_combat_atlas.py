"""Rebuild the runtime combat atlas from the imagegen source (requires Pillow + numpy).

Run from any directory: python godot_assets/prepare_combat_atlas.py
The original source is preserved.

Why not a uniform grid: the generated sheet is not laid out on a regular grid
(swords reach into neighbouring cells) and its character is drawn at a
different scale from the walk sheet. Each sprite is therefore isolated as a
connected alpha region, scaled so the body matches the walk sheet's height for
the same direction, and placed so its feet and body centre land exactly where
the walk frame's do. Cells are 64x64 so swords are not clipped; the texture
centre sits at the same point relative to the feet as a 32x32 walk frame's, so
the billboard needs no extra offset.

Downsampling uses a premultiplied BOX filter and a hard alpha threshold, the
same treatment as lappland_8dir_walk_32.png.
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
CELL = 64
WALK_CELL = 32
COLUMNS = 14
# Source rows: S, SW, W, NW, N. Walk sheet rows use the same first five.
ROWS = 5
MIN_SPRITE_PIXELS = 2000
# A row counts as "body" (not a thin sword blade) with at least this many
# opaque source pixels; used for measuring height and the foot line.
BODY_ROW_PIXELS = 14
# Columns whose pose is not an upright stance (raised crossed swords, deep
# crouch, recoil) are excluded when measuring the standing height.
NON_STANDING = {6, 7, 8, 13}


def label(mask: np.ndarray) -> list[np.ndarray]:
	"""8-connected components larger than MIN_SPRITE_PIXELS, left to right."""
	height, width = mask.shape
	labels = np.zeros(mask.shape, np.int32)
	found = []
	for y0, x0 in zip(*np.nonzero(mask)):
		if labels[y0, x0]:
			continue
		index = len(found) + 1
		labels[y0, x0] = index
		queue = deque([(y0, x0)])
		pixels = []
		while queue:
			y, x = queue.popleft()
			pixels.append((y, x))
			for dy in (-1, 0, 1):
				for dx in (-1, 0, 1):
					yy, xx = y + dy, x + dx
					if 0 <= yy < height and 0 <= xx < width and mask[yy, xx] and not labels[yy, xx]:
						labels[yy, xx] = index
						queue.append((yy, xx))
		found.append(pixels)
	parts = []
	for index, pixels in enumerate(found, 1):
		if len(pixels) > MIN_SPRITE_PIXELS:
			parts.append(labels == index)
	parts.sort(key=lambda part: np.nonzero(part.any(0))[0].min())
	return parts


def split_widest(parts: list[np.ndarray]) -> list[np.ndarray]:
	"""Two neighbouring poses touching by a sword tip: cut at the thinnest column."""
	widest = max(range(len(parts)), key=lambda i: np.ptp(np.nonzero(parts[i].any(0))[0]))
	part = parts[widest]
	columns = np.nonzero(part.any(0))[0]
	middle = (columns.min() + columns.max()) // 2
	counts = part.sum(0)
	cut = min(range(middle - 40, middle + 40), key=lambda x: counts[x])
	left, right = part.copy(), part.copy()
	left[:, cut:] = False
	right[:, :cut] = False
	return parts[:widest] + [left, right] + parts[widest + 1:]


def body_extent(mask: np.ndarray) -> tuple[int, int, float]:
	"""Top row, foot row and horizontal median of a sprite, ignoring thin blades."""
	rows = np.nonzero(mask.sum(1) >= BODY_ROW_PIXELS)[0]
	return int(rows.min()), int(rows.max()), float(np.median(np.nonzero(mask)[1]))


def row_bands(alpha: np.ndarray) -> list[tuple[int, int]]:
	occupied = alpha.any(1)
	bands, start = [], None
	for y, filled in enumerate(occupied):
		if filled and start is None:
			start = y
		elif not filled and start is not None:
			bands.append((start, y))
			start = None
	if start is not None:
		bands.append((start, len(occupied)))
	return bands


def main() -> None:
	source = Image.open(ROOT / "lappland_combat_source.png").convert("RGBA")
	pixels = np.array(source)
	alpha = pixels[:, :, 3] >= 128
	walk_source = np.array(Image.open(ROOT / "lappland_8dir_walk_4frames.png").convert("RGBA"))
	walk_size = walk_source.shape[0] // 8
	bands = row_bands(alpha)
	assert len(bands) == ROWS, f"expected {ROWS} sprite rows, found {len(bands)}"

	atlas = Image.new("RGBA", (COLUMNS * CELL, ROWS * CELL))
	for row, (top, bottom) in enumerate(bands):
		parts = label(alpha[top:bottom])
		while len(parts) < COLUMNS:
			parts = split_widest(parts)
		assert len(parts) == COLUMNS, f"row {row}: {len(parts)} sprites"

		walk_cell = walk_source[row * walk_size:(row + 1) * walk_size, :walk_size, 3] >= 128
		walk_top, walk_foot, walk_x = body_extent(walk_cell)
		to_runtime = WALK_CELL / walk_size
		standing = [body_extent(part) for column, part in enumerate(parts) if column not in NON_STANDING]
		standing_height = float(np.median([foot - head for head, foot, _ in standing]))
		scale = (walk_foot - walk_top) * to_runtime / standing_height
		# Where the walk frame's feet and body centre sit inside a 64x64 cell
		# that shares a 32x32 frame's centre.
		target_foot = CELL / 2 + (walk_foot + 1) * to_runtime - WALK_CELL / 2
		target_x = CELL / 2 + (walk_x + 0.5) * to_runtime - WALK_CELL / 2

		band = pixels[top:bottom]
		for column, part in enumerate(parts):
			sprite = np.where(part[:, :, None], band, 0).astype(np.uint8)
			_, foot, center_x = body_extent(part)
			# Canvas in source pixels whose downsample is exactly one cell.
			canvas_size = round(CELL / scale)
			actual = CELL / canvas_size
			offset_x = round(target_x / actual - (center_x + 0.5))
			offset_y = round(target_foot / actual - (foot + 1))
			canvas = Image.new("RGBA", (canvas_size, canvas_size))
			canvas.paste(Image.fromarray(sprite, "RGBA"), (offset_x, offset_y))
			cell = canvas.convert("RGBa").resize((CELL, CELL), Image.Resampling.BOX).convert("RGBA")
			cell.putalpha(cell.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
			atlas.paste(cell, (column * CELL, row * CELL))
		print(f"row {row}: scale {scale:.4f}, feet y {target_foot:.1f}, centre x {target_x:.1f}")

	atlas.save(ROOT / "lappland_combat_64.png")
	print(f"Saved {atlas.width}x{atlas.height}, {ROWS * COLUMNS} cells of {CELL}x{CELL}, RGBA")


if __name__ == "__main__":
	main()
