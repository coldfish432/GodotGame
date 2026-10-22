// The body of kit_piece.gdshader, shared with kit_piece_cave.gdshader, which
// defines CUTAWAY: a discard anywhere in a shader costs every material that
// uses it its fast depth path (Lungmen fell from 106 to 41 fps).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float gain = 1.0;
// Snow holds on steeper faces too (a conifer's sloping branch tiers).
uniform float snow_bias = 0.0;
// Per-instance colour (MultiMesh use_colors; CityDressing): a building's roof
// takes it in full, its walls a share, so a block of one model is not one grey.
uniform bool use_tint = false;
uniform float wall_tint = 0.35;
// The relief baked from the colour (场景渲染统一改造案_v1 S2); flat without one.
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float normal_depth = 2.0;
// The mine's cave pillars (TerraceDressing._place_cave_pillars): above
// void_from (model metres) the stone fades to black over void_span, and it
// opens round Lappland when it stands in front of her.
uniform float void_from = 1000.0;
// How dark the stone gets up there: dark, its grain still showing (恐怖黎明).
uniform float void_floor = 0.22;
uniform float void_span = 8.0;
uniform float cut_radius = 4.0;
uniform float cut_above = 1.4;
varying vec3 world_normal;
varying vec3 world_position;
varying vec3 tint;
varying float model_height;
#include "res://world/field_light.gdshaderinc"
#include "res://world/cutaway.gdshaderinc"
void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = use_tint ? COLOR.rgb : vec3(1.0);
	model_height = VERTEX.y;
}
void fragment() {
#ifdef CUTAWAY
	if (cut_away(VERTEX, world_position, VIEW_MATRIX, FRAGCOORD.xy, cut_radius, cut_above)) discard;
#endif
	vec3 base = texture(albedo_tex, UV).rgb * gain;
	base *= mix(vec3(1.0), tint, world_normal.y > 0.7 ? 1.0 : wall_tint);
	ALBEDO = field_lit_px(field_snowed_bias(base, world_normal, world_position, snow_bias), world_position, FRAGCOORD.xy);
	ALBEDO *= mix(1.0, void_floor, smoothstep(void_from, void_from + void_span, model_height));
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = 0.72;
	SPECULAR = 0.35;
}
