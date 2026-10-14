shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D background_tex : source_color, filter_nearest_mipmap, repeat_disable;
uniform float world_scale = 28.0;
uniform float brightness = 0.88;
varying vec3 world_position;
varying vec3 world_normal;

#include "res://art/terrain_sampling.gdshaderinc"
#include "res://world/field_light.gdshaderinc"

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 weights = pow(abs(normalize(world_normal)), vec3(6.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 tex = surface_texture(world_position.zy) * weights.x
		+ surface_texture(world_position.xz) * weights.y
		+ surface_texture(world_position.xy) * weights.z;
	// Broad, very subtle value changes prevent the whole background looking
	// like a small repeated patch; there are no height-based contour stripes.
	float variation = 0.96 + 0.04 * sin(world_position.x * 0.11 + sin(world_position.z * 0.07));
	// Snow on the scene dressing's rocks too, in the snowfield (field_snowed).
	ALBEDO = field_lit_px(field_snowed(tex * COLOR.rgb * brightness * variation, normalize(world_normal), world_position), world_position, FRAGCOORD.xy);
	ROUGHNESS = 1.0;
}
