# build_arched_ramp_segment.py
#
# Every execute_blender_code call Claude sent over Blender MCP to build
# art/blender/arched_ramp_segment.blend, verbatim and in order (2026-10-12).
# Each "# --- call N ---" block was one call. Call 1 starts from the scene left by
# build_cliff_wall_segment.py (Camera, Light, cliff_wall_segment).
#
# Note on call 5's last print: its filter `abs(c.x) < 3.1` also caught the kerbs'
# inner vertices (x = 3.0999…), so its 0.27 is a kerb top, not the road. Call 6
# re-measures the road alone (0.02).

# --- call 1 ---
# Step 0: start the ramp file from the saved cliff scene — remove the cliff mesh and its
# materials (cliff_wall_segment.blend is already saved), keep Camera and Light.
import bpy
obj = bpy.data.objects.get("cliff_wall_segment")
if obj is not None:
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.meshes.remove(mesh)
for name in ("cliff_rock", "cliff_boulder"):
    mat = bpy.data.materials.get(name)
    if mat is not None and mat.users == 0:
        bpy.data.materials.remove(mat)
print([o.name for o in bpy.data.objects], [m.name for m in bpy.data.materials])

# --- call 2 ---
# Step 1: road_body — one plane primitive edited (bmesh) into a solid cambered wedge.
# Footprint 6.8 (x -3.4..3.4) by 6.5 run (y 0..6.5). Top: slope 2.2/6.5 + 0.02 above the
# slope plane + a crown of 0.10 on the centre line, tapered to 0 over the first and last 0.5.
# Bottom flat at z = 0.
import bpy, bmesh

def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def flat_material(name, hex_rgb):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    rgb = [srgb_to_linear(int(hex_rgb[i:i + 2], 16) / 255) for i in (0, 2, 4)]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    mat.diffuse_color = (*rgb, 1.0)
    return mat

RISE, RUN, HALF_W, CROWN, TAPER, CLEAR = 2.2, 6.5, 3.4, 0.10, 0.5, 0.02

def top_z(x, y):
    taper = max(0.0, min(1.0, min(y, RUN - y) / TAPER))
    return RISE * y / RUN + CLEAR + CROWN * (1.0 - abs(x) / HALF_W) * taper

road = flat_material("ramp_road", "988164")
flat_material("ramp_kerb", "6E6A60")

bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "road_body"
bm = bmesh.new()
bm.from_mesh(obj.data)
for v in bm.verts:
    v.co.x = HALF_W if v.co.x > 0 else -HALF_W
    v.co.y = RUN if v.co.y > 0 else 0.0
# One cut across x (the crown line), two cuts along y (taper rows), then move the rows to 0.5 / 6.0.
x_edges = [e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) < 1e-6]
bmesh.ops.subdivide_edges(bm, edges=x_edges, cuts=1, use_grid_fill=True)
bm.edges.ensure_lookup_table()
y_edges = [e for e in bm.edges if abs(e.verts[0].co.x - e.verts[1].co.x) < 1e-6]
bmesh.ops.subdivide_edges(bm, edges=y_edges, cuts=2, use_grid_fill=True)
for v in bm.verts:
    if 0.1 < v.co.y < RUN / 2:
        v.co.y = TAPER
    elif RUN / 2 < v.co.y < RUN - 0.1:
        v.co.y = RUN - TAPER
    v.co.z = top_z(v.co.x, v.co.y)
# Extrude the top down into a solid with a flat bottom at z = 0.
top_faces = list(bm.faces)
ext = bmesh.ops.extrude_face_region(bm, geom=top_faces)
for v in [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]:
    v.co.z = 0.0
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(obj.data)
bm.free()
obj.data.update()
obj.data.materials.append(road)
co = [v.co for v in obj.data.vertices]
print(obj.name, "verts", len(co), "faces", len(obj.data.polygons),
      "x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))
print("rows y", sorted({round(c.y, 3) for c in co}), "cols x", sorted({round(c.x, 3) for c in co}))

# --- call 3 ---
# Step 2: kerb_left — one cube primitive edited so its bottom lies 0.02 above the slope plane,
# its top 0.25 above that, ends vertical. 0.3 wide (x -3.4..-3.1), run 0..6.5.
import bpy, bmesh
RISE, RUN, CLEAR, KERB_W, KERB_H, HALF_W = 2.2, 6.5, 0.02, 0.30, 0.25, 3.4
kerb = bpy.data.materials["ramp_kerb"]
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "kerb_left"
bm = bmesh.new()
bm.from_mesh(obj.data)
for v in bm.verts:
    v.co.x = -HALF_W if v.co.x < 0 else -HALF_W + KERB_W
    v.co.y = 0.0 if v.co.y < 0 else RUN
    v.co.z = RISE * v.co.y / RUN + CLEAR + (KERB_H if v.co.z > 0 else 0.0)
bm.to_mesh(obj.data)
bm.free()
obj.data.update()
obj.data.materials.append(kerb)
co = [v.co for v in obj.data.vertices]
print(obj.name, "x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 4 ---
# Step 3: kerb_right — mirror of kerb_left: x 3.1..3.4.
import bpy, bmesh
RISE, RUN, CLEAR, KERB_W, KERB_H, HALF_W = 2.2, 6.5, 0.02, 0.30, 0.25, 3.4
kerb = bpy.data.materials["ramp_kerb"]
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "kerb_right"
bm = bmesh.new()
bm.from_mesh(obj.data)
for v in bm.verts:
    v.co.x = HALF_W if v.co.x > 0 else HALF_W - KERB_W
    v.co.y = 0.0 if v.co.y < 0 else RUN
    v.co.z = RISE * v.co.y / RUN + CLEAR + (KERB_H if v.co.z > 0 else 0.0)
bm.to_mesh(obj.data)
bm.free()
obj.data.update()
obj.data.materials.append(kerb)
co = [v.co for v in obj.data.vertices]
print(obj.name, "x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))

# --- call 5 ---
# Step 4: join into one object arched_ramp_segment (origin = low-end bottom edge centre),
# outward normals, and check F4 (slope <= 19 deg; no top vertex below slope plane + 0.02).
import bpy, bmesh, math
RISE, RUN, CLEAR = 2.2, 6.5, 0.02
parts = [bpy.data.objects[n] for n in ("road_body", "kerb_left", "kerb_right")]
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
obj = bpy.context.active_object
obj.name = "arched_ramp_segment"
obj.data.name = "arched_ramp_segment"
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode="OBJECT")

bm = bmesh.new()
bm.from_mesh(obj.data)
tris = sum(len(f.verts) - 2 for f in bm.faces)
bm.free()
co = [v.co for v in obj.data.vertices]
raised = [c for c in co if c.z > 1e-6]
worst = min(c.z - (RISE * c.y / RUN + CLEAR) for c in raised)
edge = [c for c in co if abs(abs(c.x) - 3.4) < 1e-6 and c.z > 1e-6 and c.z < RISE * c.y / RUN + 0.05]
slope = math.degrees(math.atan2(max(c.z for c in edge) - min(c.z for c in edge),
                                max(c.y for c in edge) - min(c.y for c in edge)))
centre_low = max(c.z for c in co if abs(c.x) < 1e-6 and abs(c.y - 0.5) < 1e-6)
print("location", tuple(obj.location), "rotation", tuple(obj.rotation_euler), "scale", tuple(obj.scale))
print("x", round(min(c.x for c in co), 3), round(max(c.x for c in co), 3),
      "y", round(min(c.y for c in co), 3), round(max(c.y for c in co), 3),
      "z", round(min(c.z for c in co), 3), round(max(c.z for c in co), 3))
print("triangles", tris, "materials", [m.name for m in obj.data.materials])
print("edge slope deg", round(slope, 2), "min clearance above slope plane", round(worst + CLEAR, 4))
print("crown at y=0.5 centre minus edge", round(centre_low - (RISE * 0.5 / RUN + CLEAR), 4))
print("low edge at y=0: max z", round(max(c.z for c in co if abs(c.y) < 1e-6 and abs(c.x) < 3.1), 4))

# --- call 6 ---
# Step 5: drop data left over from the cliff file, then save the ramp as its own .blend.
import bpy, os
bpy.data.orphans_purge(do_recursive=True)
road_z0 = max(v.co.z for v in bpy.data.objects["arched_ramp_segment"].data.vertices
              if abs(v.co.y) < 1e-6 and abs(v.co.x) < 3.0)
print("road surface height at the low edge", round(road_z0, 4))
print("materials", [m.name for m in bpy.data.materials])
path = r"D:\CSYE 7370\downfall-godot\art\blender\arched_ramp_segment.blend"
bpy.ops.wm.save_as_mainfile(filepath=path)
print(bpy.data.filepath, os.path.getsize(path))

# --- manual edit by the author (not code) ---
# 2026-10-12: the author opened this file in Blender and, by hand in Edit Mode,
# selected each kerb (L) and moved it outward along X by 0.1 m (G X 0.1 / G X -0.1),
# then saved (Ctrl+S). Overall width 6.8 -> 7.0. Reason: bury the kerb's outer edge
# 0.1 into the corridor's rock bank so the seam is covered.

# --- call 7 ---
# Verify the author's manual edit (read-only): kerb positions per connected piece, file saved state.
import bpy, bmesh, os
obj = bpy.data.objects["arched_ramp_segment"]
print("file", bpy.data.filepath, "dirty", bpy.data.is_dirty, "mode", obj.mode)
bm = bmesh.new()
bm.from_mesh(obj.data)
bm.verts.ensure_lookup_table()
seen, pieces = set(), []
for v in bm.verts:
    if v.index in seen:
        continue
    stack, island = [v], []
    seen.add(v.index)
    while stack:
        cur = stack.pop()
        island.append(cur)
        for e in cur.link_edges:
            o = e.other_vert(cur)
            if o.index not in seen:
                seen.add(o.index)
                stack.append(o)
    xs = [p.co.x for p in island]
    pieces.append((len(island), round(min(xs), 4), round(max(xs), 4), round(sum(xs) / len(xs), 4)))
bm.free()
for p in sorted(pieces, key=lambda t: t[3]):
    print("piece verts %d  x %.4f .. %.4f  median x %.4f" % p)
for f in ("arched_ramp_segment.blend", "arched_ramp_segment.blend1"):
    path = os.path.join(r"D:\CSYE 7370\downfall-godot\art\blender", f)
    print(f, os.path.exists(path), os.path.getsize(path) if os.path.exists(path) else "")
