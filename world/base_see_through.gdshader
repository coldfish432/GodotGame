shader_type spatial;
// North-wall facade: depth-tested like any prop. See base_see_through.gdshaderinc.
render_mode unshaded, cull_disabled;
#include "res://world/base_see_through.gdshaderinc"

void fragment() {
	vec4 c = see_through(UV, FRAGCOORD.xy);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb;
}
