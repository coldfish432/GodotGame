# build_cliff_rubble_pile.py
#
# Every execute_blender_code call Claude sent over Blender MCP to build
# art/blender/cliff_rubble_pile.blend, verbatim and in order (2026-10-12).
# Each "# --- call N ---" block was one call. Call 1 starts from the scene left by
# build_arched_ramp_segment.py (Camera, Light, arched_ramp_segment).

# --- call 1 ---
# Step 0: start the rubble file from the saved ramp scene — remove the ramp mesh and its
# materials (arched_ramp_segment.blend is already saved), keep Camera and Light.
import bpy
obj = bpy.data.objects.get("arched_ramp_segment")
if obj is not None:
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
bpy.data.orphans_purge(do_recursive=True)
print([o.name for o in bpy.data.objects], [m.name for m in bpy.data.materials])

# --- call 2 ---
# Step 1: rubble_a — the largest stone: icosphere (subdivisions 2) flattened to 0.95 x 0.80 x 0.55,
# turned 20 deg about Z, resting on the ground at the front-left.
import bpy, math

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def flat_material(name, hex_rgb):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    rgb = [srgb_to_linear(int(hex_rgb[i:i + 2], 16) / 255) for i in (0, 2, 4)]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
    mat.diffuse_color = (*rgb, 1.0)
    return mat

light_stone = flat_material("rubble_stone", "6B5E4C")
flat_material("rubble_stone_dark", "4F463A")

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "rubble_a"
d = obj.dimensions.copy()
obj.scale = (0.95 / d.x, 0.80 / d.y, 0.55 / d.z)
obj.rotation_euler = (0.0, 0.0, math.radians(20.0))
obj.data.materials.append(light_stone)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
obj.location = (-0.28, -0.22, 0.55 / 2 - 0.04)
bpy.context.view_layer.update()
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
print(obj.name, tuple(round(v, 3) for v in obj.dimensions), "faces", len(obj.data.polygons),
      "x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 3 ---
# Step 2: rubble_b — second stone, dark: icosphere (subdivisions 2) flattened to 0.85 x 0.70 x 0.50,
# turned -35 deg about Z and tipped 12 deg about Y so it leans into rubble_a, at the back-right.
import bpy, math
dark = bpy.data.materials["rubble_stone_dark"]
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "rubble_b"
d = obj.dimensions.copy()
obj.scale = (0.85 / d.x, 0.70 / d.y, 0.50 / d.z)
obj.rotation_euler = (0.0, math.radians(12.0), math.radians(-35.0))
obj.data.materials.append(dark)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
obj.location = (0.30, 0.25, 0.0)
bpy.context.view_layer.update()
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
obj.location.z -= min(c.z for c in co) + 0.04   # sink 0.04 into the ground like rubble_a
bpy.context.view_layer.update()
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
print(obj.name, tuple(round(v, 3) for v in obj.dimensions), "faces", len(obj.data.polygons),
      "x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 4 ---
# Step 3: rubble_c — small stone on top: icosphere (subdivisions 1) 0.50 x 0.45 x 0.35,
# wedged into the saddle between rubble_a and rubble_b; its peak sets the pile's height (~0.85-0.9).
import bpy, math
light_stone = bpy.data.materials["rubble_stone"]
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "rubble_c"
d = obj.dimensions.copy()
obj.scale = (0.50 / d.x, 0.45 / d.y, 0.35 / d.z)
obj.rotation_euler = (math.radians(8.0), 0.0, math.radians(50.0))
obj.data.materials.append(light_stone)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
obj.location = (-0.05, -0.02, 0.86 - obj.dimensions.z / 2)
bpy.context.view_layer.update()
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
print(obj.name, tuple(round(v, 3) for v in obj.dimensions), "faces", len(obj.data.polygons),
      "x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 5 ---
# Step 3b (fix after look): rubble_c floated — its bottom (0.51) cleared the stones below it,
# leaving a visible gap in the front and right views. Move it over rubble_a's peak and
# lower it until it sinks 0.05 into rubble_a there.
import bpy
from mathutils import Vector
a = bpy.data.objects["rubble_a"]
c = bpy.data.objects["rubble_c"]
peak = max((a.matrix_world @ v.co for v in a.data.vertices), key=lambda p: p.z)
c.location.x, c.location.y = peak.x + 0.05, peak.y + 0.05
bpy.context.view_layer.update()
c_bottom = min((c.matrix_world @ v.co).z for v in c.data.vertices)
c.location.z += (peak.z - 0.05) - c_bottom
bpy.context.view_layer.update()
co = [c.matrix_world @ v.co for v in c.data.vertices]
print("rubble_a peak", tuple(round(v, 3) for v in peak))
print(c.name, "x", round(min(p.x for p in co), 3), round(max(p.x for p in co), 3),
      "y", round(min(p.y for p in co), 3), round(max(p.y for p in co), 3),
      "z", round(min(p.z for p in co), 3), round(max(p.z for p in co), 3))

# --- call 6 ---
# Step 4: join into cliff_rubble_pile, then move the mesh so the bounding box's bottom centre
# is the origin (lowest vertex z = 0, x/y centred), outward normals, count triangles.
import bpy, bmesh
from mathutils import Vector
parts = [bpy.data.objects[n] for n in ("rubble_a", "rubble_b", "rubble_c")]
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
obj = bpy.context.active_object
obj.name = "cliff_rubble_pile"
obj.data.name = "cliff_rubble_pile"
co = [v.co for v in obj.data.vertices]
shift = Vector((-(min(c.x for c in co) + max(c.x for c in co)) / 2,
                -(min(c.y for c in co) + max(c.y for c in co)) / 2,
                -min(c.z for c in co)))
for v in obj.data.vertices:
    v.co += shift
obj.data.update()
obj.location = (0.0, 0.0, 0.0)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")
bm = bmesh.new()
bm.from_mesh(obj.data)
tris = sum(len(f.verts) - 2 for f in bm.faces)
bm.free()
co = [v.co for v in obj.data.vertices]
print("shift", tuple(round(v, 3) for v in shift))
print("location", tuple(obj.location), "rotation", tuple(obj.rotation_euler), "scale", tuple(obj.scale))
print("x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))
print("triangles", tris, "materials", [m.name for m in obj.data.materials])

# --- call 7 ---
# Step 5: save the rubble pile as its own .blend.
import bpy, os
bpy.data.orphans_purge(do_recursive=True)
path = r"D:\CSYE 7370\downfall-godot\art\blender\cliff_rubble_pile.blend"
bpy.ops.wm.save_as_mainfile(filepath=path)
print(bpy.data.filepath, os.path.getsize(path), [o.name for o in bpy.data.objects])
