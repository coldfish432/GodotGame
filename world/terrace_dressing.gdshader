// The Blender terrace pieces (TerraceDressing) drawn like the terrain around
// them: unshaded, the region's rock texture sampled in world space so pieces
// share the ground's grain and scale, tinted by each piece's flat Blender
// colour. Triplanar, because cliff faces are vertical and a top-down sample
// would streak down them. Shading is the same fixed sun the terrain bakes
// into its vertex colours (TerrainSurface._triangle).
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D background_tex : source_color, filter_nearest_mipmap, repeat_disable;
uniform float world_scale = 12.0;
uniform vec3 tint = vec3(1.0);
varying vec3 world_position;
varying vec3 world_normal;
#include "res://art/terrain_sampling.gdshaderinc"
#include "res://world/field_light.gdshaderinc"
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 weight = pow(abs(world_normal), vec3(4.0));
	weight /= weight.x + weight.y + weight.z;
	vec3 grain = surface_texture(world_position.zy) * weight.x
		+ surface_texture(world_position.xz) * weight.y
		+ surface_texture(world_position.xy) * weight.z;
	float shade = 0.74 + abs(dot(world_normal, normalize(vec3(-0.4, 0.8, -0.4)))) * 0.26;
	ALBEDO = field_lit_px(field_snowed(grain * tint, world_normal, world_position) * shade, world_position, FRAGCOORD.xy);
}
