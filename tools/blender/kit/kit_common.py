"""Shared helpers for the terrace kit (art/kit/*.glb).

Run from tools/blender/kit/build_*.py inside Blender (background is fine):

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_mine_cliff.py

Every piece follows the conventions of the Assignment 3 assets
(a3/CHANGE-BRIEF.md) so TerraceDressing can place either:
Blender Z-up, metres, exported glTF +Y up; a cliff's origin sits on its face
line at the foot, front towards Blender -Y (Godot +Z).

Pieces are no longer held to the assignment's limits. They are subdivided,
displaced with procedural noise, decimated to a modest budget, and textured by
baking a procedural material (colour and ambient occlusion, multiplied) to one
image per piece, embedded in the .glb.
"""
import math
import os
import random

import bpy
import bmesh

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT_DIR = os.path.join(REPO, "art", "kit")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    return scene


def principled(nodes):
    """The material's Principled BSDF. Looked up by type: a Blender with a
    translated interface names new nodes in its own language."""
    return next(n for n in nodes if n.bl_idname == "ShaderNodeBsdfPrincipled")


def srgb(hex_rgb):
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(lin(int(hex_rgb[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


def box(name, size, location, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def rock(name, radius, location, squash=(1.0, 1.0, 1.0), subdivisions=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = squash
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def roughen(obj, seed, strength, size, bevel=0.0, subdiv=3, crack_strength=0.0, bulge=0.0, bulge_size=1.3):
    """Bevel, subdivide and displace with clouds (lumps) and voronoi (cracks)."""
    if bevel > 0.0:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    mod = obj.modifiers.new("subdiv", "SUBSURF")
    mod.subdivision_type = "SIMPLE"
    mod.levels = subdiv
    mod.render_levels = subdiv
    if bulge > 0.0:
        # Large, slow swelling first: breaks the box outline into a rock mass.
        swell = bpy.data.textures.new(f"{obj.name}_swell", "CLOUDS")
        swell.noise_scale = bulge_size
        swell.noise_depth = 1
        disp = obj.modifiers.new("swell", "DISPLACE")
        disp.texture = swell
        disp.strength = bulge
        disp.mid_level = 0.5
        disp.texture_coords = "GLOBAL"
    lumps = bpy.data.textures.new(f"{obj.name}_lumps", "CLOUDS")
    lumps.noise_scale = size
    lumps.noise_depth = 2
    disp = obj.modifiers.new("lumps", "DISPLACE")
    disp.texture = lumps
    disp.strength = strength
    disp.mid_level = 0.5
    disp.texture_coords = "GLOBAL"
    if crack_strength > 0.0:
        cracks = bpy.data.textures.new(f"{obj.name}_cracks", "VORONOI")
        cracks.noise_scale = size * 0.7
        cracks.distance_metric = "DISTANCE"
        cracks.color_mode = "INTENSITY"
        disp = obj.modifiers.new("cracks", "DISPLACE")
        disp.texture = cracks
        disp.strength = crack_strength
        disp.mid_level = 0.0
        disp.texture_coords = "GLOBAL"
    # The noise is sampled in world space, so each variant is moved by a
    # seed-dependent offset while its modifiers are applied, then moved back:
    # same shape budget, different rock.
    random.seed(seed)
    shift = (random.uniform(-500, 500), random.uniform(-500, 500), random.uniform(-500, 500))
    obj.location = (obj.location.x + shift[0], obj.location.y + shift[1], obj.location.z + shift[2])
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.location = (obj.location.x - shift[0], obj.location.y - shift[1], obj.location.z - shift[2])
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name
    # The join keeps the first part's location as the object origin; the
    # piece's origin has to be the world origin (its foot on the face line).
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def decimate(obj, target_triangles):
    """Collapse to about target_triangles (counted after triangulation)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    tri = obj.modifiers.new("triangulate", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    tris = triangle_count(obj)
    if tris > target_triangles:
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = target_triangles / tris
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return triangle_count(obj)


def fit(obj, width=None, height=None, front_limit=None):
    """Scale the joined mesh so its x span is `width` and its top is `height`
    (displacement makes both drift), keeping the origin where it is, then keep
    every vertex behind `front_limit` in y."""
    xs = [v.co.x for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    sx = width / (max(xs) - min(xs)) if width else 1.0
    cx = (max(xs) + min(xs)) * 0.5
    sz = height / max(zs) if height else 1.0
    for v in obj.data.vertices:
        v.co.x = (v.co.x - cx) * sx
        v.co.z = v.co.z * sz
        if front_limit is not None:
            v.co.y = max(v.co.y, front_limit)
    obj.data.update()


def render_preview(obj, name, ortho=4.2):
    """Render the piece from the game's follow camera (16 up, 10 back: 58 deg),
    orthographic, to art/kit/preview/<name>.png."""
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("preview_cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho
    cam = bpy.data.objects.new("preview_cam", cam_data)
    scene.collection.objects.link(cam)
    # Godot's camera offset (0, 16, -10) in Godot = Blender (0, 10, 16)... the
    # front of a piece faces Blender -Y, i.e. towards the camera at -Y.
    cam.location = (0.0, -10.0 * 0.4, 16.0 * 0.4 + 1.1)
    target = (0.0, 0.0, 1.1)
    direction = [target[i] - cam.location[i] for i in range(3)]
    import mathutils
    cam.rotation_euler = mathutils.Vector(direction).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    sun = bpy.data.lights.new("preview_sun", "SUN")
    sun.energy = 3.0
    sun_obj = bpy.data.objects.new("preview_sun", sun)
    sun_obj.rotation_euler = (0.9, 0.3, 0.6)
    scene.collection.objects.link(sun_obj)
    scene.world = scene.world or bpy.data.worlds.new("w")
    scene.world.color = (0.25, 0.24, 0.22)
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.filepath = os.path.join(OUT_DIR, "preview", f"{name}.png")
    scene.cycles.samples = 16
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(sun_obj)


def triangle_count(obj):
    mesh = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    return count


def clip_below(obj, z=0.0):
    """Flatten anything that the displacement pushed under the foot."""
    for v in obj.data.vertices:
        if v.co.z < z:
            v.co.z = z


def finish_mesh(obj):
    # Only this object: edit mode takes in every selected mesh, and unwrapping
    # an already baked part again would scramble its texture.
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_flat()


def bake_texture(obj, material, name, resolution=1024):
    """Bake the procedural material's colour and AO, store colour * AO."""
    scene = bpy.context.scene
    tree = material.node_tree
    target = bpy.data.images.new(f"{name}_bake", resolution, resolution)
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = target
    tree.nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    scene.render.bake.margin = 8
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    colour = list(target.pixels)
    scene.cycles.samples = 64
    bpy.ops.object.bake(type="AO")
    ao = list(target.pixels)
    scene.cycles.samples = 24
    out = [0.0] * len(colour)
    for i in range(0, len(colour), 4):
        # Soften the AO: full-strength contact shadow reads as dirt at pixel size.
        a = 0.45 + 0.55 * ao[i]
        out[i] = colour[i] * a
        out[i + 1] = colour[i + 1] * a
        out[i + 2] = colour[i + 2] * a
        out[i + 3] = 1.0
    final = bpy.data.images.new(name, resolution, resolution)
    final.pixels = out
    final.filepath_raw = os.path.join(OUT_DIR, "textures", f"{name}.png")
    final.file_format = "PNG"
    os.makedirs(os.path.dirname(final.filepath_raw), exist_ok=True)
    final.save()
    tree.nodes.remove(node)
    # 场景渲染统一改造案_v1 S2: a normal map from the colour's own relief, so
    # seams sink and rivets stand under the base's real lights. Lamps' glass
    # (parts named "glow") stays flat.
    if "glow" not in name:
        height_normal(colour, resolution, f"{name}_normal")
    return final


## How steep the relief from colour is: dark seams sink, light rims rise.
NORMAL_STRENGTH = 3.0


def height_normal(colour, resolution, name, strength=None):
    """A tangent-space normal map (OpenGL, green up, as glTF wants) from the
    baked colour's luminance treated as height, saved next to the colour."""
    import numpy as np
    s = NORMAL_STRENGTH if strength is None else strength
    px = np.asarray(colour, dtype=np.float32).reshape(resolution, resolution, 4)
    lum = px[..., 0] * 0.299 + px[..., 1] * 0.587 + px[..., 2] * 0.114
    # A light blur so single noisy texels do not read as pits.
    lum = (lum + np.roll(lum, 1, 0) + np.roll(lum, -1, 0) + np.roll(lum, 1, 1) + np.roll(lum, -1, 1)) / 5.0
    dx = (np.roll(lum, -1, 1) - np.roll(lum, 1, 1)) * 0.5 * s
    dy = (np.roll(lum, -1, 0) - np.roll(lum, 1, 0)) * 0.5 * s   # rows run bottom to top
    n = np.stack([-dx, -dy, np.ones_like(lum)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    rgba = np.concatenate([n * 0.5 + 0.5, np.ones((resolution, resolution, 1), np.float32)], axis=-1)
    stale = bpy.data.images.get(name)   # a rebuild in the same session
    if stale is not None: bpy.data.images.remove(stale)
    image = bpy.data.images.new(name, resolution, resolution, float_buffer=False)
    image.colorspace_settings.name = "Non-Color"
    image.pixels = rgba.ravel().tolist()
    image.filepath_raw = os.path.join(OUT_DIR, "textures", f"{name}.png")
    image.file_format = "PNG"
    image.save()
    return image


def baked_material(name, image):
    """The export material: just the baked image as base colour."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = principled(tree.nodes)
    tex = tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    normal = bpy.data.images.get(f"{name}_normal")
    if normal is not None:
        ntex = tree.nodes.new("ShaderNodeTexImage")
        ntex.image = normal
        ntex.interpolation = "Linear"
        nmap = tree.nodes.new("ShaderNodeNormalMap")
        tree.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        tree.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def save_blend(obj, name):
    """The piece's own .blend under art/kit/blend: only its datablocks, so a
    live Blender's open file (other scenes, its path) is left as it was."""
    path = os.path.join(OUT_DIR, "blend", f"{name}.blend")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.data.libraries.write(path, {obj}, fake_user=True)


def export(obj, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    # A live Blender has other scenes, with their own selections: export the
    # active scene only (touching another scene's selection crashes 5.4).
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_image_format="AUTO", use_active_scene=True)
    blend_dir = os.path.join(REPO, "art", "kit", "blend")
    os.makedirs(blend_dir, exist_ok=True)
    return path


def report(obj, name):
    dims = obj.dimensions
    lo = [min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in obj.data.vertices) for i in range(3)]
    print(f"KIT {name}: tris {triangle_count(obj)} dims {dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} "
          f"x[{lo[0]:.2f},{hi[0]:.2f}] y[{lo[1]:.2f},{hi[1]:.2f}] z[{lo[2]:.2f},{hi[2]:.2f}]")


def publish(obj, procedural, name, resolution=1024, preview_scale=4.2):
    """UV, bake `procedural` to one texture, swap in the baked material, then
    export the .glb, save the .blend and render the preview."""
    finish_mesh(obj)
    obj.data.materials.clear()
    obj.data.materials.append(procedural)
    image = bake_texture(obj, procedural, name, resolution)
    obj.data.materials.clear()
    obj.data.materials.append(baked_material(name, image))
    report(obj, name)
    path = export(obj, name)
    render_preview(obj, name, preview_scale)
    save_blend(obj, name)
    print("EXPORTED", path)
    return path


def publish_parts(pieces, name, preview_scale=4.2, resolution=512):
    """Several parts, each baked from its own procedural material to its own
    texture, joined into one object with one baked material per part. A part
    named "glow" is drawn self-lit in the game (TerraceDressing: kit_glow)."""
    baked = []
    for obj, mat, part in pieces:
        finish_mesh(obj)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        image = bake_texture(obj, mat, f"{name}_{part}", resolution)
        obj.data.materials.clear()
        obj.data.materials.append(baked_material(f"{name}_{part}", image))
        baked.append(obj)
    whole = join(baked, name)
    report(whole, name)
    path = export(whole, name)
    render_preview(whole, name, preview_scale)
    save_blend(whole, name)
    return path


def flat_material(name, hex_rgb, noise_scale=0.0, darker=None):
    """A flat colour, optionally mottled towards `darker` by noise."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = principled(nodes)
    if noise_scale <= 0.0 or darker is None:
        bsdf.inputs["Base Color"].default_value = srgb(hex_rgb)
        return mat
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    links.new(noise.outputs["Fac"], mix.inputs["Factor"])
    mix.inputs["A"].default_value = srgb(darker)
    mix.inputs["B"].default_value = srgb(hex_rgb)
    links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mat
