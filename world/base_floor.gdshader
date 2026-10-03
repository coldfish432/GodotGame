shader_type spatial;
// Base floor layers (room ground and floor decals): the texture as drawn,
// transparent pixels left out, dimmed by the room lights. Same look as the unshaded StandardMaterial3D it replaces.
render_mode unshaded, cull_disabled;
#include "res://world/base_room_light.gdshaderinc"

uniform sampler2D tex : source_color, filter_nearest;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) discard;  // decals (zone highlights) have holes; the art's alpha is binary
	ALBEDO = c.rgb * room_light(world_pos);
}
