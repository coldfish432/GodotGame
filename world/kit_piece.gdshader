// Terrace kit pieces with baked textures (tools/blender/kit): the bake already
// holds colour and ambient occlusion, so the piece is drawn unshaded like the
// terrain, with the same fixed sun the terrain bakes into its vertex colours
// (TerrainSurface._triangle) for the facets to read.
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float gain = 1.0;
// Snow holds on steeper faces too (a conifer's sloping branch tiers).
uniform float snow_bias = 0.0;
varying vec3 world_normal;
varying vec3 world_position;
#include "res://world/field_light.gdshaderinc"
void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float shade = 0.7 + abs(dot(world_normal, normalize(vec3(-0.4, 0.8, -0.4)))) * 0.3;
	ALBEDO = field_lit_px(field_snowed_bias(texture(albedo_tex, UV).rgb * gain, world_normal, world_position, snow_bias) * shade, world_position, FRAGCOORD.xy);
}
