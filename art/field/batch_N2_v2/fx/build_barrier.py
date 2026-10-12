"""Pixel-finish the painted barrier concept as exact, reusable 64 px VFX."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
BATCH = HERE.parent
FIELD = BATCH.parent
COLORS = {
    "white": (255, 255, 255, 255),
    "light": (230, 236, 242, 255),
    "mid": (196, 204, 214, 255),
    "dim": (154, 164, 176, 255),
}
ELLIPSE = (17, 13, 47, 53)
FACETS = [
    [(21, 23), (26, 20), (31, 22), (36, 19), (42, 23)],
    [(21, 23), (23, 30), (20, 35)],
    [(26, 20), (27, 28), (23, 30)],
    [(31, 22), (32, 29), (27, 28)],
    [(36, 19), (37, 27), (32, 29)],
    [(42, 23), (40, 31), (37, 27)],
    [(23, 30), (28, 35), (25, 41), (21, 43)],
    [(37, 27), (40, 31), (36, 36)],
    [(25, 41), (31, 44), (28, 49)],
    [(36, 36), (40, 43), (37, 48), (31, 44)],
]


def empty() -> Image.Image:
    return Image.new("RGBA", (64, 64))


def rim() -> Image.Image:
    layer = empty()
    ImageDraw.Draw(layer).ellipse(ELLIPSE, outline=COLORS["white"], width=1)
    return layer


def shell(phase: int) -> Image.Image:
    result = rim()
    inside = Image.new("1", (64, 64))
    ImageDraw.Draw(inside).ellipse((19, 15, 45, 51), fill=1)
    lines = empty()
    draw = ImageDraw.Draw(lines)
    drift = (0, 1, 0, -1)[phase]
    for index, path in enumerate(FACETS):
        shifted = [(x + drift if index % 3 else x, y) for x, y in path]
        shade = ("dim", "mid", "light")[(index + phase) % 3]
        draw.line(shifted, fill=COLORS[shade], width=1, joint="curve")
    lines.putalpha(Image.composite(lines.getchannel("A"), Image.new("L", (64, 64)), inside))
    result.alpha_composite(lines)
    draw = ImageDraw.Draw(result)
    for x, y in [(32, 14), (45, 31), (33, 52), (18, 34)]:
        if (x + y + phase) % 3 == 0:
            draw.point((x, y), fill=COLORS["white"])
    return result


def shatter() -> list[Image.Image]:
    frames = []
    cracked = shell(0)
    ImageDraw.Draw(cracked).line([(33, 14), (30, 22), (35, 27), (30, 34), (34, 41), (31, 51)], fill=COLORS["white"])
    frames.append(cracked)

    split = shell(1)
    draw = ImageDraw.Draw(split)
    draw.line([(32, 14), (30, 22), (34, 28), (30, 34), (34, 42), (32, 52)], fill=COLORS["white"])
    draw.polygon([(29, 12), (35, 12), (32, 52), (30, 54)], fill=(0, 0, 0, 0))
    frames.append(split)

    for step in range(3):
        frame = empty()
        draw = ImageDraw.Draw(frame)
        spread = (0, 4, 8)[step]
        color = ("white", "light", "dim")[step]
        fragments = [
            [(18-spread, 20-spread), (20-spread, 16-spread), (23-spread, 14-spread)],
            [(42+spread, 17-spread), (46+spread, 21-spread), (47+spread, 25-spread)],
            [(17-spread, 37), (18-spread, 43), (21-spread, 47)],
            [(45+spread, 36), (46+spread, 42), (43+spread, 47)],
            [(25-spread//2, 51+spread), (29-spread//2, 53+spread)],
            [(35+spread//2, 52+spread), (39+spread//2, 50+spread)],
        ]
        for points in fragments:
            draw.line(points, fill=COLORS[color], width=1)
        frames.append(frame)
    return frames


def absorb() -> list[Image.Image]:
    first = shell(2)
    second = shell(3)
    draw = ImageDraw.Draw(first)
    draw.arc((11, 20, 35, 45), 75, 255, fill=COLORS["light"], width=1)
    draw.arc((14, 17, 42, 48), 85, 265, fill=COLORS["white"], width=1)
    draw = ImageDraw.Draw(second)
    draw.arc((9, 17, 37, 48), 78, 250, fill=COLORS["mid"], width=1)
    draw.arc((13, 22, 31, 43), 75, 255, fill=COLORS["white"], width=1)
    return [first, second]


def save_strip(name: str, frames: list[Image.Image]) -> None:
    output = Image.new("RGBA", (len(frames) * 64, 64))
    for index, frame in enumerate(frames):
        output.alpha_composite(frame, (index * 64, 0))
    output.save(HERE / name)


def tinted(frame: Image.Image, rgb: tuple[int, int, int]) -> Image.Image:
    out = frame.copy()
    pixels = out.load()
    for y in range(64):
        for x in range(64):
            r, g, b, a = pixels[x, y]
            if a:
                pixels[x, y] = (r * rgb[0] // 255, g * rgb[1] // 255, b * rgb[2] // 255, 179)
    return out


def preview(shell_frame: Image.Image) -> None:
    colors = [(159, 200, 255), (200, 176, 240), (191, 232, 255)]
    ground = Image.open(FIELD / "background_city_v1.png").convert("RGBA")
    size = 64 * 6
    result = Image.new("RGBA", (3 * size + 48, 2 * (size + 28) + 18), (35, 38, 47, 255))
    draw = ImageDraw.Draw(result)
    font = ImageFont.load_default()
    for row, enemy_id in enumerate(("greytail", "greytail_lord")):
        sheet = Image.open(BATCH / f"{enemy_id}_action_64.png").convert("RGBA")
        figure = sheet.crop((0, 0, 64, 64))
        for col, color in enumerate(colors):
            x = 12 + col * (size + 12)
            y = 24 + row * (size + 28)
            backdrop = ground.crop((440 + col * 87, 380 + row * 114, 504 + col * 87, 444 + row * 114))
            backdrop = Image.blend(backdrop, Image.new("RGBA", (64, 64), (38, 44, 54, 255)), 0.27)
            backdrop.alpha_composite(figure)
            backdrop.alpha_composite(tinted(shell_frame, color))
            result.alpha_composite(backdrop.resize((size, size), Image.Resampling.NEAREST), (x, y))
            draw.text((x + 5, y - 14), f"{enemy_id}  #{color[0]:02x}{color[1]:02x}{color[2]:02x}", fill="white", font=font)
    result.convert("RGB").save(HERE / "barrier_preview_x6.png")


def sequence_preview(sequences: list[tuple[str, list[Image.Image]]]) -> None:
    scale = 6
    tile = 64 * scale
    result = Image.new("RGBA", (5 * tile + 24, 3 * (tile + 24)), (42, 47, 57, 255))
    draw = ImageDraw.Draw(result)
    font = ImageFont.load_default()
    for row, (name, frames) in enumerate(sequences):
        draw.text((8, row * (tile + 24) + 5), name, fill="white", font=font)
        for col, frame in enumerate(frames):
            x = 8 + col * tile
            y = row * (tile + 24) + 20
            checker = Image.new("RGBA", (64, 64), (61, 66, 76, 255))
            draw_checker = ImageDraw.Draw(checker)
            for cy in range(0, 64, 8):
                for cx in range(0, 64, 8):
                    if (cx + cy) // 8 % 2:
                        draw_checker.rectangle((cx, cy, cx + 7, cy + 7), fill=(49, 54, 64, 255))
            checker.alpha_composite(frame)
            result.alpha_composite(checker.resize((tile, tile), Image.Resampling.NEAREST), (x, y))
    result.convert("RGB").save(HERE / "barrier_sequences_x6.png")


def main() -> None:
    loop = [shell(i) for i in range(4)]
    breaking = shatter()
    hitting = absorb()
    save_strip("barrier_shell.png", loop)
    save_strip("barrier_break.png", breaking)
    save_strip("barrier_hit.png", hitting)
    preview(loop[0])
    sequence_preview([("SHELL 6 FPS", loop), ("BREAK", breaking), ("HIT", hitting)])
    print("built 4-frame shell, 5-frame break, 2-frame hit, x6 preview")


if __name__ == "__main__":
    main()
