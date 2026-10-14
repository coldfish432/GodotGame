// Lamp glass and other self-lit parts of kit pieces: the baked texture at full
// strength, ignoring the field light, so a lamp reads as the source of its pool.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float gain = 1.6;
void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * gain;
}
