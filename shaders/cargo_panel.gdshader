shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

group_uniforms Surface;
uniform float uv_scale : hint_range(0.25, 8.0, 0.25) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

group_uniforms Response;
uniform float roughness_scale : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0, 0.05) = 1.0;
group_uniforms;

void fragment() {
	vec2 uv = UV * uv_scale;
	ALBEDO = texture(albedo_tex, uv).rgb * tint_color.rgb;
	ROUGHNESS = clamp(texture(roughness_tex, uv).r * roughness_scale, 0.0, 1.0);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
