"""Build the exact 64px round, plain barrier states specified in N2 v3."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FIELD = HERE.parent.parent
V2 = FIELD / "batch_N2_v2"
WHITE = (255, 255, 255, 255)
LIGHT = (230, 236, 242, 255)
MID = (196, 204, 214, 255)
DIM = (154, 164, 176, 255)
BOX = (12, 12, 52, 52)
HIGHLIGHTS = [
    ([(19, 20), (21, 18), (24, 16), (27, 15), (30, 14)], [(46, 44), (44, 46), (42, 47)]),
    ([(20, 19), (22, 17), (25, 15), (28, 14), (31, 14)], [(45, 45), (43, 47), (41, 48)]),
    ([(21, 18), (23, 16), (26, 15), (29, 14), (32, 14)], [(44, 46), (42, 48), (40, 49)]),
    ([(20, 19), (22, 17), (25, 15), (28, 14), (31, 14)], [(45, 45), (43, 47), (41, 48)]),
]
CRACKS = [
    [(17, 18), (20, 20), (21, 23), (25, 25)],
    [(21, 23), (19, 26)],
    [(48, 20), (45, 22), (44, 26), (41, 28)],
    [(44, 26), (46, 28)],
    [(25, 50), (27, 47), (27, 44), (30, 42)],
]


def blank() -> Image.Image:
    return Image.new("RGBA", (64, 64))


def near_rim_points(anchor: tuple[int, int], radius: int = 1) -> list[tuple[int, int]]:
    rim = blank()
    ImageDraw.Draw(rim).ellipse(BOX, outline=WHITE, width=1)
    points = []
    for y in range(64):
        for x in range(64):
            if rim.getpixel((x, y))[3] and (x-anchor[0])**2 + (y-anchor[1])**2 <= radius**2:
                points.append((x, y))
    return points


def shell(phase: int, cracked: bool = False) -> Image.Image:
    image = blank()
    draw = ImageDraw.Draw(image)
    draw.ellipse(BOX, outline=WHITE, width=1)
    if cracked:
        # The gaps stay in the same pixels across all four cracked frames.
        for anchor in ((17, 18), (48, 20)):
            for point in near_rim_points(anchor, 2):
                draw.point(point, fill=(0, 0, 0, 0))
    top, lower = HIGHLIGHTS[phase]
    draw.line(top, fill=MID, width=1, joint="curve")
    draw.line(lower, fill=DIM, width=1, joint="curve")
    if cracked:
        for path in CRACKS:
            draw.line(path, fill=WHITE, width=1, joint="curve")
    return image


def break_frames() -> list[Image.Image]:
    first = shell(0, cracked=True)
    draw = ImageDraw.Draw(first)
    draw.line([(25, 25), (27, 28)], fill=WHITE, width=1)
    draw.line([(41, 28), (39, 30)], fill=WHITE, width=1)
    frames = [first]

    second = shell(1, cracked=True)
    draw = ImageDraw.Draw(second)
    for anchor in ((20, 17), (47, 23), (25, 50)):
        for point in near_rim_points(anchor, 3):
            draw.point(point, fill=(0, 0, 0, 0))
    draw.line([(17, 18), (22, 22), (26, 27)], fill=LIGHT, width=1)
    draw.line([(48, 20), (43, 24), (39, 30)], fill=LIGHT, width=1)
    frames.append(second)

    # Six curved rim shards: the arc fragment keeps its own curve while moving out.
    segments = [
        [(14, 24), (16, 19), (20, 16), (24, 14)],
        [(30, 12), (35, 12), (39, 14), (42, 16)],
        [(48, 20), (51, 25), (52, 29)],
        [(51, 36), (49, 41), (46, 45)],
        [(38, 51), (33, 52), (28, 51)],
        [(19, 47), (15, 43), (13, 39)],
    ]
    directions = [(-1, -1), (0, -1), (1, -1), (1, 1), (0, 1), (-1, 1)]
    for step, color in ((1, WHITE), (2, MID), (3, DIM)):
        frame = blank()
        draw = ImageDraw.Draw(frame)
        for points, (dx, dy) in zip(segments, directions):
            draw.line([(x + step * 3 * dx, y + step * 3 * dy) for x, y in points], fill=color, width=1, joint="curve")
        frames.append(frame)
    return frames


def save_strip(name: str, frames: list[Image.Image]) -> None:
    result = Image.new("RGBA", (64 * len(frames), 64))
    for index, frame in enumerate(frames):
        result.alpha_composite(frame, (index * 64, 0))
    result.save(HERE / name)


def tint(frame: Image.Image, rgb: tuple[int, int, int]) -> Image.Image:
    result = frame.copy()
    pixels = result.load()
    for y in range(64):
        for x in range(64):
            r, g, b, a = pixels[x, y]
            if a:
                pixels[x, y] = (r * rgb[0] // 255, g * rgb[1] // 255, b * rgb[2] // 255, 179)
    return result


def overlay_preview(intact: Image.Image, cracked: Image.Image) -> None:
    scale = 6
    tile = 64 * scale
    gap = 12
    colors = [(159, 200, 255), (200, 176, 240), (191, 232, 255)]
    ground = Image.open(FIELD / "background_city_v1.png").convert("RGBA")
    canvas = Image.new("RGBA", (3 * tile + 4 * gap, 4 * (tile + 28) + 8), (35, 38, 47, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    for row, (enemy_id, state, effect) in enumerate((
        ("greytail", "intact", intact),
        ("greytail", "cracked", cracked),
        ("greytail_lord", "intact", intact),
        ("greytail_lord", "cracked", cracked),
    )):
        sheet = Image.open(V2 / f"{enemy_id}_action_64.png").convert("RGBA")
        figure = sheet.crop((0, 0, 64, 64))
        for col, color in enumerate(colors):
            x = gap + col * (tile + gap)
            y = 24 + row * (tile + 28)
            backdrop = ground.crop((440 + col * 87, 380 + row * 79, 504 + col * 87, 444 + row * 79))
            backdrop = Image.blend(backdrop, Image.new("RGBA", (64, 64), (38, 44, 54, 255)), 0.27)
            backdrop.alpha_composite(figure)
            backdrop.alpha_composite(tint(effect, color))
            canvas.alpha_composite(backdrop.resize((tile, tile), Image.Resampling.NEAREST), (x, y))
            draw.text((x + 4, y - 14), f"{enemy_id} {state} #{color[0]:02x}{color[1]:02x}{color[2]:02x}", fill="white", font=font)
    canvas.convert("RGB").save(HERE / "barrier_preview_x6.png")


def sequence_preview(sequences: list[tuple[str, list[Image.Image]]]) -> None:
    tile = 64 * 6
    canvas = Image.new("RGBA", (5 * tile + 24, 3 * (tile + 24)), (42, 47, 57, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    for row, (label, frames) in enumerate(sequences):
        draw.text((8, row * (tile + 24) + 5), label, fill="white", font=font)
        for col, frame in enumerate(frames):
            checker = Image.new("RGBA", (64, 64), (61, 66, 76, 255))
            chk = ImageDraw.Draw(checker)
            for cy in range(0, 64, 8):
                for cx in range(0, 64, 8):
                    if (cx + cy) // 8 % 2:
                        chk.rectangle((cx, cy, cx + 7, cy + 7), fill=(49, 54, 64, 255))
            checker.alpha_composite(frame)
            canvas.alpha_composite(checker.resize((tile, tile), Image.Resampling.NEAREST), (8 + col * tile, row * (tile + 24) + 20))
    canvas.convert("RGB").save(HERE / "barrier_sequences_x6.png")


def main() -> None:
    intact = [shell(i) for i in range(4)]
    cracked = [shell(i, cracked=True) for i in range(4)]
    breaking = break_frames()
    save_strip("barrier_shell.png", intact)
    save_strip("barrier_cracked.png", cracked)
    save_strip("barrier_break.png", breaking)
    overlay_preview(intact[0], cracked[0])
    sequence_preview([("INTACT 6 FPS", intact), ("CRACKED 6 FPS", cracked), ("BREAK", breaking)])
    print("built round intact, cracked and break barrier assets")


if __name__ == "__main__":
    main()
