"""Uniform integer reduction and 31-color quantization for H3 generated sources.

This is a shared image-processing library. Each room's executable build script
lives inside its batch folder alongside the generated originals in sources/.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from pixel_kit import COLORS, canvas, dependency, emit_from_colors, load, paste, rgba, save_native, write_json


PALETTE_NAMES = tuple(name for name in COLORS if name not in ("K", "E0", "E1"))
PALETTE_RGB = np.array([list(bytes.fromhex(COLORS[name][1:])) for name in PALETTE_NAMES], dtype=np.float32)


def lab(rgb: np.ndarray) -> np.ndarray:
    value = rgb.astype(np.float32) / 255.0
    linear = np.where(value <= 0.04045, value / 12.92, ((value + 0.055) / 1.055) ** 2.4)
    xyz = linear @ np.array([[0.4124564, 0.3575761, 0.1804375],
                             [0.2126729, 0.7151522, 0.0721750],
                             [0.0193339, 0.1191920, 0.9503041]], dtype=np.float32).T
    xyz /= np.array([0.95047, 1.0, 1.08883], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack((116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]),
                     200 * (f[..., 1] - f[..., 2])), axis=-1)


PALETTE_LAB = lab(PALETTE_RGB)


def reduce_source(source_path: Path, factor: int, *, alpha_threshold: int = 112,
                  allowed_names: tuple[str, ...] | None = None) -> Image.Image:
    """Crop transparent source, pad, nearest-reduce uniformly by an integer, quantize."""
    if factor < 2 or int(factor) != factor:
        raise ValueError(f"reduction factor must be an integer >=2: {factor}")
    source = Image.open(source_path).convert("RGBA")
    hard = source.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    bbox = hard.getbbox()
    if bbox is None:
        raise ValueError(f"empty generated source: {source_path}")
    cropped = source.crop(bbox)
    width = math.ceil(cropped.width / factor) * factor + 2 * factor
    height = math.ceil(cropped.height / factor) * factor + 2 * factor
    padded = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    padded.alpha_composite(cropped, (factor, factor))
    reduced = padded.resize((width // factor, height // factor), Image.Resampling.NEAREST)
    array = np.asarray(reduced).copy()
    solid = array[:, :, 3] >= alpha_threshold
    colors = PALETTE_RGB if allowed_names is None else np.array(
        [list(bytes.fromhex(COLORS[name][1:])) for name in allowed_names], dtype=np.float32)
    colors_lab = PALETTE_LAB if allowed_names is None else lab(colors)
    if solid.any():
        ink = lab(array[:, :, :3][solid])
        # L component slightly amplified to retain top/front plane separation.
        delta = ink[:, None, :] - colors_lab[None, :, :]
        delta[:, :, 0] *= 1.18
        nearest = np.argmin(np.sum(delta ** 2, axis=2), axis=1)
        array[:, :, :3][solid] = colors[nearest].astype(np.uint8)
    array[~solid] = 0
    array[solid, 3] = 255
    return Image.fromarray(array, "RGBA")


def save_source_asset(root: Path, source_name: str, stem: str, factor: int,
                      *, alpha_threshold: int = 112, allowed_names: tuple[str, ...] | None = None) -> tuple[Image.Image, dict]:
    source_path = root / "sources" / source_name
    image = reduce_source(source_path, factor, alpha_threshold=alpha_threshold, allowed_names=allowed_names)
    save_native(image, root, stem)
    provenance = {
        "source": f"sources/{source_name}",
        "source_size_px": list(Image.open(source_path).size),
        "source_sha256": hashlib.sha256(source_path.read_bytes()).hexdigest(),
        "integer_reduction": factor,
        "quantization": "nearest CIELAB of Rhodes 31-color palette; no dithering",
        "alpha": f"binary at {alpha_threshold}/255 after uniform nearest reduction",
    }
    return image, provenance


class Kit:
    """Metadata/export support; room decisions stay in the local build_*.py."""

    def __init__(self, root: Path, room: str, code: str, size_units: tuple[int, int],
                 floor_size_px: tuple[int, int], wall: Path, floor: Path, version: int = 2):
        self.root, self.room, self.code = root, room, code
        self.version = version
        self.size_units, self.floor_size_px = size_units, floor_size_px
        self.wall, self.floor = wall, floor
        self.assets: list[dict] = []
        self.dependencies: dict[str, dict] = {}
        self.life_details: list[str] = []
        self.stand_spots: list[str] = []
        self.generated: list[str] = []
        self.root.mkdir(exist_ok=True)

    def dep(self, path: Path, purpose: str) -> None:
        self.dependencies[str(path.resolve())] = dependency(path, self.root, purpose)

    def add(self, stem: str, image: Image.Image, kind: str, notes: str, coverage: list[str],
            *, source: dict | None = None, wall: bool = False, emit: tuple[str, ...] = (),
            footprint: tuple[float, float] | None = None, life: bool = False,
            stand: bool = False, postprocess: str | None = None) -> None:
        save_native(image, self.root, stem)
        emit_name = None
        if emit:
            mask = emit_from_colors(image, emit)
            if not mask.getchannel("A").getbbox():
                raise ValueError(f"empty emit selection for {stem}: {emit}")
            emit_name = f"{stem}_emit.png"
            save_native(mask, self.root, stem + "_emit")
        if footprint is None:
            footprint = (0.0, 0.0) if wall else (round(image.width / 15, 2),
                          round(image.height / 15, 2) if kind == "decal" else 1.0)
        anchor = [image.width // 2, 0 if wall else image.height // 2 if kind == "decal" else image.height - 1]
        item = {"id": stem, "file": stem + ".png", "emit": emit_name, "kind": kind,
                "size_px": list(image.size), "anchor_px": anchor,
                "footprint_units": list(footprint), "wall_mounted": wall,
                "states": ["default"], "notes": notes, "coverage_35": coverage,
                "source": source, "postprocess": postprocess}
        self.assets.append(item)
        if life:
            self.life_details.append(stem)
        if stand:
            self.stand_spots.append(stem)
        if source:
            self.generated.append(stem)

    def generated_asset(self, source_name: str, stem: str, factor: int, kind: str,
                        notes: str, coverage: list[str], *, wall: bool = False,
                        emit: tuple[str, ...] = (), life: bool = False,
                        footprint: tuple[float, float] | None = None,
                        polish=None, postprocess: str | None = None,
                        allowed_names: tuple[str, ...] | None = None) -> Image.Image:
        image, provenance = save_source_asset(self.root, source_name, stem, factor,
                                              allowed_names=allowed_names)
        if polish:
            image = image.copy()
            polish(image)
        self.add(stem, image, kind, notes, coverage, source=provenance, wall=wall,
                 emit=emit, life=life, footprint=footprint, postprocess=postprocess)
        return image

    def geometric(self, path: Path, stem: str, kind: str, notes: str, coverage: list[str],
                  *, wall: bool = False, stand: bool = False) -> None:
        self.add(stem, load(path), kind, notes, coverage, wall=wall, stand=stand,
                 postprocess="Accepted H3 v1 native-grid geometric module copied without resampling")
        self.dep(path, "Accepted H3 v1 geometry source")

    def composite(self, output_stem: str, placements: list[tuple[Path, tuple[int, int]]],
                  lap: Image.Image, lap_xy: tuple[int, int]) -> tuple[int, int]:
        width, depth = self.floor_size_px
        wall = load(self.wall)
        floor = load(self.floor)
        review = canvas(width, depth + 46)
        for y in range(review.height):
            for x in range(review.width):
                review.putpixel((x, y), wall.getpixel((x % wall.width, y)) if y < 46 else
                                floor.getpixel((x % floor.width, (y - 46) % floor.height)))
        for path, xy in placements:
            paste(review, load(path), xy)
        paste(review, lap, lap_xy)
        review.save(self.root / (output_stem + ".png"))
        review.resize((width * 4, (depth + 46) * 4), Image.Resampling.NEAREST).save(
            self.root / (output_stem + "_4x.png"))
        return review.size

    def finish(self, preview_stem: str, preview_size: tuple[int, int], lap_xy: tuple[int, int],
               assembly: dict, checklist: dict, extra_dependencies: list[tuple[Path, str]]) -> None:
        self.dep(self.wall, "46px room wall shell")
        self.dep(self.floor, "120x120 seamless floor shell")
        for path, use in extra_dependencies:
            self.dep(path, use)
        manifest = {
            "batch": f"H3 {self.room} v{self.version}", "spec": "罗德岛基地美术策划案_v2_0.md §§2.3, 3.1.1, 3.5, 3.7, 4.4",
            "method": "Each furniture/equipment item has its own generated PNG in sources/. The local build script crops alpha, reduces uniformly by an item-specific integer factor, quantizes to the 31-color palette and preserves binary alpha. Geometric modules reuse accepted native-grid exports.",
            "pixel_scale": 1, "assets": self.assets, "external_dependencies": list(self.dependencies.values()),
            "shell": {"size_units": list(self.size_units), "floor_size_px": list(self.floor_size_px),
                      "wall_height_px": 46, "wall_tile": self.dependencies[str(self.wall.resolve())]["file"],
                      "floor_tile": self.dependencies[str(self.floor.resolve())]["file"],
                      "assembly": "Review composite shows one suggested layout; final scene assembly remains with user."},
            "preview": {"file": preview_stem + ".png", "size_px": list(preview_size),
                        "character_origin_px": list(lap_xy), "character": "Lappland frame 0 unscaled; 30px visible height",
                        "review_4x": preview_stem + "_4x.png"},
            "logo_policy": "M on department sign and S on the main interactive furniture only; two per review screen, below six cap.",
            "stand_spots": self.stand_spots, "life_details": self.life_details,
            "assembly": assembly, "checklist_35": checklist,
            "build_script": next(path.name for path in self.root.glob("build_*.py")),
        }
        write_json(self.root / "manifest.json", manifest)
        (self.root / "validation.txt").write_text(
            f"H3 {self.room} v{self.version}: {len(self.assets)} assets, {len(self.generated)} generated furniture/equipment items, "
            f"{sum(bool(a['emit']) for a in self.assets)} emit masks, {len(self.dependencies)} hashed dependencies.\n"
            "Uniform integer downscale only; independent validation follows.\n", encoding="utf-8")
