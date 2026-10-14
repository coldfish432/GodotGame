"""Point-of-interest models (搜索点): art/kit/poi_*.glb.

One model per searchable kind in game/loot_tables.gd POI, plus the vault
chest and the mine's context variants (兴趣点策划案_v1.md): a variant is the
same kind, with the same loot, dressed for where the map put it.

Sizes follow the rule from the research (塔科夫: the bigger the container, the
bigger what can come out of it): weapon crates are long, safes heavy, the
vault chest the largest; toolboxes and packs small. Every kind keeps a
silhouette of its own so it reads from the follow camera before the label.

Origin at the bottom centre, Blender Z up, metres, front towards Blender -Y
(Godot +Z, the camera side). Textures are baked from procedural materials
for now; the hand-painted set is asked of Sol in 兴趣点贴图美术需求_v1.md.

Run: blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_poi.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
from build_mine_accents import rust_material, wood_material  # noqa: E402
from build_mine_cliff import rock_material  # noqa: E402


def _ramp_material(name, stops, scale, seed, detail=6.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 1.3, seed * 2.1, seed * 0.4)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    elements = ramp.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], kit.srgb(stops[0][1])
    elements[1].position, elements[1].color = stops[-1][0], kit.srgb(stops[-1][1])
    for position, colour in stops[1:-1]:
        elements.new(position).color = kit.srgb(colour)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], kit.principled(nodes).inputs["Base Color"])
    return mat


def olive(name, seed):
    return _ramp_material(name, [(0.35, "3a3f2c"), (0.6, "555c40"), (0.85, "6f7856")], 5.0, seed, 4.0)


def steel(name, seed, base="5d6266"):
    return _ramp_material(name, [(0.3, "33373b"), (0.6, base), (0.9, "858b90")], 6.0, seed, 5.0)


def painted(name, hex_rgb, seed):
    """Chipped paint: the colour, with worn spots down to dark metal."""
    return _ramp_material(name, [(0.25, "2c2c2e"), (0.36, hex_rgb), (1.0, hex_rgb)], 7.0, seed, 8.0)


def cloth(name, seed, base="6a5a3e"):
    return _ramp_material(name, [(0.3, "3a3022"), (0.65, base), (0.95, "8a7656")], 9.0, seed, 3.0)


def crystal(name, seed):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Generated"], xyz.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, kit.srgb("6a2c0a")
    e[1].position, e[1].color = 1.0, kit.srgb("ffd36a")
    e.new(0.55).color = kit.srgb("e2781c")
    links.new(xyz.outputs["Z"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], kit.principled(nodes).inputs["Base Color"])
    return mat


def _wood(parts, seed):
    for i, part in enumerate(parts):
        kit.roughen(part, seed + i, strength=0.006, size=0.1, bevel=0.012, subdiv=1)
    return parts


def _crystal_shard(name, length, radius, location, tilt):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius, radius2=radius * 0.55, depth=length * 0.78, location=(0, 0, length * 0.39))
    shaft = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius * 0.55, radius2=0.0, depth=length * 0.22, location=(0, 0, length * 0.89))
    tip = bpy.context.object
    obj = kit.join([shaft, tip], name)
    obj.rotation_euler = (tilt[0], tilt[1], tilt[2])
    obj.location = location
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


_publish = kit.publish_parts


def _settled_publish(pieces, name, preview_scale=4.2, resolution=512):
    """Every POI stands centred on its origin with its foot on the ground, and
    no part over 6000 triangles: recentre the parts together, lift them to
    z = 0, decimate the heavy ones, then bake and export."""
    objects = [obj for obj, _mat, _part in pieces]
    xs, ys, zs = [], [], []
    for obj in objects:
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            xs.append(w.x)
            ys.append(w.y)
            zs.append(w.z)
    shift = ((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, min(zs))
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        for v in obj.data.vertices:
            v.co.x -= shift[0]
            v.co.y -= shift[1]
            v.co.z -= shift[2]
        obj.data.update()
        if kit.triangle_count(obj) > 6000:
            kit.decimate(obj, 6000)
    return _publish(pieces, name, preview_scale, resolution)


kit.publish_parts = _settled_publish


# --- base kinds (v2: finer, 2026-10-12) ----------------------------------------
import poi_detail as d  # noqa: E402


def _wear_wood(name, seed):
    return d.worn(wood_material(name, seed), edge="a0825e", edge_strength=0.35, grime="140f0a", grime_strength=0.45)


def _wear_paint(name, hex_rgb, seed, edge="9a9a96"):
    return d.worn(painted(name, hex_rgb, seed), edge=edge, edge_strength=0.6, grime="16140f", grime_strength=0.4)


def _wear_steel(name, seed, base="5d6266"):
    return d.worn(steel(name, seed, base), edge="b8bcbf", edge_strength=0.5, grime="1c1a17", grime_strength=0.35)


def _wear_rust(name, seed):
    return d.worn(rust_material(name, seed), edge="8a8784", edge_strength=0.4, grime="1a120c", grime_strength=0.4)


def weapon_box(seed):
    """武器箱: a long military crate in olive paint, planked, on skids, with
    rope handles, four toggle latches, a hinged lid and a stencil band."""
    kit.reset_scene()
    shell = kit.join(d.plank_box("c", (1.45, 0.56, 0.4), (0, 0, 0.3), plank=0.1), "shell")
    lid = kit.join(d.plank_box("l", (1.5, 0.6, 0.07), (0, 0, 0.535), plank=0.12, battens=False), "lid")
    skids = kit.join(_wood([d.bbox(f"skid{x}", (0.1, 0.64, 0.09), (x, 0, 0.045)) for x in (-0.55, 0, 0.55)], seed), "skids")
    crate = kit.join([shell, lid], "crate")
    metal = []
    for i, x in enumerate((-0.55, -0.2, 0.2, 0.55)):
        metal += d.latch(f"lt{i}", (x, -0.31, 0.47))
    for x in (-0.45, 0.45):
        metal += d.hinge(f"hg{x}", (x, 0.3, 0.52), 0.14)
    for x in (-0.76, 0.76):
        metal += d.handle(f"hd{x}", (x, 0, 0.35), 0.16, face_axis="x", face_sign=1.0 if x > 0 else -1.0)
    corners = [d.bbox(f"cn{ex}{ey}{ez}", (0.07, 0.07, 0.07), (ex * 0.72, ey * 0.27, 0.1 + ez * 0.4), width=0.008)
               for ex in (-1, 1) for ey in (-1, 1) for ez in (0, 1)]
    iron = kit.join(metal + corners, "iron")
    band = kit.box("stencil", (0.56, 0.004, 0.13), (0, -0.287, 0.3))
    arrows = kit.join([kit.box(f"ar{i}", (0.05, 0.004, 0.05), (x, -0.289, 0.3), (0, math.radians(45), 0)) for i, x in enumerate((-0.4, 0.4))], "arrows")
    kit.publish_parts([(crate, d.worn(olive("poi_weapon_box_shell_p", seed), edge="8a8a6a", edge_strength=0.6, grime="14140c"), "shell"),
                       (skids, _wear_wood("poi_weapon_box_skid_p", seed), "skid"),
                       (iron, _wear_steel("poi_weapon_box_iron_p", seed, "3e4246"), "iron"),
                       (band, kit.flat_material("poi_weapon_box_band_p", "d9c27a", 30.0, "a8925a"), "band"),
                       (arrows, kit.flat_material("poi_weapon_box_arrow_p", "1e1e1a"), "arrow")], "poi_weapon_box", 2.2, 1024)


def armor_box(seed):
    """护具箱: a blue hard case, rounded, ribbed, with hinges, two clasps, a
    carry handle and corner bumpers, strapped onto a pallet."""
    kit.reset_scene()
    pallet = kit.join(_wood([d.bbox(f"plank{y}", (1.05, 0.16, 0.035), (0, y, 0.11), width=0.006) for y in (-0.3, -0.1, 0.1, 0.3)] +
                            [d.bbox(f"block{x}{y}", (0.1, 0.1, 0.09), (x, y, 0.045), width=0.008) for x in (-0.42, 0, 0.42) for y in (-0.3, 0.3)] +
                            [d.bbox(f"stringer{x}", (0.1, 0.78, 0.03), (x, 0, 0.1), width=0.005) for x in (-0.42, 0, 0.42)], seed), "pallet")
    lower = d.bevel(kit.box("lower", (0.9, 0.6, 0.27), (0, 0, 0.27)), 0.05, 4)
    upper = d.bevel(kit.box("upper", (0.9, 0.6, 0.15), (0, 0, 0.47)), 0.05, 4)
    ribs = [d.bevel(kit.box(f"rib{x}", (0.05, 0.62, 0.43), (x, 0, 0.34)), 0.02, 2) for x in (-0.3, 0, 0.3)]
    seam = kit.box("seam", (0.92, 0.62, 0.012), (0, 0, 0.405))
    shell = kit.join([lower, upper, seam] + ribs, "shell")
    bumpers = kit.join([d.bevel(kit.box(f"bump{ex}{ey}", (0.1, 0.1, 0.44), (ex * 0.43, ey * 0.28, 0.34)), 0.03, 3) for ex in (-1, 1) for ey in (-1, 1)], "bumpers")
    metal = []
    for x in (-0.18, 0.18):
        metal += d.latch(f"cl{x}", (x, -0.31, 0.41))
    for x in (-0.3, 0.3):
        metal += d.hinge(f"hg{x}", (x, 0.31, 0.41), 0.12)
    metal += d.handle("carry", (0, 0, 0.56), 0.24, face_sign=1.0, face_axis="y")
    clasps = kit.join(metal, "clasps")
    strap = kit.join([kit.box(f"strap{x}", (0.05, 0.64, 0.5), (x, 0, 0.36)) for x in (-0.15, 0.15)], "strap")
    label = kit.box("label", (0.22, 0.004, 0.1), (0.2, -0.302, 0.27))
    kit.publish_parts([(pallet, _wear_wood("poi_armor_box_pallet_p", seed), "pallet"),
                       (shell, _wear_paint("poi_armor_box_shell_p", "3f5a75", seed, "8aa0b4"), "shell"),
                       (bumpers, kit.flat_material("poi_armor_box_bump_p", "222428", 20.0, "35383d"), "bumper"),
                       (clasps, _wear_steel("poi_armor_box_clasp_p", seed), "clasp"),
                       (strap, cloth("poi_armor_box_strap_p", seed, "2c2a24"), "strap"),
                       (label, kit.flat_material("poi_armor_box_label_p", "d8d4c4", 40.0, "a8a494"), "label")], "poi_armor_box", 1.8, 1024)


def tool_box(seed):
    """工具箱: a red cantilever toolbox with its trays fanned open, tools in
    them, on an upturned planked crate, a spanner and hammer beside."""
    kit.reset_scene()
    crate = kit.join(d.plank_box("cr", (0.75, 0.55, 0.45), (0, 0, 0.225), plank=0.11, battens=False), "crate")
    box = d.bbox("box", (0.6, 0.3, 0.24), (0, 0, 0.57), width=0.015)
    trays = [d.bbox(f"tray{i}", (0.56, 0.13, 0.06), (0.04 + i * 0.05, (-0.09 if i == 0 else 0.09), 0.72 + i * 0.05), (0, 0, 0), width=0.008) for i in range(2)]
    arms = [d.bbox(f"arm{s}{t}", (0.012, 0.02, 0.16), (s * 0.24, t * 0.12, 0.68), (0, 0.6 * s, 0), width=0.003) for s in (-1, 1) for t in (-1, 1)]
    red = kit.join([box] + trays, "red")
    metal = d.handle("hdl", (0, 0, 0.72), 0.24, face_sign=0.0) + arms
    metal += d.latch("lt", (0, -0.155, 0.6))
    tools = []
    tools.append(d.bbox("spanner", (0.34, 0.045, 0.016), (-0.12, -0.2, 0.458), (0, 0, 0.45), width=0.004))
    tools.append(d.cyl("spanner_end", 0.035, 0.016, (0.03, -0.12, 0.458), (0, 0, 0), 12))
    tools.append(d.bbox("hammer_head", (0.05, 0.14, 0.045), (0.26, -0.15, 0.475), width=0.006))
    tools.append(d.bbox("screwdriver", (0.18, 0.012, 0.012), (0.08, -0.08, 0.76), (0, 0, 0.2), width=0.002))
    steel_obj = kit.join(metal + tools, "metal")
    grips = kit.join([d.bbox("hammer_grip", (0.03, 0.03, 0.26), (0.26, -0.15, 0.36), (0, math.pi / 2, 0.3), width=0.008),
                      d.bbox("sd_grip", (0.07, 0.025, 0.025), (0.0, -0.1, 0.76), (0, 0, 0.2), width=0.006)], "grips")
    kit.publish_parts([(crate, _wear_wood("poi_tool_box_crate_p", seed), "crate"),
                       (red, _wear_paint("poi_tool_box_red_p", "a3302a", seed, "c8c0b8"), "red"),
                       (steel_obj, _wear_steel("poi_tool_box_metal_p", seed), "metal"),
                       (grips, kit.flat_material("poi_tool_box_grip_p", "d0a020", 20.0, "8a6a12"), "grip")], "poi_tool_box", 1.6, 1024)


def safe(seed):
    """保险柜: an old iron safe on cast feet: panelled sides, a thick door on
    two big hinges, a combination dial with its index plate, a spoked
    wheel handle, a brass name plate and rivets round the door."""
    kit.reset_scene()
    body = d.bevel(kit.box("body", (0.8, 0.72, 0.95), (0, 0, 0.545)), 0.04, 3)
    plinth = d.bbox("plinth", (0.86, 0.78, 0.05), (0, 0, 0.095), width=0.012)
    feet = [d.cyl(f"foot{x}{y}", 0.05, 0.07, (x, y, 0.035), vertices=10) for x in (-0.33, 0.33) for y in (-0.28, 0.28)]
    panels = [d.bbox(f"panel{s}", (0.012, 0.56, 0.72), (s * 0.405, 0, 0.55), width=0.006) for s in (-1, 1)]
    door = d.bevel(kit.box("door", (0.64, 0.05, 0.78), (0, -0.375, 0.545)), 0.02, 2)
    frame = d.bbox("frame", (0.7, 0.02, 0.84), (0, -0.36, 0.545), width=0.006)
    shell = kit.join([body, plinth, door, frame] + feet + panels, "shell")
    hinges = []
    for z in (0.3, 0.8):
        hinges.append(d.cyl(f"hinge{z}", 0.03, 0.12, (0.33, -0.39, z), vertices=12))
    iron = kit.join(hinges + d.rivets("rv", [(x, -0.402, z) for x in (-0.29, 0.29) for z in (0.2, 0.4, 0.6, 0.8, 0.9)] +
                                      [(x, -0.402, z) for x in (-0.15, 0.0, 0.15) for z in (0.17, 0.92)], 0.012), "iron")
    dial = d.cyl("dial", 0.085, 0.04, (0.1, -0.415, 0.7), (math.pi / 2, 0, 0), 24)
    dial_knob = d.cyl("dial_knob", 0.035, 0.05, (0.1, -0.44, 0.7), (math.pi / 2, 0, 0), 12)
    index = d.bbox("index", (0.03, 0.01, 0.03), (0.1, -0.405, 0.8), width=0.004)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.1, minor_radius=0.014, major_segments=20, minor_segments=6, location=(-0.12, -0.43, 0.5), rotation=(math.pi / 2, 0, 0))
    wheel = bpy.context.object
    spokes = [d.bbox(f"spoke{k}", (0.2, 0.014, 0.014), (-0.12, -0.43, 0.5), (0, k * math.pi / 3, 0), width=0.003) for k in range(3)]
    hub = d.cyl("hub", 0.03, 0.05, (-0.12, -0.425, 0.5), (math.pi / 2, 0, 0), 12)
    plate = d.bbox("plate", (0.26, 0.008, 0.07), (0, -0.402, 0.87), width=0.003)
    brass = kit.join([dial, dial_knob, index, wheel, hub, plate] + spokes, "brass")
    kit.publish_parts([(shell, _wear_paint("poi_safe_shell_p", "4d5a4c", seed, "8c8c84"), "shell"),
                       (iron, _wear_steel("poi_safe_iron_p", seed, "3a3d40"), "iron"),
                       (brass, d.worn(kit.flat_material("poi_safe_brass_p", "c8a24a", 9.0, "7a5f22"), edge="f0d890", edge_strength=0.5), "brass")], "poi_safe", 2.0, 1024)


def electronics(seed):
    """电子柜: a field electrical cabinet: door with a handle and hinges, louvres,
    a warning plate, a glowing meter panel with switches, a junction box on
    the side and a cable run into the floor."""
    kit.reset_scene()
    body = d.bbox("body", (0.85, 0.5, 1.4), (0, 0, 0.78), width=0.02)
    plinth = d.bbox("plinth", (0.95, 0.6, 0.08), (0, 0, 0.04), width=0.01)
    roof = d.bbox("roof", (0.95, 0.6, 0.04), (0, 0, 1.5), width=0.01)
    door_edge = d.bbox("door_edge", (0.78, 0.012, 1.3), (0, -0.256, 0.78), width=0.004)
    louvres = [d.bbox(f"louvre{i}", (0.55, 0.035, 0.025), (0, -0.27, 0.25 + i * 0.055), (math.radians(-30), 0, 0), width=0.004) for i in range(6)]
    jbox = d.bbox("jbox", (0.2, 0.3, 0.3), (0.53, 0, 0.5), width=0.01)
    shell = kit.join([body, plinth, roof, door_edge, jbox] + louvres, "shell")
    metal = d.handle("door_handle", (-0.3, -0.262, 0.85), 0.14, face_axis="y", face_sign=-1.0)
    for z in (0.3, 1.25):
        metal += d.hinge(f"hg{z}", (0.37, -0.262, z), 0.12, axis="z")
    switches = [d.bbox(f"sw{i}", (0.035, 0.03, 0.06), (-0.16 + i * 0.08, -0.27, 1.02), width=0.004) for i in range(5)]
    iron = kit.join(metal + switches, "iron")
    cable = d.cyl("cable", 0.035, 0.45, (0.53, 0.0, 0.18), vertices=10)
    conduit = d.cyl("conduit", 0.035, 0.7, (0.88, 0.0, 0.035), (0, math.pi / 2, 0), 10)
    elbow = d.bbox("elbow", 0.08, 0.08, (0.53, 0, 0.035)) if False else d.bbox("elbow", (0.08, 0.08, 0.08), (0.53, 0, 0.035), width=0.02)
    black = kit.join([cable, conduit, elbow], "black")
    sign = d.bbox("sign", (0.2, 0.006, 0.17), (0.2, -0.264, 0.6), (0, math.radians(45), 0), width=0.002)
    panel = d.bbox("panel", (0.36, 0.015, 0.2), (0.12, -0.265, 1.2), width=0.004)
    kit.publish_parts([(shell, _wear_paint("poi_electronics_shell_p", "6b7a6a", seed, "a8b0a4"), "shell"),
                       (iron, _wear_steel("poi_electronics_iron_p", seed, "2e3134"), "iron"),
                       (black, kit.flat_material("poi_electronics_cable_p", "1c1c1e", 20.0, "2a2a2e"), "cable"),
                       (sign, kit.flat_material("poi_electronics_sign_p", "e0b424", 30.0, "a8861a"), "sign"),
                       (panel, kit.flat_material("poi_electronics_glow_p", "8fffd0", 12.0, "3fbf90"), "glow")], "poi_electronics", 2.4, 1024)


def medical(seed):
    """医疗柜: a white enamel wall cabinet with a glass-panelled door, handle
    and hinges, a red cross, on a timber stand with a shelf of kits, a
    folded stretcher leaning on it."""
    kit.reset_scene()
    stand = _wood([d.bbox(f"leg{x}{y}", (0.07, 0.07, 1.4), (x, y, 0.7), width=0.008) for x in (-0.33, 0.33) for y in (-0.05, 0.15)] +
                  [d.bbox(f"shelf{z}", (0.78, 0.36, 0.035), (0, 0.05, z), width=0.006) for z in (0.25, 0.68)] +
                  [d.bbox("brace", (0.7, 0.03, 0.05), (0, 0.16, 0.45), (0, math.radians(32), 0), width=0.005)], seed)
    stretcher = _wood([d.bbox(f"pole{x}", (0.04, 0.04, 1.3), (x, -0.26, 0.62), (math.radians(14), 0, 0), width=0.008) for x in (-0.22, 0.22)], seed + 9)
    wood = kit.join(stand + stretcher, "wood")
    cabinet = d.bevel(kit.box("cabinet", (0.7, 0.3, 0.55), (0, 0, 1.0)), 0.02, 3)
    door = d.bbox("door", (0.64, 0.02, 0.5), (0, -0.155, 1.0), width=0.006)
    kits = [d.bbox(f"kit{i}", (0.26, 0.2, 0.15), (x, 0.05, 0.345), (0, 0, z), width=0.02) for i, (x, z) in enumerate(((-0.18, 0.1), (0.16, -0.08)))]
    kits += [d.bbox("kit_top", (0.22, 0.18, 0.12), (0.0, 0.05, 0.76), (0, 0, 0.2), width=0.02)]
    white = kit.join([cabinet, door] + kits, "white")
    canvas_obj = d.bbox("canvas", (0.4, 0.02, 1.15), (0, -0.25, 0.62), (math.radians(14), 0, 0), width=0.004)
    metal = d.handle("dh", (-0.25, -0.17, 1.0), 0.1, face_axis="y", face_sign=-1.0)
    for z in (0.82, 1.18):
        metal += d.hinge(f"hg{z}", (0.32, -0.17, z), 0.08, axis="z")
    iron = kit.join(metal, "iron")
    glass = d.bbox("glass", (0.44, 0.01, 0.26), (0, -0.168, 1.07), width=0.002)
    cross = kit.join([kit.box("crossv", (0.06, 0.006, 0.2), (0, -0.172, 0.89)), kit.box("crossh", (0.2, 0.006, 0.06), (0, -0.172, 0.89))] +
                     [kit.box(f"kc{i}", (0.06, 0.006, 0.06), (x, -0.052, 0.345)) for i, x in enumerate((-0.18, 0.16))], "cross")
    kit.publish_parts([(wood, _wear_wood("poi_medical_wood_p", seed), "wood"),
                       (white, _wear_steel("poi_medical_white_p", seed, "c9cfd2"), "white"),
                       (canvas_obj, cloth("poi_medical_canvas_p", seed, "5c6448"), "canvas"),
                       (iron, _wear_steel("poi_medical_iron_p", seed, "4a4e52"), "iron"),
                       (glass, kit.flat_material("poi_medical_glass_p", "7f9aa8", 20.0, "5a6e78"), "glass"),
                       (cross, kit.flat_material("poi_medical_cross_p", "c42a2a"), "cross")], "poi_medical", 1.9, 1024)


def construction(seed):
    """建材堆: pit props stacked on bearers and wired, with sawn ends; cement
    sacks, a coil of wire, a bucket and a shovel stuck in a heap of sand."""
    kit.reset_scene()
    random.seed(seed)
    logs = []
    for layer in range(3):
        for i in range(4 - layer):
            r = random.uniform(0.085, 0.1)
            logs.append(d.cyl(f"log{layer}{i}", r, random.uniform(1.5, 1.7),
                              (random.uniform(-0.05, 0.05), (i - (3 - layer) / 2) * 0.2, 0.17 + layer * 0.17), (0, math.pi / 2, random.uniform(-0.04, 0.04)), 10))
    bearers = [d.bbox(f"bearer{x}", (0.1, 0.9, 0.08), (x, 0, 0.04), width=0.01) for x in (-0.55, 0.55)]
    wood = kit.join(_wood(logs + bearers, seed), "wood")
    ends = kit.join([d.cyl(f"end{layer}{i}", 0.088, 0.004, (0.79 + random.uniform(-0.04, 0.04), (i - (3 - layer) / 2) * 0.2, 0.17 + layer * 0.17), (0, math.pi / 2, 0), 10)
                     for layer in range(3) for i in range(4 - layer)], "ends")
    sacks = []
    for i, (x, y, z) in enumerate(((0.35, 0.72, 0.1), (0.78, 0.7, 0.1), (0.56, 0.7, 0.29))):
        sack = kit.box(f"sack{i}", (0.42, 0.3, 0.17), (x, y, z), (0, 0, random.uniform(-0.3, 0.3)))
        kit.roughen(sack, seed + 10 + i, strength=0.025, size=0.12, bevel=0.06, subdiv=2)
        sacks.append(sack)
    bags = kit.join(sacks, "bags")
    sand = kit.rock("sand", 0.42, (-0.65, 0.68, 0.0), (1.3, 1.0, 0.5))
    kit.roughen(sand, seed + 20, strength=0.04, size=0.2, subdiv=2)
    kit.clip_below(sand, 0.0)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.025, major_segments=18, minor_segments=5, location=(0.15, -0.6, 0.03))
    coil1 = bpy.context.object
    bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.025, major_segments=18, minor_segments=5, location=(0.15, -0.6, 0.075))
    coil2 = bpy.context.object
    bucket = d.cyl("bucket", 0.13, 0.26, (-0.15, -0.62, 0.13), vertices=16)
    for v in bucket.data.vertices:
        if v.co.z > 0: v.co.x *= 1.15; v.co.y *= 1.15
    blade = d.bbox("blade", (0.22, 0.02, 0.26), (-0.6, 0.55, 0.38), (math.radians(20), 0, 0), width=0.004)
    iron = kit.join([coil1, coil2, bucket, blade], "iron")
    shaft = d.cyl("shaft", 0.018, 0.9, (-0.6, 0.45, 0.8), (math.radians(20), 0, 0), 8)
    kit.publish_parts([(wood, _wear_wood("poi_construction_wood_p", seed), "wood"),
                       (ends, kit.flat_material("poi_construction_ends_p", "b08a5a", 25.0, "7a5a32"), "ends"),
                       (bags, cloth("poi_construction_bags_p", seed, "a59a83"), "bags"),
                       (sand, rock_material("poi_construction_sand_p", seed), "sand"),
                       (iron, _wear_rust("poi_construction_iron_p", seed), "iron"),
                       (shaft, wood_material("poi_construction_shaft_p", seed), "shaft")], "poi_construction", 2.6, 1024)


def ore_vein(seed):
    """源石矿脉: a split rock mound with Originium breaking out of the crack in
    clusters, small crystals around the foot, a pick left leaning on it."""
    kit.reset_scene()
    random.seed(seed)
    rocks = []
    for i in range(7):
        a = i * 0.9
        r = random.uniform(0.25, 0.48)
        stone = kit.rock(f"rock{i}", r, (math.cos(a) * 0.42, math.sin(a) * 0.42, r * 0.45), (1.2, 1.0, 0.75))
        kit.roughen(stone, seed + i, strength=0.08, size=0.22, subdiv=2, crack_strength=0.03)
        rocks.append(stone)
    rock_obj = kit.join(rocks, "rock")
    kit.clip_below(rock_obj, 0.0)
    kit.decimate(rock_obj, 3000)
    shards = []
    for c, (cx, cy, scale) in enumerate(((0.0, 0.0, 1.0), (0.32, 0.2, 0.6), (-0.3, 0.25, 0.55), (0.1, -0.4, 0.45))):
        for i in range(random.randint(4, 6)):
            shards.append(_crystal_shard(f"shard{c}{i}", random.uniform(0.5, 1.2) * scale, random.uniform(0.06, 0.12) * max(scale, 0.6),
                                         (cx + random.uniform(-0.1, 0.1), cy + random.uniform(-0.1, 0.1), 0.25 * scale + 0.05),
                                         (random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5), random.uniform(0, math.pi))))
    glow = kit.join(shards, "shards")
    pick = kit.join([d.bbox("pick_head", (0.36, 0.035, 0.05), (0.62, -0.3, 0.62), (0, 0.3, 0.6), width=0.006)], "pick_head")
    handle_obj = d.cyl("pick_handle", 0.02, 0.75, (0.6, -0.32, 0.35), (0.25, 0.35, 0), 8)
    kit.publish_parts([(rock_obj, rock_material("poi_ore_vein_rock_p", seed), "rock"),
                       (pick, _wear_rust("poi_ore_vein_pick_p", seed), "pick"),
                       (handle_obj, wood_material("poi_ore_vein_handle_p", seed), "handle"),
                       (glow, crystal("poi_ore_vein_glow_p", seed), "glow")], "poi_ore_vein", 2.2, 1024)


def vault_chest(seed):
    """密室宝箱: the biggest container. A planked chest with a barrel lid, iron
    bands with rivets, corner caps, a hasp with a heavy gold padlock, ring
    handles at the ends, on a low plinth."""
    kit.reset_scene()
    body = kit.join(d.plank_box("vb", (1.25, 0.78, 0.6), (0, 0, 0.36), plank=0.12, battens=False), "body")
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.39, depth=1.25, location=(0, 0, 0), rotation=(0, math.pi / 2, 0))
    lid = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for v in lid.data.vertices:
        if v.co.z < 0: v.co.z = 0.0
    lid.location = (0, 0, 0.66)
    bpy.ops.object.transform_apply(location=True)
    plinth = d.bbox("plinth", (1.35, 0.88, 0.06), (0, 0, 0.03), width=0.01)
    wood = kit.join(_wood([lid], seed) + [body, plinth], "wood")
    bands = []
    for x in (-0.5, 0, 0.5):
        bands.append(d.bbox(f"bandb{x}", (0.07, 0.8, 0.62), (x, 0, 0.36), width=0.006))
        bpy.ops.mesh.primitive_torus_add(major_radius=0.395, minor_radius=0.025, major_segments=24, minor_segments=4, location=(x, 0, 0.66), rotation=(0, math.pi / 2, 0))
        arc = bpy.context.object
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bands.append(arc)
    caps = [d.bbox(f"cap{ex}{ey}", (0.08, 0.08, 0.62), (ex * 0.6, ey * 0.37, 0.36), width=0.01) for ex in (-1, 1) for ey in (-1, 1)]
    ring_parts = []
    for x in (-0.64, 0.64):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.012, major_segments=14, minor_segments=4, location=(x, 0, 0.45), rotation=(0, math.pi / 2, 0))
        ring_parts.append(bpy.context.object)
    rivet_pts = [(x, -0.405, z) for x in (-0.5, 0, 0.5) for z in (0.12, 0.3, 0.48)]
    iron = kit.join(bands + caps + ring_parts + d.rivets("rv", rivet_pts, 0.014), "iron")
    hasp = d.bbox("hasp", (0.08, 0.02, 0.2), (0, -0.405, 0.62), width=0.004)
    body_lock = d.bbox("lock", (0.16, 0.06, 0.16), (0, -0.44, 0.5), width=0.015)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.05, minor_radius=0.014, major_segments=12, minor_segments=4, location=(0, -0.44, 0.6), rotation=(math.pi / 2, 0, 0))
    shackle = bpy.context.object
    gold = kit.join([hasp, body_lock, shackle], "gold")
    kit.publish_parts([(wood, _wear_wood("poi_vault_chest_wood_p", seed), "wood"),
                       (iron, _wear_steel("poi_vault_chest_iron_p", seed, "3a3d40"), "iron"),
                       (gold, d.worn(kit.flat_material("poi_vault_chest_gold_p", "e2b84a", 9.0, "8a6a22"), edge="fff0b0", edge_strength=0.6), "gold")], "poi_vault_chest", 2.4, 1024)


# --- mine context variants (same loot as their kind) ----------------------------

def ore_cart(seed):
    """翻倒的源石矿车 (ore_vein on a rail line): a riveted cart tipped on its
    side off a bent stretch of track, ore and crystal spilling out."""
    kit.reset_scene()
    random.seed(seed)
    iron = [d.bbox("floor", (1.2, 0.8, 0.05), (0, 0, 0.0), width=0.008)]
    for sx in (-1, 1):
        iron.append(d.bbox(f"end{sx}", (0.05, 0.8, 0.55), (sx * 0.58, 0, 0.27), width=0.008))
    iron.append(d.bbox("side", (1.2, 0.05, 0.55), (0, 0.38, 0.27), width=0.008))
    iron.append(d.bbox("rim", (1.24, 0.06, 0.05), (0, -0.38, 0.55), width=0.008))
    iron += [d.bbox(f"rib{x}", (0.04, 0.06, 0.55), (x, 0.4, 0.27), width=0.004) for x in (-0.3, 0, 0.3)]
    iron += d.rivets("rv", [(x, 0.415, z) for x in (-0.45, -0.15, 0.15, 0.45) for z in (0.1, 0.45)], 0.014)
    axles = []
    for sx in (-0.4, 0.4):
        iron.append(d.cyl(f"wheel{sx}", 0.16, 0.06, (sx, 0.45, -0.1), (math.pi / 2, 0, 0), 16))
        iron.append(d.cyl(f"hub{sx}", 0.05, 0.1, (sx, 0.47, -0.1), (math.pi / 2, 0, 0), 10))
    cart = kit.join(iron, "cart")
    cart.rotation_euler = (math.radians(-80), 0, math.radians(6))
    cart.location = (0, 0.15, 0.42)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    track = [d.bbox(f"rail{y}", (1.8, 0.05, 0.07), (0.1, y, 0.035), (0, 0, 0.08 * (1 if y > 0 else -1)), width=0.006) for y in (0.55, 1.0)]
    sleepers = _wood([d.bbox(f"sl{x}", (0.18, 0.75, 0.07), (x, 0.78, 0.0), (0, 0, random.uniform(-0.1, 0.1)), width=0.008) for x in (-0.6, -0.1, 0.4, 0.9)], seed)
    rails = kit.join(track, "rails")
    sleeper_obj = kit.join(sleepers, "sleepers")
    kit.clip_below(sleeper_obj, 0.0)
    ore = [kit.rock(f"ore{i}", random.uniform(0.07, 0.18), (random.uniform(-0.6, 0.6), random.uniform(-0.8, -0.15), 0.06), (1.2, 1.0, 0.7), subdivisions=2) for i in range(14)]
    for i, stone in enumerate(ore):
        kit.roughen(stone, seed + i, strength=0.03, size=0.1, subdiv=1)
    ore_obj = kit.join(ore, "ore")
    kit.clip_below(ore_obj, 0.0)
    kit.decimate(ore_obj, 2500)
    shards = [_crystal_shard(f"s{i}", random.uniform(0.2, 0.5), random.uniform(0.04, 0.07), (random.uniform(-0.5, 0.5), random.uniform(-0.75, -0.15), 0.04),
                             (random.uniform(-0.7, 0.7), random.uniform(-0.7, 0.7), 0)) for i in range(9)]
    glow = kit.join(shards, "shards")
    kit.publish_parts([(cart, _wear_rust("poi_ore_cart_iron_p", seed), "iron"),
                       (rails, _wear_steel("poi_ore_cart_rail_p", seed, "4a4a4c"), "rail"),
                       (sleeper_obj, _wear_wood("poi_ore_cart_sleeper_p", seed), "sleeper"),
                       (ore_obj, rock_material("poi_ore_cart_ore_p", seed), "ore"),
                       (glow, crystal("poi_ore_cart_glow_p", seed), "glow")], "poi_ore_cart", 2.4, 1024)


def miner_locker(seed):
    """矿工储物柜 (tool_box under a frame or lamp): a dented two-door steel
    locker with vents, handles and a padlock hasp, a name card, a hard hat
    with its lamp on top and a coat hung on the side hook."""
    kit.reset_scene()
    body = d.bbox("body", (0.7, 0.45, 1.75), (0, 0, 0.9), width=0.015)
    plinth = d.bbox("plinth", (0.72, 0.47, 0.06), (0, 0, 0.03), width=0.008)
    doors = [d.bbox(f"door{s}", (0.335, 0.012, 1.6), (s * 0.172, -0.23, 0.93), width=0.004) for s in (-1, 1)]
    vents = [d.bbox(f"vent{s}{i}", (0.2, 0.012, 0.022), (s * 0.17, -0.24, 1.5 + i * 0.05), (math.radians(-25), 0, 0), width=0.003) for s in (-1, 1) for i in range(4)]
    dents = [kit.rock(f"dent{i}", 0.06, (x, -0.233, z), (1.0, 0.15, 1.2), subdivisions=1) for i, (x, z) in enumerate(((-0.2, 0.6), (0.15, 1.1)))]
    shell = kit.join([body, plinth] + doors + vents + dents, "shell")
    metal = []
    for s in (-1, 1):
        metal += d.handle(f"h{s}", (s * 0.04, -0.24, 1.0), 0.0, face_axis="y") if False else [d.bbox(f"h{s}", (0.02, 0.03, 0.16), (s * 0.05, -0.25, 1.0), width=0.005)]
    metal.append(d.bbox("hasp", (0.05, 0.02, 0.04), (0, -0.25, 1.12), width=0.004))
    metal.append(d.bbox("hook", (0.02, 0.08, 0.02), (0.37, 0, 1.55), width=0.004))
    iron = kit.join(metal, "iron")
    card = d.bbox("card", (0.1, 0.004, 0.06), (-0.17, -0.238, 1.38), width=0.001)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.16, location=(0.1, 0, 1.78))
    helmet = bpy.context.object
    for v in helmet.data.vertices:
        if v.co.z < 0.0: v.co.z = 0.0  # local: flat bottom of the dome
    brim = d.cyl("brim", 0.2, 0.015, (0.1, 0, 1.785), vertices=18)
    hat = kit.join([helmet, brim], "hat")
    lamp = d.cyl("lamp", 0.035, 0.04, (0.1, -0.16, 1.86), (math.pi / 2, 0, 0), 10)
    # A coat on the side hook: body and a sleeve, bevelled (roughen on a part
    # this thin displaced it off the model).
    coat = kit.join([d.bbox("coat", (0.08, 0.4, 0.75), (0.4, 0, 1.15), width=0.025),
                     d.bbox("sleeve", (0.07, 0.1, 0.5), (0.41, 0.17, 1.05), (0.15, 0, 0), width=0.02)], "coat")
    kit.publish_parts([(shell, _wear_paint("poi_miner_locker_shell_p", "56677a", seed, "a0aab4"), "shell"),
                       (iron, _wear_steel("poi_miner_locker_iron_p", seed), "iron"),
                       (card, kit.flat_material("poi_miner_locker_card_p", "e4dcc4", 40.0, "b0a890"), "card"),
                       (hat, _wear_paint("poi_miner_locker_helmet_p", "c49a2a", seed, "e0d0a0"), "helmet"),
                       (coat, cloth("poi_miner_locker_coat_p", seed, "4a5038"), "coat"),
                       (lamp, kit.flat_material("poi_miner_locker_glow_p", "fff0b0"), "glow")], "poi_miner_locker", 2.2, 1024)


def winch_box(seed):
    """绞车控制箱 (electronics by the headframe): a control box on a base with
    a big lever in a slotted quadrant, two glowing gauges, a row of buttons,
    a hazard-striped kick plate and a cable to the winch."""
    kit.reset_scene()
    body = d.bbox("body", (0.8, 0.55, 1.0), (0, 0, 0.6), width=0.02)
    base = d.bbox("base", (0.95, 0.7, 0.1), (0, 0, 0.05), width=0.012)
    hood = d.bbox("hood", (0.86, 0.3, 0.05), (0, -0.16, 1.12), (math.radians(-12), 0, 0), width=0.008)
    quadrant = d.bbox("quadrant", (0.06, 0.25, 0.25), (0.3, -0.26, 1.02), width=0.008)
    shell = kit.join([body, base, hood, quadrant], "shell")
    lever = kit.join([d.bbox("arm", (0.04, 0.04, 0.55), (0.3, -0.34, 1.25), (math.radians(25), 0, 0), width=0.006),
                      d.cyl("knob", 0.05, 0.08, (0.3, -0.46, 1.48), (0, math.pi / 2, 0), 12)], "lever")
    buttons = [d.cyl(f"btn{i}", 0.025, 0.03, (-0.25 + i * 0.08, -0.29, 0.72), (math.pi / 2, 0, 0), 10) for i in range(4)]
    btn = kit.join(buttons, "buttons")
    gauges = [d.cyl(f"g{x}", 0.07, 0.03, (x, -0.29, 0.92), (math.pi / 2, 0, 0), 18) for x in (-0.22, 0.0)]
    rims = [d.cyl(f"rim{x}", 0.08, 0.02, (x, -0.282, 0.92), (math.pi / 2, 0, 0), 18) for x in (-0.22, 0.0)]
    iron = kit.join(rims + d.rivets("rv", [(x, -0.282, z) for x in (-0.36, 0.36) for z in (0.2, 0.6, 1.0)], 0.012), "iron")
    glow = kit.join(gauges, "gauges")
    kick = kit.join(d.stripes("st", (0.8, 0.012, 0.1), (0, -0.286, 0.16), count=7), "stripes")
    cable = d.cyl("cable", 0.035, 0.8, (-0.45, 0.2, 0.05), (0, math.pi / 2, 0.4), 10)
    kit.publish_parts([(shell, _wear_paint("poi_winch_box_shell_p", "8a7a3a", seed, "c8b880"), "shell"),
                       (lever, _wear_paint("poi_winch_box_lever_p", "b8322a", seed, "e0a090"), "lever"),
                       (btn, kit.flat_material("poi_winch_box_btn_p", "30a040", 20.0, "1a6a26"), "buttons"),
                       (iron, _wear_steel("poi_winch_box_iron_p", seed), "iron"),
                       (kick, kit.flat_material("poi_winch_box_stripe_p", "1a1a1a"), "stripe"),
                       (cable, kit.flat_material("poi_winch_box_cable_p", "1c1c1e"), "cable"),
                       (glow, kit.flat_material("poi_winch_box_glow_p", "fff4c0", 12.0, "e0c070"), "glow")], "poi_winch_box", 2.0, 1024)


def miner_pack(seed):
    """遗留的矿工背包 (medical in a dead end): a canvas rucksack with straps,
    flap and side pockets, a bedroll tied on, a med pouch, a dented canteen
    and a burnt-out lamp, left on a rock."""
    kit.reset_scene()
    random.seed(seed)
    stone = kit.rock("stone", 0.35, (0.15, 0.1, 0.12), (1.4, 1.1, 0.6))
    kit.roughen(stone, seed, strength=0.05, size=0.2, subdiv=2)
    kit.clip_below(stone, 0.0)
    kit.decimate(stone, 1200)
    pack = kit.box("pack", (0.42, 0.28, 0.55), (-0.25, -0.05, 0.3), (0.2, 0, 0.3))
    kit.roughen(pack, seed + 1, strength=0.02, size=0.12, bevel=0.07, subdiv=2)
    flap = kit.box("flap", (0.44, 0.2, 0.06), (-0.22, -0.1, 0.58), (0.5, 0, 0.3))
    kit.roughen(flap, seed + 2, strength=0.015, size=0.1, bevel=0.03, subdiv=2)
    pockets = [kit.box(f"pocket{s}", (0.08, 0.18, 0.2), (-0.25 + s * 0.24, -0.05, 0.25), (0.2, 0, 0.3)) for s in (-1, 1)]
    for p in pockets: kit.roughen(p, seed + 3, strength=0.01, size=0.1, bevel=0.03, subdiv=1)
    roll = d.cyl("roll", 0.11, 0.62, (0.22, 0.08, 0.36), (0, math.pi / 2, 0.4), 16)
    canvas = kit.join([pack, flap, roll] + pockets, "canvas")
    kit.decimate(canvas, 2500)
    straps = kit.join([kit.box(f"strap{i}", (0.04, 0.3, 0.5), (-0.28 + i * 0.12, -0.05, 0.32), (0.2, 0, 0.3)) for i in range(2)] +
                      [d.cyl(f"tie{i}", 0.115, 0.03, (0.22 + (i - 0.5) * 0.4 * math.cos(0.4), 0.08 + (i - 0.5) * 0.4 * math.sin(0.4), 0.36), (0, math.pi / 2, 0.4), 16) for i in range(2)], "straps")
    pouch = d.bbox("pouch", (0.2, 0.08, 0.15), (-0.2, -0.24, 0.32), (0.2, 0, 0.3), width=0.02)
    cross = kit.join([kit.box("cv", (0.03, 0.006, 0.1), (-0.2, -0.285, 0.32)), kit.box("ch", (0.1, 0.006, 0.03), (-0.2, -0.285, 0.32))], "cross")
    canteen = d.cyl("canteen", 0.08, 0.06, (0.45, -0.25, 0.08), (math.pi / 2, 0, 0.3), 16)
    lamp = kit.join([d.cyl("lamp_body", 0.06, 0.18, (0.05, -0.32, 0.09), vertices=12), d.bbox("lamp_top", (0.08, 0.08, 0.03), (0.05, -0.32, 0.2), width=0.005)], "lamp")
    metal = kit.join([canteen, lamp], "metal")
    kit.publish_parts([(stone, rock_material("poi_miner_pack_stone_p", seed), "stone"),
                       (canvas, cloth("poi_miner_pack_canvas_p", seed, "6b6142"), "canvas"),
                       (straps, cloth("poi_miner_pack_strap_p", seed, "3a2e1e"), "strap"),
                       (pouch, kit.flat_material("poi_miner_pack_pouch_p", "d8d8d0", 30.0, "a8a8a0"), "pouch"),
                       (cross, kit.flat_material("poi_miner_pack_cross_p", "c42a2a"), "cross"),
                       (metal, _wear_rust("poi_miner_pack_metal_p", seed), "metal")], "poi_miner_pack", 1.6, 1024)


if __name__ == "__main__":
    weapon_box(301)
    armor_box(303)
    tool_box(305)
    safe(307)
    electronics(309)
    medical(311)
    construction(313)
    ore_vein(315)
    vault_chest(317)
    ore_cart(321)
    miner_locker(323)
    winch_box(325)
    miner_pack(327)
