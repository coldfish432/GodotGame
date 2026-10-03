// Rhodes Island base occluders (north-wall facades, overhead hoists and beams).
// When Lappland stands behind one, the pixels around her are cut in a 50%
// checkerboard so she stays readable. Every pixel is either fully drawn or
// discarded, which keeps the art's binary alpha and pixel grid intact.

#include "res://world/base_room_light.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 player_center = vec3(0.0, -1000.0, 0.0); // Lappland's sprite centre, world space
uniform float occludes_north_of = -100000.0;          // world z; active only while she is north of it
uniform vec2 radius = vec2(1.5, 1.7);                 // ellipse half-size in camera-plane units

varying vec3 view_pos;
varying vec3 player_view;
varying vec3 world_pos;

void vertex() {
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	player_view = (VIEW_MATRIX * vec4(player_center, 1.0)).xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Texel colour, with alpha 0 where the pixel is transparent or cut away.
vec4 see_through(vec2 uv, vec2 frag) {
	vec4 c = texture(tex, uv);
	if (c.a < 0.5) return vec4(0.0);
	if (player_center.z > occludes_north_of) {
		vec2 d = (view_pos.xy - player_view.xy) / radius;
		ivec2 cell = ivec2(floor(frag));
		if (dot(d, d) < 1.0 && (cell.x + cell.y) % 2 == 0) return vec4(0.0);
	}
	return vec4(c.rgb * room_light(world_pos), 1.0);
}
