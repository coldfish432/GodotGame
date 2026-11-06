shader_type spatial;
// A boss's last frame as a billboard of its own (Boss演出策划案 v0.2 §1.3 溶/褪):
// the cell is copied from the sprite's atlas, then fades to a colour (褪: 爱国者
// to iron grey, 木裂 to ice) and/or falls apart texel by texel (溶: 鼠王 into
// sand from the feet up, 扎罗 into black mist from the edge in). Its own shader
// so the shared sprite path never carries a discard (vfx-lighting: discard).
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D atlas : filter_nearest, source_color;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 cell = vec2(64.0, 64.0);
uniform bool flip = false;
// 0 none, 1 from the feet up, 2 from the edge in (random texels, outer first).
uniform int mode = 0;
// How far it has gone, 0 whole .. 1 gone.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// 褪: how much of the colour is replaced by fade_colour (kept as light and shade).
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_colour : source_color = vec4(0.42, 0.43, 0.45, 1.0);
// The thin lit edge where texels are about to go.
uniform vec4 edge_colour : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float edge : hint_range(0.0, 0.3) = 0.08;
// The whole husk's opacity (a last fade).
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = flip ? vec2(1.0 - UV.x, UV.y) : UV;
	vec2 texel = floor(uv * cell);
	vec4 c = texture(atlas, region.xy + (texel + 0.5) / cell * region.zw);
	if (c.a < 0.5) discard;
	// Each texel's turn to go, 0..1 (pixel-sized, like the art).
	float turn = 2.0;
	if (mode == 1) turn = (cell.y - texel.y) / cell.y * 0.8 + hash(texel) * 0.2;
	else if (mode == 2) turn = (1.0 - length(texel / cell - 0.5) * 1.6) * 0.6 + hash(texel) * 0.4;
	if (turn < amount) discard;
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 faded = fade_colour.rgb * (0.45 + grey * 1.1);
	vec3 rgb = mix(c.rgb, faded, fade);
	if (mode != 0 && turn < amount + edge) rgb = edge_colour.rgb;
	ALBEDO = rgb;
	ALPHA = opacity;
}
