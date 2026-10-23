"""Runtime sheets for the Doctor and the crew walking the base from Sol's batch
CR sources (art/characters/crew/CR_brief_v1.md), the recruits' treatment
(prepare_operator_atlas.py) without the combat sheet: each source scaled about
the feet to its height, premultiplied BOX downsample, alpha thresholded at 128,
1 px dark outline.

    python godot_assets/prepare_crew_atlas.py [id ...]

Reads every art/characters/crew/batch_CR*_v*/manifest.json (a later version
wins for an id) and writes godot_assets/crew/<id>_walk_32.png and
<id>_idle_32.png, which LapplandAnimator3D.sheet finds by name.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_amiya_guard_atlas import downsample, steady_walk  # noqa: E402
from prepare_operator_atlas import SRC, WALK, front_height, grow, outline  # noqa: E402

ROOT = Path(__file__).resolve().parent
CREW = ROOT.parent / "art" / "characters" / "crew"
OUT = ROOT / "crew"
# Standing height of the front walk frame in texels, outline included, as the
# recruits' HEIGHT (Lappland's frame 30). CR_brief_v1 §5's table, one less:
# a 32 cell with the feet on row 30 holds 31 at most, so its 32s lost the top
# of the head.
HEIGHT = {"doctor": 30, "sharp": 31, "stormeye": 31, "pith": 29, "touch": 28, "tulip": 30, "mechanist": 31, "misery": 30,
	"reserve_vanguard": 29, "reserve_guard": 28, "reserve_defender": 31, "reserve_sniper": 29, "reserve_caster": 28,
	"reserve_medic": 27, "reserve_supporter": 29, "reserve_specialist": 28,
	# ST1b (batch_CR3_v1): Dobermann tall and upright, Kal'tsit a little shorter.
	"dobermann": 30, "kaltsit": 29}


def sources() -> dict:
	"""{id: {kind: path}} from the batches, later versions over earlier."""
	found: dict = {}
	def version(path: Path) -> int:
		return int(path.parent.name.rsplit("_v", 1)[-1] or 0)
	for manifest in sorted(CREW.glob("batch_CR*_v*/manifest.json"), key=version):
		for sheet in json.loads(manifest.read_text(encoding="utf-8"))["sheets"]:
			found.setdefault(sheet["id"], {})[sheet["kind"]] = manifest.parent / sheet["file"]
	return found


def bake(src: np.ndarray, cols: int) -> np.ndarray:
	out = np.zeros((8 * WALK, cols * WALK, 4), np.uint8)
	for r in range(8):
		for c in range(cols):
			out[r * WALK:(r + 1) * WALK, c * WALK:(c + 1) * WALK] = downsample(src[r * SRC:(r + 1) * SRC, c * SRC:(c + 1) * SRC], WALK)
	return outline(out, WALK)


def steady_idle(idle: np.ndarray) -> np.ndarray:
	"""The breath frame's feet are the standing frame's (CR_brief_v1 §2: from the
	knees down pixel-identical). Sol's differ by a texel here and there after
	the downsample, which shimmers at 2 FPS, so the lowest quarter of the
	standing figure is copied over."""
	out = idle.copy()
	for r in range(8):
		stand = idle[r * WALK:(r + 1) * WALK, 0:WALK]
		ys = np.nonzero(stand[:, :, 3].any(1))[0]
		knee = ys.max() + 1 - (ys.max() + 1 - ys.min()) // 4
		out[r * WALK + knee:(r + 1) * WALK, WALK:2 * WALK] = stand[knee:]
	return out


def headroom(sheet: np.ndarray) -> float:
	"""The most a sheet can grow about the cells' bottom (grow) before its
	tallest figure loses the top of the head, keeping one texel above it for
	the outline. Sol drew this crew taller in the cell than Amiya, so the
	heads of the tall ones reach the top first."""
	top = int(np.nonzero((sheet[:, :, 3] >= 128).reshape(-1, SRC, sheet.shape[1]).any(2).any(0))[0].min())
	return (SRC - SRC / WALK * 1.5) / (SRC - top)


def clipped(sheet: np.ndarray) -> int:
	"""Cells whose figure touches the top row (a head cut off)."""
	return sum(int(sheet[y, x:x + WALK, 3].any()) for y in range(0, sheet.shape[0], WALK) for x in range(0, sheet.shape[1], WALK))


def build(op: str, files: dict) -> dict:
	walk_src = steady_walk(np.array(Image.open(files["walk"]).convert("RGBA")))
	idle_src = np.array(Image.open(files["idle"]).convert("RGBA"))
	factor = min(HEIGHT.get(op, front_height(walk_src)) / front_height(walk_src), headroom(walk_src), headroom(idle_src))
	OUT.mkdir(exist_ok=True)
	walk = bake(grow(walk_src, factor, 4, 8), 4)
	Image.fromarray(walk).save(OUT / f"{op}_walk_32.png")
	idle = steady_idle(bake(grow(idle_src, factor, 2, 8), 2))
	Image.fromarray(idle).save(OUT / f"{op}_idle_32.png")
	ys = np.nonzero((walk[0:WALK, WALK:2 * WALK, 3] > 0).any(1))[0]
	return {"walk_S_height": int(ys.max() - ys.min() + 1), "scale": round(factor, 3), "clipped": clipped(walk) + clipped(idle)}


if __name__ == "__main__":
	found = sources()
	for op in sys.argv[1:] or sorted(found):
		if not {"walk", "idle"} <= set(found.get(op, {})):
			print(op, "missing walk or idle")
			continue
		print(op, build(op, found[op]))
