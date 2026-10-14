"""Native-pixel NPC v3 revision-1 field sprite strips; no painting reduction."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
REF = HERE.parent.parent / "portraits" / "refs_F"
INK = "#0b0c0d"
DEEP = "#191c21"
BASE = "#393e47"
LIT = "#626971"
SILVER = "#929a9e"
WHITE = "#c9cfd2"
CYAN_DARK = "#2a8a92"
CYAN = "#5fd0d8"
ORANGE_DARK = "#bc5309"
ORANGE = "#ffae20"
LILAC_DARK = "#695973"
LILAC = "#a996b4"
LILAC_LIT = "#dccae0"
SKIN = "#f1c6ad"
GOLD = "#e6c25a"
LEATHER = "#74604b"
LEATHER_LIT = "#9e8265"
GOLD_DARK = "#a8873a"
STEEL_DARK = "#5b6366"
COAT_MID = "#2a3038"
RED_DARK = "#8d2031"
RED = "#c52f42"
RED_LIT = "#e04a5a"
BLUE = "#344362"
BLUE_LIT = "#526995"
WHITE_DARK = "#aab4b8"


def outlined(im: Image.Image) -> Image.Image:
    mask = im.getchannel("A").filter(ImageFilter.MaxFilter(3))
    border = Image.new("RGBA", im.size, INK)
    border.putalpha(mask)
    border.alpha_composite(im)
    return border


def reserve(kind: str, phase: int) -> Image.Image:
    im = Image.new("RGBA", (24, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sway = (0, 1, 0, -1)[phase]
    # Shared short legs, boots and dark tactical body.
    d.rectangle((8, 22, 10, 26), fill=BASE)
    d.rectangle((15, 22, 17, 26), fill=BASE)
    d.rectangle((7, 25, 11, 26), fill=DEEP)
    d.rectangle((14, 25, 18, 26), fill=DEEP)
    if kind == "melee":
        d.polygon([(7 + sway, 12), (16 + sway, 12), (20 + sway, 16), (19 + sway, 23), (6 + sway, 23), (5 + sway, 17)], fill=BASE)
        d.polygon([(7 + sway, 14), (9 + sway, 13), (9 + sway, 21), (6 + sway, 21)], fill=LIT)
        d.rectangle((17 + sway, 14, 19 + sway, 21), fill=LIT)
        d.line((7 + sway, 14, 9 + sway, 16, 9 + sway, 21), fill=CYAN_DARK)
        d.line((17 + sway, 14, 18 + sway, 17, 18 + sway, 21), fill=CYAN)
        d.line((10 + sway, 14, 14 + sway, 14), fill=CYAN_DARK)
        d.rectangle((10 + sway, 17, 16 + sway, 21), fill=DEEP)
        d.rectangle((11 + sway, 18, 15 + sway, 19), fill=LIT)
        d.ellipse((5, 2, 19, 14), fill=BASE)
        d.polygon([(8, 3), (13, 2), (17, 5), (10, 5)], fill=LIT)
        d.rectangle((6, 7, 19, 10), fill=DEEP)
        d.polygon([(7, 8), (18, 8), (17, 11), (8, 11)], fill=SILVER)
        d.line((8, 8, 13, 8), fill=WHITE)
        d.rectangle((8, 12, 17, 14), fill=DEEP)
        d.line((10, 13, 15, 13), fill=LIT)
        d.line((21, 19, 23, 16), fill=SILVER, width=2)
    elif kind == "sniper":
        d.polygon([(7 + sway, 13), (17 + sway, 13), (20 + sway, 17), (18 + sway, 23), (6 + sway, 23), (5 + sway, 17)], fill=BASE)
        d.rectangle((8 + sway, 16, 17 + sway, 22), fill=DEEP)
        d.line((7 + sway, 15, 10 + sway, 17, 10 + sway, 21), fill=CYAN)
        d.line((17 + sway, 15, 18 + sway, 18, 18 + sway, 22), fill=CYAN_DARK)
        d.line((10 + sway, 16, 15 + sway, 16), fill=CYAN_DARK)
        d.arc((0, 3, 8, 23), 80, 270, fill=SILVER, width=2)
        d.line((5, 4, 5, 22), fill=WHITE)
        d.polygon([(5, 9), (7, 1), (10, 5), (15, 5), (19, 1), (20, 11), (18, 15), (7, 15)], fill=BASE)
        d.polygon([(7, 3), (9, 7), (7, 8)], fill=LIT)
        d.polygon([(18, 7), (19, 3), (19, 9)], fill=LIT)
        d.line((7, 7, 17, 7), fill=LIT)
        d.rectangle((7, 8, 19, 11), fill=DEEP)
        d.rectangle((8, 9, 17, 10), fill=ORANGE)
        d.line((9, 10, 16, 10), fill=ORANGE_DARK)
        d.rectangle((9, 12, 18, 14), fill=DEEP)
        d.line((11, 13, 16, 13), fill=LIT)
    else:  # logistics
        d.rectangle((8, 21, 17, 24), fill=CYAN_DARK)
        d.rectangle((9, 21, 16, 22), fill=CYAN)
        d.polygon([(6, 14), (9, 12), (17, 12), (20, 15), (19, 22), (5, 22)], fill=WHITE)
        d.rectangle((9, 15, 17, 21), fill=DEEP)
        d.line((7, 15, 7, 21), fill=CYAN)
        d.line((17, 15, 18, 20), fill=CYAN_DARK)
        d.rectangle((18, 18, 21, 22), fill=BASE)
        d.polygon([(5, 5), (2, 7), (3, 14), (7, 16), (8, 11)], fill=LILAC_DARK)
        d.polygon([(19, 5), (22, 7), (22, 14), (18, 16), (16, 11)], fill=LILAC_DARK)
        d.ellipse((5, 3, 20, 16), fill=LILAC)
        d.polygon([(7, 4), (13, 3), (19, 6), (17, 7), (8, 6)], fill=LILAC_LIT)
        d.rectangle((8, 8, 18, 10), fill=DEEP)
        d.rectangle((10, 10, 17, 13), fill=SKIN)
        d.polygon([(7, 9), (15, 7), (18, 10), (17, 12), (11, 11), (8, 13)], fill=LILAC)
        d.line((9, 12, 9, 15), fill=LILAC_DARK)
        d.line((18, 11, 19, 15), fill=LILAC_DARK)
        d.rectangle((11, 13, 17, 14), fill=WHITE)
    return outlined(im)


def squad_frame(frame: int) -> Image.Image:
    im = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    im.alpha_composite(reserve("sniper", 2 if frame == 2 else 0), (52, 34))
    im.alpha_composite(reserve("melee", 1 if frame == 1 else 0), (29, 34))
    im.alpha_composite(reserve("logistics", 3 if frame == 3 else 0), (76 + (1 if frame == 3 else 0), 34))
    d = ImageDraw.Draw(im)
    d.rectangle((96, 51, 110, 60), fill=INK)
    d.rectangle((97, 52, 109, 59), fill=WHITE)
    d.line((98, 53, 108, 53), fill=SILVER)
    d.line((102, 52, 102, 59), fill=BASE)
    d.rectangle((105, 54, 106, 55), fill=CYAN if frame != 2 else CYAN_DARK)
    return im


def cannot_frame(frame: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sway = (0, -1, 1, 0)[frame]
    # A single visible gold-edged bundle behind the high collar.
    d.polygon([(19, 36), (26, 34), (27, 50), (21, 51)], fill=DEEP)
    d.line((20, 38, 24, 37, 25, 47), fill=GOLD, width=2)
    d.line((20, 48, 25, 48), fill=GOLD)
    d.line((22, 40, 23, 45), fill=GOLD_DARK, width=2)
    d.rectangle((28, 56, 31, 60), fill=LEATHER)
    d.rectangle((37, 56, 40, 60), fill=LEATHER)
    d.polygon([(25, 38), (40, 38), (45 + sway, 54), (42 + sway, 58), (38 + sway, 55), (36 + sway, 59), (33 + sway, 56), (29 + sway, 59), (25 + sway, 55), (22 + sway, 57)], fill=DEEP)
    d.polygon([(26, 39), (39, 39), (42 + sway, 54), (38 + sway, 55), (35 + sway, 53), (32 + sway, 56), (27 + sway, 53), (24 + sway, 55)], fill=BASE)
    d.polygon([(31, 43), (37, 43), (39 + sway, 53), (34 + sway, 52)], fill=COAT_MID)
    d.polygon([(25, 42), (29, 41), (28 + sway, 53), (24 + sway, 54)], fill=LIT)
    d.rectangle((23, 40, 26, 49), fill=BASE)
    d.rectangle((40, 41, 43, 49), fill=BASE)
    d.polygon([(24, 36), (29, 33), (39, 33), (44, 38), (40, 44), (26, 43)], fill=DEEP)
    d.polygon([(27, 35), (31, 32), (39, 32), (42, 37), (39, 42), (29, 42)], fill=BASE)
    d.polygon([(28, 29), (31, 28), (39, 28), (41, 38), (29, 39)], fill=SILVER)
    d.polygon([(30, 30), (37, 29), (40, 33), (31, 33)], fill=WHITE)
    d.line((30, 37, 38, 37), fill=STEEL_DARK)
    d.rectangle((32, 34, 40, 35), fill=INK)
    d.line((27, 42, 39, 47), fill=LEATHER, width=2)
    d.rectangle((32, 43, 36, 46), fill=WHITE)
    d.line((33, 44, 35, 44), fill=DEEP)
    d.rectangle((27, 48, 31, 50), fill=LEATHER)
    d.rectangle((37, 48, 41, 50), fill=LEATHER)
    d.line((28, 48, 31, 48), fill=LEATHER_LIT)
    d.line((38, 48, 40, 48), fill=LEATHER_LIT)
    return outlined(im)


def closure_frame(frame: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sway = (0, 1, 0, -1)[frame]
    d.rectangle((28, 56, 31, 60), fill=DEEP)
    d.rectangle((37, 56, 40, 60), fill=DEEP)
    d.polygon([(26, 51), (41, 51), (40, 57), (27, 57)], fill=BASE)
    d.polygon([(23 + sway, 40), (28 + sway, 42), (27 + sway, 54), (22 + sway, 57), (20 + sway, 54)], fill=DEEP)
    d.polygon([(39 + sway, 42), (44 + sway, 40), (47 + sway, 54), (44 + sway, 57), (40 + sway, 54)], fill=DEEP)
    d.line((23 + sway, 43, 22 + sway, 52), fill=BLUE, width=2)
    d.line((44 + sway, 43, 45 + sway, 52), fill=BLUE, width=2)
    d.line((22 + sway, 44, 22 + sway, 48), fill=BLUE_LIT)
    d.line((45 + sway, 44, 45 + sway, 48), fill=BLUE_LIT)
    d.polygon([(25, 44), (41, 44), (42, 54), (25, 54)], fill=RED_DARK)
    d.polygon([(28, 43), (32, 41), (37, 41), (40, 44), (38, 52), (29, 52)], fill=WHITE)
    d.line((29, 43, 38, 43), fill=WHITE_DARK)
    d.rectangle((32, 42, 35, 49), fill=DEEP)
    d.polygon([(25, 44), (28, 44), (27, 54), (22, 52)], fill=RED)
    d.polygon([(39, 44), (42, 44), (45, 52), (40, 54)], fill=RED)
    d.line((24, 45, 23, 49), fill=RED_LIT)
    d.line((41, 45, 43, 49), fill=RED_LIT)
    d.rectangle((22, 51, 25, 53), fill=DEEP)
    d.rectangle((41, 51, 44, 53), fill=DEEP)
    d.rectangle((35, 45, 38, 49), fill=GOLD)
    d.rectangle((29, 52, 35, 53), fill=GOLD)
    d.polygon([(26, 39), (29, 36), (38, 36), (41, 39), (40, 47), (27, 47)], fill=DEEP)
    d.rectangle((29, 40, 38, 46), fill=SKIN)
    d.point((32, 42), fill=RED)
    d.point((36, 42), fill=RED)
    d.line((33, 45, 36, 45), fill=RED_DARK)
    d.polygon([(25, 38), (29, 35), (38, 35), (41, 39), (37, 40), (35, 38), (32, 41), (28, 39)], fill=DEEP)
    d.line((27, 37, 31, 36), fill=BLUE)
    d.polygon([(27, 43), (24, 42), (25, 46), (28, 46)], fill=SKIN)
    d.polygon([(40, 43), (43, 42), (42, 46), (39, 46)], fill=SKIN)
    body = outlined(im)
    drone = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    q = ImageDraw.Draw(drone)
    bob = (0, -1, 0, 1)[frame]
    q.rectangle((47, 39 + bob, 52, 43 + bob), fill=WHITE)
    q.rectangle((49, 40 + bob, 50, 41 + bob), fill=RED)
    q.line((48, 39 + bob, 47, 37 + bob), fill=LIT)
    q.line((51, 39 + bob, 52, 37 + bob), fill=LIT)
    body.alpha_composite(outlined(drone))
    return body


def write_asset(name: str, width: int, maker, fps: int) -> dict:
    frames = [maker(i) for i in range(4)]
    strip = Image.new("RGBA", (width * 4, 64), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.alpha_composite(frame, (i * width, 0))
    strip.save(HERE / f"{name}.png")
    frames[0].resize((width * 8, 512), Image.Resampling.NEAREST).save(HERE / f"{name}_frame0_8x.png")
    big = [f.resize((width * 8, 512), Image.Resampling.NEAREST) for f in frames]
    big[0].save(HERE / f"{name}.gif", save_all=True, append_images=big[1:], duration=round(1000 / fps), loop=0, disposal=2, transparency=0)
    return {"id": name, "file": f"{name}.png", "size": [width * 4, 64], "frame_size": [width, 64], "frames": 4, "anchor_px": [width // 2, 61], "fps": fps, "preview": f"{name}_frame0_8x.png", "gif": f"{name}.gif", "source": "Native pixels in build_npc_idle.py"}


def main() -> None:
    manifest = [write_asset("npc_squad_idle", 128, squad_frame, 3), write_asset("npc_cannot_idle", 64, cannot_frame, 3), write_asset("npc_closure_idle", 64, closure_frame, 3)]
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lappland = Image.open(REF / "lappland_sprite.png").convert("RGBA")
    contact = Image.new("RGBA", (322, 64), (32, 38, 43, 255))
    contact.alpha_composite(lappland, (2, 22))
    x = 48
    for name, width in (("npc_squad_idle", 128), ("npc_cannot_idle", 64), ("npc_closure_idle", 64)):
        frame = Image.open(HERE / f"{name}.png").convert("RGBA").crop((0, 0, width, 64))
        contact.alpha_composite(frame, (x, 0))
        x += width + 4
    contact.save(HERE / "npc_contact_1x.png")
    contact.resize((2576, 512), Image.Resampling.NEAREST).save(HERE / "npc_contact_8x.png")
    report = ["F1-C v2 native-pixel static validation"]
    for item in manifest:
        strip = Image.open(HERE / item["file"]).convert("RGBA")
        w = item["frame_size"][0]
        frames = [strip.crop((i * w, 0, (i + 1) * w, 64)) for i in range(4)]
        colours = {p[:3] for p in strip.get_flattened_data() if p[3]}
        assert 12 <= len(colours) <= 20, (item["id"], len(colours))
        assert {p[3] for p in strip.get_flattened_data()} == {0, 255}
        assert len({f.tobytes() for f in frames}) >= 2
        assert all(f.getchannel("A").getbbox()[3] <= 62 for f in frames)
        if item["id"] == "npc_squad_idle":
            assert all(any(p[:3] == (255, 174, 32) for p in f.get_flattened_data()) for f in frames)
            assert len({f.tobytes() for f in frames}) == 4
        report.append(f"PASS {item['id']}: {strip.width}x64, four frames, {len(colours)} colours, binary alpha, feet with 2px clear below.")
    report.append("Reviewed at native 1x beside Lappland; Godot import and animation playback not tested.")
    (HERE / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
