"""Review v3 hornbeast beside the accepted Sami action boards."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent
V1 = FIELD / "batch_N2_v1"
V2 = FIELD / "batch_N2_v2"
IDS = ("taint_husk", "distorted_caster", "shattered_champion", "shell_vine", "rock_hornbeast", "fallen_snowpriest")
LABELS = ("IDLE", "START", "CHARGE", "STRIKE", "RECOVER", "SPECIAL")
TILE = 64 * 4


def main() -> None:
    review = Image.new("RGBA", (180 + 6 * TILE, 35 + len(IDS) * (TILE + 38)), (48, 52, 59, 255))
    draw = ImageDraw.Draw(review)
    font = ImageFont.load_default()
    for row, label in enumerate(LABELS):
        draw.text((180 + row * TILE + 8, 12), label, fill="white", font=font)
    for index, enemy_id in enumerate(IDS):
        y = 35 + index * (TILE + 38)
        directory = HERE if enemy_id == "rock_hornbeast" else V2 if enemy_id == "distorted_caster" else V1
        version = "v3" if directory == HERE else "v2" if directory == V2 else "v1"
        draw.text((12, y + TILE // 2), f"{enemy_id} {version}", fill="white", font=font)
        sheet = Image.open(directory / f"{enemy_id}_action_64.png").convert("RGBA")
        for pose in range(sheet.height // 64):
            cell = sheet.crop((0, pose * 64, 64, (pose + 1) * 64))
            x = 180 + pose * TILE
            draw.rectangle((x, y, x + TILE - 1, y + TILE - 1), fill=(60, 65, 73, 255))
            review.alpha_composite(cell.resize((TILE, TILE), Image.Resampling.NEAREST), (x, y))
    review.convert("RGB").save(HERE / "sami_action_review.png")
    close = Image.new("RGBA", (3 * 320, 2 * 340), (70, 72, 77, 255))
    close_draw = ImageDraw.Draw(close)
    horn = Image.open(HERE / "rock_hornbeast_action_64.png").convert("RGBA")
    for line, row in enumerate((0, 2)):
        for index, (col, heading) in enumerate(((0, "S"), (2, "W"), (6, "E"))):
            cell = horn.crop((col * 64, row * 64, (col + 1) * 64, (row + 1) * 64))
            close.alpha_composite(cell.resize((320, 320), Image.Resampling.NEAREST), (index * 320, line * 340 + 20))
            close_draw.text((index * 320 + 4, line * 340 + 3), f"{heading} {'IDLE' if row == 0 else 'CHARGE'}", fill="white", font=font)
    close.convert("RGB").save(HERE / "hornbeast_charge_check.png")
    print("Sami review", review.size)


if __name__ == "__main__":
    main()
