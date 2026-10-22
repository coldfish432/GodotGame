// The swept cliff faces (CliffFace): one continuous surface per cliff line,
// textured with a Blender-baked rock swatch sampled triplanar in world space
// through the terrain's mirrored, patch-offset sampler, so the grain carries
// across the whole face with no tile seam. Height runs along the swatch's v
// on both side projections, so its strata lie level. Unshaded like the
// terrain; vertex colour holds the sweep's occlusion (foot, ledge undersides),
// and the same fixed sun as TerrainSurface._triangle shades the facets.
shader_type spatial;
render_mode cull_disabled;
#include "res://world/cliff_face.gdshaderinc"
