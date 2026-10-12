from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
REFS = ROOT.parent / "refs_N"
GROUPS = {
    "mine": ["armed", "caster", "shield", "slug_volatile", "picket"],
    "city": ["greytail", "greytail_lord", "thrower", "bully", "avenger", "breacher"],
    "snow": ["taint_husk", "distorted_caster", "shattered_champion", "shell_vine", "rock_hornbeast", "fallen_snowpriest"],
}
OUT = ROOT / "sources"
OUT.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 20)
for group, ids in GROUPS.items():
    sheet = Image.new("RGB", (3 * 240, 2 * 220), "#d9d9d9")
    draw = ImageDraw.Draw(sheet)
    for index, enemy_id in enumerate(ids):
        x, y = index % 3 * 240, index // 3 * 220
        portrait = Image.open(REFS / f"prts_{enemy_id}.png").convert("RGBA")
        portrait = portrait.resize((180, 180), Image.Resampling.NEAREST)
        sheet.paste(portrait, (x + 30, y + 5), portrait)
        draw.text((x + 8, y + 187), enemy_id, fill="#111111", font=font)
    sheet.save(OUT / f"reference_{group}.png")
