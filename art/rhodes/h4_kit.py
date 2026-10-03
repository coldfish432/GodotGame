"""H4 source reduction, native exports, manifests, and asset validation."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

from h3_source_pipeline import reduce_source
from pixel_kit import COLORS, canvas, emit_from_colors, load, save_native


class H4Kit:
    def __init__(self, root: Path, room: str, room_units: tuple[int, int], version: int = 1,
                 spec: str | None = None, method: str | None = None):
        self.root = root
        self.room = room
        self.room_units = room_units
        self.version = version
        self.spec = spec or "罗德岛基地美术策划案_v2_0.md §2.5, §§3.5/3.7/4.4; 基地玩法补充案_v0_1.md"
        self.method = method or "Furniture/equipment originals are stored in sources/ and reduced uniformly by an integer, nearest-neighbor, then palette-quantized. Native-grid edits are limited to state overlays, iconography, signage, decals and alignment to accepted geometry."
        self.root.mkdir(parents=True, exist_ok=True)
        self.assets: list[dict] = []
        self.dependencies: list[dict] = []

    def add(self, name: str, image: Image.Image, *, kind: str, zone: str,
            state: str = "default", group: str | None = None, wall: bool = False,
            emit_colors: tuple[str, ...] = (), source: str | None = None,
            factor: int | None = None, note: str = "", anchor: tuple[int, int] | None = None,
            layer: str = "object") -> Image.Image:
        image = image.convert("RGBA")
        save_native(image, self.root, name)
        emit_name = None
        if emit_colors:
            mask = emit_from_colors(image, emit_colors)
            if mask.getchannel("A").getbbox():
                emit_name = name + "_emit.png"
                save_native(mask, self.root, name + "_emit")
        provenance = None
        if source:
            path = self.root / "sources" / source
            provenance = {"file": "sources/" + source,
                          "size_px": list(Image.open(path).size),
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "uniform_integer_reduction": factor,
                          "quantization": "nearest CIELAB in Rhodes 31-color palette; no dithering"}
        self.assets.append({"id": name, "file": name + ".png", "emit": emit_name,
                            "kind": kind, "zone": zone, "layer": layer,
                            "state_group": group or name,
                            "state": state, "size_px": list(image.size),
                            "anchor_px": list(anchor or (image.width // 2, 0 if wall else image.height - 1)),
                            "wall_mounted": wall, "footprint_units": [0, 0] if wall else
                            [round(image.width / 15, 2), 1], "source": provenance,
                            "notes": note})
        return image

    def generated(self, source: str, name: str, factor: int, *, kind: str,
                  zone: str, state: str = "default", group: str | None = None,
                  wall: bool = False, emit_colors: tuple[str, ...] = (),
                  note: str = "", layer: str = "object") -> Image.Image:
        image = reduce_source(self.root / "sources" / source, factor)
        return self.add(name, image, kind=kind, zone=zone, state=state,
                        group=group, wall=wall, emit_colors=emit_colors,
                        source=source, factor=factor, note=note, layer=layer)

    def dep(self, path: Path, use: str) -> None:
        self.dependencies.append({"file": str(path.resolve()),
                                  "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                  "size_px": list(Image.open(path).size), "use": use,
                                  "locked": True})

    def preview(self, name: str, wall_path: Path, floor_path: Path,
                placements: list[tuple[str, int, int]], lap_path: Path,
                lap_xy: tuple[int, int], size: tuple[int, int],
                overhead_placements: list[tuple[str, int, int]] | None = None) -> None:
        wall, floor, lap = map(load, (wall_path, floor_path, lap_path))
        scene = canvas(*size)
        for y in range(size[1]):
            for x in range(size[0]):
                scene.putpixel((x, y), wall.getpixel((x % wall.width, y)) if y < 46 else
                               floor.getpixel((x % floor.width, (y - 46) % floor.height)))
        for stem, x, y in placements:
            scene.alpha_composite(load(self.root / (stem + ".png")), (x, y))
        scene.alpha_composite(lap, lap_xy)
        for stem, x, y in overhead_placements or []:
            scene.alpha_composite(load(self.root / (stem + ".png")), (x, y))
        scene.save(self.root / (name + ".png"))
        scene.resize((size[0] * 4, size[1] * 4), Image.Resampling.NEAREST).save(
            self.root / (name + "_4x.png"))
        self.dep(wall_path, "accepted 46px room wall")
        self.dep(floor_path, "accepted room floor")
        self.dep(lap_path, "unscaled Lappland frame 0")

    def finish(self, preview: str, assembly: dict, notes: list[str]) -> None:
        manifest = {"batch": f"H4 {self.room} v{self.version}",
                    "spec": self.spec,
                    "palette": {"name": "Rhodes 31-color", "colors": COLORS},
                    "projection": {"pixels_per_unit": 15, "ground_y_scale": 0.85,
                                   "yaw_degrees": 0, "wall_height_px": 46,
                                   "room_units": list(self.room_units)},
                    "method": self.method,
                    "assets": self.assets, "external_dependencies": self.dependencies,
                    "preview": {"file": preview + ".png", "review_4x": preview + "_4x.png",
                                "character": "Lappland frame 0, unscaled"},
                    "assembly": assembly, "notes": notes,
                    "build_script": "build_" + self.room + ".py"}
        (self.root / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        self.validate()

    def validate(self) -> None:
        palette = {tuple(bytes.fromhex(value[1:])) for value in COLORS.values()}
        report = [f"H4 {self.room} v{self.version}: {len(self.assets)} native assets; 31-color palette; 8x exact nearest previews."]
        groups: dict[str, list[dict]] = {}
        for asset in self.assets:
            path = self.root / asset["file"]
            image = load(path)
            colors = set(image.getdata())
            assert {c[3] for c in colors} <= {0, 255}, path
            assert {c[:3] for c in colors if c[3]} <= palette, path
            up = load(self.root / (path.stem + "_8x.png"))
            assert up.size == (image.width * 8, image.height * 8), path
            assert up == image.resize(up.size, Image.Resampling.NEAREST), path
            if asset["emit"]:
                emit = load(self.root / asset["emit"])
                assert emit.size == image.size and emit.getchannel("A").getbbox(), path
            groups.setdefault(asset["state_group"], []).append(asset)
            report.append(f"PASS {asset['id']}: {image.width}x{image.height}, source_factor={asset['source']['uniform_integer_reduction'] if asset['source'] else '-'}, emit={bool(asset['emit'])}")
        for name, items in groups.items():
            if len(items) > 1:
                sizes = {tuple(item["size_px"]) for item in items}
                assert len(sizes) == 1, (name, sizes)
        (self.root / "validation.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
