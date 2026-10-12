"""Package the painted N1 regional sources as review identity sheets."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parent
REFS = ROOT.parent / "refs_N"
CELL = 418

# Bounds isolate figures from the three painted regional source sheets.
# Each output cell is anchored at the same ground line as the old cast.
FIGURES = [
    ("mine", "armed", (45, 55, 592, 550), 396, 396),
    ("mine", "caster", (588, 85, 930, 552), 340, 340),
    ("mine", "shield", (962, 95, 1536, 552), 360, 340),
    ("mine", "slug_volatile", (50, 620, 615, 970), 390, 315),
    ("mine", "picket", (650, 555, 1155, 980), 355, 350),
    ("city", "greytail", (60, 95, 490, 510), 350, 340),
    ("city", "greytail_lord", (552, 45, 1095, 510), 390, 390),
    ("city", "thrower", (1105, 90, 1536, 515), 350, 340),
    ("city", "bully", (0, 520, 460, 988), 390, 390),
    ("city", "avenger", (430, 520, 1040, 985), 385, 385),
    ("city", "breacher", (1020, 520, 1536, 990), 390, 390),
    ("snow", "taint_husk", (95, 145, 520, 545), 345, 340),
    ("snow", "distorted_caster", (550, 25, 945, 545), 355, 350),
    ("snow", "shattered_champion", (980, 0, 1536, 550), 395, 395),
    ("snow", "shell_vine", (30, 550, 510, 995), 385, 325),
    ("snow", "rock_hornbeast", (520, 545, 1055, 1005), 397, 355),
    ("snow", "fallen_snowpriest", (1060, 545, 1536, 995), 355, 350),
]


def crop_figure(source: Image.Image, bounds: tuple[int, int, int, int], enemy_id: str) -> Image.Image:
    crop = source.crop(bounds).convert("RGBA")
    pixels = np.array(crop)
    if enemy_id == "thrower":
        # Erase the white X from the source armband. Its final design is a
        # solid red band, as required by the brief's no-emblems rule.
        yy, xx = np.indices(pixels.shape[:2])
        global_x, global_y = xx + bounds[0], yy + bounds[1]
        white = np.min(pixels[:, :, :3], axis=2) > 145
        emblem = (
            (global_x >= 1140) & (global_x <= 1204)
            & (global_y >= 297) & (global_y <= 333) & white
        )
        pixels[emblem, :3] = [207, 65, 31]
    pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 200, 255, 0).astype(np.uint8)
    crop = Image.fromarray(pixels, "RGBA")
    visible = crop.getbbox()
    if visible is None:
        raise ValueError(f"No visible painting for {enemy_id}")
    return crop.crop(visible)


def main() -> None:
    sources = {region: Image.open(ROOT / "sources" / f"{region}_raw.png") for region in ("mine", "city", "snow")}
    sheet = Image.new("RGBA", (3 * CELL, 6 * CELL), (0, 0, 0, 0))
    manifest = []
    for index, (region, enemy_id, bounds, max_width, max_height) in enumerate(FIGURES):
        figure = crop_figure(sources[region], bounds, enemy_id)
        scale = min(max_width / figure.width, max_height / figure.height)
        size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
        figure = figure.resize(size, Image.Resampling.NEAREST)
        cell_index = index if index < 5 else index + 1
        column, row = cell_index % 3, cell_index // 3
        x = column * CELL + (CELL - size[0]) // 2
        y = row * CELL + CELL - 15 - size[1]
        sheet.alpha_composite(figure, (x, y))
        manifest.append(f"{enemy_id}: region={region}, cell=({column},{row}), bbox={bounds}, export_size={size}")
    sheet.save(ROOT / "identity_sheet.png")

    old = Image.open(REFS / "style_enemies_identity_v1.png").convert("RGBA")
    with_old = Image.new("RGBA", (6 * CELL, 6 * CELL), (0, 0, 0, 0))
    with_old.alpha_composite(old, (0, 0))
    with_old.alpha_composite(sheet, (3 * CELL, 0))
    with_old.save(ROOT / "identity_sheet_with_old_cast.png")

    # Review version: IDs outside the sprite cells and dark/grey/snow ground
    # swatches at near-game scale. The formal sheets above stay transparent.
    card_w, card_h = 150, 150
    review = Image.new("RGB", (6 * card_w, 3 * card_h), "#191b20")
    draw = ImageDraw.Draw(review)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    grounds = ["#2c2e30", "#59616b", "#d8dfe1"]
    for index, (_, enemy_id, _, _, _) in enumerate(FIGURES):
        col, row = index % 6, index // 6
        x, y = col * card_w, row * card_h
        draw.rectangle((x + 3, y + 3, x + 146, y + 121), fill=grounds[row])
        cell_index = index if index < 5 else index + 1
        src_col, src_row = cell_index % 3, cell_index // 3
        cell = sheet.crop((src_col * CELL, src_row * CELL, (src_col + 1) * CELL, (src_row + 1) * CELL))
        small = cell.resize((110, 110), Image.Resampling.NEAREST)
        review.paste(small, (x + 20, y + 8), small)
        draw.text((x + 7, y + 126), enemy_id, font=font, fill="#f3f3f1")
    review.save(ROOT / "review_contact.png")
    ground_check = Image.new("RGB", (17 * 100, 3 * 130), "#1b1d20")
    ground_draw = ImageDraw.Draw(ground_check)
    backgrounds = ["background_mine_v1.png", "background_city_v1.png", "background_snow_v1.png"]
    for ground_index, background_name in enumerate(backgrounds):
        background = Image.open(ROOT.parent / background_name).convert("RGB")
        bx, by = background.width // 2, background.height // 2
        patch = background.crop((bx - 180, by - 180, bx + 180, by + 180)).resize((96, 100), Image.Resampling.BOX)
        for index, (_, enemy_id, _, _, _) in enumerate(FIGURES):
            x, y = index * 100, ground_index * 130
            ground_check.paste(patch, (x + 2, y + 2))
            cell_index = index if index < 5 else index + 1
            src_col, src_row = cell_index % 3, cell_index // 3
            cell = sheet.crop((src_col * CELL, src_row * CELL, (src_col + 1) * CELL, (src_row + 1) * CELL))
            small = cell.resize((88, 88), Image.Resampling.NEAREST)
            ground_check.paste(small, (x + 6, y + 12), small)
            ground_draw.text((x + 2, y + 105), enemy_id[:13], font=font, fill="#f4f4f1")
    ground_check.save(ROOT / "ground_check.png")
    (ROOT / "manifest.txt").write_text("\n".join(manifest) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
