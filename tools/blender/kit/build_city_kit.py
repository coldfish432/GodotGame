"""Lungmen lower-city kit: art/kit/city_*.glb (城市地图调研与方案_v1.md §3).

用户 2026-10-14: 真实高度，区分不同区域的城景；都建. Buildings stand at real
height and differ by district: the outer city's shop houses and tall blocks
(painted plaster, shopfronts with shutters and signboards, air conditioners,
rooftop water tanks), a two-storey tea restaurant, a collapsed block; the
slums' corrugated shacks; the warehouse yard's containers and gantry crane;
the building site's scaffolding. Then the street furniture of a city under
siege: water barriers, czech hedgehogs, sandbag walls, a news kiosk; the
quarantine wall and its gate; a concrete overpass (the city's bridge), a
sewer culvert, a rooftop helipad.

Blender Z up, metres; origin at the bottom centre unless noted; a building's
street front faces Blender -Y. Windows are thin panes on the walls; some are
lit (parts named "glow" draw self-lit in the game).

Through the Blender MCP add-on, one new scene per piece (see BUILDERS), or:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_city_kit.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
import poi_detail as d  # noqa: E402
from build_mine_accents import rust_material, wood_material  # noqa: E402
from build_poi import _ramp_material, painted, cloth, _settled_publish, _publish  # noqa: E402

# --- Materials ------------------------------------------------------------------------

## The outer city's buildings are kept up (用户 2026-10-16: 城区里的房子不应该是
## 斑驳的，贫民窟应该是): built with CLEAN on, their render and roofs use the
## cleaned swatches (art/kit/textures/painted/build_city_clean.py) and their
## concrete trims a narrow ramp. The slums' copies (WORN) are built with it off.
CLEAN = False


def concrete(name, seed, base="7e8184"):
    if CLEAN:
        return _ramp_material(name, [(0.4, _blend(base, "000000", 0.12)), (0.6, base), (0.8, _blend(base, "ffffff", 0.1))], 4.0, seed, 2.0)
    return _ramp_material(name, [(0.28, "4e5154"), (0.55, base), (0.95, "a3a5a6")], 4.0, seed, 6.0)


# Sol's hand-painted swatches (城市贴图美术需求_v1.md C5–C9), 42.67 px a metre.
PAINTED = os.path.join(kit.OUT_DIR, "textures", "painted")


def _image(file):
    return bpy.data.images.load(os.path.join(PAINTED, file), check_existing=True)


def _swatch(nodes, links, file, metres):
    """The swatch laid over the part in metres, box-projected from its object
    space: walls take it upright, roofs from above."""
    coord = nodes.new("ShaderNodeTexCoord")
    scale = nodes.new("ShaderNodeVectorMath")
    scale.operation = "SCALE"
    scale.inputs["Scale"].default_value = 1.0 / metres
    links.new(coord.outputs["Object"], scale.inputs[0])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = _image(file)
    tex.projection = "BOX"
    tex.projection_blend = 0.0
    tex.interpolation = "Closest"
    links.new(scale.outputs[0], tex.inputs["Vector"])
    return tex.outputs["Color"]


def _tinted(nodes, links, colour, hex_rgb, gain):
    """A neutral swatch coloured: times the tint, lifted by the gain."""
    mix = nodes.new("ShaderNodeVectorMath")
    mix.operation = "MULTIPLY"
    links.new(colour, mix.inputs[0])
    rgb = kit.srgb(hex_rgb)
    mix.inputs[1].default_value = (rgb[0] * gain, rgb[1] * gain, rgb[2] * gain)
    return mix.outputs[0]


def _blend(a, b, t):
    ca, cb = kit.srgb(a), kit.srgb(b)
    mixed = [ca[i] * (1 - t) + cb[i] * t for i in range(3)]
    # Back to sRGB hex for kit.srgb.
    def enc(c):
        c = max(0.0, min(1.0, c))
        return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return "".join(f"{round(enc(c) * 255):02x}" for c in mixed)


def _new(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    return mat, mat.node_tree.nodes, mat.node_tree.links


def plaster(name, hex_rgb, seed):
    """Painted render (C6), coloured per building; its roof the flat roof (C5)."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    wall = _tinted(nodes, links, _swatch(nodes, links, "city_plaster_clean.png" if CLEAN else "city_plaster.png", 6.0), hex_rgb, 1.8)
    # The roof a shade of its walls, so a block of roofs is not one grey.
    roof = _tinted(nodes, links, _swatch(nodes, links, "city_roof_clean.png" if CLEAN else "city_roof.png", 6.0), _blend("ffffff", hex_rgb, 0.35), 1.75)
    # Faces looking up are roof (the parapet's top included).
    geometry = nodes.new("ShaderNodeNewGeometry")
    up = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geometry.outputs["Normal"], up.inputs[0])
    flat = nodes.new("ShaderNodeMath")
    flat.operation = "GREATER_THAN"
    flat.inputs[1].default_value = 0.7
    links.new(up.outputs["Z"], flat.inputs[0])
    pick = nodes.new("ShaderNodeMix")
    pick.data_type = "RGBA"
    links.new(flat.outputs[0], pick.inputs["Factor"])
    links.new(wall, pick.inputs["A"])
    links.new(roof, pick.inputs["B"])
    links.new(pick.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def shutter(name):
    """Roller shutters (C8)."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    links.new(_tinted(nodes, links, _swatch(nodes, links, "city_shutter.png", 3.0), "ffffff", 1.15), bsdf.inputs["Base Color"])
    return mat


## C9's eight boards: 茶餐廳 藥房 當舖 五金 / 押 涼茶 旅館 電器.
SIGNS = 8


def sign_face(name, cell, axes="xz"):
    """One board of C9 across a square part: its generated coordinates (0–1
    over the part) picked out of the 4x2 atlas. axes: the part's width and
    height axes (xz for a board facing the street, yz for a blade sign)."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    coord = nodes.new("ShaderNodeTexCoord")
    split = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Generated"], split.inputs[0])
    col, row = cell % 4, cell // 4
    u = nodes.new("ShaderNodeMath")
    u.operation = "MULTIPLY_ADD"
    links.new(split.outputs["X" if axes[0] == "x" else "Y"], u.inputs[0])
    u.inputs[1].default_value = 0.25
    u.inputs[2].default_value = col * 0.25
    v = nodes.new("ShaderNodeMath")
    v.operation = "MULTIPLY_ADD"
    links.new(split.outputs["Z"], v.inputs[0])
    v.inputs[1].default_value = 0.5
    v.inputs[2].default_value = 1.0 - (row + 1) * 0.5
    join = nodes.new("ShaderNodeCombineXYZ")
    links.new(u.outputs[0], join.inputs["X"])
    links.new(v.outputs[0], join.inputs["Y"])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = _image("city_signs.png")
    tex.interpolation = "Closest"
    tex.extension = "EXTEND"
    links.new(join.outputs[0], tex.inputs["Vector"])
    links.new(_tinted(nodes, links, tex.outputs["Color"], "ffffff", 1.2), bsdf.inputs["Base Color"])
    return mat


def glass(name, seed):
    return _ramp_material(name, [(0.3, "141b21"), (0.7, "24323d"), (1.0, "3a4c58")], 6.0, seed, 2.0)


def lit(name):
    return kit.flat_material(name, "ffd690", 8.0, "e8a050")


def corrugated(name, hex_rgb, seed, rusty=0.5):
    """Corrugated sheet (C7), its paint the tint; the rust is Sol's."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    links.new(_tinted(nodes, links, _swatch(nodes, links, "city_corrugated.png", 3.0), hex_rgb, 1.9), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def steel(name, seed, base="5d6266"):
    return d.worn(_ramp_material(name, [(0.3, "2e3134"), (0.6, base), (1.0, "8a8f93")], 6.0, seed, 4.0),
                  edge="b8bcbe", edge_strength=0.35, grime="1a1a1a", grime_strength=0.3)


# --- Building helpers -------------------------------------------------------------------

def _windows(prefix, width, depth, floors, floor_h, start, seed, sides=("front", "back", "left", "right"), lit_share=0.18):
    """Panes on every floor of the given sides; returns (glass, glow, units)."""
    random.seed(seed)
    panes, glow, units = [], [], []
    sills, cages = [], []
    for side in sides:
        along = width if side in ("front", "back") else depth
        count = max(1, int(along / 1.75))
        step = along / count
        for f in range(floors):
            z = start + f * floor_h + floor_h * 0.5
            for k in range(count):
                u = -along * 0.5 + step * (k + 0.5)
                if random.random() < 0.08: continue
                size = (1.15, 0.06, 1.25)
                if side == "front": loc, rot = (u, -depth * 0.5 - 0.02, z), (0, 0, 0)
                elif side == "back": loc, rot = (u, depth * 0.5 + 0.02, z), (0, 0, 0)
                elif side == "left": loc, rot = (-width * 0.5 - 0.02, u, z), (0, 0, math.pi / 2)
                else: loc, rot = (width * 0.5 + 0.02, u, z), (0, 0, math.pi / 2)
                pane = kit.box(f"{prefix}w{side}{f}_{k}", size, loc, rot)
                (glow if random.random() < lit_share else panes).append(pane)
                # A sill under each window; iron window cages (Lungmen's 铁窗) on some.
                out_dir = {"front": (0, -1), "back": (0, 1), "left": (-1, 0), "right": (1, 0)}[side]
                sill_loc = (loc[0] + out_dir[0] * 0.08, loc[1] + out_dir[1] * 0.08, z - 0.7)
                sills.append(kit.box(f"{prefix}s{side}{f}_{k}", (1.35, 0.2, 0.1), sill_loc, rot))
                if random.random() < 0.35:
                    cage_loc = (loc[0] + out_dir[0] * 0.3, loc[1] + out_dir[1] * 0.3, z)
                    for b in range(5):
                        offset = -0.55 + b * 0.275
                        bar_loc = (cage_loc[0] + (offset if side in ("front", "back") else 0.0), cage_loc[1] + (offset if side in ("left", "right") else 0.0), z)
                        cages.append(kit.box(f"{prefix}c{side}{f}_{k}_{b}", (0.035, 0.035, 1.35), bar_loc))
                    cages.append(kit.box(f"{prefix}ct{side}{f}_{k}", (1.3, 0.55, 0.04), (cage_loc[0], cage_loc[1], z + 0.68), rot))
                # An air conditioner hung under some windows.
                if random.random() < 0.22:
                    out = 0.25
                    if side == "front": aloc = (u + 0.3, -depth * 0.5 - out, z - 0.95)
                    elif side == "back": aloc = (u + 0.3, depth * 0.5 + out, z - 0.95)
                    elif side == "left": aloc = (-width * 0.5 - out, u + 0.3, z - 0.95)
                    else: aloc = (width * 0.5 + out, u + 0.3, z - 0.95)
                    units.append(d.bbox(f"{prefix}ac{side}{f}_{k}", (0.75, 0.45, 0.5), aloc, rot, width=0.02))
    return panes, glow, units + cages, sills


def _roof(prefix, width, depth, top, seed, tank=True):
    """Parapet round the roof, a water tank on legs, an aerial."""
    random.seed(seed)
    parts = []
    t = 0.18
    for (sx, sy, lx, ly) in ((width, t, 0, -depth * 0.5 + t * 0.5), (width, t, 0, depth * 0.5 - t * 0.5),
                             (t, depth, -width * 0.5 + t * 0.5, 0), (t, depth, width * 0.5 - t * 0.5, 0)):
        parts.append(kit.box(f"{prefix}par{len(parts)}", (sx, sy, 0.7), (lx, ly, top + 0.35)))
    extras = []
    if tank:
        x, y = random.uniform(-width * 0.25, width * 0.25), random.uniform(-depth * 0.2, depth * 0.25)
        extras.append(d.cyl(f"{prefix}tank", 0.75, 1.5, (x, y, top + 1.45), vertices=16))
        for i in range(4):
            a = i * math.pi / 2 + math.pi / 4
            extras.append(d.bbox(f"{prefix}leg{i}", (0.1, 0.1, 0.8), (x + math.cos(a) * 0.55, y + math.sin(a) * 0.55, top + 0.4)))
    extras.append(d.cyl(f"{prefix}aerial", 0.04, 2.2, (width * 0.35, depth * 0.3, top + 1.1), vertices=6))
    return parts, extras


def _shopfront(prefix, width, depth, seed, sign_hex):
    """Ground floor street side: roller shutters, one half up, and a signboard."""
    random.seed(seed)
    shutters, boards = [], []
    count = max(1, int(width / 2.8))
    step = width / count
    for k in range(count):
        u = -width * 0.5 + step * (k + 0.5)
        h = 2.5 if random.random() > 0.3 else 1.2
        shutters.append(kit.box(f"{prefix}sh{k}", (step - 0.35, 0.08, h), (u, -depth * 0.5 - 0.05, 0.3 + (2.5 - h) + h * 0.5)))
    boards.append(d.bbox(f"{prefix}sign", (width * 0.9, 0.18, 0.75), (0, -depth * 0.5 - 0.15, 3.25), width=0.03))
    # The shop's own name on the fascia: a square board from C9.
    face = kit.box(f"{prefix}face", (1.3, 0.06, 1.3), (random.uniform(-width * 0.25, width * 0.25), -depth * 0.5 - 0.27, 3.25))
    # Blade signs stacked out over the street, the Lungmen street signature.
    blades = []
    for b in range(random.randint(2, 3)):
        x = -width * 0.5 + 0.6 + b * (width - 1.2) / 2.0
        size = random.uniform(1.2, 1.6)
        blades.append(kit.box(f"{prefix}blade{b}", (0.12, size, size), (x, -depth * 0.5 - 0.15 - size * 0.5, random.uniform(4.8, 6.6))))
    return shutters, boards, blades, face


def _shop_parts(name, shutters, boards, blades, face, seed):
    """Shutters, the fascia, the shop's board and its blade signs, each a part
    of its own (a board is one C9 cell over the whole part)."""
    random.seed(seed + 11)
    cells = random.sample(range(SIGNS), 1 + len(blades))
    parts = [(kit.join(shutters, "shutter"), shutter(f"{name}_shutter_p"), "shutter"),
             (kit.join(boards, "sign"), painted(f"{name}_sign_p", "2a2c2e", seed), "sign"),
             (face, sign_face(f"{name}_face_p", cells[0]), "face")]
    for k, blade in enumerate(blades):
        parts.append((blade, sign_face(f"{name}_blade{k}_p", cells[k + 1], "yz"), f"blade{k}"))
    return parts


def _building(name, width, depth, floors, floor_h, wall_hex, sign_hex, seed, shop=True, lit_share=0.18):
    random.seed(seed)
    height = floors * floor_h
    body = d.bbox("body", (width, depth, height), (0, 0, height * 0.5), width=0.04)
    # Floor bands: a slab edge between storeys.
    bands = [kit.box(f"band{f}", (width + 0.12, depth + 0.12, 0.16), (0, 0, f * floor_h)) for f in range(1, floors)]
    start = floor_h if shop else 0.0
    panes, glow, units, sills = _windows("", width, depth, floors - (1 if shop else 0), floor_h, start, seed, lit_share=lit_share)
    trims, extras = _roof("", width, depth, height, seed)
    trims += sills
    metal = units + extras
    parts = [(kit.join([body] + bands + trims, "wall"), plaster(f"{name}_wall_p", wall_hex, seed), "wall"),
             (kit.join(panes, "glass"), glass(f"{name}_glass_p", seed), "glass")]
    if glow: parts.append((kit.join(glow, "glow"), lit(f"{name}_glow_p"), "glow"))
    if shop:
        shutters, boards, blades, face = _shopfront("", width, depth, seed, sign_hex)
        parts += _shop_parts(name, shutters, boards, blades, face, seed)
    parts.append((kit.join(metal, "metal"), steel(f"{name}_metal_p", seed), "metal"))
    trims_w, mulls = _framed_windows("", width, depth, floors - (1 if shop else 0), floor_h, start, seed)
    parts.append((kit.join(trims_w, "frames"), concrete(f"{name}_frames_p", seed, "b0aea6"), "frames"))
    parts.append((kit.join(mulls, "mullions"), steel(f"{name}_mullions_p", seed, "3a3e42"), "mullions"))
    parts += _detail_parts(name, seed, width, depth, floors - (1 if shop else 0), floor_h, start, height, shop)
    return parts


# --- Detail (用户 2026-10-14: 城市地图里的建模能更精细一点，提升画面表现) -------------
# What the follow camera (58° down) sees most of a building is its roof, then
# its street face: both get the clutter of a lived-in Lungmen block.

LAUNDRY = ["c8352a", "2e6fb0", "e0b030", "dedad2", "3fae6a", "d04a8a", "8a6a4a"]


def _side_frame(side, width, depth):
    """Where a side's face lies, and how a local (u, out, z) maps onto it."""
    if side == "front": return lambda u, o, z: (u, -depth * 0.5 - o, z), (0, 0, 0)
    if side == "back": return lambda u, o, z: (u, depth * 0.5 + o, z), (0, 0, 0)
    if side == "left": return lambda u, o, z: (-width * 0.5 - o, u, z), (0, 0, math.pi / 2)
    return lambda u, o, z: (width * 0.5 + o, u, z), (0, 0, math.pi / 2)


def _frame(prefix, at, rot, w, h):
    """A window's surround and its cross mullion, standing proud of the wall."""
    trim = [kit.box(f"{prefix}ft", (w + 0.2, 0.08, 0.1), _shift(at, rot, 0, 0, h * 0.5 + 0.05), rot),
            kit.box(f"{prefix}fl", (0.1, 0.08, h + 0.2), _shift(at, rot, -w * 0.5 - 0.05, 0, 0), rot),
            kit.box(f"{prefix}fr", (0.1, 0.08, h + 0.2), _shift(at, rot, w * 0.5 + 0.05, 0, 0), rot)]
    mull = [kit.box(f"{prefix}mv", (0.05, 0.05, h), _shift(at, rot, 0, -0.02, 0), rot),
            kit.box(f"{prefix}mh", (w, 0.05, 0.05), _shift(at, rot, 0, -0.02, h * 0.12), rot)]
    return trim, mull


def _shift(at, rot, du, dout, dz):
    """`at` moved du along the face, dout out of it, dz up (for a face turned rot)."""
    if rot[2] == 0: return (at[0] + du, at[1] - dout if at[1] < 0 else at[1] + dout, at[2] + dz)
    return (at[0] - dout if at[0] < 0 else at[0] + dout, at[1] + du, at[2] + dz)


def _facade(prefix, width, depth, floors, floor_h, start, top, seed, sides=("front", "back")):
    """Balconies (Lungmen's caged ones, laundry out on a pole), drainpipes down
    the corners, a bundle of cables across the face."""
    random.seed(seed + 101)
    concrete_parts, iron, cloth_parts = [], [], []
    for side in sides:
        place, rot = _side_frame(side, width, depth)
        along = width if side in ("front", "back") else depth
        for f in range(floors):
            if random.random() > 0.45: continue
            z = start + f * floor_h
            u = random.uniform(-along * 0.3, along * 0.3)
            bw = random.uniform(1.8, 2.6)
            # Slab, its railing, the cage over it.
            concrete_parts.append(kit.box(f"{prefix}bs{side}{f}", (bw, 0.9, 0.12) if rot[2] == 0 else (0.9, bw, 0.12), place(u, 0.45, z + 0.06)))
            rail = kit.box(f"{prefix}br{side}{f}", (bw, 0.05, 0.9) if rot[2] == 0 else (0.05, bw, 0.9), place(u, 0.88, z + 0.55))
            iron.append(rail)
            for k in range(int(bw / 0.3)):
                iron.append(kit.box(f"{prefix}bb{side}{f}_{k}", (0.03, 0.03, 0.9), place(u - bw * 0.5 + 0.15 + k * 0.3, 0.88, z + 0.55)))
            # Laundry on a pole out from the cage: three or four bright cloths.
            pole_z = z + floor_h * 0.75
            iron.append(kit.box(f"{prefix}lp{side}{f}", (bw + 0.6, 0.03, 0.03) if rot[2] == 0 else (0.03, bw + 0.6, 0.03), place(u, 1.15, pole_z)))
            for k in range(random.randint(2, 4)):
                cu = u - bw * 0.4 + k * bw * 0.28
                cloth_parts.append(kit.box(f"{prefix}lc{side}{f}_{k}", (0.45, 0.02, 0.6) if rot[2] == 0 else (0.02, 0.45, 0.6), place(cu, 1.15, pole_z - 0.32)))
        # A drainpipe down one corner of the face.
        corner = along * 0.5 - 0.15
        iron.append(d.cyl(f"{prefix}dp{side}", 0.06, top + 0.6, place(corner * random.choice((-1, 1)), 0.08, (top + 0.6) * 0.5), vertices=6))
        # Cables sagging across the face.
        if random.random() < 0.6:
            cz = random.uniform(max(start, 2.8), top - 0.4)
            for k in range(2):
                iron.append(kit.box(f"{prefix}cb{side}{k}", (along * 0.9, 0.025, 0.025) if rot[2] == 0 else (0.025, along * 0.9, 0.025), place(0, 0.05, cz - k * 0.12)))
    return concrete_parts, iron, cloth_parts


def _roof_detail(prefix, width, depth, top, seed, stairs=True):
    """A Lungmen roof: parapet coping, the stair housing, condensers with their
    fans, a solar water heater, a dish, vent stacks, a skylight, laundry lines."""
    random.seed(seed + 202)
    walls, metal, glass_parts, cloth_parts = [], [], [], []
    units, tanks = [], []
    # Coping along the parapet's top.
    for (sx, sy, lx, ly) in ((width + 0.08, 0.3, 0, -depth * 0.5 + 0.09), (width + 0.08, 0.3, 0, depth * 0.5 - 0.09),
                             (0.3, depth + 0.08, -width * 0.5 + 0.09, 0), (0.3, depth + 0.08, width * 0.5 - 0.09, 0)):
        walls.append(kit.box(f"{prefix}cope{len(walls)}", (sx, sy, 0.08), (lx, ly, top + 0.74)))
    taken = []

    def spot(w, dd, margin=0.5):
        for _ in range(20):
            x = random.uniform(-width * 0.5 + w * 0.5 + margin, width * 0.5 - w * 0.5 - margin)
            y = random.uniform(-depth * 0.5 + dd * 0.5 + margin, depth * 0.5 - dd * 0.5 - margin)
            if all(abs(x - tx) > (w + tw) * 0.5 + 0.2 or abs(y - ty) > (dd + td) * 0.5 + 0.2 for tx, ty, tw, td in taken):
                taken.append((x, y, w, dd))
                return x, y
        return None

    if stairs and width >= 6.0:
        # The stair housing at the back (away from the street), door to the roof.
        sx, sy = random.uniform(-width * 0.25, width * 0.25), depth * 0.5 - 1.6
        taken.append((sx, sy, 2.6, 2.6))
        walls.append(d.bbox(f"{prefix}stair", (2.4, 2.4, 2.4), (sx, sy, top + 1.2), width=0.03))
        walls.append(kit.box(f"{prefix}stairtop", (2.6, 2.6, 0.12), (sx, sy, top + 2.46)))
        metal.append(kit.box(f"{prefix}stairdoor", (0.9, 0.05, 1.9), (sx + 0.4, sy - 1.22, top + 0.95)))
    for i in range(random.randint(2, 4)):
        at = spot(1.0, 0.6)
        if at is None: break
        x, y = at
        units.append(d.bbox(f"{prefix}cond{i}", (0.95, 0.55, 0.7), (x, y, top + 0.35), width=0.02))
        metal.append(d.cyl(f"{prefix}fan{i}", 0.22, 0.03, (x, y - 0.29, top + 0.38), (math.pi / 2, 0, 0), vertices=12))
        metal.append(kit.box(f"{prefix}grill{i}", (0.5, 0.02, 0.04), (x, y - 0.31, top + 0.38)))
        metal.append(kit.box(f"{prefix}line{i}", (0.05, 0.05, 0.05 + abs(y) * 0.0), (x, y + 0.3, top + 0.08)))
    # Blue plastic water tanks, one or two, on a steel stand.
    for i in range(random.randint(1, 2)):
        at = spot(1.3, 1.3)
        if at is None: break
        x, y = at
        tanks.append(d.cyl(f"{prefix}ptank{i}", 0.55, 1.2, (x, y, top + 1.05), vertices=14))
        tanks.append(d.cyl(f"{prefix}ptlid{i}", 0.3, 0.12, (x, y, top + 1.7), vertices=12))
        metal.append(kit.box(f"{prefix}ptstand{i}", (1.2, 1.2, 0.45), (x, y, top + 0.22)))
    # Patches of fresh felt over the old roof.
    for i in range(random.randint(1, 3)):
        at = spot(random.uniform(1.5, 3.0), random.uniform(1.2, 2.5), 0.3)
        if at is None: break
        x, y = at
        w, dd = taken[-1][2], taken[-1][3]
        taken.pop()
        walls.append(kit.box(f"{prefix}patch{i}", (w, dd, 0.03), (x, y, top + 0.02)))
    if random.random() < 0.6:
        at = spot(2.0, 1.4)
        if at:
            x, y = at
            # Solar water heater: a tilted panel and its tank above.
            glass_parts.append(kit.box(f"{prefix}solar", (1.9, 1.3, 0.05), (x, y, top + 0.75), (math.radians(35), 0, 0)))
            metal.append(d.cyl(f"{prefix}soltank", 0.2, 2.0, (x, y + 0.6, top + 1.25), (0, math.pi / 2, 0), vertices=10))
            for k in (-0.8, 0.8):
                metal.append(kit.box(f"{prefix}solleg{k}", (0.05, 0.05, 1.2), (x + k, y + 0.5, top + 0.6)))
    if random.random() < 0.5:
        at = spot(0.9, 0.9)
        if at:
            x, y = at
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.45, location=(x, y, top + 0.9))
            dish = bpy.context.object
            dish.scale = (1.0, 0.35, 1.0)
            dish.rotation_euler = (math.radians(-30), 0, random.uniform(0, math.tau))
            metal.append(dish)
            metal.append(kit.box(f"{prefix}dishpost", (0.06, 0.06, 0.6), (x, y, top + 0.3)))
    for i in range(random.randint(1, 3)):
        at = spot(0.4, 0.4, 0.3)
        if at is None: break
        metal.append(d.cyl(f"{prefix}stack{i}", 0.12, random.uniform(0.7, 1.4), (at[0], at[1], top + 0.5), vertices=8))
    if random.random() < 0.4:
        at = spot(1.4, 1.0)
        if at:
            walls.append(kit.box(f"{prefix}skyb", (1.4, 1.0, 0.25), (at[0], at[1], top + 0.12)))
            glass_parts.append(kit.box(f"{prefix}sky", (1.2, 0.8, 0.04), (at[0], at[1], top + 0.27)))
    if random.random() < 0.55:
        # A laundry line across the roof between two posts.
        y = random.uniform(-depth * 0.2, depth * 0.2)
        span = width * 0.6
        for k in (-span * 0.5, span * 0.5):
            metal.append(kit.box(f"{prefix}lpost{k}", (0.05, 0.05, 1.6), (k, y, top + 0.8)))
        metal.append(kit.box(f"{prefix}lline", (span, 0.02, 0.02), (0, y, top + 1.55)))
        for k in range(random.randint(3, 6)):
            cloth_parts.append(kit.box(f"{prefix}lcl{k}", (random.uniform(0.35, 0.6), 0.02, random.uniform(0.5, 0.8)), (-span * 0.45 + k * span * 0.17, y, top + 1.2)))
    return walls, metal, glass_parts, cloth_parts, units, tanks


def _awning(prefix, width, depth, seed):
    """A striped cloth awning over part of the shopfront."""
    random.seed(seed + 303)
    w = random.uniform(width * 0.35, width * 0.6)
    x = random.uniform(-width * 0.5 + w * 0.5 + 0.2, width * 0.5 - w * 0.5 - 0.2)
    return [d.bbox(f"{prefix}awn", (w, 1.2, 0.08), (x, -depth * 0.5 - 0.6, 2.85), (math.radians(18), 0, 0), width=0.01)]


def _laundry_material(name, seed):
    """Laundry: the bright cloths of LAUNDRY, patched by object position."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    coord = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexVoronoi")
    noise.inputs["Scale"].default_value = 2.2
    links.new(coord.outputs["Object"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    elements = ramp.color_ramp.elements
    random.seed(seed)
    colours = random.sample(LAUNDRY, 5)
    elements[0].color = kit.srgb(colours[0])
    elements[1].position = 0.2
    elements[1].color = kit.srgb(colours[1])
    for i, c in enumerate(colours[2:]):
        e = elements.new(0.4 + i * 0.2)
        e.color = kit.srgb(c)
    links.new(noise.outputs["Color"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def _detail_parts(name, seed, width, depth, floors, floor_h, start, top, shop, stairs=True):
    """The detail of a building as material parts, added to its own."""
    random.seed(seed)
    walls, metal, glass_parts, cloth_parts, units, tanks = _roof_detail("", width, depth, top, seed, stairs)
    bal, iron, laundry = _facade("", width, depth, floors, floor_h, start, top, seed)
    parts = [(kit.join(walls + bal, "trim"), concrete(f"{name}_trim_p", seed, "9a9a94"), "trim"),
             (kit.join(metal + iron, "fixtures"), steel(f"{name}_fixtures_p", seed + 1, "6a6e72"), "fixtures")]
    if units: parts.append((kit.join(units, "units"), painted(f"{name}_units_p", "d6d2c4", seed), "units"))
    if tanks: parts.append((kit.join(tanks, "tanks"), painted(f"{name}_tanks_p", random.choice(["2e6fb0", "3a80c0", "c8c4b8"]), seed), "tanks"))
    if glass_parts: parts.append((kit.join(glass_parts, "panels"), glass(f"{name}_panels_p", seed), "panels"))
    if laundry + cloth_parts: parts.append((kit.join(laundry + cloth_parts, "laundry"), _laundry_material(f"{name}_laundry_p", seed), "laundry"))
    if shop: parts.append((kit.join(_awning("", width, depth, seed), "awning"), cloth(f"{name}_awning_p", seed, random.choice(["3c7a5a", "b8402e", "2e6fb0", "c48a2a"])), "awning"))
    return parts


def _framed_windows(prefix, width, depth, floors, floor_h, start, seed):
    """The window surrounds and mullions, to go with _windows' panes."""
    random.seed(seed)
    trims, mulls = [], []
    for side in ("front", "back", "left", "right"):
        along = width if side in ("front", "back") else depth
        count = max(1, int(along / 1.75))
        step = along / count
        place, rot = _side_frame(side, width, depth)
        for f in range(floors):
            z = start + f * floor_h + floor_h * 0.5
            for k in range(count):
                u = -along * 0.5 + step * (k + 0.5)
                t, m = _frame(f"{prefix}{side}{f}_{k}", place(u, 0.04, z), rot, 1.15, 1.25)
                trims += t
                mulls += m
    return trims, mulls


# --- Pieces ------------------------------------------------------------------------------

def city_shop_house(seed=601):
    """外城商住楼: three storeys of painted render over a shopfront."""
    return _building("city_shop_house", 8.0, 8.0, 3, 3.1, "7f9a96", "b8402e", seed)


def city_tower(seed=603):
    """外城高楼: five storeys, a bank of lit windows, a shop at its foot."""
    return _building("city_tower", 10.0, 10.0, 5, 3.1, "a8a294", "2e6fb0", seed, lit_share=0.25)


def city_tea_house(seed=605):
    """茶餐厅: two storeys, wide signboard, awning over the door."""
    parts = _building("city_tea_house", 8.0, 6.0, 2, 3.2, "c9b58c", "c23b2c", seed, lit_share=0.35)
    awning = d.bbox("awning", (7.0, 1.4, 0.12), (0, -3.7, 2.7), (0.25, 0, 0), width=0.02)
    parts.append((awning, cloth("city_tea_house_awning_p", seed, "3c7a5a"), "awning"))
    return parts


def city_ruin(seed=607):
    """坍塌楼: three storeys with the top broken open, rubble at its foot."""
    random.seed(seed)
    width, depth, floor_h = 8.0, 8.0, 3.1
    walls = [d.bbox("lower", (width, depth, floor_h * 2), (0, 0, floor_h), width=0.04)]
    # The top storey: two broken walls standing, the rest gone.
    walls.append(kit.box("back", (width, 0.3, floor_h * 0.9), (0, depth * 0.5 - 0.15, floor_h * 2.45)))
    walls.append(kit.box("side", (0.3, depth * 0.6, floor_h * 0.6), (-width * 0.5 + 0.15, depth * 0.2, floor_h * 2.3)))
    slab = kit.box("slab", (width * 0.7, depth * 0.8, 0.25), (-width * 0.12, 0.3, floor_h * 2.0 + 0.12), (0.12, -0.08, 0))
    rubble = []
    for i in range(16):
        r = random.uniform(0.25, 0.65)
        rock = kit.rock(f"rb{i}", r, (random.uniform(-width * 0.6, width * 0.6), random.uniform(-depth * 0.85, -depth * 0.45), r * 0.4),
                        (random.uniform(1.0, 1.6), random.uniform(0.8, 1.2), random.uniform(0.5, 0.8)), subdivisions=1)
        kit.roughen(rock, seed + i, strength=0.08, size=0.25, subdiv=1)
        rubble.append(rock)
    panes, glow, units, sills = _windows("", width, depth, 2, floor_h, 0.0, seed, lit_share=0.0)
    walls += sills
    rebar = [d.cyl(f"rebar{i}", 0.02, random.uniform(0.6, 1.4), (random.uniform(-3, 3), random.uniform(-2, 3), floor_h * 2.0 + 0.5), (random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), 0), vertices=4) for i in range(10)]
    return [(kit.join(walls + [slab], "wall"), plaster("city_ruin_wall_p", "8d8a80", seed), "wall"),
            (kit.join(panes, "glass"), glass("city_ruin_glass_p", seed), "glass"),
            (kit.join(rubble, "rubble"), concrete("city_ruin_rubble_p", seed), "rubble"),
            (kit.join(rebar + units, "metal"), rust_material("city_ruin_metal_p", seed), "metal")]


def _shack(name, width, depth, height, seed, sheet_hex, upper=False):
    random.seed(seed)
    walls = [d.bbox("walls", (width, depth, height), (0, 0, height * 0.5), width=0.03)]
    roof = [kit.box("roof", (width + 0.6, depth + 0.5, 0.08), (0, 0, height + 0.15), (math.radians(random.uniform(-8, 8)), math.radians(6), 0))]
    if upper:
        w2, d2, h2 = width * 0.65, depth * 0.7, height * 0.8
        walls.append(d.bbox("upper", (w2, d2, h2), (width * 0.12, depth * 0.1, height + 0.2 + h2 * 0.5), width=0.03))
        roof.append(kit.box("roof2", (w2 + 0.5, d2 + 0.4, 0.08), (width * 0.12, depth * 0.1, height + h2 + 0.35), (0, math.radians(-7), 0)))
    door = [kit.box("door", (0.9, 0.06, 1.9), (-width * 0.2, -depth * 0.5 - 0.03, 0.95))]
    junk = [d.bbox(f"crate{i}", (0.6, 0.6, 0.5), (width * 0.5 + 0.4, -depth * 0.3 + i * 0.7, 0.25), width=0.02) for i in range(2)]
    panes = [kit.box("win", (0.8, 0.05, 0.6), (width * 0.25, -depth * 0.5 - 0.03, height * 0.6))]
    glow = [kit.box("lamp", (0.18, 0.18, 0.18), (-width * 0.2, -depth * 0.5 - 0.15, 2.05))]
    # What the camera sees of a shack is its roof: a tarp lashed over part of
    # it, old tyres and bricks holding the sheets down, a stovepipe, a plastic
    # water barrel; a line of laundry by the door.
    roof_top = height + 0.2 + (height * 0.8 + 0.15 if upper else 0.0)
    lo_w, lo_d = (width * 0.65, depth * 0.7) if upper else (width, depth)
    ox, oy = (width * 0.12, depth * 0.1) if upper else (0.0, 0.0)
    tarp = [kit.box("tarp", (lo_w * random.uniform(0.5, 0.8), lo_d * random.uniform(0.5, 0.9), 0.04),
                    (ox + random.uniform(-0.3, 0.3), oy + random.uniform(-0.2, 0.2), roof_top + 0.02), (math.radians(random.uniform(-8, 8)), math.radians(6), 0))]
    weights = []
    for i in range(random.randint(2, 3)):
        weights.append(d.cyl(f"tyre{i}", 0.3, 0.18, (ox + random.uniform(-lo_w * 0.35, lo_w * 0.35), oy + random.uniform(-lo_d * 0.3, lo_d * 0.3), roof_top + 0.12), vertices=10))
    for i in range(random.randint(2, 4)):
        weights.append(kit.box(f"brick{i}", (0.3, 0.15, 0.12), (ox + random.uniform(-lo_w * 0.4, lo_w * 0.4), oy + random.uniform(-lo_d * 0.35, lo_d * 0.35), roof_top + 0.08), (0, 0, random.uniform(0, math.pi))))
    pipe = [d.cyl("stove", 0.08, 1.4, (ox + lo_w * 0.3, oy + lo_d * 0.25, roof_top + 0.6), vertices=8),
            d.cyl("stovecap", 0.14, 0.06, (ox + lo_w * 0.3, oy + lo_d * 0.25, roof_top + 1.32), vertices=8)]
    barrel = [d.cyl("barrel", 0.32, 0.85, (width * 0.5 + 0.45, depth * 0.3, 0.43), vertices=12)]
    line = [kit.box("lpost", (0.05, 0.05, 2.0), (width * 0.5 + 0.2, -depth * 0.5 - 0.9, 1.0)),
            kit.box("lline", (width * 0.8, 0.02, 0.02), (width * 0.1, -depth * 0.5 - 0.9, 1.95))]
    laundry = [kit.box(f"cl{k}", (0.4, 0.02, 0.55), (-width * 0.25 + k * 0.55, -depth * 0.5 - 0.9, 1.62)) for k in range(random.randint(2, 4))]
    return [(kit.join(walls + roof + door, "sheet"), corrugated(f"{name}_sheet_p", sheet_hex, seed), "sheet"),
            (kit.join(junk, "wood"), wood_material(f"{name}_wood_p", seed), "wood"),
            (kit.join(panes, "glass"), glass(f"{name}_glass_p", seed), "glass"),
            (kit.join(glow, "glow"), lit(f"{name}_glow_p"), "glow"),
            (kit.join(tarp, "tarp"), cloth(f"{name}_tarp_p", seed, random.choice(["2e5f9a", "c8702a", "3f7a4a"])), "tarp"),
            (kit.join(weights + pipe + line, "junk"), kit.flat_material(f"{name}_junk_p", "2a2a2c", 5.0, "4a4440"), "junk"),
            (kit.join(barrel, "barrel"), painted(f"{name}_barrel_p", random.choice(["2e6fb0", "c8352a"]), seed), "barrel"),
            (kit.join(laundry, "laundry"), _laundry_material(f"{name}_laundry_p", seed), "laundry")]


def city_shack_a(seed=611):
    """贫民区棚屋: a single corrugated room."""
    return _shack("city_shack_a", 3.2, 3.0, 2.6, seed, "6f7f86")


def city_shack_b(seed=613):
    return _shack("city_shack_b", 4.2, 3.4, 2.8, seed, "8a6a4a")


def city_shack_c(seed=615):
    """Two storeys of shack, the upper one built on the roof of the lower."""
    return _shack("city_shack_c", 4.0, 3.6, 2.7, seed, "5f7a62", upper=True)


def _roof_clutter(prefix, width, depth, top, seed):
    """What the camera sees of a low building: AC units, a hatch, vents, pipes."""
    random.seed(seed)
    metal = []
    for i in range(random.randint(3, 5)):
        metal.append(d.bbox(f"{prefix}ac{i}", (0.9, 0.6, 0.6), (random.uniform(-width * 0.38, width * 0.38), random.uniform(-depth * 0.3, depth * 0.3), top + 0.3), (0, 0, random.choice([0, math.pi / 2])), width=0.02))
    metal.append(d.bbox(f"{prefix}hatch", (1.1, 1.1, 0.5), (random.uniform(-width * 0.3, width * 0.3), depth * 0.25, top + 0.25), width=0.02))
    for i in range(2):
        metal.append(d.cyl(f"{prefix}vent{i}", 0.18, 0.9, (random.uniform(-width * 0.4, width * 0.4), random.uniform(-depth * 0.35, depth * 0.35), top + 0.45), vertices=8))
    metal.append(d.cyl(f"{prefix}pipe", 0.07, width * 0.8, (0, depth * 0.42, top + 0.15), (0, math.pi / 2, 0), vertices=6))
    return metal


def _low_row(name, width, depth, wall_hex, sign_hex, seed, lean=False):
    """临街平房: one storey of shops with a flat roof, for the street's south
    side, where the camera looks over it to the road: its roof is its face."""
    random.seed(seed)
    height = 3.6
    body = d.bbox("body", (width, depth, height), (0, 0, height * 0.5), width=0.04)
    trims, extras = _roof("", width, depth, height, seed, tank=random.random() < 0.6)
    metal = _roof_clutter("", width, depth, height, seed) + extras
    shutters, boards, blades, face = _shopfront("", width, depth, seed, sign_hex)
    for blade in blades: bpy.data.objects.remove(blade)
    # A strip of roofing felt in a darker patch, so the roofs are not all one flat.
    felt = [kit.box("felt", (width * random.uniform(0.35, 0.6), depth * random.uniform(0.35, 0.6), 0.03), (random.uniform(-width * 0.2, width * 0.2), random.uniform(-depth * 0.15, depth * 0.15), height + 0.02))]
    parts = [(kit.join([body] + trims, "wall"), plaster(f"{name}_wall_p", wall_hex, seed), "wall"),
             (kit.join(felt, "felt"), concrete(f"{name}_felt_p", seed, "3e4246"), "felt"),
             (kit.join(metal, "metal"), steel(f"{name}_metal_p", seed), "metal")]
    parts += _shop_parts(name, shutters, boards, [], face, seed)
    parts += _detail_parts(name, seed, width, depth, 0, height, 0.0, height, True, stairs=False)
    if lean:
        # A corrugated room knocked up on the roof, as the lower city does.
        w2, d2 = width * 0.4, depth * 0.5
        shed = [d.bbox("shed", (w2, d2, 2.2), (-width * 0.22, depth * 0.12, height + 1.1), width=0.03),
                kit.box("shedroof", (w2 + 0.4, d2 + 0.4, 0.08), (-width * 0.22, depth * 0.12, height + 2.3), (math.radians(7), 0, 0))]
        parts.append((kit.join(shed, "sheet"), corrugated(f"{name}_sheet_p", random.choice(["6f7f86", "8a6a4a", "5f7a62"]), seed), "sheet"))
    return parts


def city_row_low_a(seed=641):
    """临街平房: a 6 m one-storey shop, flat roof."""
    return _low_row("city_row_low_a", 6.0, 6.0, "8f8a7c", "2e6fb0", seed)


def city_row_low_b(seed=643):
    """临街平房: a 9 m one-storey row with a shed built on its roof."""
    return _low_row("city_row_low_b", 9.0, 6.0, "7a8a8e", "c23b2c", seed, lean=True)


def city_row_mid(seed=645):
    """窄楼: a 6 m two-storey shop house, to fill the street fronts between the wide ones."""
    return _building("city_row_mid", 6.0, 7.0, 3, 3.0, "b49a7a", "d04a8a", seed, lit_share=0.25)


def city_fence(seed=647):
    """路边护栏: a 2 m panel of iron railing between two posts, rusted, a
    sheet of corrugated iron wired to it now and then. Runs along x; the
    road side is -Y."""
    random.seed(seed)
    iron = []
    for x in (-1.0, 1.0):
        iron.append(d.bbox(f"post{x}", (0.1, 0.1, 1.35), (x, 0, 0.675), width=0.01))
    for z in (0.15, 0.6, 1.15):
        iron.append(kit.box(f"rail{z}", (2.0, 0.05, 0.05), (0, 0, z)))
    for k in range(13):
        iron.append(kit.box(f"bar{k}", (0.025, 0.025, 1.0), (-0.9 + k * 0.15, 0, 0.65)))
    sheet = [kit.box("sheet", (1.1, 0.03, 0.9), (random.uniform(-0.3, 0.3), -0.04, 0.6), (0, math.radians(random.uniform(-6, 6)), 0))]
    return [(kit.join(iron, "iron"), rust_material("city_fence_iron_p", seed), "iron"),
            (kit.join(sheet, "sheet"), corrugated("city_fence_sheet_p", "6f7f86", seed), "sheet")]


def city_street_lamp(seed=649):
    """路灯: a 6 m steel pole, its arm out over the road (-Y), a sodium head."""
    random.seed(seed)
    steel_parts = [d.cyl("pole", 0.09, 6.0, (0, 0, 3.0), vertices=8),
                   d.cyl("foot", 0.18, 0.5, (0, 0, 0.25), vertices=8),
                   d.cyl("arm", 0.05, 1.7, (0, -0.8, 5.9), (math.pi / 2, 0, 0), vertices=6),
                   kit.box("head", (0.35, 0.6, 0.16), (0, -1.65, 5.86))]
    glow = [kit.box("lens", (0.28, 0.5, 0.04), (0, -1.65, 5.77))]
    return [(kit.join(steel_parts, "metal"), steel("city_street_lamp_metal_p", seed, "4a4e52"), "metal"),
            (kit.join(glow, "glow"), kit.flat_material("city_street_lamp_glow_p", "ffcf80", 8.0, "f0a040"), "glow")]


# --- Street furniture (用户 2026-10-14: 加城市中常见摆件，红绿灯什么的) ---------------
# Each stands on its origin; anything with a street side faces it at -Y.

def city_traffic_light(seed=651):
    """红绿灯: a pole at the corner, its mast arm out over the road (-Y) with the
    signal head; a pedestrian signal and a push button on the pole. Red lit,
    the city being under siege."""
    random.seed(seed)
    metal = [d.cyl("pole", 0.1, 5.2, (0, 0, 2.6), vertices=8),
             d.cyl("foot", 0.2, 0.4, (0, 0, 0.2), vertices=8),
             d.cyl("arm", 0.06, 3.4, (0, -1.7, 5.0), (math.pi / 2, 0, 0), vertices=6),
             d.bbox("head", (0.42, 0.36, 1.25), (0, -3.2, 4.45), width=0.02),
             d.bbox("visor", (0.46, 0.08, 1.3), (0, -3.42, 4.45), width=0.01),
             d.bbox("ped", (0.32, 0.3, 0.62), (0, -0.25, 2.7), width=0.015),
             d.bbox("button", (0.14, 0.1, 0.22), (0, -0.14, 1.1), width=0.01)]
    paint = [kit.box("band", (0.22, 0.22, 0.3), (0, 0, 2.1))]
    lamps_dark = [d.cyl(f"l{i}", 0.13, 0.04, (0, -3.39, 4.85 - i * 0.4), (math.pi / 2, 0, 0), vertices=12) for i in (1, 2)]
    red = [d.cyl("red", 0.13, 0.04, (0, -3.39, 4.85), (math.pi / 2, 0, 0), vertices=12),
           kit.box("man", (0.18, 0.03, 0.22), (0, -0.41, 2.82))]
    return [(kit.join(metal, "metal"), steel("city_traffic_light_metal_p", seed, "3a3e42"), "metal"),
            (kit.join(paint, "paint"), painted("city_traffic_light_paint_p", "d8c030", seed), "paint"),
            (kit.join(lamps_dark, "lens"), glass("city_traffic_light_lens_p", seed), "lens"),
            (kit.join(red, "glow"), kit.flat_material("city_traffic_light_glow_p", "ff3a2a", 6.0, "c01810"), "glow")]


def city_hydrant(seed=653):
    """消防栓: a red hydrant, its caps chained."""
    body = [d.cyl("barrel", 0.16, 0.7, (0, 0, 0.35), vertices=12),
            d.cyl("cap", 0.19, 0.12, (0, 0, 0.74), vertices=12),
            d.cyl("dome", 0.12, 0.12, (0, 0, 0.84), vertices=12),
            d.cyl("noz1", 0.07, 0.3, (0.18, 0, 0.5), (0, math.pi / 2, 0), vertices=8),
            d.cyl("noz2", 0.07, 0.3, (-0.18, 0, 0.5), (0, math.pi / 2, 0), vertices=8),
            d.cyl("base", 0.22, 0.08, (0, 0, 0.04), vertices=12)]
    return [(kit.join(body, "paint"), painted("city_hydrant_paint_p", "c0302a", seed), "paint")]


def city_bin(seed=655):
    """垃圾箱: a green wheelie dumpster, lid half open, bags heaped beside."""
    random.seed(seed)
    box_parts = [d.bbox("body", (1.6, 1.0, 1.05), (0, 0, 0.62), width=0.03),
                 d.bbox("lid", (1.66, 1.04, 0.06), (0, 0.15, 1.25), (math.radians(-18), 0, 0), width=0.01)]
    wheels = [d.cyl(f"w{i}", 0.09, 0.06, (x, y, 0.09), (0, math.pi / 2, 0), vertices=10) for i, (x, y) in enumerate(((-0.65, -0.35), (0.65, -0.35), (-0.65, 0.35), (0.65, 0.35)))]
    bags = []
    for i in range(4):
        r = random.uniform(0.22, 0.32)
        bag = kit.rock(f"bag{i}", r, (1.05 + random.uniform(-0.1, 0.3), random.uniform(-0.45, 0.45), r * 0.7), (1.0, 0.9, 0.8), subdivisions=2)
        bags.append(bag)
    return [(kit.join(box_parts, "box"), painted("city_bin_box_p", "2f6a3c", seed), "box"),
            (kit.join(wheels, "wheels"), kit.flat_material("city_bin_wheels_p", "1c1c1e"), "wheels"),
            (kit.join(bags, "bags"), kit.flat_material("city_bin_bags_p", "26282c", 6.0, "121316"), "bags")]


def city_postbox(seed=657):
    """邮筒: a green pillar box, Lungmen post."""
    body = [d.cyl("pillar", 0.26, 1.1, (0, 0, 0.55), vertices=14),
            d.cyl("top", 0.3, 0.14, (0, 0, 1.16), vertices=14),
            d.cyl("cap", 0.2, 0.12, (0, 0, 1.28), vertices=14)]
    slot = [kit.box("slot", (0.24, 0.03, 0.05), (0, -0.26, 0.92))]
    return [(kit.join(body, "paint"), painted("city_postbox_paint_p", "2e7a4a", seed), "paint"),
            (kit.join(slot, "slot"), kit.flat_material("city_postbox_slot_p", "101214"), "slot")]


def city_bus_stop(seed=659):
    """巴士站: a shelter, back panel, bench and the route sign on its post."""
    metal = [d.cyl(f"post{i}", 0.05, 2.5, (x, 0.5, 1.25), vertices=8) for i, x in enumerate((-1.7, 1.7))]
    metal += [d.bbox("roof", (3.8, 1.4, 0.1), (0, 0.15, 2.55), width=0.02),
              d.bbox("bench", (2.6, 0.4, 0.06), (0, 0.25, 0.48), width=0.01),
              d.cyl("signpost", 0.04, 2.8, (2.3, -0.2, 1.4), vertices=6)]
    panel = [kit.box("back", (3.4, 0.04, 1.7), (0, 0.55, 1.35))]
    sign = [kit.box("sign", (0.55, 0.05, 0.7), (2.3, -0.2, 2.6))]
    return [(kit.join(metal, "metal"), steel("city_bus_stop_metal_p", seed, "5a6066"), "metal"),
            (kit.join(panel, "glass"), glass("city_bus_stop_glass_p", seed), "glass"),
            (kit.join(sign, "glow"), kit.flat_material("city_bus_stop_glow_p", "e8d080", 6.0, "c09040"), "glow")]


def city_phone_booth(seed=661):
    """电话亭: a booth, glass round, a lit panel at the top."""
    frame = [d.bbox("roof", (1.05, 1.05, 0.14), (0, 0, 2.33), width=0.02)]
    frame += [d.bbox(f"c{i}", (0.07, 0.07, 2.3), (x, y, 1.15), width=0.005) for i, (x, y) in enumerate(((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)))]
    frame += [d.bbox("base", (1.05, 1.05, 0.08), (0, 0, 0.04), width=0.01)]
    panes = [kit.box("back", (0.95, 0.03, 2.0), (0, 0.5, 1.1)), kit.box("l", (0.03, 0.95, 2.0), (-0.5, 0, 1.1)), kit.box("r", (0.03, 0.95, 2.0), (0.5, 0, 1.1))]
    lit_panel = [kit.box("panel", (0.9, 0.04, 0.2), (0, -0.52, 2.18))]
    return [(kit.join(frame, "paint"), painted("city_phone_booth_paint_p", "b8352a", seed), "paint"),
            (kit.join(panes, "glass"), glass("city_phone_booth_glass_p", seed), "glass"),
            (kit.join(lit_panel, "glow"), kit.flat_material("city_phone_booth_glow_p", "f0e8d0", 6.0, "c0b090"), "glow")]


def city_vending(seed=663):
    """自动售货机: drinks behind a lit front."""
    body = [d.bbox("body", (0.95, 0.8, 1.9), (0, 0, 0.95), width=0.02)]
    front = [kit.box("front", (0.7, 0.03, 1.1), (-0.05, -0.41, 1.25))]
    slot = [kit.box("tray", (0.6, 0.06, 0.22), (-0.05, -0.41, 0.35))]
    return [(kit.join(body, "paint"), painted("city_vending_paint_p", "2e6fb0", seed), "paint"),
            (kit.join(front, "glow"), kit.flat_material("city_vending_glow_p", "dff0ff", 6.0, "80a8c8"), "glow"),
            (kit.join(slot, "slot"), kit.flat_material("city_vending_slot_p", "101214"), "slot")]


def city_bollards(seed=665):
    """护柱: three bollards in a row along x, yellow-banded."""
    posts = [d.cyl(f"b{i}", 0.09, 0.9, (-1.0 + i * 1.0, 0, 0.45), vertices=10) for i in range(3)]
    bands = [d.cyl(f"t{i}", 0.095, 0.12, (-1.0 + i * 1.0, 0, 0.78), vertices=10) for i in range(3)]
    return [(kit.join(posts, "metal"), steel("city_bollards_metal_p", seed, "4a4e52"), "metal"),
            (kit.join(bands, "paint"), painted("city_bollards_paint_p", "e0b030", seed), "paint")]


def city_cones(seed=667):
    """路锥: a few traffic cones, one knocked over."""
    random.seed(seed)
    cones, bands = [], []
    spots = [(0, 0, 0), (0.7, 0.2, 0), (-0.5, 0.5, 1)]
    for i, (x, y, down) in enumerate(spots):
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.17, radius2=0.03, depth=0.7, location=(x, y, 0.35))
        cone = bpy.context.object
        cone.name = f"cone{i}"
        if down:
            cone.rotation_euler = (math.pi / 2, 0, random.uniform(0, math.tau))
            cone.location.z = 0.17
        cones.append(cone)
        cones.append(kit.box(f"base{i}", (0.4, 0.4, 0.04), (x, y, 0.02)) if not down else kit.box(f"base{i}", (0.4, 0.04, 0.4), (x, y + 0.35, 0.2)))
    return [(kit.join(cones, "paint"), painted("city_cones_paint_p", "e86a20", seed), "paint")]


def city_car_wreck(seed=669):
    """废弃轿车: a burnt-out sedan along x, glass gone, sitting on its rims."""
    random.seed(seed)
    shell = [d.bbox("lower", (4.4, 1.8, 0.7), (0, 0, 0.55), width=0.08),
             d.bbox("cabin", (2.3, 1.62, 0.6), (-0.15, 0, 1.18), width=0.1)]
    hood = [d.bbox("hood", (1.2, 1.7, 0.05), (1.55, 0, 0.95), (0, math.radians(-8), 0), width=0.01)]
    holes = [kit.box("ws", (0.05, 1.4, 0.5), (1.0, 0, 1.15), (0, math.radians(-30), 0)),
             kit.box("rw", (0.05, 1.4, 0.45), (-1.32, 0, 1.15), (0, math.radians(30), 0)),
             kit.box("sl", (1.9, 0.04, 0.4), (-0.15, -0.81, 1.2)), kit.box("sr", (1.9, 0.04, 0.4), (-0.15, 0.81, 1.2))]
    wheels = [d.cyl(f"w{i}", 0.33, 0.22, (x, y, 0.3), (math.pi / 2, 0, 0), vertices=12) for i, (x, y) in enumerate(((-1.35, -0.85), (1.35, -0.85), (-1.35, 0.85), (1.35, 0.85)))]
    colour = random.choice(["6a3a24", "3a4a5a", "8a8578"])
    return [(kit.join(shell + hood, "body"), d.worn(rust_material("city_car_wreck_body_p", seed), edge="d0a070", edge_strength=0.2), "body"),
            (kit.join(holes, "dark"), kit.flat_material("city_car_wreck_dark_p", "0c0d0f"), "dark"),
            (kit.join(wheels, "wheels"), kit.flat_material("city_car_wreck_wheels_p", "1a1a1c", 4.0, "2a2624"), "wheels")]


def city_manhole(seed=671):
    """井盖: a cast-iron cover flush with the road."""
    cover = [d.cyl("cover", 0.42, 0.03, (0, 0, 0.015), vertices=20)]
    ribs = [kit.box(f"r{i}", (0.7, 0.04, 0.012), (0, -0.24 + i * 0.12, 0.034)) for i in range(5)]
    return [(kit.join(cover + ribs, "iron"), steel("city_manhole_iron_p", seed, "34363a"), "iron")]


# --- District borders (用户 2026-10-14: 区域间用标志性的东西分隔) -------------------
# Each district's own border: a 6 m panel along x for the blocks between
# buildings, and a gate (10 m clear, along x, the way through along y) where a
# road crosses it. The slums keep city_wall / city_gate.

def city_yard_fence(seed=681):
    """木禾仓库围栏: a 6 m chain-link panel, razor wire on cranked arms."""
    frame = [d.bbox(f"post{i}", (0.12, 0.12, 2.8), (-3.0 + i * 6.0, 0, 1.4), width=0.01) for i in range(2)]
    frame += [kit.box(f"rail{z}", (6.0, 0.06, 0.06), (0, 0, z)) for z in (0.1, 1.3, 2.5)]
    mesh = [kit.box(f"m{k}", (0.025, 0.025, 2.4), (-2.9 + k * 0.2, 0, 1.3), (0, math.radians(18 if k % 2 else -18), 0)) for k in range(30)]
    arms = [kit.box(f"arm{i}", (0.05, 0.6, 0.05), (-3.0 + i * 6.0, -0.25, 2.95), (math.radians(45), 0, 0)) for i in range(2)]
    wire = [d.cyl(f"w{k}", 0.025, 6.0, (0, -0.1 - k * 0.15, 2.85 + k * 0.15), (0, math.pi / 2, 0), vertices=4) for k in range(3)]
    sign = [kit.box("sign", (0.9, 0.04, 0.6), (random.uniform(-1.5, 1.5), -0.05, 1.7))]
    return [(kit.join(frame + arms, "steel"), steel("city_yard_fence_steel_p", seed, "6a7076"), "steel"),
            (kit.join(mesh + wire, "mesh"), steel("city_yard_fence_mesh_p", seed + 1, "8a9094"), "mesh"),
            (kit.join(sign, "sign"), painted("city_yard_fence_sign_p", "d8b030", seed), "sign")]


def city_yard_gate(seed=683):
    """仓库大门: striped gate posts, a guard booth, the boom raised, a floodlight
    mast that is seen from across the floor."""
    posts = [d.bbox(f"post{i}", (0.6, 0.6, 3.2), (-5.2 + i * 10.4, 0, 1.6), width=0.02) for i in range(2)]
    stripes = [kit.box(f"band{i}_{k}", (0.62, 0.62, 0.3), (-5.2 + i * 10.4, 0, 0.4 + k * 0.6)) for i in range(2) for k in range(5)]
    booth = [d.bbox("booth", (2.2, 2.2, 2.6), (-6.9, 1.2, 1.3), width=0.03),
             d.bbox("boothroof", (2.6, 2.6, 0.15), (-6.9, 1.2, 2.7), width=0.02)]
    panes = [kit.box("bwin", (1.6, 0.04, 0.9), (-6.9, 0.08, 1.7)), kit.box("bwin2", (0.04, 1.6, 0.9), (-5.78, 1.2, 1.7))]
    boom = [kit.box("boom", (0.12, 0.12, 6.0), (-4.6, 0, 3.8), (0, math.radians(-12), 0)),
            d.bbox("boombox", (0.6, 0.5, 1.1), (-4.6, 0.5, 0.55), width=0.02)]
    mast = [d.cyl("mast", 0.15, 9.0, (6.4, 1.0, 4.5), vertices=8),
            kit.box("mastbar", (2.0, 0.15, 0.15), (6.4, 1.0, 8.9))]
    flood = [kit.box(f"flood{i}", (0.5, 0.35, 0.35), (5.7 + i * 1.4, 0.75, 8.7)) for i in range(2)]
    flood.append(kit.box("boothlamp", (0.3, 0.3, 0.15), (-6.9, -0.05, 2.45)))
    return [(kit.join(posts + booth + mast, "steel"), steel("city_yard_gate_steel_p", seed, "5a6064"), "steel"),
            (kit.join(stripes + boom, "paint"), painted("city_yard_gate_paint_p", "e0b030", seed), "paint"),
            (kit.join(panes, "glass"), glass("city_yard_gate_glass_p", seed), "glass"),
            (kit.join(flood, "glow"), kit.flat_material("city_yard_gate_glow_p", "f4f8ff", 6.0, "c0d0e0"), "glow")]


def city_hoarding(seed=685):
    """施工围挡: a 6 m run of blue site hoarding, white band, braced at the back."""
    panel = [d.bbox("panel", (6.0, 0.08, 2.6), (0, 0, 1.3), width=0.01)]
    band = [kit.box("band", (6.0, 0.1, 0.35), (0, 0, 2.05))]
    base = [kit.box(f"chev{k}", (0.5, 0.1, 0.3), (-2.75 + k * 0.5, 0, 0.15)) for k in range(0, 12, 2)]
    braces = [kit.box(f"brace{i}", (0.06, 1.3, 0.06), (-2.5 + i * 2.5, 0.55, 1.1), (math.radians(-55), 0, 0)) for i in range(3)]
    return [(kit.join(panel, "panel"), painted("city_hoarding_panel_p", "2e5f9a", seed), "panel"),
            (kit.join(band + base, "paint"), painted("city_hoarding_paint_p", "e8e4d8", seed), "paint"),
            (kit.join(braces, "steel"), steel("city_hoarding_steel_p", seed, "5a6064"), "steel")]


def city_site_gate(seed=687):
    """工地大门: two tall hoarding piers under a yellow header, the mesh gate
    slid aside, amber warning lamps."""
    piers = [d.bbox(f"pier{i}", (1.0, 1.0, 4.2), (-5.4 + i * 10.8, 0, 2.1), width=0.02) for i in range(2)]
    header = [d.bbox("header", (11.8, 0.6, 1.0), (0, 0, 4.7), width=0.02)]
    stripes = [kit.box(f"hs{k}", (0.5, 0.62, 1.02), (-5.5 + k * 1.0, 0, 4.7), (0, math.radians(35), 0)) for k in range(0, 12, 2)]
    gate = [kit.box("gframe", (4.0, 0.08, 2.2), (-7.6, 0.6, 1.1))]
    gate += [kit.box(f"gbar{k}", (0.03, 0.03, 2.1), (-9.4 + k * 0.3, 0.6, 1.1)) for k in range(13)]
    lamps = [d.cyl(f"amber{i}", 0.16, 0.25, (-5.4 + i * 10.8, -0.1, 4.45), vertices=10) for i in range(2)]
    return [(kit.join(piers, "panel"), painted("city_site_gate_panel_p", "2e5f9a", seed), "panel"),
            (kit.join(header + stripes, "paint"), painted("city_site_gate_paint_p", "e0b030", seed), "paint"),
            (kit.join(gate, "steel"), steel("city_site_gate_steel_p", seed, "6a7076"), "steel"),
            (kit.join(lamps, "glow"), kit.flat_material("city_site_gate_glow_p", "ffa830", 6.0, "e07010"), "glow")]


def city_tower_crane(seed=689):
    """塔吊: the building site's landmark, a lattice mast 12 m up, its jib out
    along +x, counter-jib and ballast behind, the hook hanging."""
    lattice = []
    for cx, cy in ((-0.6, -0.6), (0.6, -0.6), (-0.6, 0.6), (0.6, 0.6)):
        lattice.append(kit.box(f"leg{cx}{cy}", (0.12, 0.12, 12.0), (cx, cy, 6.0)))
    for k in range(12):
        lattice.append(kit.box(f"x{k}", (1.2, 0.05, 0.05), (0, -0.6, 0.5 + k), (0, math.radians(40 if k % 2 else -40), 0)))
        lattice.append(kit.box(f"y{k}", (0.05, 1.2, 0.05), (0.6, 0, 0.5 + k), (math.radians(40 if k % 2 else -40), 0, 0)))
    jib = [kit.box("jib", (16.0, 0.8, 0.8), (8.0, 0, 12.4)), kit.box("cjib", (6.0, 0.8, 0.6), (-3.0, 0, 12.3)),
           kit.box("apex", (0.4, 0.4, 3.0), (0, 0, 13.8)), kit.box("tie1", (0.06, 0.06, 15.0), (6.5, 0, 13.4), (0, math.radians(80), 0)),
           kit.box("cab", (1.4, 1.4, 1.2), (0.9, -0.9, 11.6))]
    ballast = [kit.box("ballast", (1.6, 1.2, 1.4), (-5.4, 0, 11.6))]
    hook = [kit.box("rope", (0.03, 0.03, 6.0), (11.0, 0, 9.0)), kit.box("hook", (0.4, 0.4, 0.5), (11.0, 0, 5.9))]
    base = [d.bbox("base", (3.0, 3.0, 0.6), (0, 0, 0.3), width=0.02)]
    lamp = [kit.box("beacon", (0.25, 0.25, 0.25), (16.0, 0, 12.95)), kit.box("beacon2", (0.25, 0.25, 0.25), (0, 0, 15.4))]
    return [(kit.join(lattice + jib, "paint"), painted("city_tower_crane_paint_p", "e0b030", seed), "paint"),
            (kit.join(ballast + base, "concrete"), concrete("city_tower_crane_concrete_p", seed), "concrete"),
            (kit.join(hook, "steel"), steel("city_tower_crane_steel_p", seed), "steel"),
            (kit.join(lamp, "glow"), kit.flat_material("city_tower_crane_glow_p", "ff3a2a", 6.0, "c01810"), "glow")]


def city_container(seed=621):
    """木禾仓库: a shipping container, ribbed, doors at one end."""
    random.seed(seed)
    body = d.bbox("box", (6.06, 2.44, 2.59), (0, 0, 1.295), width=0.03)
    doors = [d.bbox("door", (0.06, 2.3, 2.45), (3.06, 0, 1.3), width=0.01)]
    bars = [d.cyl(f"bar{i}", 0.03, 2.4, (3.1, -0.85 + i * 0.57, 1.3), vertices=6) for i in range(4)]
    return [(kit.join([body] + doors, "box"), corrugated("city_container_box_p", random.choice(["b8452e", "2e6f9a", "3f7a4a", "c48a2a"]), seed, 0.3), "box"),
            (kit.join(bars, "metal"), steel("city_container_metal_p", seed), "metal")]


def city_scaffold(seed=623):
    """荒废工地: two bays of scaffold three lifts high, planks and braces."""
    poles, planks = [], []
    for ix in range(3):
        for iy in range(2):
            poles.append(d.cyl(f"p{ix}{iy}", 0.05, 6.2, (-2.0 + ix * 2.0, -0.6 + iy * 1.2, 3.1), vertices=8))
    for lift in range(1, 4):
        z = lift * 2.0
        for iy in range(2):
            poles.append(d.cyl(f"l{lift}{iy}", 0.04, 4.2, (0, -0.6 + iy * 1.2, z), (0, math.pi / 2, 0), vertices=8))
        for k in range(4):
            planks.append(d.bbox(f"pl{lift}{k}", (4.1, 0.26, 0.05), (0, -0.45 + k * 0.3, z + 0.08), width=0.01))
    for ix in range(2):
        poles.append(d.cyl(f"br{ix}", 0.035, 2.9, (-1.0 + ix * 2.0, -0.6, 3.0), (0, math.radians(45 if ix else -45), 0), vertices=6))
    return [(kit.join(poles, "metal"), rust_material("city_scaffold_metal_p", seed), "metal"),
            (kit.join(planks, "wood"), wood_material("city_scaffold_wood_p", seed), "wood")]


def city_water_barrier(seed=631):
    """水马: two plastic road barriers, red and white, linked."""
    def unit(name, x):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, 0, 0.45))
        obj = bpy.context.object
        obj.name = name
        obj.scale = (1.0, 0.45, 0.9)
        bpy.ops.object.transform_apply(scale=True)
        for v in obj.data.vertices:
            if v.co.z > 0.0: v.co.y *= 0.45
        d.bevel(obj, 0.04)
        return obj
    return [(unit("red", -0.52), painted("city_water_barrier_red_p", "c8352a", seed), "red"),
            (unit("white", 0.52), painted("city_water_barrier_white_p", "dedad2", seed), "white")]


def city_hedgehog(seed=633):
    """拒马: three steel beams welded crossways."""
    beams = []
    for i, rot in enumerate(((0.0, math.radians(55), 0.0), (math.radians(55), 0.0, math.radians(90)), (math.radians(-55), 0.0, math.radians(30)))):
        beams.append(d.bbox(f"beam{i}", (1.9, 0.14, 0.14), (0, 0, 0.62), rot, width=0.015))
    return [(kit.join(beams, "metal"), rust_material("city_hedgehog_metal_p", seed), "metal")]


def city_sandbags(seed=635):
    """Sandbag wall: three courses, bags staggered."""
    random.seed(seed)
    bags = []
    for course in range(3):
        n = 5 - (course % 2)
        for k in range(n):
            x = -1.0 + k * 0.5 + (0.25 if course % 2 else 0.0)
            bag = kit.rock(f"bag{course}_{k}", 0.3, (x, random.uniform(-0.03, 0.03), 0.15 + course * 0.26), (0.95, 0.6, 0.45), subdivisions=2)
            bags.append(bag)
    obj = kit.join(bags, "bags")
    kit.clip_below(obj, 0.0)
    return [(obj, cloth("city_sandbags_p", seed, "8a7a58"), "bags")]


def city_kiosk(seed=637):
    """报亭: a green kiosk, shutter half up, magazines on the counter."""
    random.seed(seed)
    shell = [d.bbox("shell", (2.0, 1.6, 2.4), (0, 0, 1.2), width=0.03), kit.box("awn", (2.3, 0.7, 0.08), (0, -1.05, 2.25), (0.3, 0, 0))]
    counter = [d.bbox("counter", (1.8, 0.4, 0.1), (0, -0.95, 1.0), width=0.01)]
    mags = [kit.box(f"mag{i}", (0.22, 0.3, 0.03), (-0.75 + i * 0.25, -0.95, 1.07), (0.0, 0.0, random.uniform(-0.2, 0.2))) for i in range(7)]
    glow = [kit.box("lamp", (1.6, 0.05, 0.12), (0, -0.82, 2.05))]
    return [(kit.join(shell + counter, "shell"), painted("city_kiosk_shell_p", "3c7a52", seed), "shell"),
            (kit.join(mags, "mags"), painted("city_kiosk_mags_p", "d0c25a", seed + 1), "mags"),
            (kit.join(glow, "glow"), lit("city_kiosk_glow_p"), "glow")]


def city_gantry(seed=641):
    """龙门吊: two A-frame legs on rails, a girder 12 m across, a trolley and hook."""
    steelwork = []
    for side in (-1, 1):
        x = side * 6.0
        for k in (-1, 1):
            steelwork.append(d.bbox(f"leg{side}{k}", (0.35, 0.35, 9.4), (x, k * 1.4, 4.7), (k * math.radians(-8), 0, 0), width=0.02))
        steelwork.append(d.bbox(f"foot{side}", (0.6, 3.6, 0.4), (x, 0, 0.2), width=0.02))
        steelwork.append(d.bbox(f"tie{side}", (0.3, 2.4, 0.3), (x, 0, 4.5), width=0.02))
    steelwork.append(d.bbox("girder", (13.0, 1.0, 1.1), (0, 0, 9.6), width=0.03))
    steelwork.append(d.bbox("trolley", (1.4, 1.4, 0.8), (1.5, 0, 8.7), width=0.02))
    cable = [d.cyl("cable", 0.03, 4.0, (1.5, 0, 6.3), vertices=6), d.bbox("hook", (0.4, 0.2, 0.5), (1.5, 0, 4.2), width=0.02)]
    return [(kit.join(steelwork, "steel"), painted("city_gantry_steel_p", "d0a020", seed), "steel"),
            (kit.join(cable, "metal"), steel("city_gantry_metal_p", seed), "metal")]


def city_wall(seed=651):
    """隔离墙: a 6 m concrete panel between posts, razor wire along the top."""
    panel = [d.bbox("panel", (6.0, 0.45, 4.0), (0, 0, 2.0), width=0.03)]
    posts = [d.bbox(f"post{i}", (0.5, 0.65, 4.4), (-3.0 + i * 6.0, 0, 2.2), width=0.03) for i in range(2)]
    wire = []
    for k in range(6):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.025, location=(-2.5 + k * 1.0, 0, 4.4), rotation=(0, math.pi / 2, 0))
        wire.append(bpy.context.object)
    stripes = [kit.box("stripe", (6.0, 0.47, 0.25), (0, 0, 0.6))]
    return [(kit.join(panel + posts, "concrete"), concrete("city_wall_concrete_p", seed), "concrete"),
            (kit.join(wire, "wire"), steel("city_wall_wire_p", seed), "wire"),
            (kit.join(stripes, "paint"), painted("city_wall_paint_p", "d0a020", seed), "paint")]


def city_gate(seed=653):
    """闸门: the wall's one way through, 8 m clear between two guard pillars;
    a steel gate leaf rolled half aside, a floodlight on each pillar."""
    pillars = [d.bbox(f"pillar{i}", (1.2, 1.2, 5.0), (-4.6 + i * 9.2, 0, 2.5), width=0.04) for i in range(2)]
    lintel = [d.bbox("lintel", (10.4, 0.8, 0.7), (0, 0, 5.35), width=0.03)]
    leaf = [d.bbox("leaf", (3.4, 0.2, 3.8), (-5.9, 0.6, 1.9), width=0.02)]
    bars = [d.cyl(f"bar{i}", 0.04, 3.6, (-7.4 + i * 0.5, 0.6, 1.9), vertices=6) for i in range(7)]
    lights = [kit.box(f"flood{i}", (0.5, 0.3, 0.3), (-4.6 + i * 9.2, -0.75, 4.6)) for i in range(2)]
    return [(kit.join(pillars + lintel, "concrete"), concrete("city_gate_concrete_p", seed, "8a8c8e"), "concrete"),
            (kit.join(leaf + bars, "steel"), steel("city_gate_steel_p", seed, "4a5560"), "steel"),
            (kit.join(lights, "glow"), lit("city_gate_glow_p"), "glow")]


# The overpass follows snow_bridge's convention so ContinuousWorldMap can
# stand it on a bridge: X along the span, deck top at z = 0, piers at the
# cliff lines x = +-SPAN / 2 down to the road two tiers below.
SPAN = 10.0
LENGTH = 12.8
HALF_WIDTH = 2.5
DROP = 4.4


def city_overpass(seed=661):
    """高架: a concrete deck with Jersey barriers, two piers, a lamp post."""
    deck = [d.bbox("deck", (LENGTH, HALF_WIDTH * 2 + 0.6, 0.85), (0, 0, -0.425), width=0.04)]
    beams = [d.bbox(f"beam{i}", (LENGTH - 0.4, 0.5, 0.7), (0, -1.6 + i * 1.6, -1.2), width=0.03) for i in range(3)]
    piers = []
    for side in (-1, 1):
        piers.append(d.bbox(f"pier{side}", (1.0, 3.6, DROP + 0.6), (side * SPAN * 0.5, 0, -(DROP + 0.6) * 0.5), width=0.04))
        piers.append(d.bbox(f"cap{side}", (1.4, HALF_WIDTH * 2 + 0.4, 0.5), (side * SPAN * 0.5, 0, -1.55), width=0.03))
    barriers = [d.bbox(f"jersey{s}", (LENGTH, 0.35, 0.85), (0, s * (HALF_WIDTH + 0.12), 0.42), width=0.04) for s in (-1, 1)]
    lamp = [d.cyl("pole", 0.07, 4.2, (2.0, HALF_WIDTH + 0.1, 2.5), vertices=8), d.bbox("arm", (0.1, 1.2, 0.1), (2.0, HALF_WIDTH - 0.5, 4.5), width=0.01)]
    glow = [kit.box("head", (0.35, 0.5, 0.15), (2.0, HALF_WIDTH - 1.05, 4.42))]
    return [(kit.join(deck + beams + piers + barriers, "concrete"), concrete("city_overpass_concrete_p", seed), "concrete"),
            (kit.join(lamp, "metal"), steel("city_overpass_metal_p", seed), "metal"),
            (kit.join(glow, "glow"), lit("city_overpass_glow_p"), "glow")]


def city_culvert(seed=663):
    """下水道: a concrete headwall with an arched mouth, a grate rusted open."""
    wall = [d.bbox("head", (5.0, 0.9, 3.2), (0, 0.45, 1.6), width=0.04)]
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=1.3, depth=1.2, location=(0, 0.1, 1.2), rotation=(math.pi / 2, 0, 0))
    mouth = bpy.context.object
    bars = [d.cyl(f"bar{i}", 0.04, 2.4, (-1.0 + i * 0.4, -0.45, 1.2), vertices=6) for i in range(5)]
    bars[1].rotation_euler = (0.5, 0, 0)
    water = [kit.box("channel", (2.4, 2.0, 0.05), (0, -1.2, 0.03))]
    return [(kit.join(wall, "concrete"), concrete("city_culvert_concrete_p", seed), "concrete"),
            (kit.join([mouth] + water, "dark"), glass("city_culvert_dark_p", seed), "dark"),
            (kit.join(bars, "metal"), rust_material("city_culvert_metal_p", seed), "metal")]


def city_helipad(seed=665):
    """楼顶直升机坪: an 8 m slab with its H, edge lights and a windsock."""
    slab = [d.bbox("slab", (8.0, 8.0, 0.3), (0, 0, 0.15), width=0.04)]
    marks = [kit.box("h1", (0.5, 3.2, 0.02), (-1.0, 0, 0.31)), kit.box("h2", (0.5, 3.2, 0.02), (1.0, 0, 0.31)), kit.box("h3", (1.6, 0.5, 0.02), (0, 0, 0.31))]
    ring = []
    for k in range(12):
        a = k * math.tau / 12
        ring.append(kit.box(f"l{k}", (0.18, 0.18, 0.12), (math.cos(a) * 3.6, math.sin(a) * 3.6, 0.36)))
    sock = [d.cyl("mast", 0.04, 2.5, (3.6, 3.6, 1.55), vertices=6)]
    cloth_sock = [kit.box("sock", (0.9, 0.3, 0.3), (3.95, 3.6, 2.6))]
    return [(kit.join(slab, "slab"), concrete("city_helipad_slab_p", seed, "6e7276"), "slab"),
            (kit.join(marks + cloth_sock, "paint"), painted("city_helipad_paint_p", "e8e2d0", seed), "paint"),
            (kit.join(sock, "metal"), steel("city_helipad_metal_p", seed), "metal"),
            (kit.join(ring, "glow"), kit.flat_material("city_helipad_glow_p", "7ff0a8", 8.0, "40c070"), "glow")]


BUILDERS = [city_shop_house, city_tower, city_tea_house, city_ruin, city_shack_a, city_shack_b, city_shack_c,
            city_container, city_scaffold, city_water_barrier, city_hedgehog, city_sandbags, city_kiosk,
            city_gantry, city_wall, city_gate, city_overpass, city_culvert, city_helipad,
            city_row_low_a, city_row_low_b, city_row_mid, city_fence, city_street_lamp,
            city_traffic_light, city_hydrant, city_bin, city_postbox, city_bus_stop, city_phone_booth,
            city_vending, city_bollards, city_cones, city_car_wreck, city_manhole,
            city_yard_fence, city_yard_gate, city_hoarding, city_site_gate, city_tower_crane]
PREVIEW = {"city_tower": 18.0, "city_gantry": 16.0, "city_overpass": 15.0, "city_gate": 12.0, "city_shop_house": 14.0,
           "city_tea_house": 11.0, "city_ruin": 13.0, "city_wall": 8.0, "city_helipad": 10.0}


def publish(name, parts):
    """Published as built: every piece is modelled on its own origin (a gate
    round its opening, a building round its footprint), which recentring on
    the bounding box would shift."""
    baked = []
    for obj, mat, part in parts:
        kit.finish_mesh(obj)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        # The big painted surfaces near Sol's density (43 px a metre would be
        # 2048 on a tower; 1024 keeps the brushwork readable at game zoom).
        resolution = BAKE_SIZE.get(part, 512)
        image = kit.bake_texture(obj, mat, f"{name}_{part}", resolution)
        obj.data.materials.clear()
        obj.data.materials.append(kit.baked_material(f"{name}_{part}", image))
        baked.append(obj)
    whole = kit.join(baked, name)
    kit.report(whole, name)
    path = kit.export(whole, name)
    kit.render_preview(whole, name, PREVIEW.get(name, 6.0))
    kit.save_blend(whole, name)
    return path


BAKE_SIZE = {"wall": 1024, "sheet": 1024, "box": 1024, "shutter": 512, "face": 256}


## Built clean for the outer city, and the ones the slums also front their
## lanes with built again weathered as "<name>_worn".
CLEAN_BUILDINGS = ["city_tower", "city_shop_house", "city_tea_house", "city_row_low_a", "city_row_low_b", "city_row_mid"]
WORN = ["city_row_low_a", "city_row_low_b"]


def rebuild_clean(new_scene):
    """Through the MCP: every clean building, then the worn copies."""
    global CLEAN
    for name in CLEAN_BUILDINGS:
        CLEAN = True
        new_scene(name)
        publish(name, globals()[name]())
    for name in WORN:
        CLEAN = False
        new_scene(name + "_worn")
        publish(name + "_worn", globals()[name]())
    CLEAN = False


if __name__ == "__main__":
    for builder in BUILDERS:
        kit.reset_scene()
        CLEAN = builder.__name__ in CLEAN_BUILDINGS
        publish(builder.__name__, builder())
    CLEAN = False
    for name in WORN:
        kit.reset_scene()
        publish(name + "_worn", globals()[name]())
