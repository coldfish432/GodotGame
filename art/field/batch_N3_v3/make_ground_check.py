"""Make a static readability contact sheet on the three field grounds."""

from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
GROUNDS = ("mine", "city", "snow")
FRAMES = (("action", 0, "IDLE S"), ("action", 2, "CHARGE S"),
          ("walk", 0, "CONTACT A S"))
TILE = 160
SCALE = 4
sheet = Image.new("RGB", (len(GROUNDS) * TILE * SCALE,
                          len(FRAMES) * TILE * SCALE), "#16191d")
for col, ground in enumerate(GROUNDS):
    backdrop = Image.open(FIELD / f"background_{ground}_v1.png").convert("RGB")
    left = (backdrop.width - TILE) // 2
    top = (backdrop.height - TILE) // 2
    patch = backdrop.crop((left, top, left + TILE, top + TILE))
    for row, (kind, frame, label) in enumerate(FRAMES):
        tile = patch.copy().convert("RGBA")
        board = Image.open(HERE / f"sentinel_{kind}_64.png").convert("RGBA")
        sprite = board.crop((0, frame * 64, 64, (frame + 1) * 64))
        tile.alpha_composite(sprite, ((TILE - 64) // 2, (TILE - 64) // 2))
        enlarged = tile.convert("RGB").resize((TILE * SCALE, TILE * SCALE), Image.Resampling.NEAREST)
        sheet.paste(enlarged, (col * TILE * SCALE, row * TILE * SCALE))
        ImageDraw.Draw(sheet).text((col * TILE * SCALE + 8,
                                    row * TILE * SCALE + 8),
                                   f"{ground.upper()} / {label}", fill="white",
                                   stroke_width=1, stroke_fill="black")
sheet.save(HERE / "ground_check_x4.png")
