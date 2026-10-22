"""爱国者 (Patriot, "大爹") as a 3D model, to judge whether characters could be
modelled (用户 2026-10-20: 像素风格是不是影响画面效果…你先建模一个人物我看看 / 建大爹吧).

Built after Sol's B1 v2 painting (art/field/batch_B1_v2/source_paintings/
patriot_generated.png): chibi proportions, a wendigo-skull helm with antlers
and a red eye, black plate armour with grey edges and orange Reunion marks, a
white fur cloak, a tower shield with the orange X, a halberd with a torn orange
banner, a hose looping from the helm to the back. Cel shading (Shader to RGB
through a constant ramp) and an inverted-hull outline, like the painting's
flat colour and thick black line.

Through the MCP add-on: exec(open(path).read()); build()
Blender Z up, metres, the figure faces -Y (towards a front camera).
"""
import math
import bpy
import bmesh
import mathutils

V = mathutils.Vector
PALETTE = {
    "black": "26282c", "plate": "3a3d42", "grey": "8c9096", "light": "c9ccd0", "white": "ece8e0",
    "orange": "e8541c", "rust": "a8582a", "bone": "e6e0d4", "antler": "8a7a68", "leather": "6a4a34",
    "fur": "e4e2dc", "fur_dark": "9a9890", "eye": "ff2a2a", "steel": "b8b2a8", "dark_steel": "4a4c50",
}


def _hex(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


_MATS = {}


def toon(key, emission=0.0):
    """Cel material: lit, quantised to three flat steps of the colour."""
    name = f"patriot_{key}"
    if name in _MATS: return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    col = _lin(_hex(PALETTE[key]))
    if emission > 0:
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*col, 1)
        em.inputs["Strength"].default_value = emission
        nt.links.new(em.outputs[0], out.inputs[0])
    else:
        diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
        diff.inputs["Color"].default_value = (1, 1, 1, 1)
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        els = ramp.color_ramp.elements
        els[0].position = 0.0
        els[0].color = (*[c * 0.42 for c in col], 1)
        els[1].position = 0.18
        els[1].color = (*[c * 0.75 for c in col], 1)
        e = els.new(0.5)
        e.color = (*col, 1)
        nt.links.new(diff.outputs[0], s2r.inputs[0])
        nt.links.new(s2r.outputs["Color"], ramp.inputs["Fac"])
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(em.outputs[0], out.inputs[0])
    _MATS[name] = m
    return m


def outline_mat():
    name = "patriot_outline"
    if name in _MATS: return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.01, 0.01, 0.012, 1)
    nt.links.new(em.outputs[0], out.inputs[0])
    m.use_backface_culling = True
    _MATS[name] = m
    return m


ALL = []


def _finish(obj, key, smooth=False, bevel=0.0, sub=0, emission=0.0):
    obj.data.materials.clear()
    obj.data.materials.append(toon(key, emission))
    if bevel > 0:
        b = obj.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    if sub > 0:
        s = obj.modifiers.new("sub", "SUBSURF")
        s.levels = sub
        s.render_levels = sub
    if smooth:
        for p in obj.data.polygons: p.use_smooth = True
    ALL.append(obj)
    return obj


def box(name, size, loc, key, rot=(0, 0, 0), bevel=0.03, sub=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, key, bevel=bevel, sub=sub, smooth=sub > 0)


def cyl(name, r, depth, loc, key, rot=(0, 0, 0), verts=24, bevel=0.0, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    return _finish(o, key, smooth=True, bevel=bevel)


def sphere(name, r, loc, key, scale=(1, 1, 1), segs=32):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segs, ring_count=segs // 2)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, key, smooth=True)


def tube(name, points, r, key, verts=10):
    """A tube along a polyline (a curve with a bevel, converted to mesh)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return _finish(bpy.context.object, key, smooth=True)


def poly(name, outline, thickness, key, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.01):
    """A flat shape from an XZ outline, extruded `thickness` along Y."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((x, -thickness / 2, z)) for x, z in outline]
    face = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.y += thickness
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return _finish(o, key, bevel=bevel)


def antler(name, root, direction, length, side):
    """A branching antler: a main beam with three tines, all tapering."""
    parts = []
    d = V(direction).normalized()
    up = V((0, 0, 1))
    pts = [V(root)]
    for k in range(1, 5):
        bend = V((side * 0.08 * k, 0.03 * k, 0))
        pts.append(pts[-1] + (d * (length / 4)) + bend)
    for k in range(4):
        a, b = pts[k], pts[k + 1]
        r = 0.075 * (1.0 - k * 0.18)
        parts.append(_seg(f"{name}_b{k}", a, b, r, r * 0.82))
    for k, (at, tdir, tl) in enumerate(((1, (side * 0.6, -0.2, 0.8), 0.32), (2, (side * 0.9, 0.1, 0.5), 0.3), (3, (-side * 0.2, -0.3, 0.9), 0.26))):
        base = pts[at]
        tip = base + V(tdir).normalized() * tl
        parts.append(_seg(f"{name}_t{k}", base, tip, 0.05, 0.012))
    return parts


def _seg(name, a, b, r1, r2):
    axis = b - a
    o = cyl(name, r1, axis.length, tuple((a + b) / 2), "antler", verts=8, r2=r2)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = axis.to_track_quat("Z", "Y")
    return o


def jagged_skirt(name, r_top, r_bottom, z_top, z_bottom, teeth, key, open_front=0.0, seed=1):
    """A fur cloak: a cone whose bottom edge is cut into ragged points."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    top, bot = [], []
    n = teeth * 2
    import random
    rnd = random.Random(seed)
    for k in range(n):
        a = k / n * math.tau + math.pi / 2
        if open_front > 0:
            # leave a gap at the front (-Y) where the shield stands
            span = math.tau - open_front
            a = -math.pi / 2 + open_front / 2 + k / (n - 1) * span
        top.append(bm.verts.new((r_top * math.cos(a), r_top * math.sin(a), z_top)))
        drop = (rnd.uniform(0.18, 0.42) if k % 2 == 0 else rnd.uniform(0.0, 0.08))
        rr = r_bottom * (1.0 + (0.06 if k % 2 == 0 else 0.0))
        bot.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z_bottom - drop)))
    rng = range(n - 1) if open_front > 0 else range(n)
    for k in rng:
        j = (k + 1) % n
        bm.faces.new((top[k], top[j], bot[j], bot[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    sol = o.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.05
    return _finish(o, key, smooth=False)


def banner(name, at, key):
    """A torn banner hanging from the halberd: a cloth strip with a ragged end,
    rippled."""
    outline = [(0.0, 0.0), (0.0, -0.28), (-0.35, -0.42), (-0.62, -0.5), (-0.78, -0.72), (-0.95, -0.66), (-1.05, -0.9),
               (-1.18, -0.78), (-1.12, -0.55), (-0.98, -0.32), (-0.72, -0.18), (-0.4, -0.06)]
    o = poly(name, outline, 0.02, key, loc=at, rot=(0, 0, math.radians(15)), bevel=0.0)
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    wave = o.modifiers.new("wave", "WAVE")
    wave.height = 0.06
    wave.width = 0.35
    wave.speed = 0.0
    wave.use_normal = False
    return o


def build():
    for o in list(bpy.data.objects):
        if o.name.startswith("patriot") or o.name.startswith("pt_"): bpy.data.objects.remove(o, do_unlink=True)
    scene = bpy.data.scenes.get("patriot") or bpy.data.scenes.new("patriot")
    bpy.context.window.scene = scene
    ALL.clear()
    H = 1.0   # one unit ~ the painting's head height; the figure is ~3.3 units tall

    # --- Legs and boots ------------------------------------------------------------------
    for s in (-1, 1):
        box(f"pt_boot{s}", (0.42, 0.62, 0.3), (s * 0.34, -0.05, 0.15), "dark_steel", bevel=0.06)
        box(f"pt_boot_toe{s}", (0.38, 0.22, 0.16), (s * 0.34, -0.38, 0.1), "plate", bevel=0.05)
        cyl(f"pt_shin{s}", 0.17, 0.5, (s * 0.34, 0.0, 0.52), "black")
        box(f"pt_greave{s}", (0.3, 0.1, 0.42), (s * 0.34, -0.17, 0.55), "plate", bevel=0.04)
        box(f"pt_knee{s}", (0.3, 0.16, 0.18), (s * 0.34, -0.17, 0.82), "grey", bevel=0.05)
        cyl(f"pt_thigh{s}", 0.2, 0.42, (s * 0.32, 0.0, 1.0), "black")
    # --- Torso -----------------------------------------------------------------------------
    box("pt_hips", (0.95, 0.6, 0.32), (0, 0.02, 1.22), "black", bevel=0.08)
    box("pt_belt", (1.0, 0.64, 0.1), (0, 0.02, 1.36), "leather", bevel=0.03)
    box("pt_torso", (1.15, 0.78, 0.85), (0, 0.04, 1.85), "black", bevel=0.14, sub=1)
    box("pt_chest_plate", (0.86, 0.12, 0.55), (0, -0.37, 1.95), "plate", bevel=0.06)
    poly("pt_chest_mark", [(-0.18, 0.18), (0.0, 0.02), (0.18, 0.18), (0.24, 0.12), (0.06, -0.04), (0.24, -0.2), (0.18, -0.26),
                           (0.0, -0.1), (-0.18, -0.26), (-0.24, -0.2), (-0.06, -0.04), (-0.24, 0.12)], 0.03, "orange",
         loc=(0, -0.44, 1.97))
    box("pt_gorget", (0.6, 0.5, 0.2), (0, 0.0, 2.33), "plate", bevel=0.06)
    # --- Pauldrons and arms ------------------------------------------------------------------
    for s in (-1, 1):
        sphere(f"pt_pauldron{s}", 0.36, (s * 0.72, 0.02, 2.15), "plate", scale=(1.15, 1.0, 0.82))
        box(f"pt_pauldron_rim{s}", (0.5, 0.62, 0.08), (s * 0.78, 0.02, 1.96), "grey", rot=(0, s * 0.35, 0), bevel=0.03)
        box(f"pt_pauldron_stripe{s}", (0.08, 0.5, 0.06), (s * 0.95, -0.05, 2.18), "orange", rot=(0, s * 0.6, 0), bevel=0.01)
        cyl(f"pt_upper_arm{s}", 0.16, 0.45, (s * 0.8, 0.02, 1.72), "black")
        box(f"pt_bracer{s}", (0.32, 0.32, 0.4), (s * 0.82, -0.06, 1.38), "plate", bevel=0.05)
        box(f"pt_bracer_edge{s}", (0.34, 0.34, 0.06), (s * 0.82, -0.06, 1.58), "grey", bevel=0.02)
    # Right fist (viewer's left) round the halberd, left hand behind the shield.
    box("pt_fist", (0.34, 0.36, 0.3), (-0.84, -0.22, 1.12), "dark_steel", bevel=0.07, sub=1)
    for k in range(4):
        box(f"pt_knuckle{k}", (0.07, 0.08, 0.07), (-0.84 - 0.06 + k * 0.0, -0.42, 1.2 - k * 0.07), "grey", bevel=0.015)
    # --- Fur cloak --------------------------------------------------------------------------
    jagged_skirt("pt_cloak", 0.62, 0.95, 2.25, 0.62, 14, "fur", open_front=math.radians(80), seed=3)
    jagged_skirt("pt_cloak_under", 0.58, 0.85, 2.0, 0.48, 12, "fur_dark", open_front=math.radians(100), seed=7)
    jagged_skirt("pt_collar_fur", 0.42, 0.62, 2.45, 2.12, 12, "fur", seed=11)
    # --- The wendigo skull helm -------------------------------------------------------------
    sphere("pt_skull", 0.36, (0.08, -0.05, 2.78), "bone", scale=(0.95, 1.25, 0.9))
    cyl("pt_snout", 0.2, 0.62, (0.14, -0.5, 2.62), "bone", rot=(math.radians(-108), 0, math.radians(8)), verts=12, r2=0.06)
    box("pt_jaw", (0.32, 0.4, 0.1), (0.12, -0.36, 2.5), "bone", rot=(math.radians(-15), 0, 0), bevel=0.04)
    box("pt_brow", (0.62, 0.3, 0.1), (0.08, -0.22, 2.92), "bone", rot=(math.radians(-12), 0, 0), bevel=0.04)
    for k, (x, z, w) in enumerate(((0.0, 2.84, 0.22), (0.2, 2.76, 0.18), (-0.12, 2.7, 0.16))):
        box(f"pt_crack{k}", (w, 0.02, 0.015), (x, -0.42, z), "black", rot=(0, 0.4 * (k - 1), 0), bevel=0.0)
    sphere("pt_socket_l", 0.085, (-0.12, -0.38, 2.78), "black", scale=(1.2, 0.6, 0.8))
    sphere("pt_socket_r", 0.085, (0.26, -0.36, 2.78), "black", scale=(1.2, 0.6, 0.8))
    sphere("pt_eye", 0.05, (-0.12, -0.42, 2.78), "eye", scale=(1.3, 0.6, 0.9))
    _MATS.pop("patriot_eye", None)
    bpy.context.object.data.materials.clear()
    bpy.context.object.data.materials.append(toon("eye", emission=6.0))
    for s, root, dirn in ((-1, (-0.18, 0.02, 3.02), (-0.55, 0.1, 1.0)), (1, (0.3, 0.02, 3.02), (0.55, 0.1, 1.0))):
        antler(f"pt_antler{s}", root, dirn, 0.95, s)
    # The hose from the helm's back over the shoulder.
    tube("pt_hose", [(-0.15, 0.25, 2.7), (-0.55, 0.45, 2.95), (-0.85, 0.35, 2.55), (-0.7, 0.3, 2.2)], 0.075, "dark_steel")
    for k in range(5):
        t = k / 4
        p = V((-0.15, 0.25, 2.7)).lerp(V((-0.7, 0.3, 2.2)), t) + V((-0.25 * math.sin(t * math.pi), 0.12 * math.sin(t * math.pi), 0.3 * math.sin(t * math.pi)))
        cyl(f"pt_hose_ring{k}", 0.085, 0.04, tuple(p), "grey", verts=12)
    # --- Tower shield (in front, held by the left arm) ----------------------------------------
    shield_y = -0.62
    sh = [(-0.55, 2.3), (0.55, 2.3), (0.72, 2.0), (0.72, 0.25), (0.48, 0.0), (-0.48, 0.0), (-0.72, 0.25), (-0.72, 2.0)]
    poly("pt_shield", sh, 0.16, "black", loc=(0.38, shield_y, 0.08), bevel=0.03)
    inner = [(-0.42, 2.12), (0.42, 2.12), (0.56, 1.9), (0.56, 0.36), (0.38, 0.16), (-0.38, 0.16), (-0.56, 0.36), (-0.56, 1.9)]
    poly("pt_shield_panel", inner, 0.04, "plate", loc=(0.38, shield_y - 0.1, 0.08), bevel=0.01)
    poly("pt_shield_x", [(-0.3, 1.9), (-0.16, 1.9), (0.0, 1.62), (0.16, 1.9), (0.3, 1.9), (0.08, 1.45), (0.3, 1.0), (0.16, 1.0),
                         (0.0, 1.28), (-0.16, 1.0), (-0.3, 1.0), (-0.08, 1.45)], 0.03, "orange", loc=(0.38, shield_y - 0.14, 0.08), bevel=0.005)
    for s in (-1, 1):
        box(f"pt_shield_rail{s}", (0.06, 0.05, 1.5), (0.38 + s * 0.48, shield_y - 0.14, 1.1), "grey", bevel=0.01)
        cyl(f"pt_shield_bolt{s}", 0.05, 0.05, (0.38 + s * 0.48, shield_y - 0.17, 1.95), "white", rot=(math.radians(90), 0, 0), verts=16)
        cyl(f"pt_shield_bolt_b{s}", 0.05, 0.05, (0.38 + s * 0.48, shield_y - 0.17, 0.28), "white", rot=(math.radians(90), 0, 0), verts=16)
    box("pt_shield_foot", (0.9, 0.2, 0.12), (0.38, shield_y, 0.14), "dark_steel", bevel=0.03)
    box("pt_shield_band", (1.2, 0.04, 0.06), (0.38, shield_y - 0.12, 0.42), "orange", bevel=0.01)
    # --- Halberd (right hand, viewer's left) ---------------------------------------------------
    px, py = -0.86, -0.3
    cyl("pt_pole", 0.045, 3.6, (px, py, 1.75), "black", verts=12)
    for k in range(9):
        cyl(f"pt_wrap{k}", 0.055, 0.05, (px, py, 0.75 + k * 0.22), "leather", verts=12)
    cyl("pt_butt", 0.08, 0.2, (px, py, 0.02), "dark_steel", verts=12)
    box("pt_socket", (0.12, 0.12, 0.25), (px, py, 3.4), "dark_steel", bevel=0.02)
    poly("pt_spear", [(0.0, 0.0), (0.09, 0.08), (0.06, 0.55), (0.0, 0.75), (-0.06, 0.55), (-0.09, 0.08)], 0.04, "steel",
         loc=(px, py, 3.52), bevel=0.006)
    poly("pt_axe", [(0.0, 0.1), (0.1, 0.05), (0.38, 0.3), (0.52, 0.0), (0.42, -0.36), (0.12, -0.18), (0.0, -0.2)], 0.035, "steel",
         loc=(px, py, 3.25), rot=(0, 0, math.pi), bevel=0.006)
    poly("pt_hook", [(0.0, 0.06), (0.22, 0.12), (0.3, -0.02), (0.16, 0.0), (0.0, -0.06)], 0.035, "steel", loc=(px + 0.05, py, 3.28), bevel=0.006)
    for k, (dx, dz) in enumerate(((-0.25, 3.32), (-0.38, 3.12), (-0.18, 3.0))):
        box(f"pt_rust{k}", (0.07, 0.04, 0.05), (px + dx, py - 0.02, dz), "rust", bevel=0.005)
    banner("pt_banner", (px - 0.04, py, 2.95), "orange")
    # --- Outline: an inverted hull on everything solid ---------------------------------------
    om = outline_mat()
    for o in ALL:
        if o.type != "MESH": continue
        o.data.materials.append(om)
        sol = o.modifiers.new("outline", "SOLIDIFY")
        sol.thickness = -0.022
        sol.use_flip_normals = True
        sol.material_offset = len(o.data.materials) - 1
        sol.use_rim = False
    return len(ALL)
