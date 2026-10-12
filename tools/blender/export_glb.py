# export_glb.py — export one asset .blend to art/models/<name>.glb (glTF binary, +Y up).
#
# Run headless, once per asset:
#   blender.exe -b art/blender/<name>.blend --python tools/blender/export_glb.py
#
# Only the asset's mesh is exported (the preview Camera and Light stay behind).
# Transforms are already applied in the .blend; the exporter is told to apply
# modifiers too, though none are used.
import os
import bpy

name = os.path.splitext(os.path.basename(bpy.data.filepath))[0]
project = os.path.dirname(os.path.dirname(os.path.dirname(bpy.data.filepath)))
out = os.path.join(project, "art", "models", name + ".glb")
os.makedirs(os.path.dirname(out), exist_ok=True)

obj = bpy.data.objects[name]
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
print("EXPORT", name, "location", tuple(obj.location), "rotation", tuple(obj.rotation_euler),
      "scale", tuple(obj.scale), "dimensions", tuple(round(v, 4) for v in obj.dimensions))

bpy.ops.export_scene.gltf(
    filepath=out,
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=True,
    export_cameras=False,
    export_lights=False,
    export_materials="EXPORT",
)
print("WROTE", out, os.path.getsize(out))
