// Field lighting (world/field_light.gd, 地图表现调研_光照贴图构图.md §3).
// Every field surface multiplies its colour by the light at its x/z: a
// light texture baked over the whole map when it is generated (ambient plus
// every static lamp, warm in the light and cool in the dark), plus a warm
// glow that follows Lappland. Falloff is smooth (the user found banded light
// read as rings, 2026-10-12); a faint ordered dither on the screen's pixel grid
// hides the 8-bit steps of the light texture. Outside the field (the base) the
// texture is a white pixel and the rect huge, so nothing changes there.
global uniform sampler2D field_light : source_color, filter_linear, repeat_disable;
global uniform vec4 field_light_rect;     // x, z origin; x, z size (world units)
global uniform vec3 field_player;         // her feet, world space
global uniform vec4 field_player_light;   // rgb, radius (0 = off)
global uniform float field_snow;          // 1 in the snowfield: upward faces carry snow

// Snow lying on whatever faces up (雪原地图调研与方案_v1.md §2): flat tops
// white, ledges dusted, walls bare. A little world-space noise breaks the edge.
vec3 field_snowed_bias(vec3 albedo, vec3 normal, vec3 world_pos, float bias) {
	if (field_snow <= 0.0) return albedo;
	float grain = fract(sin(dot(floor(world_pos.xz * 6.0), vec2(12.9898, 78.233))) * 43758.5453);
	float lying = smoothstep(0.5, 0.8, normal.y + bias + (grain - 0.5) * 0.25);
	// A shade under white, so lit snow still has room to brighten and the
	// rock under it reads.
	vec3 snow = vec3(0.74, 0.79, 0.86) * (0.92 + grain * 0.08);
	return mix(albedo, snow, lying * field_snow);
}

vec3 field_snowed(vec3 albedo, vec3 normal, vec3 world_pos) {
	return field_snowed_bias(albedo, normal, world_pos, 0.0);
}

// 4x4 Bayer threshold in [-0.5, 0.5) for this screen pixel.
float field_dither(vec2 frag) {
	ivec2 p = ivec2(mod(frag, 4.0));
	int bayer[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(bayer[p.x + p.y * 4]) / 16.0 - 0.5;
}

// 场景渲染统一改造案_v1 S3: the field is lit by real lights now (the lamps
// are OmniLights, the glow round her a light that follows her), so these
// return the surface colour as it is; the light texture is no longer read.
// Kept as functions so every field shader reads the same.
vec3 field_lit(vec3 albedo, vec3 world_pos) {
	return albedo;
}

vec3 field_lit_px(vec3 albedo, vec3 world_pos, vec2 frag) {
	return albedo;
}
