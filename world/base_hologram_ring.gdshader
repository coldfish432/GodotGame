// The exchange's quote ring: base_hologram.gdshader (added light, scanlines,
// flicker) drawn on its outer face only (cull_back).
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled;
uniform sampler2D map_tex : source_color, filter_linear, repeat_disable;
uniform bool use_map = false;
uniform vec3 colour : source_color = vec3(0.35, 0.78, 1.0);
uniform float strength = 1.0;
uniform float flicker_phase = 0.0;
// Scrolls the map across the surface (a ticker), in UV per second.
uniform vec2 uv_scroll = vec2(0.0);
void fragment() {
	vec3 base = use_map ? texture(map_tex, fract(UV + TIME * uv_scroll)).rgb : colour;
	float scan = 0.72 + 0.28 * step(0.5, fract(FRAGCOORD.y / 3.0));
	float flicker = 0.9 + 0.1 * sin(TIME * 6.3 + flicker_phase) * sin(TIME * 1.7);
	ALBEDO = base * scan * flicker * strength;
}
