"""Rock swatch textures for the swept cliff faces: art/kit/textures/<region>_rock_swatch.png.

The cliff face is no longer a row of segments; world/cliff_face.gd sweeps one
continuous surface along each cliff line and samples this swatch triplanar in
world space (mirrored, with patch offsets, art/terrain_sampling.gdshaderinc),
so there is no seam to hide. The swatch is the same procedural rock as the
mine cliff pieces (build_mine_cliff.rock_material), baked flat onto a 4 x 4 m
vertical plane so its strata run horizontally: texture v is world height.
"""
import os
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
from build_mine_cliff import rock_material  # noqa: E402


def bake_swatch(region, seed, size=4.0, resolution=2048):
    kit.reset_scene()
    # Vertical plane in Blender XZ; object Z is height, as on a cliff.
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, size / 2), rotation=(1.5707963, 0, 0))
    plane = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    material = rock_material(f"{region}_swatch", seed)
    plane.data.materials.append(material)
    scene = bpy.context.scene
    target = bpy.data.images.new(f"{region}_rock_swatch", resolution, resolution)
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = target
    material.node_tree.nodes.active = node
    plane.select_set(True)
    bpy.context.view_layer.objects.active = plane
    scene.render.bake.margin = 0
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    # The plane's unwrap lays its height along u; transpose so v is height,
    # which is what the cliff shader's side projections read.
    import numpy
    pixels = numpy.array(target.pixels[:]).reshape(resolution, resolution, 4)
    target.pixels = numpy.ascontiguousarray(pixels.transpose(1, 0, 2)).ravel()
    path = os.path.join(kit.OUT_DIR, "textures", f"{region}_rock_swatch.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    target.filepath_raw = path
    target.file_format = "PNG"
    target.save()
    print("SWATCH", path)


bake_swatch("mine", 5)
