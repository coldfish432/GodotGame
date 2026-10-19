// The modelled base's deck (基地建模改造案_v1 §二): a plate texture tiled in
// world space (Sol's R1 swatch replaces the stand-in), the Rhodes logo laid in
// as a lighter inlay, lit by the base's light map like every kit piece.
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D deck_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float metres_per_tile = 2.0;
uniform sampler2D inlay_tex : source_color, filter_nearest, repeat_disable;
// x, z of the inlay's north-west corner and its size (world units).
uniform vec4 inlay_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec3 inlay_colour : source_color = vec3(0.5, 0.54, 0.57);
// The plate's mean colour (linear), so the inlay keeps the plate's seams and rivets.
uniform vec3 plate_mean = vec3(0.0766, 0.0927, 0.107);
varying vec3 world_position;
#include "res://world/field_light.gdshaderinc"
// The room's lights in strips (the warehouse comes on bank by bank).
#include "res://world/base_room_light.gdshaderinc"
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 base = texture(deck_tex, world_position.xz / metres_per_tile).rgb;
	if (inlay_rect.z > 0.0) {
		vec2 uv = (world_position.xz - inlay_rect.xy) / inlay_rect.zw;
		if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
			vec4 inlay = texture(inlay_tex, vec2(uv.x, 1.0 - uv.y));
			// base / the plate's mean colour (linear), so the seams and rivets carry over.
			// Only the logo's light triangle is laid in; its dark tower stays deck.
			float light_part = step(0.5, inlay.a) * step(0.25, dot(inlay.rgb, vec3(0.2126, 0.7152, 0.0722)));
			base = mix(base, inlay_colour * (base / max(plate_mean, vec3(0.001))), light_part);
		}
	}
	ALBEDO = field_lit_px(base, world_position, FRAGCOORD.xy) * room_light(world_position);
}
