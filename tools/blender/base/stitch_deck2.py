"""Puts tests/capture_deck2_overview.gd's three shots side by side into
evidence/rhodes-engine/deck2-overview.png. The shots are 74 m apart along
the deck at an orthographic camera size of 82 (720 px tall), so 74 m is
74 × 720 / 82 px across; the HUD strips at the top and bottom are cut."""
import os
from PIL import Image

HERE = os.path.dirname(__file__)
EVIDENCE = os.path.join(HERE, "..", "..", "..", "..", "evidence", "rhodes-engine")
STEP = round(74 * 720 / 82)
TOP, BOTTOM = 58, 652

shots = [Image.open(os.path.join(EVIDENCE, f"deck2-overview-{k}.png")).convert("RGB") for k in range(3)]
w, h = shots[0].size
out = Image.new("RGB", (w + STEP * 2, BOTTOM - TOP))
# Middle of each shot over the next: paste left to right, each covering the last's right part.
for k, shot in enumerate(shots):
    out.paste(shot.crop((0, TOP, w, BOTTOM)), (k * STEP, 0))
out.save(os.path.join(EVIDENCE, "deck2-overview.png"))
print(out.size)
