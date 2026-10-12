# build_cliff_wall_segment.py
#
# Every execute_blender_code call Claude sent over Blender MCP to build
# art/blender/cliff_wall_segment.blend, verbatim and in order (2026-10-12).
# Each "# --- call N ---" block was one call. Run in order, the blocks rebuild
# the file from Blender's default startup scene.

# --- call 1 ---
# Step 0: clear the default cube; keep Camera and Light for previews.
import bpy
cube = bpy.data.objects.get("Cube")
if cube is not None:
    mesh = cube.data
    bpy.data.objects.remove(cube, do_unlink=True)
    if mesh.users == 0:
        bpy.data.meshes.remove(mesh)
print([o.name for o in bpy.data.objects])

# --- call 2 ---
# Step 1: strata_low — bottom rock stratum, 2.94 x 1.20 x 1.0, front at y = -0.30.
import bpy

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

rock = flat_material("cliff_rock", "443C31")
flat_material("cliff_boulder", "5A4F40")

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.30, 0.50))
obj = bpy.context.active_object
obj.name = "strata_low"
obj.scale = (2.94, 1.20, 1.00)
obj.data.materials.append(rock)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
print(obj.name, tuple(round(v, 3) for v in obj.dimensions), tuple(obj.location))

# --- call 3 ---
# Step 2: strata_mid — middle stratum, 2.75 x 1.00 x 0.9, turned -3 deg about Z, stepped back.
import bpy, math
rock = bpy.data.materials["cliff_rock"]
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.32, 1.40))
obj = bpy.context.active_object
obj.name = "strata_mid"
obj.scale = (2.75, 1.00, 0.90)
obj.rotation_euler = (0.0, 0.0, math.radians(-3.0))
obj.data.materials.append(rock)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
ys = [(obj.matrix_world @ v.co).y for v in obj.data.vertices]
xs = [(obj.matrix_world @ v.co).x for v in obj.data.vertices]
print(obj.name, "x", round(min(xs), 3), round(max(xs), 3), "y", round(min(ys), 3), round(max(ys), 3))

# --- call 4 ---
# Step 3: strata_top — top stratum, 2.90 x 0.90 x 0.45, turned +2 deg about Z, stepped back further.
import bpy, math
rock = bpy.data.materials["cliff_rock"]
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.40, 2.025))
obj = bpy.context.active_object
obj.name = "strata_top"
obj.scale = (2.90, 0.90, 0.45)
obj.rotation_euler = (0.0, 0.0, math.radians(2.0))
obj.data.materials.append(rock)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
print(obj.name, "x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 5 ---
# Step 4: lip_boulder — flattened icosphere (subdivisions 2) on the top stratum's front lip, peak at z = 2.4.
import bpy
mat = bpy.data.materials["cliff_boulder"]
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "lip_boulder"
d = obj.dimensions.copy()
obj.scale = (0.80 / d.x, 0.60 / d.y, 0.35 / d.z)
obj.data.materials.append(mat)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
obj.location = (0.75, 0.15, 2.40 - 0.175)
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
print(obj.name, tuple(round(v, 3) for v in obj.dimensions), "faces", len(obj.data.polygons),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 6 ---
# Step 4b (fix after look): the boulder was buried 0.2 of its 0.35 in strata_top and read as a disc.
# Make it 0.8 x 0.6 x 0.5 and set it on the front lip so it bulges out of the face:
# z 1.9-2.4 (peak still 2.4), front at y = -0.30 (the brief's front limit).
import bpy
obj = bpy.data.objects["lip_boulder"]
d = obj.dimensions.copy()
obj.scale = (0.80 / d.x, 0.60 / d.y, 0.50 / d.z)
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
obj.location = (0.75, 0.0, 2.40 - 0.25)
bpy.context.view_layer.update()
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
print(obj.name, tuple(round(v, 3) for v in obj.dimensions),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 7 ---
# Step 5: join the four parts into one mesh object, origin at the world origin
# (bottom of the face line), transforms applied, normals outward, count triangles.
import bpy, bmesh
parts = [bpy.data.objects[n] for n in ("strata_low", "strata_mid", "strata_top", "lip_boulder")]
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
obj = bpy.context.active_object
obj.name = "cliff_wall_segment"
obj.data.name = "cliff_wall_segment"
obj.location = (0.0, 0.0, 0.0)

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")

bm = bmesh.new()
bm.from_mesh(obj.data)
tris = sum(len(f.verts) - 2 for f in bm.faces)
bm.free()
co = [obj.matrix_world @ v.co for v in obj.data.vertices]
print("objects", [o.name for o in bpy.data.objects])
print("location", tuple(obj.location), "rotation", tuple(obj.rotation_euler), "scale", tuple(obj.scale))
print("x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))
print("triangles", tris, "materials", [m.name for m in obj.data.materials])

# --- call 8 ---
# Step 6: save as its own .blend (no backup .blend1 on this first save).
import bpy, os
path = r"D:\CSYE 7370\downfall-godot\art\blender\cliff_wall_segment.blend"
os.makedirs(os.path.dirname(path), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=path)
print(bpy.data.filepath, os.path.getsize(path))
