// Field shading shared by every field shader (world/field_light.gd).
// The field is lit by real lights (场景渲染统一改造案_v1 S3): lamps are
// OmniLights, the glow round her a light that follows her. No light texture
// is baked or read; field_lit / field_lit_px return the colour as it is.
// What this file still does: snow on upward faces, and field_player for
// cutaway.gdshaderinc. field_light, field_light_rect and field_player_light
// are still declared and set by FieldLight but nothing reads them.
global uniform sampler2D field_light : source_color, filter_linear, repeat_disable;
global uniform vec4 field_light_rect;     // x, z origin; x, z size (world units); unread
global uniform vec3 field_player;         // her feet, world space
global uniform vec4 field_player_light;   // rgb, radius (0 = off); unread
global uniform float field_snow;          // the snowfield's lying snow on upward faces (0 off)

// Weather on the ground (GPU粒子特效推广策划案 v0.6 §5; FieldWeather sets these).
global uniform float field_wet;            // rain on every surface, 0..1
global uniform vec4 field_puddle;          // puddle field: x, z offset; turn (radians); fill 0..1
global uniform float field_snow_cover;     // fresh snow on the ground, 0..1 (from the cold)
global uniform sampler2D field_trail : filter_linear, repeat_disable;  // R: game time a foot passed (s)
global uniform vec4 field_trail_rect;      // x, z origin; size (m); seconds to fill a track
global uniform float field_time;           // game seconds, the clock the trail uses
global uniform vec4 field_fire_0;          // lit fires: xyz, melt radius (0 none)
global uniform vec4 field_fire_1;
global uniform vec4 field_fire_2;
global uniform vec4 field_fire_3;
global uniform vec4 field_lamp_0;          // the nearest lamps: xyz, strength (0 none)
global uniform vec4 field_lamp_1;
global uniform vec4 field_lamp_2;
global uniform vec4 field_lamp_3;
global uniform vec4 field_lamp_tint_0;     // rgb, reach
global uniform vec4 field_lamp_tint_1;
global uniform vec4 field_lamp_tint_2;
global uniform vec4 field_lamp_tint_3;

float field_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float field_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(field_hash(i), field_hash(i + vec2(1.0, 0.0)), f.x), mix(field_hash(i + vec2(0.0, 1.0)), field_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How much a lit fire has melted the snow here: 1 none, 0 at the fire.
float field_melt(vec3 wp) {
	float keep = 1.0;
	vec4 fires[4] = vec4[4](field_fire_0, field_fire_1, field_fire_2, field_fire_3);
	for (int i = 0; i < 4; i++) {
		if (fires[i].w <= 0.0) continue;
		float d = length(wp.xz - fires[i].xz) / fires[i].w;
		keep *= smoothstep(0.55, 1.0, d);
	}
	return keep;
}

// One trail texel's freshness: 1 where a foot just passed, 0 once filled in.
float field_track_tap(vec2 uv) {
	float stamped = texture(field_trail, uv).r;
	if (stamped <= 0.0) return 0.0;
	float age = max(field_time - stamped, 0.0);
	return clamp(1.0 - age / max(field_trail_rect.w, 0.1), 0.0, 1.0);
}

// A footprint's depth here, 0..1: fresh where a foot passed, filled in by new
// snow over field_trail_rect.w seconds. Nine taps soften the texel edges into
// a trodden furrow (the global sampler reads nearest).
float field_track(vec2 xz) {
	if (field_trail_rect.z <= 0.0) return 0.0;
	vec2 uv = (xz - field_trail_rect.xy) / field_trail_rect.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	vec2 t = 1.5 / vec2(textureSize(field_trail, 0));
	float sum = field_track_tap(uv) * 2.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		sum += field_track_tap(uv + vec2(cos(a), sin(a)) * t);
	}
	return smoothstep(0.1, 0.75, sum / 10.0);
}

// Snow lying on whatever faces up (雪原地图调研与方案_v1.md §2): flat tops
// white, ledges dusted, walls bare. A little world-space noise breaks the edge.
// It melts round a lit fire and is pressed thin along fresh tracks.
vec3 field_snowed_bias(vec3 albedo, vec3 normal, vec3 world_pos, float bias) {
	if (field_snow <= 0.0) return albedo;
	float grain = fract(sin(dot(floor(world_pos.xz * 6.0), vec2(12.9898, 78.233))) * 43758.5453);
	float lying = smoothstep(0.5, 0.8, normal.y + bias + (grain - 0.5) * 0.25);
	lying *= field_melt(world_pos) * (1.0 - 0.6 * field_track(world_pos.xz));
	// A shade under white, so lit snow still has room to brighten and the
	// rock under it reads.
	vec3 snow = vec3(0.74, 0.79, 0.86) * (0.92 + grain * 0.08);
	return mix(albedo, snow, lying * field_snow);
}

vec3 field_snowed(vec3 albedo, vec3 normal, vec3 world_pos) {
	return field_snowed_bias(albedo, normal, world_pos, 0.0);
}

// Rain on a surface (§5.2): darker and glossier, most on what faces up.
void field_wet_surface(inout vec3 albedo, out float rough, out float spec, vec3 normal, float base_rough, float base_spec) {
	float w = field_wet * mix(0.45, 1.0, smoothstep(0.3, 0.9, normal.y));
	albedo *= mix(1.0, 0.78, w);
	rough = mix(base_rough, 0.3, w);
	spec = mix(base_spec, 0.55, w);
}

// The floor's puddles (§5.2): where they lie this floor (field_puddle turns and
// shifts the pattern per floor seed) and how full they are; 0..1.
float field_puddle_mask(vec3 wp, float wetness) {
	float fill = field_puddle.w > 0.0 ? field_puddle.w : 1.0;
	float c = cos(field_puddle.z);
	float s = sin(field_puddle.z);
	vec2 p = mat2(vec2(c, -s), vec2(s, c)) * wp.xz + field_puddle.xy;
	float n = field_noise(p / 3.5) * 0.7 + field_noise(p / 1.3) * 0.3;
	// Fuller puddles spread out from the low patches.
	float edge = mix(0.66, 0.52, fill);
	return wetness * smoothstep(edge, edge + 0.06, n);
}

// Rain rings on a puddle: a few at a time, each spreading and fading (no particles).
float field_ripples(vec2 xz) {
	vec2 cell = floor(xz * 1.6);
	float rings = 0.0;
	for (int dx = 0; dx <= 1; dx++) for (int dz = 0; dz <= 1; dz++) {
		vec2 c = cell + vec2(float(dx), float(dz));
		float h = field_hash(c);
		float t = fract(field_time * (0.7 + 0.6 * h) + h * 7.0);
		vec2 centre = (c + vec2(field_hash(c + 3.1), field_hash(c + 5.7))) / 1.6;
		float r = length(xz - centre) - t * 0.45;
		rings += (1.0 - t) * smoothstep(0.035, 0.0, abs(r));
	}
	return rings;
}

// The lamps seen in a puddle (§5.2, no SSR): each lamp's mirror image below the
// ground, met where the view line through it lands on the puddle, drawn as a
// soft spot stretched away from the camera, in the lamp's colour.
vec3 field_lamp_glints(vec3 wp, mat4 inv_view) {
	vec3 view = normalize(-inv_view[2].xyz);   // camera looks along this
	vec2 along = normalize(view.xz + vec2(1e-5));
	vec2 across = vec2(-along.y, along.x);
	vec3 sum = vec3(0.0);
	vec4 lamps[4] = vec4[4](field_lamp_0, field_lamp_1, field_lamp_2, field_lamp_3);
	vec4 tints[4] = vec4[4](field_lamp_tint_0, field_lamp_tint_1, field_lamp_tint_2, field_lamp_tint_3);
	for (int i = 0; i < 4; i++) {
		if (lamps[i].w <= 0.0) continue;
		float h = max(lamps[i].y - wp.y, 0.2);
		// The mirror image sits h below the ground; the view line through it
		// meets the ground h / |view.y| further along the view.
		vec2 image = lamps[i].xz + view.xz * (h / max(abs(view.y), 0.2));
		vec2 d = wp.xz - image;
		float a = dot(d, along);
		float b = dot(d, across);
		float spot = exp(-(b * b) / 0.12 - (a * a) / 2.2);
		float reach = max(tints[i].w, 1.0);
		float near = clamp(1.0 - length(wp.xz - lamps[i].xz) / (reach * 2.5), 0.0, 1.0);
		sum += tints[i].rgb * lamps[i].w * spot * near;
	}
	return sum;
}
// 4x4 Bayer threshold in [-0.5, 0.5) for this screen pixel (it hid the light
// texture's 8-bit steps; nothing calls it now).
float field_dither(vec2 frag) {
	ivec2 p = ivec2(mod(frag, 4.0));
	int bayer[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(bayer[p.x + p.y * 4]) / 16.0 - 0.5;
}

// Pass-throughs: the surface colour as it is. Kept so every field shader
// reads the same.
vec3 field_lit(vec3 albedo, vec3 world_pos) {
	return albedo;
}

vec3 field_lit_px(vec3 albedo, vec3 world_pos, vec2 frag) {
	return albedo;
}

// Rain on an upward face of a kit piece or a cliff top (叙拉古's paving is a
// cliff top): wet as field_wet_surface, plus the floor's puddles, their rain
// rings and the lamps seen in them, the same as on the terrain.
void field_rain_surface(inout vec3 albedo, out float rough, out float spec, inout vec3 emission, vec3 normal, vec3 wp, mat4 inv_view, float base_rough, float base_spec) {
	field_wet_surface(albedo, rough, spec, normal, base_rough, base_spec);
	if (field_wet <= 0.0 || normal.y < 0.85) return;
	float puddle = field_puddle_mask(wp, 1.0);
	if (puddle <= 0.0) return;
	albedo *= mix(1.0, 0.6, puddle);
	rough = mix(rough, 0.06, puddle);
	spec = mix(spec, 0.65, puddle);
	float rain = step(0.0001, field_puddle.w);
	float rings = field_ripples(wp.xz) * rain;
	emission += (field_lamp_glints(wp, inv_view) * (0.85 + 0.5 * rings) * 0.6 + vec3(0.5, 0.58, 0.72) * rings * 0.06) * puddle;
}
