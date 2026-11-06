"""手办参考图 (用户 2026-10-26: 手办可以是高清图，需要有手办的3d感，给出参考图).

Not a game asset: a neutral figure in 1/7 scale-figure proportions (用户:
要1/7比例手办那种的手办) — about seven heads tall, posed, on a sculpted base —
lit like a product photo, rendered at the canvas Sol delivers (512 × 1024, transparent),
so all eighteen figurine icons share one framing, light and finish:
art/items/reference/figurine_template.png (and _guides.png with the frame).

Built through the Blender MCP add-on into the open Blender (a new scene).
"""
import math
import os

import bpy

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(REPO, "art", "items", "reference")


def _mat(name, hex_rgb, rough=0.35, coat=0.0, alpha=1.0, transmission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")
    c = tuple(int(hex_rgb[i:i + 2], 16) / 255 for i in (0, 2, 4))
    bsdf.inputs["Base Color"].default_value = tuple(x ** 2.2 for x in c) + (1.0,)
    bsdf.inputs["Roughness"].default_value = rough
    if "Coat Weight" in bsdf.inputs: bsdf.inputs["Coat Weight"].default_value = coat
    if transmission > 0 and "Transmission Weight" in bsdf.inputs:
        bsdf.inputs["Transmission Weight"].default_value = transmission
        bsdf.inputs["IOR"].default_value = 1.49
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


def _put(obj, mat, smooth=True):
    obj.data.materials.append(mat)
    if smooth:
        for p in obj.data.polygons: p.use_smooth = True
    return obj


def build():
    scene = bpy.data.scenes.new("figurine_reference")
    bpy.context.window.scene = scene
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.device = "CPU"
    scene.cycles.samples = 96
    scene.render.resolution_x, scene.render.resolution_y = 512, 1024
    scene.render.film_transparent = True
    scene.view_settings.look = "AgX - Medium High Contrast" if "AgX - Medium High Contrast" in [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items] else scene.view_settings.look
    world = bpy.data.worlds.new("fig_world")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.bl_idname == "ShaderNodeBackground")
    bg.inputs["Color"].default_value = (0.9, 0.92, 0.95, 1.0)
    bg.inputs["Strength"].default_value = 0.35
    scene.world = world

    skin = _mat("fig_skin", "f3d9c8", 0.42, 0.3)
    hair = _mat("fig_hair", "5b6f8f", 0.3, 0.6)
    coat = _mat("fig_coat", "262b33", 0.45, 0.35)
    cloth = _mat("fig_cloth", "e6e9ee", 0.4, 0.2)
    trim = _mat("fig_trim", "3fa8d8", 0.3, 0.5)
    boots = _mat("fig_boots", "1a1d22", 0.3, 0.6)
    eye = _mat("fig_eye", "3a6fb0", 0.15, 0.8)
    stone = _mat("fig_stone", "3a3d42", 0.75, 0.0)
    crystal = _mat("fig_crystal", "ff8a2a", 0.1, 0.8)
    rim = _mat("fig_rim", "c8a24a", 0.25, 0.6)

    from mathutils import Vector

    def limb(a, b, r1, r2, mat, verts=20):
        """A tapered cylinder from point a to point b."""
        a, b = Vector(a), Vector(b)
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=(b - a).length, location=(a + b) * 0.5)
        obj = bpy.context.object
        obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
        return _put(obj, mat)

    def ball(at, r, mat, scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r, location=at)
        bpy.context.object.scale = scale
        return _put(bpy.context.object, mat)

    # Sculpted base (1/7 figures stand on a themed base): a dark stone disc
    # with a gold rim, broken rock and Originium shards round its edge.
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.4, depth=0.08, location=(0, 0, 0.04))
    _put(bpy.context.object, stone)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.4, minor_radius=0.012, major_segments=64, minor_segments=8, location=(0, 0, 0.08))
    _put(bpy.context.object, rim)
    for i, (ang, size) in enumerate([(200, 0.09), (235, 0.06), (320, 0.08), (20, 0.05), (110, 0.07)]):
        a = math.radians(ang)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=size, location=(0.3 * math.cos(a), 0.3 * math.sin(a), 0.1))
        bpy.context.object.rotation_euler = (i * 0.7, i * 1.3, i * 0.4)
        _put(bpy.context.object, stone, smooth=False)
    for ang, tilt, length in [(215, 0.35, 0.22), (230, -0.2, 0.15), (330, 0.25, 0.18)]:
        a = math.radians(ang)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.035, radius2=0.0, depth=length, location=(0.3 * math.cos(a), 0.3 * math.sin(a), 0.08 + length * 0.45), rotation=(tilt, tilt * 0.6, a))
        _put(bpy.context.object, crystal, smooth=False)

    # A figure about seven heads tall, weight on the left leg, the right foot
    # stepped out; the right hand on a staff planted on the base.
    hip_l, hip_r = (-0.07, 0.0, 0.86), (0.07, 0.0, 0.86)
    knee_l, knee_r = (-0.075, -0.01, 0.48), (0.13, -0.05, 0.5)
    foot_l, foot_r = (-0.08, 0.0, 0.12), (0.19, -0.06, 0.12)
    limb(hip_l, knee_l, 0.075, 0.055, skin)
    limb(hip_r, knee_r, 0.075, 0.055, skin)
    limb(knee_l, foot_l, 0.06, 0.05, boots)
    limb(knee_r, foot_r, 0.06, 0.05, boots)
    for f in (foot_l, foot_r):
        ball((f[0], f[1] - 0.04, 0.11), 0.055, boots, (0.9, 1.6, 0.6))
    limb((0, 0, 0.78), (0, 0, 0.98), 0.17, 0.12, cloth)          # skirt and hips
    limb((0, 0, 0.98), (0, 0.01, 1.3), 0.12, 0.14, cloth)        # torso
    # The open coat: flared, longer behind, and its collar.
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.27, radius2=0.15, depth=0.62, location=(0, 0.03, 1.0), end_fill_type="NOTHING")
    coat_obj = _put(bpy.context.object, coat)
    coat_obj.rotation_euler = (math.radians(-6), 0, 0)
    mod = coat_obj.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.015
    limb((0, 0.01, 1.28), (0, 0.01, 1.36), 0.15, 0.09, trim)     # collar
    # Arms: the left hand on the hip, the right holding the staff.
    sh_l, sh_r = (-0.16, 0.01, 1.27), (0.16, 0.01, 1.27)
    el_l, el_r = (-0.27, 0.03, 1.05), (0.26, -0.08, 1.08)
    wr_l, wr_r = (-0.16, 0.0, 0.92), (0.32, -0.16, 0.95)
    limb(sh_l, el_l, 0.055, 0.045, coat)
    limb(el_l, wr_l, 0.045, 0.035, coat)
    limb(sh_r, el_r, 0.055, 0.045, coat)
    limb(el_r, wr_r, 0.045, 0.035, coat)
    ball(wr_l, 0.035, skin)
    ball(wr_r, 0.035, skin)
    limb((0.33, -0.17, 0.09), (0.31, -0.15, 1.72), 0.012, 0.012, rim, 10)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.05, radius2=0.0, depth=0.16, location=(0.31, -0.15, 1.8))
    _put(bpy.context.object, crystal, smooth=False)
    # Neck and head (about 1/7 of the height), hair falling down the back,
    # a fringe, two ears: the silhouette reads as a character.
    limb((0, 0, 1.33), (0, 0, 1.42), 0.04, 0.035, skin)
    ball((0, -0.01, 1.52), 0.11, skin, (0.92, 0.95, 1.05))
    ball((0, 0.02, 1.55), 0.122, hair, (0.98, 1.0, 1.0))
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.15, radius2=0.09, depth=0.6, location=(0, 0.08, 1.22))
    _put(bpy.context.object, hair).scale = (1.0, 0.55, 1.0)
    for x in (-0.06, 0.0, 0.06):
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.04, radius2=0.0, depth=0.12, location=(x, -0.1, 1.53), rotation=(math.radians(160), 0, 0))
        _put(bpy.context.object, hair)
    for s in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.035, radius2=0.004, depth=0.16, location=(s * 0.08, 0.02, 1.68), rotation=(0, s * math.radians(-20), 0))
        _put(bpy.context.object, hair)
        ball((s * 0.04, -0.105, 1.51), 0.017, eye, (0.8, 0.3, 1.3))

    # Product-photo light: a big soft key from the upper left front, a fill,
    # and a rim from behind on the right for the plastic's edge highlight.
    def area(name, loc, rot, power, size, color=(1, 1, 1)):
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.size, light.color = power, size, color
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location, obj.rotation_euler = loc, rot
    area("key", (-1.6, -2.0, 2.6), (math.radians(50), 0, math.radians(-38)), 420, 1.6)
    area("fill", (2.0, -1.6, 1.0), (math.radians(75), 0, math.radians(50)), 120, 2.0, (0.9, 0.95, 1.0))
    area("rim", (1.2, 2.2, 2.0), (math.radians(-55), 0, math.radians(150)), 300, 1.0)

    # Camera: three-quarter from the front left, a little above, the whole
    # figure and base filling the 1:2 canvas with a small margin.
    cam_data = bpy.data.cameras.new("fig_cam")
    cam_data.lens = 85
    cam = bpy.data.objects.new("fig_cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (-1.75, -5.3, 1.9)
    direction = (0 - cam.location[0], 0 - cam.location[1], 0.95 - cam.location[2])
    from mathutils import Vector
    cam.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    return scene


def render(scene):
    os.makedirs(OUT, exist_ok=True)
    scene.render.filepath = os.path.join(OUT, "figurine_template.png")
    bpy.ops.render.render(write_still=True, scene=scene.name)
    return scene.render.filepath


if __name__ == "__main__":
    render(build())
