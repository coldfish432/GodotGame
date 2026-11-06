shader_type spatial;
render_mode unshaded;

uniform sampler2D tex_color : source_color, filter_nearest, repeat_disable;
uniform sampler2D tex_raw : filter_nearest, repeat_disable;
uniform bool use_source_color = true;

void fragment() {
	ALBEDO = use_source_color ? texture(tex_color, UV).rgb : texture(tex_raw, UV).rgb;
}
