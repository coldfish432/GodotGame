// A modelled base piece (基地建模改造案_v1), lit by the scene's real lights
// (场景渲染统一改造案_v1 §4.2: the base's lamps are lights now, not a light
// texture) and dimmed by its room's light strips. Whole at all times: it
// simply hides whoever stands behind it (用户 2026-10-18: 不要虚化；蓝色也不要，直接遮挡).
shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float gain = 1.0;
// The relief baked from the colour (场景渲染统一改造案_v1 S2); flat without one.
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float normal_depth = 2.0;
uniform float roughness = 0.62;
uniform float metallic = 0.15;
varying vec3 world_position;
// The room's lights in strips (the warehouse comes on bank by bank).
#include "res://world/base_room_light.gdshaderinc"
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * gain * room_light(world_position);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.45;
}
