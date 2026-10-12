"""Reduce approved painted identities to actual 64px game cells."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

ROOT = Path(__file__).resolve().parent
FIELD = ROOT.parent
V1 = FIELD / "batch_N1_v1"
CELL = 64
SCALE = 8
OUTLINE = (11, 12, 13)
BASE = [
    OUTLINE, (39, 39, 45), (79, 79, 86), (137, 136, 141),
    (197, 195, 188), (245, 242, 234),
    (105, 79, 56), (184, 154, 110), (158, 177, 188),
]
ACCENTS = {
    "yellow": [(128, 89, 17), (231, 173, 26), (255, 216, 82)],
    "orange": [(139, 57, 13), (237, 122, 21), (255, 180, 70)],
    "red": [(126, 31, 28), (218, 53, 45), (247, 106, 77)],
    "blue": [(39, 66, 104), (77, 120, 175), (150, 187, 217)],
    "teal": [(23, 72, 69), (55, 138, 130), (111, 188, 176)],
    "violet": [(67, 39, 111), (134, 84, 208), (215, 170, 255)],
    "green": [(44, 77, 29), (91, 142, 58), (177, 210, 99)],
}

# Source painting bounds, target silhouette width and height, and native palette.
FIGURES = [
    ("mine", "armed", (52, 110, 610, 580), 46, 34, ["yellow"]),
    ("mine", "caster", (610, 145, 1015, 580), 34, 28, ["orange"]),
    ("mine", "shield", (1050, 145, 1535, 580), 39, 28, ["yellow"]),
    ("mine", "slug_volatile", (42, 675, 620, 975), 41, 19, ["orange"]),
    ("mine", "picket", (680, 585, 1150, 995), 35, 28, ["orange"]),
    ("city", "greytail", (65, 105, 480, 515), 35, 28, ["blue"]),
    ("city", "greytail_lord", (550, 70, 1075, 520), 42, 34, ["red"]),
    ("city", "thrower", (1080, 100, 1535, 520), 37, 28, ["red", "orange"]),
    ("city", "bully", (0, 520, 495, 985), 43, 34, ["red"]),
    ("city", "avenger", (475, 520, 1050, 985), 45, 34, ["yellow"]),
    ("city", "breacher", (1000, 515, 1535, 990), 45, 34, ["red"]),
    ("snow", "taint_husk", (65, 195, 515, 585), 37, 28, ["blue"]),
    ("snow", "distorted_caster", (540, 30, 960, 585), 38, 28, ["blue"]),
    ("snow", "shattered_champion", (970, 15, 1535, 580), 46, 34, ["teal"]),
    ("snow", "shell_vine", (55, 600, 520, 990), 24, 22, ["green"]),
    ("snow", "rock_hornbeast", (510, 590, 1045, 1005), 40, 30, ["green", "yellow"]),
    ("snow", "fallen_snowpriest", (1050, 590, 1535, 1005), 37, 28, ["violet"]),
]


def crop_painting(sheet: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    crop = sheet.crop(box).convert("RGBA")
    a = np.array(crop)
    a[:, :, 3] = np.where(a[:, :, 3] >= 180, 255, 0).astype(np.uint8)
    crop = Image.fromarray(a, "RGBA")
    bounds = crop.getbbox()
    if bounds is None:
        raise ValueError(f"Empty source crop {box}")
    return crop.crop(bounds)


def reduce_character(source: Image.Image, max_w: int, height: int, accents: list[str]) -> Image.Image:
    # Leave one pixel on each side for a native outer contour.
    factor = min((max_w - 2) / source.width, (height - 2) / source.height)
    w, h = max(1, round(source.width * factor)), max(1, round(source.height * factor))
    reduced = source.resize((w, h), Image.Resampling.BOX)
    pixels = np.asarray(reduced).copy()
    mask = pixels[:, :, 3] >= 90
    # The painted sources were already simplified to large hard clusters.
    # Preserve their face and accent areas when reducing to 28 pixels.
    rgb = pixels[:, :, :3].astype(np.int32)
    palette = np.array(BASE + [colour for accent in accents for colour in ACCENTS[accent]], dtype=np.int32)
    assert len(palette) <= 18
    distance = np.square(rgb[:, :, None, :] - palette[None, None, :, :]).sum(axis=3)
    mapped = palette[np.argmin(distance, axis=2)].astype(np.uint8)
    canvas = np.zeros((CELL, CELL, 4), dtype=np.uint8)
    x, y = (CELL - w) // 2, 51 - h
    canvas[y:y + h, x:x + w, :3] = mapped
    canvas[y:y + h, x:x + w, 3] = mask.astype(np.uint8) * 255
    # Draw the outline immediately outside the painted body, so even a slim
    # 1-pixel weapon highlight is not overwritten by an outline pass.
    alpha = canvas[:, :, 3] > 0
    dilated = alpha.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0:
                continue
            y0, y1 = max(0, dy), min(CELL, CELL + dy)
            x0, x1 = max(0, dx), min(CELL, CELL + dx)
            dilated[y0:y1, x0:x1] |= alpha[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    border = dilated & ~alpha
    canvas[border, :3] = OUTLINE
    canvas[border, 3] = 255
    return Image.fromarray(canvas, "RGBA")


def main() -> None:
    sources = {region: Image.open(ROOT / "sources" / f"{region}_raw.png") for region in ("mine", "city", "snow")}
    native_dir = ROOT / "native"
    native_dir.mkdir(parents=True, exist_ok=True)
    # Layout matches N1 v1: mine five + blank, city six, Sami six.
    new_sheet = Image.new("RGBA", (3 * CELL * SCALE, 6 * CELL * SCALE), (0, 0, 0, 0))
    for index, (region, enemy_id, box, max_w, height, accents) in enumerate(FIGURES):
        crop = crop_painting(sources[region], box)
        crop.save(ROOT / "sources" / f"{enemy_id}_painted.png")
        sprite = reduce_character(crop, max_w, height, accents)
        sprite.save(native_dir / f"{enemy_id}.png")
        pos = index if index < 5 else index + 1
        col, row = pos % 3, pos // 3
        new_sheet.alpha_composite(sprite.resize((CELL * SCALE, CELL * SCALE), Image.Resampling.NEAREST), (col * CELL * SCALE, row * CELL * SCALE))
    new_sheet.save(ROOT / "identity_sheet.png")

    # Old game frames at the SAME native x8 scale; two identity-only legacy
    # designs are reduced from the supplied old identity sheet for comparison.
    old_names = ["thug", "crossbow", "slug", "brawler", "crossbow_leader", "chainsaw", "ice_hunter", "ice_warrior", "tree"]
    old_files = {
        "thug": "enemy_dir_thug_64.png", "crossbow": "enemy_dir_crossbow_64.png",
        "slug": "enemy_dir_slug_64.png", "brawler": "enemy_dir_brawler_64.png",
        "crossbow_leader": "enemy_dir_crossbow_leader_64.png",
        "ice_hunter": "enemy_dir_ice_hunter_64.png", "ice_warrior": "enemy_dir_ice_warrior_64.png",
    }
    old_sheet = Image.new("RGBA", (3 * CELL * SCALE, 3 * CELL * SCALE), (0, 0, 0, 0))
    old_identity = Image.open(FIELD / "refs_N" / "style_enemies_identity_v1.png").convert("RGBA")
    for index, name in enumerate(old_names):
        if name in old_files:
            frame = Image.open(FIELD / old_files[name]).convert("RGBA").crop((0, 0, CELL, CELL))
        else:
            source = old_identity.crop((index % 3 * 418, index // 3 * 418, (index % 3 + 1) * 418, (index // 3 + 1) * 418))
            bounds = source.getbbox()
            source = source.crop(bounds)
            frame = reduce_character(source, 43, 34, ["orange"] if name == "chainsaw" else ["teal"])
        col, row = index % 3, index // 3
        old_sheet.alpha_composite(frame.resize((CELL * SCALE, CELL * SCALE), Image.Resampling.NEAREST), (col * CELL * SCALE, row * CELL * SCALE))
    comparison = Image.new("RGBA", (6 * CELL * SCALE, 6 * CELL * SCALE), (0, 0, 0, 0))
    comparison.alpha_composite(old_sheet, (0, 0))
    comparison.alpha_composite(new_sheet, (3 * CELL * SCALE, 0))
    comparison.save(ROOT / "identity_sheet_with_old_cast.png")

    # Every new sprite sits next to the actual first thug frame on all three
    # supplied grounds. Top strip is unscaled 1:1; lower strip is exact x6.
    thug = Image.open(FIELD / "enemy_dir_thug_64.png").convert("RGBA").crop((0, 0, CELL, CELL))
    card_w, card_h = 128, 80
    contact = Image.new("RGB", (6 * card_w, 3 * 3 * card_h), "#17191b")
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 11)
    draw = ImageDraw.Draw(contact)
    grounds = ["background_mine_v1.png", "background_city_v1.png", "background_snow_v1.png"]
    for ground_index, ground_name in enumerate(grounds):
        background = Image.open(FIELD / ground_name).convert("RGB")
        b = background.width // 2
        ground = background.crop((b - 80, b - 80, b + 80, b + 80)).resize((CARD := 64, CARD), Image.Resampling.BOX)
        for index, (_, enemy_id, _, _, _, _) in enumerate(FIGURES):
            col, row = index % 6, index // 6
            x = col * card_w
            y = (ground_index * 3 + row) * card_h
            contact.paste(ground, (x, y))
            contact.paste(ground, (x + 64, y))
            contact.paste(thug, (x, y), thug)
            sprite = Image.open(native_dir / f"{enemy_id}.png").convert("RGBA")
            contact.paste(sprite, (x + 64, y), sprite)
            draw.text((x + 2, y + 65), enemy_id[:17], font=font, fill="#f8f8f4")
    zoom = contact.resize((contact.width * 6, contact.height * 6), Image.Resampling.NEAREST)
    review = Image.new("RGB", (zoom.width, contact.height + zoom.height), "#191b1e")
    review.paste(contact, (0, 0))
    review.paste(zoom, (0, contact.height))
    review.save(ROOT / "ingame_check.png")


if __name__ == "__main__":
    main()
