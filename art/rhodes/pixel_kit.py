"""Native-grid drawing helpers for the Rhodes Island asset batches."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


COLORS = {
    "K": "#0b0c0d", "D": "#15181a", "S0": "#1f2427", "S1": "#2c3236",
    "S2": "#3d4448", "S3": "#566064", "G0": "#737d82", "G1": "#98a2a6",
    "G2": "#c3cacc", "W0": "#a9b2b3", "W1": "#d4dadb", "W2": "#eef2f2",
    "Y0": "#6b5a1e", "Y1": "#b89a2a", "Y2": "#f4d73c", "O0": "#6e2f14",
    "O1": "#b8531f", "O2": "#e0782a", "T0": "#0f3a40", "T1": "#2a8a92",
    "T2": "#5fd0d8", "T3": "#b8f4f6", "B0": "#385878", "B1": "#5888a8",
    "B2": "#78b8e8", "L0": "#5a4428", "L1": "#c89a5a", "L2": "#f1d9a6",
    "R0": "#8a1f1f", "E0": "#487808", "E1": "#68d848",
}


def rgba(name: str) -> tuple[int, int, int, int]:
    value = COLORS.get(name, name).lstrip("#")
    return (*bytes.fromhex(value), 255)


def canvas(width: int, height: int, fill: str | None = None) -> Image.Image:
    return Image.new("RGBA", (width, height), rgba(fill) if fill else (0, 0, 0, 0))


def rect(image: Image.Image, box: tuple[int, int, int, int], color: str) -> None:
    ImageDraw.Draw(image).rectangle(box, fill=rgba(color))


def line(image: Image.Image, points: list[tuple[int, int]], color: str, width: int = 1) -> None:
    ImageDraw.Draw(image).line(points, fill=rgba(color), width=width, joint="curve")


def poly(image: Image.Image, points: list[tuple[int, int]], color: str) -> None:
    ImageDraw.Draw(image).polygon(points, fill=rgba(color))


def paste(image: Image.Image, source: Image.Image, xy: tuple[int, int]) -> None:
    image.alpha_composite(source, xy)


def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def save_native(image: Image.Image, output: Path, stem: str) -> str:
    output.mkdir(parents=True, exist_ok=True)
    image.save(output / f"{stem}.png")
    image.resize((image.width * 8, image.height * 8), Image.Resampling.NEAREST).save(output / f"{stem}_8x.png")
    return f"{stem}.png"


def emit_from_colors(image: Image.Image, names: tuple[str, ...]) -> Image.Image:
    emit = canvas(*image.size)
    keep = {rgba(name) for name in names}
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            if pixel in keep:
                emit.putpixel((x, y), pixel)
    return emit


def dependency(path: Path, from_dir: Path, purpose: str) -> dict:
    image = load(path)
    return {
        "file": Path("..", path.parent.name, path.name).as_posix(),
        "size_px": list(image.size),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "use": purpose,
        "locked": True,
    }


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# Each row is exactly five pixels. The glyph lookup is also exported as JSON.
GLYPHS_5 = {
    "A": "01110/10001/10001/11111/10001/10001/10001",
    "B": "11110/10001/10001/11110/10001/10001/11110",
    "C": "01111/10000/10000/10000/10000/10000/01111",
    "D": "11110/10001/10001/10001/10001/10001/11110",
    "E": "11111/10000/10000/11110/10000/10000/11111",
    "F": "11111/10000/10000/11110/10000/10000/10000",
    "G": "01111/10000/10000/10111/10001/10001/01111",
    "H": "10001/10001/10001/11111/10001/10001/10001",
    "I": "11111/00100/00100/00100/00100/00100/11111",
    "J": "00111/00010/00010/00010/10010/10010/01100",
    "K": "10001/10010/10100/11000/10100/10010/10001",
    "L": "10000/10000/10000/10000/10000/10000/11111",
    "M": "10001/11011/10101/10101/10001/10001/10001",
    "N": "10001/11001/10101/10101/10011/10001/10001",
    "O": "01110/10001/10001/10001/10001/10001/01110",
    "P": "11110/10001/10001/11110/10000/10000/10000",
    "Q": "01110/10001/10001/10001/10101/10010/01101",
    "R": "11110/10001/10001/11110/10100/10010/10001",
    "S": "01111/10000/10000/01110/00001/00001/11110",
    "T": "11111/00100/00100/00100/00100/00100/00100",
    "U": "10001/10001/10001/10001/10001/10001/01110",
    "V": "10001/10001/10001/10001/10001/01010/00100",
    "W": "10001/10001/10001/10101/10101/10101/01010",
    "X": "10001/10001/01010/00100/01010/10001/10001",
    "Y": "10001/10001/01010/00100/00100/00100/00100",
    "Z": "11111/00001/00010/00100/01000/10000/11111",
    "0": "01110/10001/10011/10101/11001/10001/01110",
    "1": "00100/01100/00100/00100/00100/00100/01110",
    "2": "01110/10001/00001/00010/00100/01000/11111",
    "3": "11110/00001/00001/01110/00001/00001/11110",
    "4": "00010/00110/01010/10010/11111/00010/00010",
    "5": "11111/10000/10000/11110/00001/00001/11110",
    "6": "01110/10000/10000/11110/10001/10001/01110",
    "7": "11111/00001/00010/00100/01000/01000/01000",
    "8": "01110/10001/10001/01110/10001/10001/01110",
    "9": "01110/10001/10001/01111/00001/00001/01110",
    "-": "00000/00000/00000/11111/00000/00000/00000",
    ".": "00000/00000/00000/00000/00000/01100/01100",
    "/": "00001/00001/00010/00100/01000/10000/10000",
    "#": "01010/01010/11111/01010/11111/01010/01010",
    "×": "10001/01010/00100/01010/10001/00000/00000",
}


GLYPHS_3 = {
    "A": "010/101/111/101/101", "B": "110/101/110/101/110",
    "C": "011/100/100/100/011", "D": "110/101/101/101/110",
    "E": "111/100/110/100/111", "F": "111/100/110/100/100",
    "G": "011/100/101/101/011", "H": "101/101/111/101/101",
    "I": "111/010/010/010/111", "J": "001/001/001/101/010",
    "K": "101/101/110/101/101", "L": "100/100/100/100/111",
    "M": "101/111/111/101/101", "N": "101/111/111/111/101",
    "O": "010/101/101/101/010", "P": "110/101/110/100/100",
    "Q": "010/101/101/011/001", "R": "110/101/110/101/101",
    "S": "011/100/010/001/110", "T": "111/010/010/010/010",
    "U": "101/101/101/101/111", "V": "101/101/101/101/010",
    "W": "101/101/111/111/101", "X": "101/101/010/101/101",
    "Y": "101/101/010/010/010", "Z": "111/001/010/100/111",
    "0": "111/101/101/101/111", "1": "010/110/010/010/111",
    "2": "110/001/010/100/111", "3": "110/001/010/001/110",
    "4": "101/101/111/001/001", "5": "111/100/110/001/110",
    "6": "011/100/110/101/010", "7": "111/001/010/010/010",
    "8": "010/101/010/101/010", "9": "010/101/011/001/110",
    "-": "000/000/111/000/000", ".": "000/000/000/000/010",
    "/": "001/001/010/100/100", "#": "101/111/101/111/101",
    "×": "101/010/101/000/000",
}


GLYPH_ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-./#×"


def draw_text(image: Image.Image, text: str, x: int, y: int, font: int, color: str, spacing: int = 1) -> int:
    mapping = GLYPHS_5 if font == 5 else GLYPHS_3
    advance = font + spacing
    cursor = x
    ink = rgba(color)
    for character in text:
        if character == " ":
            cursor += advance
            continue
        rows = mapping[character].split("/")
        for yy, row in enumerate(rows):
            for xx, bit in enumerate(row):
                if bit == "1" and 0 <= cursor + xx < image.width and 0 <= y + yy < image.height:
                    image.putpixel((cursor + xx, y + yy), ink)
        cursor += advance
    return cursor


def glyph_sheet(font: int) -> tuple[Image.Image, dict]:
    mapping = GLYPHS_5 if font == 5 else GLYPHS_3
    cell_w, cell_h = font + 4, (7 if font == 5 else 5) + 4
    columns = 10
    rows = (len(GLYPH_ORDER) + columns - 1) // columns
    image = canvas(columns * cell_w, rows * cell_h)
    entries = {}
    for index, character in enumerate(GLYPH_ORDER):
        cx = (index % columns) * cell_w
        cy = (index // columns) * cell_h
        draw_text(image, character, cx + 2, cy + 2, font, "G2")
        entries[character] = {
            "rect_px": [cx + 2, cy + 2, font, 7 if font == 5 else 5],
            "advance_px": font + 1,
            "rows": mapping[character].split("/"),
        }
    return image, {
        "font_px": [font, 7 if font == 5 else 5],
        "sheet_px": list(image.size),
        "order": GLYPH_ORDER,
        "tracking_px": 1,
        "line_spacing_px": 2,
        "glyphs": entries,
    }
