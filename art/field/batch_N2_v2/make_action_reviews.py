"""Review v2 substitutions alongside the accepted v1 baked action poses."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
V1 = HERE.parent / "batch_N2_v1"
REGIONS = {
    "mine": ["armed", "caster", "shield", "slug_volatile", "picket"],
    "city": ["greytail", "greytail_lord", "thrower", "bully", "avenger", "breacher"],
    "sami": ["taint_husk", "distorted_caster", "shattered_champion", "shell_vine", "rock_hornbeast", "fallen_snowpriest"],
}
V2 = {"slug_volatile", "rock_hornbeast", "caster", "distorted_caster", "greytail", "greytail_lord"}
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
            directory = HERE if enemy_id in V2 else V1
            prefix = "v2" if enemy_id in V2 else "v1"
            draw.text((12, y + TILE // 2), f"{enemy_id} {prefix}", fill="white", font=font)
            sheet = Image.open(directory / f"{enemy_id}_action_64.png").convert("RGBA")
            for pose in range(sheet.height // 64):
                cell = sheet.crop((0, pose * 64, 64, (pose + 1) * 64))
                cell = cell.resize((TILE, TILE), Image.Resampling.NEAREST)
                x = 180 + pose * TILE
                draw.rectangle((x, y, x + TILE - 1, y + TILE - 1), fill=(60, 65, 73, 255))
                review.alpha_composite(cell, (x, y))
        review.convert("RGB").save(HERE / f"{region}_action_review.png")
        print(region, review.size)


if __name__ == "__main__":
    main()
