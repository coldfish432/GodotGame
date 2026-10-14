"""Encounter set pieces (NPC_brief_v3.md Part C): art/kit/enc_*.glb.

- enc_squad_post: the Rhodes squad's field post. Two stacked grey-white hard
  cases with cyan latch lights, a field terminal on a tripod, a pole with a
  black Rhodes pennant, a ground tarp.
- enc_trader_stall: 坎诺特's stall. A two-wheeled hand cart under a patched
  canvas cover, crates and tied bundles, a worn rug with wrapped goods, a
  hanging lantern in trader gold. No signs, prices or coins.

The NPC sprites stand in front of them, so each piece keeps its front
(Blender -Y, the camera side) low and open in the middle.

Textures are Sol's painted swatches (art/kit/textures/painted/encounter/),
projected (box mapping, 1 swatch per SWATCH_M metres) and baked with AO to one
image per part, as the POI models are. Timber and iron reuse the procedural
materials until the terrain swatches T4/T5 arrive. A part named "glow" is
drawn self-lit in the game.

Origin at the bottom centre, Blender Z up, metres, front towards Blender -Y.

Built through the Blender MCP add-on into the open Blender, one new scene per
piece (build_squad_post / build_trader_stall, then publish), or headless:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_encounter.py
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

PAINTED = os.path.join(kit.OUT_DIR, "textures", "painted", "encounter")
SWATCH_M = 0.8


def _image(file):
    path = os.path.join(PAINTED, file)
    for image in bpy.data.images:
        if image.filepath and os.path.normpath(bpy.path.abspath(image.filepath)) == os.path.normpath(path):
            return image
    return bpy.data.images.load(path)


def swatch(name, file, metres=SWATCH_M, edge=None, grime_strength=0.3):
    """A painted swatch, box-projected in object space, with light edge wear
    and grime in the hollows (baked with the AO)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0 / metres,) * 3
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = _image(file)
    tex.projection = "BOX"
    tex.projection_blend = 0.15
    tex.interpolation = "Closest"
    links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], kit.principled(nodes).inputs["Base Color"])
    if edge is not None:
        d.worn(mat, edge=edge, edge_strength=0.3, grime="15130f", grime_strength=grime_strength)
    return mat


def decal(name, under_hex, file="rhodes_logo_decal.png", face="y"):
    """The logo on a thin plate: the image over `under_hex` by its alpha,
    mapped once across the plate's front face (x and z of its bounds)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Generated"], xyz.inputs["Vector"])
    uv = nodes.new("ShaderNodeCombineXYZ")
    links.new(xyz.outputs["X"], uv.inputs["X"])
    links.new(xyz.outputs["Z"], uv.inputs["Y"])
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = _image(file)
    tex.interpolation = "Closest"
    tex.extension = "CLIP"
    links.new(uv.outputs["Vector"], tex.inputs["Vector"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = kit.srgb(under_hex)
    links.new(tex.outputs["Alpha"], mix.inputs["Factor"])
    links.new(tex.outputs["Color"], mix.inputs["B"])
    links.new(mix.outputs["Result"], kit.principled(nodes).inputs["Base Color"])
    return mat


def _steel(name, seed):
    from build_poi import steel
    return d.worn(steel(name, seed, "3e4246"), edge="b8bcbf", edge_strength=0.5, grime="1c1a17", grime_strength=0.35)


def _wood(name, seed):
    return d.worn(wood_material(name, seed), edge="a0825e", edge_strength=0.35, grime="140f0a", grime_strength=0.45)


def _apply(obj):
    """Bake the object's transform into its vertices (they are then world)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def _cloth_sheet(name, size, location, seed, sag=0.0, rotation=(0, 0, 0)):
    """A thin, lightly crumpled cloth sheet."""
    obj = kit.box(name, size, location, rotation)
    kit.roughen(obj, seed, strength=0.012 + sag, size=0.25, subdiv=3)
    return _apply(obj)


def _hard_case(prefix, size, location, yaw=0.0):
    """A Rhodes hard case: rounded shell with a lid seam, two latch lights on
    the front, a carry handle, corner bumpers. Returns (shell, lights, metal)."""
    sx, sy, sz = size
    x, y, z = location
    shell = d.bevel(kit.box(f"{prefix}shell", size, (x, y, z + sz / 2)), min(0.045, sz * 0.15), 4)
    seam = kit.box(f"{prefix}seam", (sx + 0.012, sy + 0.012, 0.012), (x, y, z + sz * 0.68))
    ribs = [d.bevel(kit.box(f"{prefix}rib{i}", (0.04, sy + 0.016, sz * 0.9), (x + s * sx * 0.32, y, z + sz / 2)), 0.012, 2)
            for i, s in enumerate((-1, 1))]
    shell = kit.join([shell, seam] + ribs, f"{prefix}case")
    lights = [kit.box(f"{prefix}lamp{i}", (0.09, 0.012, 0.022), (x + s * sx * 0.18, y - sy / 2 - 0.004, z + sz * 0.68))
              for i, s in enumerate((-1, 1))]
    metal = d.handle(f"{prefix}hdl", (x, y, z + sz + 0.02), min(0.26, sx * 0.4), face_sign=0.0)
    metal += [d.bevel(kit.box(f"{prefix}bump{ex}{ey}", (0.06, 0.06, sz * 0.96), (x + ex * (sx / 2 - 0.02), y + ey * (sy / 2 - 0.02), z + sz / 2)), 0.015, 2)
              for ex in (-1, 1) for ey in (-1, 1)]
    if yaw:
        for obj in [shell] + lights + metal:
            _yaw_about(obj, yaw, (x, y))
    return shell, lights, metal


def _yaw_about(obj, angle, centre):
    _apply(obj)
    c, s = math.cos(angle), math.sin(angle)
    for v in obj.data.vertices:
        dx, dy = v.co.x - centre[0], v.co.y - centre[1]
        v.co.x = centre[0] + dx * c - dy * s
        v.co.y = centre[1] + dx * s + dy * c
    obj.data.update()


def build_squad_post(seed=401):
    """Rhodes squad field post, about 2.4 x 1.8 m, 2.2 m to the pennant top."""
    random.seed(seed)
    # The tarp only under the cases: a big black sheet reads as a hole from the camera.
    tarp = _cloth_sheet("tarp", (1.35, 1.0, 0.02), (-0.5, 0.12, 0.012), seed)
    kit.clip_below(tarp, 0.0)
    # Two stacked hard cases, left; the top one turned a little.
    low = _hard_case("lo", (0.92, 0.56, 0.44), (-0.62, 0.15, 0.02))
    high = _hard_case("hi", (0.74, 0.48, 0.36), (-0.6, 0.18, 0.46), yaw=0.12)
    # A third, small supply case by the terminal, front.
    small = _hard_case("sm", (0.46, 0.32, 0.26), (0.05, -0.42, 0.02), yaw=-0.3)
    # Field terminal on a tripod, right of centre, screen to the camera.
    tx, ty = 0.55, 0.05
    legs = []
    for i in range(3):
        a = math.radians(90 + i * 120)
        foot = (tx + 0.34 * math.cos(a), ty + 0.34 * math.sin(a), 0.02)
        top = (tx, ty, 0.92)
        mid = [(foot[k] + top[k]) / 2 for k in range(3)]
        length = math.dist(foot, top)
        leg = d.cyl(f"leg{i}", 0.016, length, mid, vertices=8)
        direction = [top[k] - foot[k] for k in range(3)]
        import mathutils
        leg.rotation_euler = mathutils.Vector(direction).to_track_quat("Z", "Y").to_euler()
        bpy.context.view_layer.objects.active = leg
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        legs.append(leg)
    head = d.bbox("term_body", (0.56, 0.1, 0.38), (tx, ty, 1.12), (math.radians(-18), 0, 0), width=0.02)
    hood = d.bbox("term_hood", (0.6, 0.12, 0.04), (tx, ty - 0.02, 1.33), (math.radians(-18), 0, 0), width=0.01)
    pad = d.bbox("term_keys", (0.5, 0.22, 0.03), (tx, ty - 0.17, 0.95), (math.radians(-35), 0, 0), width=0.008)
    screen = kit.box("term_screen", (0.46, 0.01, 0.28), (tx, ty - 0.066, 1.125), (math.radians(-18), 0, 0))
    mount = d.cyl("term_mount", 0.04, 0.12, (tx, ty, 0.94), vertices=10)
    # Pennant pole at the back right, a black pennant hanging from a crossbar.
    px, py = 0.98, 0.62
    pole = d.cyl("pole", 0.022, 2.2, (px, py, 1.1), vertices=10)
    bar = d.cyl("bar", 0.014, 0.6, (px - 0.3, py, 2.12), (0, math.pi / 2, 0), 8)
    foot = d.cyl("pole_foot", 0.09, 0.05, (px, py, 0.025), vertices=12)
    flag = _cloth_sheet("pennant", (0.56, 0.012, 0.82), (px - 0.31, py, 1.7), seed + 5, sag=0.004)
    logo_flag = kit.box("logo_flag", (0.34, 0.004, 0.34), (px - 0.31, py - 0.012, 1.78))
    logo_case = kit.box("logo_case", (0.2, 0.004, 0.2), (-0.62, 0.15 - 0.287, 0.17))

    cases = kit.join([low[0], high[0], small[0], head, hood, pad], "cases")
    glow = kit.join(low[1] + high[1] + small[1] + [screen], "glow")
    iron = kit.join(low[2] + high[2] + small[2] + legs + [mount, pole, bar, foot], "iron")
    cloth = kit.join([tarp, flag], "cloth")
    return [(cases, swatch("enc_squad_post_case_p", "rhodes_case.png", 0.9, edge="e4e8ea"), "case"),
            (glow, swatch("enc_squad_post_glow_p", "rhodes_trim_glow.png", 0.5), "glow"),
            (iron, _steel("enc_squad_post_iron_p", seed), "iron"),
            (cloth, swatch("enc_squad_post_cloth_p", "rhodes_pennant.png", 1.0, edge="3a4044", grime_strength=0.2), "cloth"),
            (logo_flag, decal("enc_squad_post_logo_p", "1a1d1f"), "logo"),
            (logo_case, decal("enc_squad_post_logo2_p", "c9cfd2"), "logo2")]


def _wheel(prefix, radius, location, spokes=8):
    """A cart wheel standing in the xz plane (axle along y)."""
    x, y, z = location
    rot = (math.pi / 2, 0, 0)
    bpy.ops.mesh.primitive_torus_add(major_radius=radius - 0.03, minor_radius=0.035, major_segments=24, minor_segments=6,
                                     location=(x, y, z), rotation=rot)
    rim = bpy.context.object
    rim.name = f"{prefix}rim"
    hub = d.cyl(f"{prefix}hub", 0.08, 0.14, (x, y, z), rot, 12)
    parts = [rim, hub]
    for i in range(spokes):
        a = i * math.pi / spokes
        parts.append(d.bbox(f"{prefix}sp{i}", (2 * (radius - 0.05), 0.04, 0.035), (x, y, z), (0, a, 0), width=0.006))
    return parts


def build_trader_stall(seed=411):
    """坎诺特's stall, about 2.6 x 1.8 m, 2.0 m to the lantern pole."""
    random.seed(seed)
    # Hand cart, back left, its bed along x; wheels either side (axle along y).
    cx, cy = -0.35, 0.35
    bed_z = 0.62
    bed = d.plank_box("bed", (1.45, 0.92, 0.26), (cx, cy, bed_z), plank=0.12, battens=False)
    axle = d.cyl("axle", 0.03, 1.12, (cx, cy, 0.44), (math.pi / 2, 0, 0), 10)
    wheels = _wheel("wl", 0.44, (cx, cy - 0.53, 0.44)) + _wheel("wr", 0.44, (cx, cy + 0.53, 0.44))
    # Shafts run out to the right and down to the ground, a prop under the back.
    shafts = []
    for s in (-1, 1):
        shafts.append(d.bbox(f"shaft{s}", (1.1, 0.06, 0.06), (cx + 1.15, cy + s * 0.36, 0.42), (0, math.radians(20), 0), width=0.01))
    prop = d.bbox("prop", (0.06, 0.06, 0.5), (cx - 0.68, cy, 0.25), width=0.01)
    # Canvas cover over hoops: a half barrel along x, roughened, sagging.
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.5, depth=1.38, location=(cx, cy, bed_z + 0.13), rotation=(0, math.pi / 2, 0))
    cover = bpy.context.object
    cover.name = "cover"
    import bmesh
    mesh = bmesh.new()
    mesh.from_mesh(cover.data)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.co.x > 0.02], context="VERTS")  # local x = world -z: keep the top half
    mesh.to_mesh(cover.data)
    mesh.free()
    mod = cover.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.02
    bpy.context.view_layer.objects.active = cover
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    kit.roughen(cover, seed + 1, strength=0.035, size=0.3, subdiv=2)
    hoops = []
    for i, hx in enumerate((-0.55, 0.0, 0.55)):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.51, minor_radius=0.018, major_segments=20, minor_segments=5,
                                         location=(cx + hx, cy, bed_z + 0.13), rotation=(0, math.pi / 2, 0))
        hoop = bpy.context.object
        hoop.name = f"hoop{i}"
        hoops.append(hoop)
    # Tied bundles: one out of the cover's shaft end, one on the ground in
    # front, one on the crate stack. (x, y, z, radius, length, yaw)
    rolls = [(cx + 0.75, cy - 0.1, bed_z + 0.32, 0.16, 0.5, 0.3),
             (-0.75, -0.62, 0.17, 0.17, 0.62, 0.3),
             (-1.2, -0.3, 0.85, 0.13, 0.45, -0.4)]
    bundles, ropes = [], []
    for i, (bx, by, bz, r, l, yaw) in enumerate(rolls):
        roll = d.cyl(f"roll{i}", r, l, (bx, by, bz), (0, math.pi / 2, yaw), 14)
        kit.roughen(roll, seed + 10 + i, strength=0.015, size=0.12, subdiv=1)
        bundles.append(roll)
        for t in (-l * 0.25, l * 0.25):
            bpy.ops.mesh.primitive_torus_add(major_radius=r + 0.01, minor_radius=0.012, major_segments=16, minor_segments=4,
                                             location=(bx + t * math.cos(yaw), by + t * math.sin(yaw), bz), rotation=(0, math.pi / 2, yaw))
            ropes.append(bpy.context.object)
    # Crates (two stacked) and a sack, left of the cart.
    crates = d.plank_box("crA", (0.6, 0.5, 0.42), (-1.2, -0.3, 0.21), plank=0.1, battens=True)
    crates += d.plank_box("crB", (0.42, 0.38, 0.3), (-1.2, -0.3, 0.57), plank=0.1, battens=False)
    sack = _apply(kit.box("sack", (0.36, 0.3, 0.42), (-1.25, 0.3, 0.2)))
    kit.roughen(sack, seed + 20, strength=0.03, size=0.15, bevel=0.1, subdiv=2)
    kit.clip_below(sack, 0.0)
    # The rug in front of the cart, goods laid on it.
    rug = _cloth_sheet("rug", (1.25, 0.82, 0.016), (0.4, -0.45, 0.01), seed + 30)
    kit.clip_below(rug, 0.0)
    goods = []
    for i, (gx, gy, sx, sy, sz, yaw) in enumerate([(0.1, -0.5, 0.26, 0.2, 0.14, 0.2), (0.45, -0.35, 0.2, 0.2, 0.2, -0.4),
                                                   (0.78, -0.55, 0.3, 0.16, 0.1, 0.6)]):
        good = kit.box(f"good{i}", (sx, sy, sz), (gx, gy, 0.02 + sz / 2), (0, 0, yaw))
        kit.roughen(good, seed + 40 + i, strength=0.008, size=0.08, bevel=0.03, subdiv=2)
        goods.append(good)
    jar = d.cyl("jar", 0.07, 0.16, (0.62, -0.68, 0.1), vertices=12)
    # The lantern pole, right front, the lantern hanging off an arm towards the rug.
    lx, ly = 1.15, -0.55
    pole = d.cyl("lpole", 0.035, 2.0, (lx, ly, 1.0), vertices=10)
    arm = d.bbox("larm", (0.5, 0.04, 0.04), (lx - 0.23, ly, 1.92), width=0.008)
    brace = d.bbox("lbrace", (0.3, 0.03, 0.03), (lx - 0.12, ly, 1.8), (0, math.radians(-35), 0), width=0.006)
    hook = d.cyl("lhook", 0.006, 0.12, (lx - 0.42, ly, 1.84), vertices=6)
    cage = [d.bbox(f"lcap{t}", (0.17, 0.17, 0.03), (lx - 0.42, ly, z), width=0.01) for t, z in (("t", 1.77), ("b", 1.52))]
    cage += [d.bbox(f"lbar{i}", (0.015, 0.015, 0.24), (lx - 0.42 + ex * 0.075, ly + ey * 0.075, 1.645), width=0.003)
             for i, (ex, ey) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    glass = d.bbox("lglass", (0.13, 0.13, 0.22), (lx - 0.42, ly, 1.645), width=0.01)
    foot = d.cyl("lfoot", 0.12, 0.06, (lx, ly, 0.03), vertices=12)

    wood = kit.join(bed + shafts + [prop, pole, arm, brace] + hoops + crates, "wood")
    iron = kit.join(wheels + [axle, hook, foot, jar] + cage, "iron")
    canvas = kit.join([cover] + bundles + goods + [sack], "canvas")
    rope = kit.join(ropes, "rope")
    for obj in (wood, canvas):
        if kit.triangle_count(obj) > 6000:
            kit.decimate(obj, 6000)
    from build_poi import cloth as poi_cloth
    return [(wood, _wood("enc_trader_stall_wood_p", seed), "wood"),
            (iron, d.worn(rust_material("enc_trader_stall_iron_p", seed), edge="8a8784", edge_strength=0.4, grime="1a120c"), "iron"),
            (canvas, swatch("enc_trader_stall_canvas_p", "trader_canvas.png", 0.9, edge="b8a888"), "canvas"),
            (rug, swatch("enc_trader_stall_rug_p", "trader_rug.png", 1.25, grime_strength=0.2), "rug"),
            (rope, poi_cloth("enc_trader_stall_rope_p", seed, "4a3a26"), "rope"),
            (glass, swatch("enc_trader_stall_glow_p", "trader_lantern_glow.png", 0.25), "glow")]


def publish(pieces, name, preview_scale=3.4, resolution=1024):
    """Centre the parts on the origin with their foot at z = 0, bake each part
    (swatch or procedural, with AO) to its own texture, join, export the .glb
    and render the preview. The .blend is saved as a copy, so the open file
    (the MCP build's) keeps its own path."""
    objects = [obj for obj, _mat, _part in pieces]
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    xs = [v.co.x for o in objects for v in o.data.vertices]
    ys = [v.co.y for o in objects for v in o.data.vertices]
    zs = [v.co.z for o in objects for v in o.data.vertices]
    shift = ((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, min(zs))
    for obj in objects:
        for v in obj.data.vertices:
            v.co.x -= shift[0]
            v.co.y -= shift[1]
            v.co.z -= shift[2]
        obj.data.update()
    baked = []
    for obj, mat, part in pieces:
        kit.finish_mesh(obj)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        image = kit.bake_texture(obj, mat, f"{name}_{part}", resolution if part not in ("glow", "logo") else 256)
        obj.data.materials.clear()
        obj.data.materials.append(kit.baked_material(f"{name}_{part}", image))
        baked.append(obj)
    whole = kit.join(baked, name)
    kit.report(whole, name)
    # The exporter's selection can read another scene's view layer (an MCP
    # build runs beside the user's own scene): nothing selected anywhere else.
    for scene in bpy.data.scenes:
        for layer in scene.view_layers:
            for obj in layer.objects:
                if obj != whole: obj.select_set(False, view_layer=layer)
    path = kit.export(whole, name)
    kit.render_preview(whole, name, preview_scale)
    os.makedirs(os.path.join(kit.OUT_DIR, "blend"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(kit.OUT_DIR, "blend", f"{name}.blend"), copy=True)
    print("EXPORTED", path)
    return whole


def new_scene(name):
    """For the MCP build: a fresh scene in the open Blender, made the window's
    (exports read the window's view layer)."""
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


if __name__ == "__main__":
    kit.reset_scene()
    publish(build_squad_post(), "enc_squad_post")
    kit.reset_scene()
    publish(build_trader_stall(), "enc_trader_stall")
