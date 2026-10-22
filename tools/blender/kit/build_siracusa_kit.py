"""Siracusa old-town houses: art/kit/siracusa_*.glb (叙拉古地图调研与方案_v1.md
§2.1, §4.1; stage S3, 用户 2026-10-16: 可以补房屋建模了).

What sets them apart from Lungmen's blocks under the follow camera (58° down,
so the roof is most of what shows): a pitched roof of terracotta tiles, its
ridge and courses readable, eaves out over the lane; walls of lime render in
cream and ochre, worn through to brick in places (泰拉大典 / 「叙拉古人」: 石灰抹面);
tall windows with dark wooden shutters, a small wrought-iron balcony, an
arched door in a stone surround; two to three storeys, no tanks, condensers
or signs on the roof. Some windows are lit (parts named "glow" draw self-lit).

Blender Z up, metres; origin at the bottom centre of the footprint; the
street front faces Blender -Y (Godot +Z), as the Lungmen kit.

Through the Blender MCP add-on, one new scene per piece:

    import build_siracusa_kit as k; k.build("siracusa_house_a")

or headless:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_siracusa_kit.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bmesh  # noqa: E402
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
import poi_detail as d  # noqa: E402
from build_city_kit import _new, _swatch, _tinted, glass, lit, steel  # noqa: E402
import build_city_kit as city  # noqa: E402

# --- Materials ------------------------------------------------------------------------

def render(name, hex_rgb, seed, brick_share=0.16):
    """Lime render (Sol's plaster swatch, tinted warm), worn through to brick
    in patches, more of it low on the wall."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    wall = _tinted(nodes, links, _swatch(nodes, links, "city_plaster.png", 5.0), hex_rgb, 1.9)
    coord = nodes.new("ShaderNodeTexCoord")
    brick = nodes.new("ShaderNodeTexBrick")
    brick.inputs["Color1"].default_value = kit.srgb("8a4a32")
    brick.inputs["Color2"].default_value = kit.srgb("6e3a28")
    brick.inputs["Mortar"].default_value = kit.srgb("b8a888")
    brick.inputs["Scale"].default_value = 3.2
    brick.inputs["Mortar Size"].default_value = 0.02
    links.new(coord.outputs["Object"], brick.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.9
    noise.inputs["Detail"].default_value = 6.0
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 1.7, seed * 0.9, 0.0)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    # Lower on the wall, more worn: the threshold falls towards the ground.
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Object"], sep.inputs[0])
    low = nodes.new("ShaderNodeMath")
    low.operation = "MULTIPLY_ADD"
    low.inputs[1].default_value = 0.025
    low.inputs[2].default_value = 0.66 - brick_share
    links.new(sep.outputs["Z"], low.inputs[0])
    edge = nodes.new("ShaderNodeMath")
    edge.operation = "GREATER_THAN"
    links.new(noise.outputs["Fac"], edge.inputs[0])
    links.new(low.outputs[0], edge.inputs[1])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    links.new(edge.outputs[0], mix.inputs["Factor"])
    links.new(wall, mix.inputs["A"])
    links.new(brick.outputs["Color"], mix.inputs["B"])
    links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def tiles(name, seed, ridge_axis="x"):
    """Terracotta tiles: courses parallel to the ridge, a seam between the
    tiles of a course, each tile its own shade, the odd one dark or new."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Object"], sep.inputs[0])
    across, along = ("Y", "X") if ridge_axis == "x" else ("X", "Y")
    # Course index (down the slope) and tile index (along the course).
    def scaled(axis, metres, offset=0.0):
        m = nodes.new("ShaderNodeMath")
        m.operation = "MULTIPLY_ADD"
        m.inputs[1].default_value = 1.0 / metres
        m.inputs[2].default_value = offset
        links.new(sep.outputs[axis], m.inputs[0])
        return m.outputs[0]
    course = scaled(across, 0.34)
    combine = nodes.new("ShaderNodeCombineXYZ")
    course_floor = nodes.new("ShaderNodeMath")
    course_floor.operation = "FLOOR"
    links.new(course, course_floor.inputs[0])
    # Every other course shifted half a tile.
    half = nodes.new("ShaderNodeMath")
    half.operation = "MULTIPLY"
    half.inputs[1].default_value = 0.5
    links.new(course_floor.outputs[0], half.inputs[0])
    tile_u = nodes.new("ShaderNodeMath")
    tile_u.operation = "ADD"
    links.new(scaled(along, 0.26), tile_u.inputs[0])
    links.new(half.outputs[0], tile_u.inputs[1])
    tile_floor = nodes.new("ShaderNodeMath")
    tile_floor.operation = "FLOOR"
    links.new(tile_u.outputs[0], tile_floor.inputs[0])
    links.new(tile_floor.outputs[0], combine.inputs["X"])
    links.new(course_floor.outputs[0], combine.inputs["Y"])
    combine.inputs["Z"].default_value = seed * 0.37
    cell = nodes.new("ShaderNodeTexWhiteNoise")
    cell.noise_dimensions = "3D"
    links.new(combine.outputs[0], cell.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    # 改造案 v1.1 §2: faded terracotta, not the bright orange-red it was.
    els[0].position, els[0].color = 0.0, kit.srgb("6e4a3c")
    els[1].position, els[1].color = 1.0, kit.srgb("a8806a")
    mid = els.new(0.5)
    mid.color = kit.srgb("8c6250")
    near = els.new(0.9)
    near.color = kit.srgb("9a705a")
    links.new(cell.outputs["Value"], ramp.inputs["Fac"])
    # Shadow line at the bottom of each course and a seam between tiles.
    frac_c = nodes.new("ShaderNodeMath")
    frac_c.operation = "FRACT"
    links.new(course, frac_c.inputs[0])
    lip = nodes.new("ShaderNodeMapRange")
    lip.inputs["From Min"].default_value = 0.0
    lip.inputs["From Max"].default_value = 0.22
    lip.inputs["To Min"].default_value = 0.55
    lip.inputs["To Max"].default_value = 1.0
    links.new(frac_c.outputs[0], lip.inputs["Value"])
    frac_t = nodes.new("ShaderNodeMath")
    frac_t.operation = "FRACT"
    links.new(tile_u.outputs[0], frac_t.inputs[0])
    seam = nodes.new("ShaderNodeMath")
    seam.operation = "PINGPONG"
    seam.inputs[1].default_value = 0.5
    links.new(frac_t.outputs[0], seam.inputs[0])
    seam_dark = nodes.new("ShaderNodeMapRange")
    seam_dark.inputs["From Min"].default_value = 0.0
    seam_dark.inputs["From Max"].default_value = 0.08
    seam_dark.inputs["To Min"].default_value = 0.7
    seam_dark.inputs["To Max"].default_value = 1.0
    links.new(seam.outputs[0], seam_dark.inputs["Value"])
    shade = nodes.new("ShaderNodeMath")
    shade.operation = "MULTIPLY"
    links.new(lip.outputs[0], shade.inputs[0])
    links.new(seam_dark.outputs[0], shade.inputs[1])
    tint = nodes.new("ShaderNodeVectorMath")
    tint.operation = "SCALE"
    links.new(ramp.outputs["Color"], tint.inputs[0])
    links.new(shade.outputs[0], tint.inputs["Scale"])
    # Lichen and soot in slow patches.
    grime = nodes.new("ShaderNodeTexNoise")
    grime.inputs["Scale"].default_value = 0.6
    grime.inputs["Detail"].default_value = 3.0
    links.new(coord.outputs["Object"], grime.inputs["Vector"])
    grime_mix = nodes.new("ShaderNodeMix")
    grime_mix.data_type = "RGBA"
    grime_mix.inputs["B"].default_value = kit.srgb("4a4436")
    gr = nodes.new("ShaderNodeMapRange")
    gr.inputs["From Min"].default_value = 0.48
    gr.inputs["From Max"].default_value = 0.72
    gr.inputs["To Min"].default_value = 0.0
    gr.inputs["To Max"].default_value = 0.6
    links.new(grime.outputs["Fac"], gr.inputs["Value"])
    links.new(gr.outputs[0], grime_mix.inputs["Factor"])
    links.new(tint.outputs[0], grime_mix.inputs["A"])
    links.new(grime_mix.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def stone(name, seed, base="b4a68a"):
    return city._ramp_material(name, [(0.3, "7e735e"), (0.6, base), (0.95, "d2c6aa")], 5.0, seed, 5.0)


def shutter_wood(name, seed, hex_rgb):
    """Painted slatted wood, the paint worn at the edges."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    coord = nodes.new("ShaderNodeTexCoord")
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 18.0
    wave.inputs["Distortion"].default_value = 0.0
    links.new(coord.outputs["Object"], wave.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, kit.srgb(city._blend(hex_rgb, "101010", 0.55))
    els[1].position, els[1].color = 0.6, kit.srgb(hex_rgb)
    links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 9.0
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed, seed * 0.5, 0)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    worn = nodes.new("ShaderNodeMix")
    worn.data_type = "RGBA"
    worn.inputs["B"].default_value = kit.srgb("6a5640")
    gate = nodes.new("ShaderNodeMath")
    gate.operation = "GREATER_THAN"
    gate.inputs[1].default_value = 0.66
    links.new(noise.outputs["Fac"], gate.inputs[0])
    links.new(gate.outputs[0], worn.inputs["Factor"])
    links.new(ramp.outputs["Color"], worn.inputs["A"])
    links.new(worn.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def wood(name, seed):
    return city._ramp_material(name, [(0.3, "2a1a10"), (0.6, "4a2e1a"), (0.95, "6a4426")], 12.0, seed, 3.0)


def iron(name, seed):
    return city._ramp_material(name, [(0.3, "141414"), (0.6, "262626"), (0.95, "3a3632")], 8.0, seed, 3.0)


# --- Geometry -------------------------------------------------------------------------

def _mesh(name, verts, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _solid(obj, thickness):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1.0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def roof(name, width, depth, eave, rise, overhang=0.45, hip=True, ridge_axis="x"):
    """A tiled roof over a width x depth footprint, its eaves at `eave`:
    hipped (four slopes) or gabled (two), the ridge along `ridge_axis`.
    Returns the roof slabs, the ridge cap and the gable walls."""
    w, dd, o = width * 0.5 + overhang, depth * 0.5 + overhang, overhang
    if ridge_axis == "y":
        w, dd = dd, w
    top = eave + rise
    hip_in = dd if hip else 0.0
    hip_in = min(hip_in, w - 0.4) if hip else 0.0
    # Corners at the eaves, the ridge's two ends.
    a, b, c, e = (-w, -dd, eave), (w, -dd, eave), (w, dd, eave), (-w, dd, eave)
    r0, r1 = (-w + hip_in, 0.0, top), (w - hip_in, 0.0, top)
    verts = [a, b, c, e, r0, r1]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5)]
    if hip:
        faces += [(1, 2, 5), (3, 0, 4)]
    slab = _mesh(f"{name}_slab", verts, faces)
    gables = []
    if not hip:
        # The gable ends are wall, under the roof's overhang.
        gw = (width if ridge_axis == "x" else depth) * 0.5
        gd = (depth if ridge_axis == "x" else width) * 0.5
        grise = rise * gd / dd
        for sx in (-1.0, 1.0):
            x = sx * gw
            gables.append(_mesh(f"{name}_gable{int(sx)}", [(x, -gd, eave), (x, gd, eave), (x, 0.0, eave + grise)], [(0, 1, 2)]))
        gables = [_solid(g, 0.25) for g in gables]
    _solid(slab, 0.14)
    if ridge_axis == "y":
        for obj in [slab] + gables:
            obj.rotation_euler = (0, 0, math.pi / 2)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    # Ridge cap: a row of half-round tiles along the ridge (and the hips).
    caps = []
    length = (r1[0] - r0[0])
    if length > 0.2:
        cap = d.cyl(f"{name}_ridge", 0.13, length + 0.2, (0, 0, top + 0.1), (0, math.pi / 2, 0), vertices=8)
        if ridge_axis == "y":
            cap.rotation_euler = (0, math.pi / 2, math.pi / 2)
            bpy.ops.object.select_all(action="DESELECT")
            cap.select_set(True)
            bpy.context.view_layer.objects.active = cap
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        caps.append(cap)
    return slab, caps, gables


def _openings(prefix, width, depth, floors, floor_h, seed, door_at=0.0, sides=("front", "back", "left", "right"), lit_share=0.22):
    """Tall windows with shutters on every upper floor (and the ground floor's
    sides), an arched door on the front. Returns the parts as lists."""
    random.seed(seed)
    panes, glow, shutters, trims, ironwork, doors = [], [], [], [], [], []
    pots, plants = [], []
    for side in sides:
        along = width if side in ("front", "back") else depth
        count = max(1, int(along / 2.2))
        step = along / count
        place, rot = city._side_frame(side, width, depth)
        for f in range(floors):
            base_z = f * floor_h
            for k in range(count):
                u = -along * 0.5 + step * (k + 0.5)
                if side == "front" and f == 0 and abs(u - door_at) < step * 0.6:
                    # The door: dark wood under a round stone arch.
                    dw, dh = 1.3, 2.4
                    doors.append(kit.box(f"{prefix}door", (dw, 0.08, dh), place(u, 0.05, dh * 0.5 + 0.05), rot))
                    doors.append(d.cyl(f"{prefix}fan", dw * 0.5, 0.08, place(u, 0.05, dh + 0.05), (math.pi / 2, 0, rot[2]), vertices=12))
                    trims.append(d.cyl(f"{prefix}arch", dw * 0.5 + 0.2, 0.08, place(u, 0.01, dh + 0.05), (math.pi / 2, 0, rot[2]), vertices=12))
                    for s in (-1, 1):
                        trims.append(kit.box(f"{prefix}jamb{s}", (0.2, 0.16, dh), place(u + s * (dw * 0.5 + 0.1), 0.06, dh * 0.5 + 0.05), rot))
                    trims.append(kit.box(f"{prefix}step", (dw + 0.6, 0.5, 0.14), place(u, 0.25, 0.07), rot))
                    continue
                if random.random() < 0.1:
                    continue
                wh, ww = 1.55, 0.85
                z = base_z + floor_h * 0.55
                pane = kit.box(f"{prefix}w{side}{f}_{k}", (ww, 0.05, wh), place(u, 0.02, z), rot)
                (glow if random.random() < lit_share else panes).append(pane)
                # Stone surround and sill.
                trims.append(kit.box(f"{prefix}sill{side}{f}_{k}", (ww + 0.35, 0.18, 0.1), place(u, 0.08, z - wh * 0.5 - 0.05), rot))
                trims.append(kit.box(f"{prefix}lint{side}{f}_{k}", (ww + 0.3, 0.12, 0.16), place(u, 0.05, z + wh * 0.5 + 0.08), rot))
                # The surround's jambs (改造案 v1.1 §2: 窗套).
                for s in (-1, 1):
                    trims.append(kit.box(f"{prefix}wj{side}{f}_{k}_{s}", (0.14, 0.1, wh + 0.1), place(u + s * (ww * 0.5 + 0.07), 0.05, z), rot))
                # Shutters: open against the wall either side, or closed.
                if random.random() < 0.3:
                    shutters.append(kit.box(f"{prefix}shc{side}{f}_{k}", (ww, 0.07, wh), place(u, 0.06, z), rot))
                else:
                    for s in (-1, 1):
                        shutters.append(kit.box(f"{prefix}sh{side}{f}_{k}_{s}", (ww * 0.5, 0.06, wh), place(u + s * (ww * 0.75), 0.04, z), rot))
                # A wrought-iron balcony on some upper front windows.
                if f >= 1 and side == "front" and random.random() < 0.45:
                    by = 0.45
                    ironwork.append(kit.box(f"{prefix}bslab{f}_{k}", (ww + 0.6, by, 0.1), place(u, by * 0.5, base_z + 0.35), rot))
                    trims.append(ironwork.pop())
                    for b in range(7):
                        bu = u - (ww + 0.5) * 0.5 + b * (ww + 0.5) / 6.0
                        ironwork.append(kit.box(f"{prefix}bar{f}_{k}_{b}", (0.03, 0.03, 0.9), place(bu, by - 0.02, base_z + 0.85), rot))
                    ironwork.append(kit.box(f"{prefix}rail{f}_{k}", (ww + 0.55, 0.05, 0.05), place(u, by - 0.02, base_z + 1.32), rot))
                    for s in (-1, 1):
                        ironwork.append(kit.box(f"{prefix}rs{f}_{k}_{s}", (0.05, by, 0.05), place(u + s * (ww + 0.5) * 0.5, by * 0.5, base_z + 1.32), rot))
                    # Potted plants on the balcony (改造案 v1.1 §2: 阳台上摆着盆栽).
                    for n in range(random.randint(1, 3)):
                        pu = u + random.uniform(-ww * 0.45, ww * 0.45)
                        _pot(f"{prefix}bp{f}_{k}_{n}", place(pu, by * 0.5, base_z + 0.4), pots, plants)
                elif f >= 1 and random.random() < 0.18:
                    # A pot on the sill.
                    _pot(f"{prefix}sp{side}{f}_{k}", place(u + random.uniform(-0.2, 0.2), 0.14, z - wh * 0.5), pots, plants, 0.8)
    return panes, glow, shutters, trims, ironwork, doors, pots, plants


def _pot(name, at, pots, plants, size=1.0):
    """A terracotta pot and the green over it, standing at `at`."""
    x, y, z = at
    pots.append(d.cyl(f"{name}p", 0.13 * size, 0.24 * size, (x, y, z + 0.12 * size), vertices=10))
    plants.append(kit.rock(f"{name}g", 0.22 * size, (x, y, z + 0.34 * size), (1.2, 1.0, 0.8), subdivisions=1))


def _ivy(prefix, width, depth, height, seed):
    """Ivy up a front corner or two: leaves thick at the foot, thinning
    upwards, spread over the front and round the side."""
    random.seed(seed + 77)
    leaves = []
    for sx in (-1, 1):
        if random.random() > 0.5: continue
        top = random.uniform(0.35, 0.8) * height
        spread = random.uniform(0.6, 1.3)
        for n in range(int(top * 14)):
            z = random.uniform(0.0, top) ** 1.0
            reach = spread * (1.0 - 0.6 * z / top)
            # On the front (-Y) or round the corner on the side.
            if random.random() < 0.65:
                at = (sx * (width * 0.5 - random.uniform(0.0, reach)), -depth * 0.5 - 0.05, z)
                rot = (math.radians(random.uniform(-20, 20)), math.radians(random.uniform(0, 360)), 0)
            else:
                at = (sx * (width * 0.5 + 0.05), -depth * 0.5 + random.uniform(0.0, reach), z)
                rot = (0, math.radians(random.uniform(0, 360)), math.pi / 2)
            leaves.append(kit.box(f"{prefix}ivy{sx}_{n}", (0.28, 0.07, 0.22), at, rot))
    return leaves


def leaf(name, seed):
    return city._ramp_material(name, [(0.3, "22341c"), (0.6, "3a5a2c"), (0.95, "5a7a3c")], 9.0, seed, 3.0)


def terracotta(name, seed):
    return city._ramp_material(name, [(0.3, "6a3a26"), (0.6, "9a5a3a"), (0.95, "b8744c")], 8.0, seed, 3.0)


def _house(name, width, depth, floors, floor_h, wall_hex, shutter_hex, seed, hip=True, ridge_axis="x",
           chimney=True, cornice=True, rise=None, lit_share=0.3):
    random.seed(seed)
    height = floors * floor_h
    body = d.bbox("body", (width, depth, height), (0, 0, height * 0.5), width=0.03)
    walls = [body]
    trims = []
    # A plinth of stone at the foot, a string course between storeys, a cornice under the eaves.
    trims.append(kit.box("plinth", (width + 0.1, depth + 0.1, 0.5), (0, 0, 0.25)))
    for f in range(1, floors):
        trims.append(kit.box(f"course{f}", (width + 0.08, depth + 0.08, 0.12), (0, 0, f * floor_h)))
    if cornice:
        trims.append(kit.box("cornice", (width + 0.3, depth + 0.3, 0.22), (0, 0, height - 0.05)))
    # Quoins up the front corners.
    for sx in (-1, 1):
        for q in range(int(height / 0.6)):
            trims.append(kit.box(f"quoin{sx}_{q}", (0.42 if q % 2 else 0.28, 0.06, 0.26), (sx * (width * 0.5 - (0.21 if q % 2 else 0.14)), -depth * 0.5 - 0.03, 0.55 + q * 0.6)))
    panes, glow, shutters, open_trims, ironwork, doors, pots, plants = _openings("", width, depth, floors, floor_h, seed,
                                                                                  door_at=random.uniform(-width * 0.2, width * 0.2), lit_share=lit_share)
    plants += _ivy("", width, depth, height, seed)
    trims += open_trims
    rise = rise if rise is not None else min(width, depth) * 0.32
    slab, caps, gables = roof("roof", width, depth, height + 0.12, rise, hip=hip, ridge_axis=ridge_axis)
    walls += gables
    roof_parts = [slab] + caps
    if chimney:
        cx, cy = random.uniform(-width * 0.3, width * 0.3), random.uniform(depth * 0.05, depth * 0.25)
        stack = kit.box("chimney", (0.6, 0.6, rise + 1.2), (cx, cy, height + (rise + 1.2) * 0.5))
        trims.append(kit.box("chimney_cap", (0.8, 0.8, 0.12), (cx, cy, height + rise + 1.26)))
        walls.append(stack)
    parts = [(kit.join(walls, "wall"), render(f"{name}_wall_p", wall_hex, seed), "wall"),
             (kit.join(roof_parts, "roof"), tiles(f"{name}_roof_p", seed, ridge_axis), "roof"),
             (kit.join(trims, "trim"), stone(f"{name}_trim_p", seed), "trim"),
             (kit.join(shutters, "shutters"), shutter_wood(f"{name}_shutters_p", seed, shutter_hex), "shutters"),
             (kit.join(doors, "door"), wood(f"{name}_door_p", seed), "door")]
    if panes: parts.append((kit.join(panes, "glass"), glass(f"{name}_glass_p", seed), "glass"))
    if glow: parts.append((kit.join(glow, "glow"), lit(f"{name}_glow_p"), "glow"))
    if ironwork: parts.append((kit.join(ironwork, "iron"), iron(f"{name}_iron_p", seed), "iron"))
    if pots: parts.append((kit.join(pots, "pots"), terracotta(f"{name}_pots_p", seed), "pots"))
    if plants: parts.append((kit.join(plants, "plants"), leaf(f"{name}_plants_p", seed), "plants"))
    return parts


# --- Pieces -----------------------------------------------------------------------------

def siracusa_house_a(seed=901):
    """两层宅：7 m 宽，四坡屋顶，奶白抹灰、墨绿百叶。"""
    return _house("siracusa_house_a", 7.0, 7.0, 2, 3.3, "d2b68a", "35503a", seed)


def siracusa_house_b(seed=903):
    """三层窄楼：6 m 宽，双坡屋顶山墙朝街，赭黄抹灰、深褐百叶。"""
    return _house("siracusa_house_b", 6.0, 8.0, 3, 3.2, "c4a070", "4a3020", seed, hip=False, ridge_axis="y")


def siracusa_house_c(seed=905):
    """宽宅：10 m 宽两层，双坡屋顶屋脊顺街，淡粉抹灰、灰蓝百叶。"""
    return _house("siracusa_house_c", 10.0, 7.5, 2, 3.4, "cfae8c", "3a4a5a", seed, hip=False, ridge_axis="x")


def siracusa_house_d(seed=907):
    """三层宅：8 m 见方，四坡屋顶，沙色抹灰、墨绿百叶，楼上亮灯多。"""
    return _house("siracusa_house_d", 8.0, 8.0, 3, 3.2, "c8ac80", "2e4632", seed, lit_share=0.38)


def siracusa_house_low(seed=909):
    """一层小屋：6 m 宽，单层，矮坡屋顶；巷子南侧用（镜头视线）。"""
    return _house("siracusa_house_low", 6.0, 6.0, 1, 3.4, "d4bc94", "4a3020", seed, chimney=False, rise=1.4)


def siracusa_ruin(seed=911):
    """贝洛内家的残宅：两层，半边屋顶塌了，露出椽子，墙头残缺。"""
    random.seed(seed)
    parts = _house("siracusa_ruin", 8.0, 7.0, 2, 3.3, "a89a84", "3a3028", seed, hip=False, chimney=False, lit_share=0.0)
    # Break the roof: cut away the eastern half of the slabs, leave rafters.
    roof_obj = next(o for o, _m, p in parts if p == "roof")
    bm = bmesh.new()
    bm.from_mesh(roof_obj.data)
    gone = [f for f in bm.faces if f.calc_center_median().x > 0.6]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(roof_obj.data)
    bm.free()
    rafters = []
    height = 2 * 3.3 + 0.12
    for k in range(6):
        x = 0.9 + k * 0.6
        for s in (-1, 1):
            r = kit.box(f"rafter{k}_{s}", (0.12, 4.2, 0.14), (x, s * 1.9, height + 1.15), (s * -0.55, 0, 0))
            rafters.append(r)
    rubble = []
    for i in range(10):
        r = random.uniform(0.2, 0.5)
        rock = kit.rock(f"rb{i}", r, (random.uniform(-3.5, 3.5), random.uniform(-4.2, -3.6), r * 0.4), (1.3, 1.0, 0.6), subdivisions=1)
        rubble.append(rock)
    parts.append((kit.join(rafters, "rafters"), wood("siracusa_ruin_rafters_p", seed), "rafters"))
    parts.append((kit.join(rubble, "rubble"), stone("siracusa_ruin_rubble_p", seed, "8e8270"), "rubble"))
    return parts


# --- Landmarks and street pieces (S3 second batch, 用户 2026-10-16: 继续用 Blender
# 建剧场、法院立面，以及喷泉、壁灯、家族旗、酒桶、院墙) -------------------------

def marble(name, seed):
    """The court's marble: lime-washed, as the event's furniture says
    (「叙拉古人」: the court's white marble is really lime render): pale,
    faintly veined."""
    return city._ramp_material(name, [(0.3, "a8a294"), (0.62, "cfc9ba"), (0.95, "e4dfd2")], 3.0, seed, 7.0)


def cloth_flat(name, hex_rgb, seed):
    """A hanging banner: its colour, darker in the folds."""
    mat, nodes, links = _new(name)
    bsdf = kit.principled(nodes)
    coord = nodes.new("ShaderNodeTexCoord")
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.inputs["Scale"].default_value = 4.0
    wave.inputs["Distortion"].default_value = 1.5
    links.new(coord.outputs["Object"], wave.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, kit.srgb(city._blend(hex_rgb, "000000", 0.45))
    els[1].position, els[1].color = 0.7, kit.srgb(hex_rgb)
    links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def gold(name, seed):
    return city._ramp_material(name, [(0.3, "6a5220"), (0.6, "a4843a"), (0.95, "d6b860")], 7.0, seed, 3.0)


def water(name):
    return kit.flat_material(name, "2c4a5c", 6.0, "1c3240")


def _portico(prefix, width, front_y, height, count, radius, base_z=0.0):
    """A row of columns with bases and capitals, and the beam over them."""
    cols, trim = [], []
    for k in range(count):
        x = -width * 0.5 + width * k / (count - 1)
        cols.append(d.cyl(f"{prefix}col{k}", radius, height, (x, front_y, base_z + height * 0.5), vertices=12))
        trim.append(kit.box(f"{prefix}base{k}", (radius * 2.6, radius * 2.6, 0.3), (x, front_y, base_z + 0.15)))
        trim.append(kit.box(f"{prefix}cap{k}", (radius * 2.8, radius * 2.8, 0.3), (x, front_y, base_z + height - 0.15)))
    trim.append(kit.box(f"{prefix}beam", (width + radius * 3.0, radius * 3.2, 0.7), (0, front_y, base_z + height + 0.35)))
    return cols, trim


def _steps(prefix, width, front_y, count=3, rise=0.22, tread=0.5):
    return [kit.box(f"{prefix}step{s}", (width - s * 0.4, tread * (count - s), rise), (0, front_y - tread * (count - s) * 0.5, rise * (s + 0.5)))
            for s in range(count)]


def _pediment(name, width, depth, z, rise, y_front):
    """A triangular gable over the front, its face towards -Y."""
    verts = [(-width * 0.5, y_front, z), (width * 0.5, y_front, z), (0.0, y_front, z + rise),
             (-width * 0.5, y_front + depth, z), (width * 0.5, y_front + depth, z), (0.0, y_front + depth, z + rise)]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    return _mesh(name, verts, faces)


def siracusa_theatre(seed=921):
    """米兰剧场: a 14 m stone front facing the square (-Y), three arched doors
    under a portico of six columns, a row of tall windows lit for the night's
    show, an attic with the house's name plate, a tiled hipped roof behind.
    Its body spans y -3.5..3.5 (7 m deep); the portico and steps stand out
    in front to about y -6. Scaled in the game to the square's width."""
    random.seed(seed)
    width, depth, height = 14.0, 7.0, 10.0
    walls = [d.bbox("body", (width, depth, height), (0, 0, height * 0.5), width=0.04)]
    trims, glow, doors, metal = [], [], [], []
    front = -depth * 0.5
    trims.append(kit.box("plinth", (width + 0.2, depth + 0.2, 0.6), (0, 0, 0.3)))
    trims.append(kit.box("course", (width + 0.2, 0.3, 0.3), (0, front - 0.1, 4.6)))
    trims.append(kit.box("cornice", (width + 0.6, depth + 0.6, 0.45), (0, 0, height)))
    for k in range(7):
        x = -width * 0.5 + 0.5 + k * (width - 1.0) / 6.0
        trims.append(kit.box(f"pilaster{k}", (0.6, 0.2, height - 0.8), (x, front - 0.1, (height - 0.8) * 0.5 + 0.4)))
    for k, (x, w) in enumerate(((-4.0, 1.8), (0.0, 2.4), (4.0, 1.8))):
        h = 3.4 if w > 2 else 3.0
        doors.append(kit.box(f"door{k}", (w, 0.1, h), (x, front - 0.05, h * 0.5 + 0.6)))
        doors.append(d.cyl(f"fan{k}", w * 0.5, 0.1, (x, front - 0.05, h + 0.6), (math.pi / 2, 0, 0), vertices=14))
        trims.append(d.cyl(f"arch{k}", w * 0.5 + 0.3, 0.12, (x, front - 0.02, h + 0.6), (math.pi / 2, 0, 0), vertices=14))
        glow.append(kit.box(f"doorlight{k}", (w * 0.7, 0.05, 0.5), (x, front - 0.12, h + 0.75)))
    for k in range(6):
        x = -width * 0.5 + 1.6 + k * (width - 3.2) / 5.0
        glow.append(kit.box(f"win{k}", (1.0, 0.06, 2.4), (x, front - 0.04, 6.6)))
        trims.append(kit.box(f"winhood{k}", (1.5, 0.25, 0.25), (x, front - 0.12, 8.0)))
        trims.append(kit.box(f"winsill{k}", (1.4, 0.3, 0.15), (x, front - 0.15, 5.35)))
    trims.append(kit.box("attic", (width * 0.6, 0.5, 1.6), (0, front + 0.25, height + 1.0)))
    metal.append(kit.box("plate", (width * 0.4, 0.08, 0.8), (0, front - 0.05, height + 1.0)))
    cols, ptrim = _portico("p", width * 0.72, front - 1.6, 4.2, 6, 0.32, base_z=0.66)
    trims += ptrim
    portico_roof = kit.box("portico_roof", (width * 0.72 + 1.0, 2.2, 0.25), (0, front - 1.1, 0.66 + 4.2 + 0.85))
    trims += _steps("", width * 0.8, front - 2.0, count=3)
    slab, caps, _g = roof("roof", width, depth, height + 0.2, 2.6, overhang=0.3, hip=True)
    for s in (-1, 1):
        metal.append(kit.box(f"lantern_arm{s}", (0.06, 0.6, 0.06), (s * 2.1, front - 0.3, 3.9)))
        glow.append(kit.box(f"lantern{s}", (0.3, 0.3, 0.45), (s * 2.1, front - 0.6, 3.6)))
    return [(kit.join(walls, "wall"), stone("siracusa_theatre_wall_p", seed, "b8a888"), "wall"),
            (kit.join(trims + [portico_roof], "trim"), stone("siracusa_theatre_trim_p", seed + 1, "cfc2a6"), "trim"),
            (kit.join(cols, "columns"), marble("siracusa_theatre_columns_p", seed), "columns"),
            (kit.join([slab] + caps, "roof"), tiles("siracusa_theatre_roof_p", seed), "roof"),
            (kit.join(doors, "door"), wood("siracusa_theatre_door_p", seed), "door"),
            (kit.join(metal, "metal"), gold("siracusa_theatre_metal_p", seed), "metal"),
            (kit.join(glow, "glow"), lit("siracusa_theatre_glow_p"), "glow")]


def siracusa_court(seed=923):
    """沃尔西尼法庭: a 12 m lime-washed front (-Y), a colonnade of eight
    columns under a pediment, broad steps, tall shuttered windows behind;
    a flat roof with a stone parapet. Body y -3.5..3.5, colonnade and steps
    out to about y -6."""
    random.seed(seed)
    width, depth, height = 12.0, 7.0, 8.0
    front = -depth * 0.5
    walls = [d.bbox("body", (width, depth, height), (0, 0, height * 0.5), width=0.04)]
    trims, doors, panes = [], [], []
    trims.append(kit.box("plinth", (width + 0.2, depth + 0.2, 0.7), (0, 0, 0.35)))
    trims.append(kit.box("cornice", (width + 0.5, depth + 0.5, 0.4), (0, 0, height)))
    t = 0.25
    for (sx, sy, lx, ly) in ((width, t, 0, -depth * 0.5 + t * 0.5), (width, t, 0, depth * 0.5 - t * 0.5),
                             (t, depth, -width * 0.5 + t * 0.5, 0), (t, depth, width * 0.5 - t * 0.5, 0)):
        trims.append(kit.box(f"par{len(trims)}", (sx, sy, 0.8), (lx, ly, height + 0.6)))
    roof_top = kit.box("roof_top", (width - 0.5, depth - 0.5, 0.1), (0, 0, height + 0.25))
    cols, ptrim = _portico("c", width * 0.85, front - 1.7, 5.2, 8, 0.36, base_z=0.88)
    trims += ptrim
    trims.append(kit.box("colonnade_roof", (width * 0.85 + 1.2, 2.4, 0.3), (0, front - 1.2, 0.88 + 5.2 + 0.85)))
    ped = _pediment("pediment", width * 0.85 + 1.2, 2.4, 0.88 + 5.2 + 1.0, 1.6, front - 2.4)
    trims += _steps("", width * 0.92, front - 2.2, count=4, rise=0.22, tread=0.5)
    doors.append(kit.box("door", (2.2, 0.1, 3.6), (0, front - 0.05, 2.7)))
    for k in range(4):
        x = (-1.0 if k < 2 else 1.0) * (2.4 + (k % 2) * 2.4)
        panes.append(kit.box(f"win{k}", (1.0, 0.06, 2.6), (x, front - 0.04, 3.4)))
        doors.append(kit.box(f"shut{k}", (0.5, 0.06, 2.6), (x - 0.8, front - 0.06, 3.4)))
        doors.append(kit.box(f"shut{k}b", (0.5, 0.06, 2.6), (x + 0.8, front - 0.06, 3.4)))
    return [(kit.join(walls, "wall"), marble("siracusa_court_wall_p", seed), "wall"),
            (kit.join(trims + [ped, roof_top], "trim"), stone("siracusa_court_trim_p", seed, "c4b89e"), "trim"),
            (kit.join(cols, "columns"), marble("siracusa_court_columns_p", seed + 3), "columns"),
            (kit.join(doors, "door"), wood("siracusa_court_door_p", seed), "door"),
            (kit.join(panes, "glass"), glass("siracusa_court_glass_p", seed), "glass")]


def siracusa_fountain(seed=925):
    """广场喷泉: an octagonal stone basin 3.4 m across, its water, a column
    with a bowl, a smaller bowl over it. Centred on the origin."""
    stone_parts = [d.cyl("basin", 1.7, 0.6, (0, 0, 0.3), vertices=8),
                   d.cyl("rim", 1.78, 0.12, (0, 0, 0.62), vertices=8),
                   d.cyl("column", 0.24, 1.4, (0, 0, 1.2), vertices=10),
                   d.cyl("bowl", 0.75, 0.2, (0, 0, 1.9), vertices=12),
                   d.cyl("bowl_foot", 0.35, 0.2, (0, 0, 1.75), vertices=10),
                   d.cyl("column2", 0.14, 0.6, (0, 0, 2.3), vertices=8),
                   d.cyl("bowl2", 0.38, 0.14, (0, 0, 2.6), vertices=10),
                   d.cyl("finial", 0.1, 0.3, (0, 0, 2.82), vertices=8)]
    pool = [d.cyl("water", 1.5, 0.05, (0, 0, 0.56), vertices=16), d.cyl("water2", 0.62, 0.04, (0, 0, 2.0), vertices=12)]
    return [(kit.join(stone_parts, "stone"), stone("siracusa_fountain_stone_p", seed, "b2a68c"), "stone"),
            (kit.join(pool, "water"), water("siracusa_fountain_water_p"), "water")]


def siracusa_lantern(seed=927):
    """壁灯: a wrought-iron bracket out of the wall (origin on the wall at the
    bracket's height, out towards -Y) and a four-paned lantern hanging from it."""
    iron_parts = [kit.box("plate", (0.22, 0.04, 0.42), (0, -0.02, 0.0)),
                  kit.box("arm", (0.05, 0.62, 0.05), (0, -0.31, 0.12)),
                  kit.box("brace", (0.04, 0.5, 0.04), (0, -0.22, -0.06), (math.radians(35), 0, 0)),
                  kit.box("hook", (0.03, 0.03, 0.16), (0, -0.58, 0.04)),
                  kit.box("cap", (0.3, 0.3, 0.08), (0, -0.58, -0.08)),
                  kit.box("cap2", (0.16, 0.16, 0.08), (0, -0.58, -0.02)),
                  kit.box("base", (0.24, 0.24, 0.06), (0, -0.58, -0.58))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            iron_parts.append(kit.box(f"post{sx}{sy}", (0.025, 0.025, 0.48), (sx * 0.11, -0.58 + sy * 0.11, -0.34)))
    light = [kit.box("glass", (0.2, 0.2, 0.42), (0, -0.58, -0.34))]
    return [(kit.join(iron_parts, "iron"), iron("siracusa_lantern_iron_p", seed), "iron"),
            (kit.join(light, "glow"), lit("siracusa_lantern_glow_p"), "glow")]


BANNER_FAMILIES = {"saluzzo": "761a24", "rossetti": "1e3466", "bellone": "8a6c34"}


def _banner(family, seed):
    """家族旗: an iron pole out of the wall at 4.25 m (origin at the wall's
    foot, out towards -Y), a long cloth of the family's colour hanging from it,
    a gold fringe and a lozenge on it."""
    pole = [kit.box("pole", (0.06, 1.1, 0.06), (0, -0.55, 4.25)), kit.box("plate", (0.2, 0.04, 0.3), (0, -0.02, 4.25)),
            d.cyl("knob", 0.06, 0.12, (0, -1.12, 4.25), (math.pi / 2, 0, 0), vertices=8),
            kit.box("bar", (0.9, 0.04, 0.04), (0, -0.85, 4.15))]
    cloth_obj = kit.box("cloth", (0.82, 0.05, 1.8), (0, -0.85, 3.25))
    fringe = [kit.box("fringe", (0.82, 0.06, 0.1), (0, -0.85, 2.38)),
              kit.box("crest", (0.36, 0.07, 0.36), (0, -0.88, 3.45), (0, math.radians(45), 0))]
    return [(kit.join(pole, "iron"), iron(f"siracusa_banner_{family}_iron_p", seed), "iron"),
            (cloth_obj, cloth_flat(f"siracusa_banner_{family}_cloth_p", BANNER_FAMILIES[family], seed), "cloth"),
            (kit.join(fringe, "fringe"), gold(f"siracusa_banner_{family}_fringe_p", seed), "fringe")]


def siracusa_banner_saluzzo(seed=929):
    return _banner("saluzzo", seed)


def siracusa_banner_rossetti(seed=931):
    return _banner("rossetti", seed)


def siracusa_banner_bellone(seed=933):
    return _banner("bellone", seed)


def siracusa_barrels(seed=935):
    """酒桶: two wine barrels standing and one on its side on a pallet of
    planks, hooped in iron (萨卢佐葡萄酒). About 1.8 m across, centred."""
    random.seed(seed)
    staves, hoops = [], []
    for k, (x, y) in enumerate(((-0.45, 0.1), (0.45, 0.15))):
        staves.append(d.cyl(f"barrel{k}", 0.4, 1.0, (x, y, 0.62), vertices=14))
        staves.append(d.cyl(f"belly{k}", 0.44, 0.5, (x, y, 0.62), vertices=14))
        for z in (0.25, 1.0):
            hoops.append(d.cyl(f"hoop{k}_{z}", 0.42, 0.06, (x, y, 0.12 + z * 0.9), vertices=14))
    staves.append(d.cyl("lying", 0.38, 0.95, (0.0, -0.55, 0.5), (0, math.pi / 2, 0.15), vertices=14))
    for s in (-0.3, 0.3):
        hoops.append(d.cyl(f"lhoop{s}", 0.4, 0.06, (s, -0.55 + s * 0.15, 0.5), (0, math.pi / 2, 0.15), vertices=14))
    planks = [kit.box(f"plank{k}", (1.8, 0.24, 0.1), (0, -0.6 + k * 0.3, 0.05)) for k in range(5)]
    return [(kit.join(staves, "wood"), city._ramp_material("siracusa_barrels_wood_p", [(0.3, "4a2a14"), (0.6, "6e4222"), (0.95, "8e5a30")], 10.0, seed, 3.0), "wood"),
            (kit.join(hoops, "iron"), iron("siracusa_barrels_iron_p", seed), "iron"),
            (kit.join(planks, "planks"), wood("siracusa_barrels_planks_p", seed), "planks")]


def siracusa_garden_wall(seed=937):
    """院墙: a 2 m length of rendered garden wall, 1.2 m high, capped with
    terracotta, along x. Centred on the origin."""
    body = [d.bbox("wall", (2.0, 0.4, 1.15), (0, 0, 0.575), width=0.02)]
    cap = [kit.box("cap", (2.02, 0.52, 0.1), (0, 0, 1.2)), d.cyl("ridge", 0.1, 2.02, (0, 0, 1.27), (0, math.pi / 2, 0), vertices=8)]
    return [(kit.join(body, "wall"), render("siracusa_garden_wall_wall_p", "cbb48e", seed, brick_share=-0.06), "wall"),
            (kit.join(cap, "roof"), tiles("siracusa_garden_wall_roof_p", seed), "roof")]


def siracusa_mansion_gate(seed=939):
    """宅邸门: the one way into a family's court. Two rusticated stone piers
    with ball finials either side of a 6 m opening, a carved lintel across
    with a gold-framed crest at its middle, and the iron gate's two leaves
    swung open into the court (+Y). Origin at the middle of the opening on
    the ground; the lane side faces -Y. Scaled in x to the lane."""
    random.seed(seed)
    opening = 6.0
    stones, trims, irons, crest = [], [], [], []
    for s in (-1, 1):
        x = s * (opening * 0.5 + 0.5)
        for c in range(7):
            # Rusticated courses: alternately wider blocks.
            w = 1.0 if c % 2 else 1.12
            stones.append(kit.box(f"pier{s}_{c}", (w, w, 0.58), (x, 0.0, 0.29 + c * 0.6)))
        trims.append(kit.box(f"cap{s}", (1.25, 1.25, 0.2), (x, 0.0, 4.3)))
        trims.append(d.cyl(f"neck{s}", 0.2, 0.25, (x, 0.0, 4.52), vertices=10))
        ball = kit.rock(f"ball{s}", 0.36, (x, 0.0, 4.95), subdivisions=2)
        trims.append(ball)
    # The lintel and its cornice, a little arched in the middle.
    trims.append(kit.box("lintel", (opening + 2.2, 0.9, 0.7), (0, 0, 4.15)))
    trims.append(kit.box("cornice", (opening + 2.6, 1.1, 0.18), (0, 0, 4.58)))
    trims.append(kit.box("raise", (2.4, 0.9, 0.5), (0, 0, 4.9)))
    trims.append(kit.box("raise_cap", (2.7, 1.05, 0.14), (0, 0, 5.2)))
    # The crest on the lane side: a shield in a gold frame.
    crest.append(kit.box("frame", (1.2, 0.08, 1.0), (0, -0.48, 4.55)))
    trims.append(kit.box("shield", (0.9, 0.1, 0.75), (0, -0.52, 4.55)))
    # The gate's leaves, open against the inside of the piers.
    for s in (-1, 1):
        hinge_x = s * opening * 0.5
        leaf_w, leaf_h = opening * 0.5 - 0.2, 2.8
        for b in range(9):
            y = 0.25 + b * leaf_w / 8.0
            irons.append(kit.box(f"bar{s}_{b}", (0.04, 0.04, leaf_h), (hinge_x - s * 0.12, y, leaf_h * 0.5 + 0.1)))
        for z in (0.35, leaf_h - 0.1, leaf_h * 0.55):
            irons.append(kit.box(f"rail{s}_{z}", (0.06, leaf_w, 0.06), (hinge_x - s * 0.12, 0.25 + leaf_w * 0.5, z)))
        for b in range(9):
            y = 0.25 + b * leaf_w / 8.0
            irons.append(kit.box(f"spike{s}_{b}", (0.07, 0.07, 0.18), (hinge_x - s * 0.12, y, leaf_h + 0.2), (math.radians(45), 0, 0)))
    return [(kit.join(stones, "stone"), stone("siracusa_mansion_gate_stone_p", seed, "a89a80"), "stone"),
            (kit.join(trims, "trim"), stone("siracusa_mansion_gate_trim_p", seed + 1, "c8bb9e"), "trim"),
            (kit.join(irons, "iron"), iron("siracusa_mansion_gate_iron_p", seed), "iron"),
            (kit.join(crest, "metal"), gold("siracusa_mansion_gate_metal_p", seed), "metal")]


# --- 钟楼 and 拱门过街楼 (改造案 v1.1 §2) -------------------------------------------

def siracusa_bell_tower(seed=941):
    """钟楼: a square sandstone tower, 4.6 m a side, the tallest piece on the
    floor (to 19.5 m): a door and slit windows up its shaft, string courses,
    a clock on its front (-Y), an open belfry of paired round arches on every
    side with the bell inside and lit, a cornice, a tiled pyramid roof and a
    finial. Origin at the bottom centre."""
    random.seed(seed)
    w = 4.6
    shaft = 13.0
    bel_h = 3.6
    walls = [d.bbox("shaft", (w, w, shaft), (0, 0, shaft * 0.5), width=0.03)]
    trims, glow, doors, metal, glass_parts = [], [], [], [], []
    trims.append(kit.box("plinth", (w + 0.3, w + 0.3, 0.7), (0, 0, 0.35)))
    for z in (4.6, 9.2, shaft):
        trims.append(kit.box(f"course{z}", (w + 0.2, w + 0.2, 0.22), (0, 0, z)))
    # Quoins up all four corners.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for q in range(int(shaft / 0.6)):
                big = q % 2 == 0
                trims.append(kit.box(f"q{sx}{sy}_{q}", (0.4 if big else 0.26, 0.4 if not big else 0.26, 0.28),
                                     (sx * (w * 0.5 - (0.18 if big else 0.11)), sy * (w * 0.5 - (0.11 if big else 0.18)), 0.6 + q * 0.6)))
    # The door under a round arch, slit windows above.
    doors.append(kit.box("door", (1.2, 0.08, 2.3), (0, -w * 0.5 - 0.03, 1.15 + 0.35)))
    doors.append(d.cyl("door_fan", 0.6, 0.08, (0, -w * 0.5 - 0.03, 2.8), (math.pi / 2, 0, 0), vertices=12))
    trims.append(d.cyl("door_arch", 0.82, 0.1, (0, -w * 0.5 - 0.01, 2.8), (math.pi / 2, 0, 0), vertices=12))
    for side, (px, py, rz) in {"f": (0, -1, 0), "b": (0, 1, 0), "l": (-1, 0, math.pi / 2), "r": (1, 0, math.pi / 2)}.items():
        for z in (6.4, 7.6):
            if side == "f" and z > 7: continue
            pane = kit.box(f"slit{side}{z}", (0.3, 0.06, 1.0), (px * (w * 0.5 + 0.02), py * (w * 0.5 + 0.02), z), (0, 0, rz))
            (glow if random.random() < 0.4 else glass_parts).append(pane)
    # The clock: a pale face in a stone ring, iron hands.
    trims.append(d.cyl("clock_ring", 0.95, 0.12, (0, -w * 0.5 - 0.06, 10.9), (math.pi / 2, 0, 0), vertices=20))
    glow.append(d.cyl("clock_face", 0.78, 0.06, (0, -w * 0.5 - 0.12, 10.9), (math.pi / 2, 0, 0), vertices=20))
    metal.append(kit.box("hand_h", (0.06, 0.05, 0.5), (0.1, -w * 0.5 - 0.17, 11.05), (0, math.radians(-35), 0)))
    metal.append(kit.box("hand_m", (0.05, 0.05, 0.7), (-0.12, -w * 0.5 - 0.18, 11.1), (0, math.radians(20), 0)))
    # The belfry: four corner piers, two round arches each side.
    base = shaft + 0.11
    pier = 0.7
    for sx in (-1, 1):
        for sy in (-1, 1):
            walls.append(kit.box(f"pier{sx}{sy}", (pier, pier, bel_h), (sx * (w * 0.5 - pier * 0.5), sy * (w * 0.5 - pier * 0.5), base + bel_h * 0.5)))
    span = (w - 2 * pier) / 2.0
    for side, (px, py, rz) in {"f": (0, -1, 0), "b": (0, 1, 0), "l": (-1, 0, math.pi / 2), "r": (1, 0, math.pi / 2)}.items():
        along = (1, 0) if rz == 0 else (0, 1)
        out = (px * (w * 0.5 - 0.2), py * (w * 0.5 - 0.2))
        # The middle mullion, the arches' heads, the wall over them, the sill.
        walls.append(kit.box(f"mull{side}", (0.3, 0.4, bel_h) if rz == 0 else (0.4, 0.3, bel_h), (out[0], out[1], base + bel_h * 0.5)))
        # The wall over the openings, two round arches cut out of it.
        head = kit.box(f"head{side}", (w, 0.4, 1.6) if rz == 0 else (0.4, w, 1.6), (out[0], out[1], base + bel_h - 0.8))
        cutters = []
        for k in (-1, 1):
            cx = out[0] + along[0] * k * (span * 0.5 + 0.15)
            cy = out[1] + along[1] * k * (span * 0.5 + 0.15)
            cutters.append(d.cyl(f"arch{side}{k}", span * 0.5 - 0.02, 1.0, (cx, cy, base + bel_h - 1.6), (math.pi / 2, 0, rz), vertices=16))
        walls.append(_cut(head, cutters))
        trims.append(kit.box(f"sill{side}", (w, 0.55, 0.15) if rz == 0 else (0.55, w, 0.15), (out[0], out[1], base + 0.9)))
    # The belfry's floor and its inside, lit warm, and the bell.
    trims.append(kit.box("bel_floor", (w - 0.2, w - 0.2, 0.2), (0, 0, base + 0.05)))
    glow.append(kit.box("bel_light", (w - 1.6, w - 1.6, 0.06), (0, 0, base + 0.18)))
    metal.append(d.cyl("bell", 0.55, 0.9, (0, 0, base + bel_h - 1.4), vertices=14))
    metal.append(d.cyl("bell_lip", 0.68, 0.12, (0, 0, base + bel_h - 1.85), vertices=14))
    metal.append(kit.box("yoke", (1.6, 0.15, 0.15), (0, 0, base + bel_h - 0.9)))
    top = base + bel_h
    trims.append(kit.box("cornice", (w + 0.5, w + 0.5, 0.3), (0, 0, top + 0.1)))
    slab, caps, _g = roof("roof", w, w, top + 0.25, 2.2, overhang=0.35, hip=True)
    metal.append(d.cyl("finial_post", 0.06, 0.9, (0, 0, top + 2.8), vertices=6))
    metal.append(kit.box("finial_cross", (0.5, 0.06, 0.06), (0, 0, top + 3.0)))
    trims.append(kit.rock("finial_ball", 0.16, (0, 0, top + 2.5), subdivisions=2))
    return [(kit.join(walls, "wall"), render("siracusa_bell_tower_wall_p", "c8ac80", seed, brick_share=0.06), "wall"),
            (kit.join(trims, "trim"), stone("siracusa_bell_tower_trim_p", seed, "b8a888"), "trim"),
            (kit.join([slab] + caps, "roof"), tiles("siracusa_bell_tower_roof_p", seed), "roof"),
            (kit.join(doors, "door"), wood("siracusa_bell_tower_door_p", seed), "door"),
            (kit.join(metal, "metal"), gold("siracusa_bell_tower_metal_p", seed), "metal"),
            (kit.join(glass_parts, "glass"), glass("siracusa_bell_tower_glass_p", seed), "glass"),
            (kit.join(glow, "glow"), lit("siracusa_bell_tower_glow_p"), "glow")]


def _cut(obj, cutters):
    """obj minus the cutters (boolean difference), the cutters removed."""
    for c in cutters:
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        mod = obj.modifiers.new("cut", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = c
        mod.solver = "EXACT"
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(c)
    return obj


def siracusa_arch_house(seed=943):
    """拱门过街楼: a house over the lane, the lane through a round stone arch
    under it. The arch is 6 m wide along x between piers that go 0.8 m into
    the houses either side (origin on the ground at its middle; stretched
    along x in the game), 4 m deep along y, its crown at 4 m; two storeys
    of rendered house over it, shuttered windows on both faces (-Y, +Y), a
    gabled tile roof along x; a stone ring of voussoirs and a keystone on
    each face, a lamp under the crown."""
    random.seed(seed)
    opening, pier, depth = 6.0, 0.8, 4.0
    length = opening + pier * 2
    arch_top = 4.4
    block = kit.box("block", (length, depth, arch_top), (0, 0, arch_top * 0.5))
    vault = d.cyl("vault_cut", opening * 0.5, depth + 1.0, (0, 0, 1.0), (math.pi / 2, 0, 0), vertices=24)
    legs = kit.box("legs_cut", (opening, depth + 1.0, 2.0), (0, 0, 0.0))
    _cut(block, [vault, legs])
    floors, floor_h = 2, 3.2
    upper = d.bbox("upper", (length, depth + 0.3, floors * floor_h), (0, 0, arch_top + floors * floor_h * 0.5), width=0.03)
    walls = [block, upper]
    trims = [kit.box("course", (length + 0.1, depth + 0.4, 0.2), (0, 0, arch_top)),
             kit.box("cornice", (length + 0.3, depth + 0.6, 0.22), (0, 0, arch_top + floors * floor_h - 0.05))]
    glow, glass_parts, shutters, irons = [], [], [], []
    for sy in (-1, 1):
        y = sy * (depth * 0.5 + 0.02)
        # Voussoirs round the arch, the keystone at its crown.
        for n in range(13):
            a = math.pi * n / 12
            x, z = math.cos(a) * (opening * 0.5 + 0.22), 1.0 + math.sin(a) * (opening * 0.5 + 0.22)
            trims.append(kit.box(f"vs{sy}_{n}", (0.5, 0.12, 0.3), (x, y + sy * 0.04, z), (0, -(a - math.pi / 2), 0)))
        trims.append(kit.box(f"key{sy}", (0.45, 0.18, 0.6), (0, y + sy * 0.06, 4.15)))
        # The upper floors' windows, three a floor, shuttered.
        place = lambda u, o, z, sy=sy: (u, sy * (depth * 0.5 + 0.15) + sy * o, z)
        for f in range(floors):
            z = arch_top + f * floor_h + floor_h * 0.55
            for k in (-1, 0, 1):
                u = k * length * 0.3
                pane = kit.box(f"w{sy}{f}{k}", (0.85, 0.05, 1.5), place(u, 0.02, z))
                (glow if random.random() < 0.35 else glass_parts).append(pane)
                trims.append(kit.box(f"sill{sy}{f}{k}", (1.2, 0.18, 0.1), place(u, 0.08, z - 0.8)))
                trims.append(kit.box(f"lint{sy}{f}{k}", (1.15, 0.12, 0.16), place(u, 0.05, z + 0.83)))
                for s2 in (-1, 1):
                    shutters.append(kit.box(f"sh{sy}{f}{k}{s2}", (0.42, 0.06, 1.5), place(u + s2 * 0.64, 0.04, z)))
        # A lamp bracket under the crown.
        irons.append(kit.box(f"arm{sy}", (0.05, 0.5, 0.05), (0, sy * (depth * 0.5 - 0.6), 3.55)))
    irons.append(kit.box("lamp_cap", (0.26, 0.26, 0.08), (0, 0, 3.5)))
    glow.append(kit.box("lamp", (0.2, 0.2, 0.36), (0, 0, 3.25)))
    slab, caps, gables = roof("roof", length, depth + 0.3, arch_top + floors * floor_h + 0.1, 1.5, overhang=0.4, hip=False, ridge_axis="x")
    walls += gables
    return [(kit.join(walls, "wall"), render("siracusa_arch_house_wall_p", "cfb088", seed, brick_share=0.1), "wall"),
            (kit.join(trims, "trim"), stone("siracusa_arch_house_trim_p", seed, "b4a68a"), "trim"),
            (kit.join([slab] + caps, "roof"), tiles("siracusa_arch_house_roof_p", seed), "roof"),
            (kit.join(shutters, "shutters"), shutter_wood("siracusa_arch_house_shutters_p", seed, "35503a"), "shutters"),
            (kit.join(glass_parts, "glass"), glass("siracusa_arch_house_glass_p", seed), "glass"),
            (kit.join(irons, "iron"), iron("siracusa_arch_house_iron_p", seed), "iron"),
            (kit.join(glow, "glow"), lit("siracusa_arch_house_glow_p"), "glow")]


HOUSES = [siracusa_house_a, siracusa_house_b, siracusa_house_c, siracusa_house_d, siracusa_house_low, siracusa_ruin]
PIECES = [siracusa_theatre, siracusa_court, siracusa_fountain, siracusa_lantern, siracusa_banner_saluzzo,
          siracusa_banner_rossetti, siracusa_banner_bellone, siracusa_barrels, siracusa_garden_wall, siracusa_mansion_gate,
          siracusa_bell_tower, siracusa_arch_house]
BUILDERS = HOUSES + PIECES
PREVIEW = {"siracusa_house_a": 12.0, "siracusa_house_b": 13.0, "siracusa_house_c": 14.0, "siracusa_house_d": 13.0,
           "siracusa_house_low": 9.0, "siracusa_ruin": 13.0, "siracusa_theatre": 18.0, "siracusa_court": 16.0,
           "siracusa_fountain": 5.0, "siracusa_lantern": 1.6, "siracusa_banner_saluzzo": 5.0, "siracusa_banner_rossetti": 5.0,
           "siracusa_banner_bellone": 5.0, "siracusa_barrels": 2.6, "siracusa_garden_wall": 3.0,
           "siracusa_mansion_gate": 10.0, "siracusa_bell_tower": 22.0, "siracusa_arch_house": 13.0}
BAKE_SIZE = {"wall": 1024, "roof": 1024, "trim": 1024, "shutters": 512, "glow": 128, "glass": 256, "door": 256, "iron": 256,
             "columns": 512, "metal": 256, "stone": 512, "water": 128, "cloth": 256, "fringe": 128, "wood": 256, "planks": 256,
             "pots": 128, "plants": 256}


def publish(name, parts):
    city.BAKE_SIZE.update(BAKE_SIZE)
    city.PREVIEW.update(PREVIEW)
    return city.publish(name, parts)


def new_scene(name):
    """For the MCP build: a fresh scene in the open Blender, made the window's."""
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    return scene


def build(name, export=True):
    builder = next(b for b in BUILDERS if b.__name__ == name)
    new_scene(name)
    parts = builder()
    if not export:
        return parts
    return publish(name, parts)


if __name__ == "__main__":
    for builder in BUILDERS:
        kit.reset_scene()
        publish(builder.__name__, builder())
