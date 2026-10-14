"""Mine cliff wall segments, three variants: art/kit/mine_cliff_{a,b,c}.glb.

Same footprint and origin as the Assignment 3 cliff_wall_segment, so it drops
into TerraceDressing in its place: about 3.0 wide, the face line at y = 0 with
at most ~0.4 of rock in front of it (Blender -Y, the low floor) and the rest
buried behind; 2.4–2.6 tall so one tier (2.2) is covered from 0.1 below the low
floor to above the upper rim.

Look (chernobog mine, matching terrain_surface.gd's mine palette): stacked,
slightly mis-set strata of dark brown rock with lumpy faces and cracks, darker
bands between layers, a dirty foot, a dusty top, a few boulders on the lip and
at the foot, and sparse orange Originium flecks.
"""
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402


def rock_material(name, seed):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = kit.principled(nodes)
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 3.7, seed * 1.9, 0.0)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    vec = mapping.outputs["Vector"]

    # Base rock: mottled browns.
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.2
    noise.inputs["Detail"].default_value = 8.0
    noise.inputs["Roughness"].default_value = 0.62
    links.new(vec, noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.32
    ramp.color_ramp.elements[0].color = kit.srgb("2c251d")
    ramp.color_ramp.elements[1].position = 0.78
    ramp.color_ramp.elements[1].color = kit.srgb("6e5d48")
    mid = ramp.color_ramp.elements.new(0.55)
    mid.color = kit.srgb("4a3e30")
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])

    # Strata lines: dark bands running along the wall.
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "Z"
    wave.inputs["Scale"].default_value = 1.6
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 3.0
    links.new(vec, wave.inputs["Vector"])
    band = nodes.new("ShaderNodeMapRange")
    band.inputs["From Min"].default_value = 0.0
    band.inputs["From Max"].default_value = 0.35
    band.inputs["To Min"].default_value = 0.55
    band.inputs["To Max"].default_value = 1.0
    links.new(wave.outputs["Fac"], band.inputs["Value"])

    # Cracks: voronoi edges on noise-warped coordinates, so they wander like
    # fractures instead of tiling like paving; a coarse and a fine set.
    warp_noise = nodes.new("ShaderNodeTexNoise")
    warp_noise.inputs["Scale"].default_value = 1.4
    warp_noise.inputs["Detail"].default_value = 4.0
    links.new(vec, warp_noise.inputs["Vector"])
    warp_scale = nodes.new("ShaderNodeVectorMath")
    warp_scale.operation = "SCALE"
    warp_scale.inputs["Scale"].default_value = 0.9
    links.new(warp_noise.outputs["Color"], warp_scale.inputs[0])
    warped = nodes.new("ShaderNodeVectorMath")
    warped.operation = "ADD"
    links.new(vec, warped.inputs[0])
    links.new(warp_scale.outputs["Vector"], warped.inputs[1])
    stretch = nodes.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (1.0, 1.0, 2.2)  # fractures run more across than down
    links.new(warped.outputs["Vector"], stretch.inputs["Vector"])
    crack_parts = []
    for scale_value, width, floor in ((1.6, 0.035, 0.45), (4.5, 0.025, 0.72)):
        cracks = nodes.new("ShaderNodeTexVoronoi")
        cracks.feature = "DISTANCE_TO_EDGE"
        cracks.inputs["Scale"].default_value = scale_value
        cracks.inputs["Randomness"].default_value = 1.0
        links.new(stretch.outputs["Vector"], cracks.inputs["Vector"])
        part = nodes.new("ShaderNodeMapRange")
        part.inputs["From Min"].default_value = 0.0
        part.inputs["From Max"].default_value = width
        part.inputs["To Min"].default_value = floor
        part.inputs["To Max"].default_value = 1.0
        links.new(cracks.outputs["Distance"], part.inputs["Value"])
        crack_parts.append(part)
    crack = nodes.new("ShaderNodeMath")
    crack.operation = "MULTIPLY"
    links.new(crack_parts[0].outputs["Result"], crack.inputs[0])
    links.new(crack_parts[1].outputs["Result"], crack.inputs[1])

    # Height: dirty foot, dusty top.
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Object"], xyz.inputs["Vector"])
    foot = nodes.new("ShaderNodeMapRange")
    foot.inputs["From Min"].default_value = 0.0
    foot.inputs["From Max"].default_value = 0.6
    foot.inputs["To Min"].default_value = 0.6
    foot.inputs["To Max"].default_value = 1.0
    links.new(xyz.outputs["Z"], foot.inputs["Value"])
    dust = nodes.new("ShaderNodeMapRange")
    dust.inputs["From Min"].default_value = 2.05
    dust.inputs["From Max"].default_value = 2.5
    dust.inputs["To Min"].default_value = 0.0
    dust.inputs["To Max"].default_value = 0.2
    links.new(xyz.outputs["Z"], dust.inputs["Value"])

    shade = nodes.new("ShaderNodeMath")
    shade.operation = "MULTIPLY"
    links.new(band.outputs["Result"], shade.inputs[0])
    links.new(crack.outputs["Value"], shade.inputs[1])
    shade2 = nodes.new("ShaderNodeMath")
    shade2.operation = "MULTIPLY"
    links.new(shade.outputs["Value"], shade2.inputs[0])
    links.new(foot.outputs["Result"], shade2.inputs[1])
    darkened = nodes.new("ShaderNodeMix")
    darkened.data_type = "RGBA"
    darkened.blend_type = "MULTIPLY"
    darkened.inputs["Factor"].default_value = 1.0
    links.new(ramp.outputs["Color"], darkened.inputs["A"])
    links.new(shade2.outputs["Value"], darkened.inputs["B"])
    dusted = nodes.new("ShaderNodeMix")
    dusted.data_type = "RGBA"
    links.new(dust.outputs["Result"], dusted.inputs["Factor"])
    links.new(darkened.outputs["Result"], dusted.inputs["A"])
    dusted.inputs["B"].default_value = kit.srgb("8a7a63")

    # Originium flecks: small voronoi cells, masked to a few patches.
    flecks = nodes.new("ShaderNodeTexVoronoi")
    flecks.inputs["Scale"].default_value = 9.0
    links.new(vec, flecks.inputs["Vector"])
    fleck = nodes.new("ShaderNodeMapRange")
    fleck.inputs["From Min"].default_value = 0.08
    fleck.inputs["From Max"].default_value = 0.04
    links.new(flecks.outputs["Distance"], fleck.inputs["Value"])
    patch = nodes.new("ShaderNodeTexNoise")
    patch.inputs["Scale"].default_value = 0.9
    links.new(vec, patch.inputs["Vector"])
    patch_mask = nodes.new("ShaderNodeMapRange")
    patch_mask.inputs["From Min"].default_value = 0.62
    patch_mask.inputs["From Max"].default_value = 0.7
    links.new(patch.outputs["Fac"], patch_mask.inputs["Value"])
    fleck_mask = nodes.new("ShaderNodeMath")
    fleck_mask.operation = "MULTIPLY"
    links.new(fleck.outputs["Result"], fleck_mask.inputs[0])
    links.new(patch_mask.outputs["Result"], fleck_mask.inputs[1])
    glowing = nodes.new("ShaderNodeMix")
    glowing.data_type = "RGBA"
    links.new(fleck_mask.outputs["Value"], glowing.inputs["Factor"])
    links.new(dusted.outputs["Result"], glowing.inputs["A"])
    glowing.inputs["B"].default_value = kit.srgb("d07a2c")

    links.new(glowing.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def build(variant, seed):
    kit.reset_scene()
    random.seed(seed)
    parts = []
    z = 0.0
    face = -0.32
    layers = random.randint(3, 4)
    heights = [random.uniform(0.7, 1.0) for _ in range(layers)]
    scale = 2.55 / sum(heights)
    heights = [h * scale for h in heights]
    for i, height in enumerate(heights):
        width = random.uniform(2.85, 3.15)
        depth = random.uniform(1.15, 1.35)
        front = face + i * random.uniform(0.04, 0.12)  # each layer sits a little back
        slab = kit.box(f"stratum{i}", (width, depth, height + 0.08),
                       (random.uniform(-0.12, 0.12), front + depth / 2, z + height / 2),
                       (random.uniform(-0.05, 0.05), random.uniform(-0.04, 0.04), random.uniform(-0.06, 0.06)))
        kit.roughen(slab, seed * 10 + i, strength=0.16, size=0.35, bevel=0.07, subdiv=3, crack_strength=0.09, bulge=0.45, bulge_size=1.1)
        parts.append(slab)
        z += height
    for i in range(random.randint(1, 3)):
        lip = kit.rock(f"lip{i}", random.uniform(0.22, 0.38),
                       (random.uniform(-1.2, 1.2), random.uniform(-0.15, 0.25), 2.45),
                       (random.uniform(1.0, 1.5), random.uniform(0.8, 1.1), random.uniform(0.6, 0.85)))
        kit.roughen(lip, seed * 10 + 20 + i, strength=0.12, size=0.25, subdiv=1)
        parts.append(lip)
    for i in range(random.randint(1, 2)):
        foot = kit.rock(f"foot{i}", random.uniform(0.2, 0.32),
                        (random.uniform(-1.1, 1.1), face - 0.05, 0.12),
                        (random.uniform(1.0, 1.4), random.uniform(0.8, 1.0), random.uniform(0.55, 0.75)))
        kit.roughen(foot, seed * 10 + 30 + i, strength=0.1, size=0.25, subdiv=1)
        parts.append(foot)
    obj = kit.join(parts, f"mine_cliff_{variant}")
    kit.clip_below(obj, 0.0)
    # 3.1 wide so neighbours 2.6 apart overlap; 2.5 tall to cover a tier from
    # 0.1 under the low floor to 0.2 over the rim. Nothing further than 0.45
    # in front of the face line: the collision wall stands on that line, and
    # rock past this would be walked into.
    kit.decimate(obj, 2600)
    # 3.6 wide so neighbours 2.6 apart overlap a full metre and read as one
    # face, not a row of blocks; 2.4 tall to cover a tier from 0.1 under the
    # low floor to just over the rim. Nothing further than 0.45 in front of
    # the face line: the collision wall stands on that line, and rock past
    # this would be walked into.
    kit.fit(obj, width=3.6, height=2.4, front_limit=-0.45)
    # Behind the face the top slopes down into the upper terrace, so the
    # piece does not stand on the terrace floor as a slab.
    for v in obj.data.vertices:
        if v.co.z > 1.8 and v.co.y > 0.0:
            v.co.z = max(1.8, v.co.z - v.co.y * 0.45)
    obj.data.update()
    kit.finish_mesh(obj)
    procedural = rock_material(f"mine_cliff_{variant}_procedural", seed)
    obj.data.materials.clear()
    obj.data.materials.append(procedural)
    image = kit.bake_texture(obj, procedural, f"mine_cliff_{variant}")
    obj.data.materials.clear()
    obj.data.materials.append(kit.baked_material(f"mine_cliff_{variant}", image))
    kit.report(obj, f"mine_cliff_{variant}")
    path = kit.export(obj, f"mine_cliff_{variant}")
    kit.render_preview(obj, f"mine_cliff_{variant}")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(kit.OUT_DIR, "blend", f"mine_cliff_{variant}.blend"))
    print("EXPORTED", path)


if __name__ == "__main__":
    for variant, seed in (("a", 11), ("b", 23), ("c", 37)):
        build(variant, seed)
