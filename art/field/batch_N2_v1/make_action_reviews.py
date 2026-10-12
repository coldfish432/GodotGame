"""Create compact, baked-size action-pose review strips by region."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from build_action import ROWS_BY_ID

HERE = Path(__file__).resolve().parent
REGIONS = {
    "mine": ["armed", "caster", "shield", "slug_volatile", "picket"],
    "city": ["greytail", "greytail_lord", "thrower", "bully", "avenger", "breacher"],
    "sami": ["taint_husk", "distorted_caster", "shattered_champion", "shell_vine", "rock_hornbeast", "fallen_snowpriest"],
}
LABELS = ["IDLE", "START", "CHARGE", "STRIKE", "RECOVER", "SPECIAL"]
SCALE = 4
TILE = 64 * SCALE


def main() -> None:
    font = ImageFont.load_default()
    for region, ids in REGIONS.items():
        width = 180 + 6 * TILE
        height = 35 + len(ids) * (TILE + 38)
        review = Image.new("RGBA", (width, height), (48, 52, 59, 255))
        draw = ImageDraw.Draw(review)
        for row, label in enumerate(LABELS):
            draw.text((180 + row * TILE + 8, 12), label, fill="white", font=font)
        for index, enemy_id in enumerate(ids):
            y = 35 + index * (TILE + 38)
            draw.text((12, y + TILE // 2), enemy_id, fill="white", font=font)
            sheet = Image.open(HERE / f"{enemy_id}_action_64.png").convert("RGBA")
            for pose in range(ROWS_BY_ID[enemy_id]):
                cell = sheet.crop((0, pose * 64, 64, (pose + 1) * 64))
                cell = cell.resize((TILE, TILE), Image.Resampling.NEAREST)
                x = 180 + pose * TILE
                draw.rectangle((x, y, x + TILE - 1, y + TILE - 1), fill=(60, 65, 73, 255))
                review.alpha_composite(cell, (x, y))
        review.convert("RGB").save(HERE / f"{region}_action_review.png")
        print(region, review.size)


if __name__ == "__main__":
    main()
