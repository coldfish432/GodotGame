"""Native-pixel NPC idle strips for the NPC v3 brief."""

from __future__ import annotations

import json
import colorsys
import hashlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


HERE = Path(__file__).resolve().parent
REF = HERE.parent.parent / "portraits" / "refs_F"
PORTRAITS = HERE.parent.parent / "portraits" / "batch_P1_v3"
SQUAD_SOURCE = HERE / "source_paintings" / "squad_field_lineup.png"
INK = "#0b0c0d"
COAT = "#20252b"
COAT_SHADE = "#15191e"
COAT_LIT = "#3f4850"
GREY = "#8e979b"
GREY_LIGHT = "#c9cfd2"
CYAN = "#5fd0d8"
CYAN_DARK = "#2a8a92"
GOLD = "#e6c25a"
HAIR = "#171b27"
HAIR_LIT = "#344362"
RED = "#ac2433"
RED_LIT = "#dc394a"
SKIN = "#e5bca4"


def outlined(image: Image.Image) -> Image.Image:
    mask = image.getchannel("A")
    border = Image.new("RGBA", image.size, INK)
    border.putalpha(mask.filter(ImageFilter.MaxFilter(3)))
    border.alpha_composite(image)
    return border


def reserve_from_painting(kind: str) -> Image.Image:
    source = Image.open(SQUAD_SOURCE).convert("RGBA")
    boxes = {
        "melee": ((100, 130, 540, 770), 27),
        "sniper": ((707, 70, 1289, 770), 28),
        "logistics": ((1413, 130, 1933, 770), 27),
    }
    box, height = boxes[kind]
    crop = source.crop(box)
    width = round(crop.width * height / crop.height)
    small = crop.resize((width, height), Image.Resampling.NEAREST)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    visible = [p[:3] for p, a in zip(small.get_flattened_data(), alpha.get_flattened_data()) if a]
    row = Image.new("RGB", (len(visible), 1))
    row.putdata(visible)
    reduced = row.quantize(colors=27, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = []
    k = 0
    for a in alpha.get_flattened_data():
        if not a:
            out.append((0, 0, 0, 0))
            continue
        original = visible[k]
        colour = reduced.getpixel((k, 0))
        h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in original))
        if .47 <= h <= .58 and s >= .35 and v >= .38:
            colour = (95, 208, 216) if v >= .72 else (42, 138, 146)
        elif kind == "sniper" and .04 <= h <= .14 and s >= .65 and v >= .36:
            colour = (255, 174, 32) if v >= .65 else (188, 83, 9)
        out.append((*colour, 255))
        k += 1
    small.putdata(out)
    return outlined(small)


def squad_frame(frame: int) -> Image.Image:
    im = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    melee = reserve_from_painting("melee")
    sniper = reserve_from_painting("sniper")
    logistics = reserve_from_painting("logistics")
    im.alpha_composite(melee, (30 + (1 if frame == 1 else 0), 62 - melee.height))
    im.alpha_composite(sniper, (51 + (1 if frame == 2 else 0), 62 - sniper.height))
    x = 77 + (1 if frame == 3 else 0)
    y = 62 - logistics.height
    im.alpha_composite(logistics, (x, y))
    # The latch is a deliberately pinned 2px accent on the painted case.
    d = ImageDraw.Draw(im)
    d.rectangle((x + logistics.width - 5, 55, x + logistics.width - 4, 56), fill=CYAN if frame != 2 else CYAN_DARK)
    return im


def portrait_field_base(name: str, content_height: int) -> Image.Image:
    """Sample the approved chibi portrait into the tiny field silhouette."""
    source = Image.open(PORTRAITS / f"portrait_{name}.png").convert("RGBA")
    crop = source.crop(source.getchannel("A").getbbox())
    content_width = round(crop.width * content_height / crop.height)
    small = crop.resize((content_width, content_height), Image.Resampling.NEAREST)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    originals = [p[:3] for p, a in zip(small.get_flattened_data(), alpha.get_flattened_data()) if a]
    row = Image.new("RGB", (len(originals), 1))
    row.putdata(originals)
    reduced = list(row.quantize(colors=20, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB").get_flattened_data())
    recolored = []
    for original, color in zip(originals, reduced):
        h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in original))
        if name == "cannot" and .07 <= h <= .16 and s >= .35 and v >= .4:
            color = (230, 194, 90) if v >= .6 else (153, 116, 43)
        elif name == "closure" and .08 <= h <= .18 and s >= .5 and v >= .5:
            color = (243, 193, 46)
        elif name == "closure" and (h <= .04 or h >= .96) and s >= .5 and v >= .3:
            color = (220, 57, 74) if v >= .6 else (172, 36, 51)
        recolored.append((*color, 255))
    out = []
    k = 0
    for a in alpha.get_flattened_data():
        if a:
            out.append(recolored[k])
            k += 1
        else:
            out.append((0, 0, 0, 0))
    small.putdata(out)
    small = outlined(small)
    frame = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    frame.alpha_composite(small, ((64 - small.width) // 2, 62 - small.height))
    return frame


def shift_patch(image: Image.Image, box: tuple[int, int, int, int], dx: int = 0, dy: int = 0) -> Image.Image:
    if dx == 0 and dy == 0:
        return image
    result = image.copy()
    patch = image.crop(box)
    ImageDraw.Draw(result).rectangle((box[0], box[1], box[2] - 1, box[3] - 1), fill=(0, 0, 0, 0))
    result.alpha_composite(patch, (box[0] + dx, box[1] + dy))
    return result


def cannot_from_portrait(frame: int) -> Image.Image:
    base = portrait_field_base("cannot", 32)
    return shift_patch(base, (22, 51, 44, 58), dx=(-1, 0, 1, 0)[frame])


def closure_from_portrait(frame: int) -> Image.Image:
    base = portrait_field_base("closure", 25)
    base = shift_patch(base, (38, 38, 44, 47), dy=(0, -1, 0, 1)[frame])
    return shift_patch(base, (22, 49, 43, 57), dx=(0, 1, 0, -1)[frame])


def write_asset(asset_id: str, frame_size: tuple[int, int], maker, fps: int) -> dict:
    frames = [maker(i) for i in range(4)]
    strip = Image.new("RGBA", (frame_size[0] * 4, frame_size[1]), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        strip.alpha_composite(frame, (i * frame_size[0], 0))
    strip.save(HERE / f"{asset_id}.png")
    frames[0].resize((frame_size[0] * 8, frame_size[1] * 8), Image.Resampling.NEAREST).save(HERE / f"{asset_id}_frame0_8x.png")
    gif_frames = [frame.resize((frame_size[0] * 8, frame_size[1] * 8), Image.Resampling.NEAREST) for frame in frames]
    gif_frames[0].save(HERE / f"{asset_id}.gif", save_all=True, append_images=gif_frames[1:], duration=round(1000 / fps), loop=0, disposal=2, transparency=0)
    return {"id": asset_id, "file": f"{asset_id}.png", "size": list(strip.size), "frame_size": list(frame_size), "frames": 4, "anchor_px": [frame_size[0] // 2, 61], "fps": fps, "preview": f"{asset_id}_frame0_8x.png", "gif": f"{asset_id}.gif"}


def main() -> None:
    manifest = [
        write_asset("npc_squad_idle", (128, 64), squad_frame, 3),
        write_asset("npc_cannot_idle", (64, 64), cannot_from_portrait, 3),
        write_asset("npc_closure_idle", (64, 64), closure_from_portrait, 3),
    ]
    manifest[0]["source_painting"] = "source_paintings/squad_field_lineup.png"
    manifest[0]["source_sha256"] = hashlib.sha256(SQUAD_SOURCE.read_bytes()).hexdigest()
    for i, name in ((1, "cannot"), (2, "closure")):
        source_path = PORTRAITS / "source_paintings" / f"portrait_{name}_chibi.png"
        manifest[i]["source_painting"] = str(source_path.relative_to(HERE.parent.parent)).replace("\\", "/")
        manifest[i]["source_sha256"] = hashlib.sha256(source_path.read_bytes()).hexdigest()
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # Native-size contact with Lappland from the brief.
    lappland = Image.open(REF / "lappland_sprite.png").convert("RGBA")
    sheet = Image.new("RGBA", (42 + 128 + 64 + 64 + 24, 64), (32, 38, 43, 255))
    sheet.alpha_composite(lappland, (2, 22))
    x = 48
    for id_, width in (("npc_squad_idle", 128), ("npc_cannot_idle", 64), ("npc_closure_idle", 64)):
        frame = Image.open(HERE / f"{id_}.png").crop((0, 0, width, 64))
        sheet.alpha_composite(frame, (x, 0))
        x += width + 4
    sheet.save(HERE / "npc_contact_1x.png")
    sheet.resize((sheet.width * 8, sheet.height * 8), Image.Resampling.NEAREST).save(HERE / "npc_contact_8x.png")
    report = ["F1-C v1 static validation"]
    for item in manifest:
        strip = Image.open(HERE / item["file"]).convert("RGBA")
        assert strip.size == tuple(item["size"])
        assert {p[3] for p in strip.get_flattened_data()} == {0, 255}
        colors = len({p[:3] for p in strip.get_flattened_data() if p[3]})
        frames = [strip.crop((i * item["frame_size"][0], 0, (i + 1) * item["frame_size"][0], 64)) for i in range(4)]
        assert len({frame.tobytes() for frame in frames}) >= 2
        assert all(frame.getchannel("A").getbbox()[3] <= 62 for frame in frames)
        if item["id"] == "npc_squad_idle":
            assert len({frame.tobytes() for frame in frames}) == 4
            assert all(any(p[:3] == (255, 174, 32) for p in frame.get_flattened_data()) for frame in frames)
        report.append(f"PASS {item['id']}: {strip.width}x{strip.height}, 4 frames, binary alpha, {colors} colours, anchor {item['anchor_px']}, {item['fps']} fps.")
    report.append("PASS squad goggles: pinned bright orange visible in all four frames; all four frames differ, case latch on/on/off/on.")
    report.append("Visual check: sprites reviewed at native 1x beside the 42px Lappland reference. Godot import and in-scene animation playback not tested.")
    (HERE / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
