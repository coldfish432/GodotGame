shader_type spatial;
// Overhead layer: ignores depth and draws after everything (transparent pass,
// high render priority), so it always sits above Lappland. See base_see_through.gdshaderinc.
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;
#include "res://world/base_see_through.gdshaderinc"

void fragment() {
	vec4 c = see_through(UV, FRAGCOORD.xy);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb;
	ALPHA = 1.0;
}
