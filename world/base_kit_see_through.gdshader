// A modelled base piece (基地建模改造案_v1): drawn like a kit piece
// (world/kit_piece.gdshader), lit by the base's light map and its room's
// light strips. Whole at all times: it simply hides whoever stands behind it
// (用户 2026-10-18: 不要虚化；蓝色也不要，直接遮挡).
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float gain = 1.0;
varying vec3 world_normal;
varying vec3 world_position;
#include "res://world/field_light.gdshaderinc"
// The room's lights in strips (the warehouse comes on bank by bank).
#include "res://world/base_room_light.gdshaderinc"
void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float shade = 0.7 + abs(dot(world_normal, normalize(vec3(-0.4, 0.8, -0.4)))) * 0.3;
	ALBEDO = field_lit_px(texture(albedo_tex, UV).rgb * gain * shade, world_position, FRAGCOORD.xy) * room_light(world_position);
}
