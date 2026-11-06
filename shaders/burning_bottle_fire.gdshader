shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// A burning bottle's spilt fire: many short, thin tongues spread over the
// patch like burning alcohol (用户 2026-10-30: 铺在地上的、像酒精燃烧那样).
// One MultiMesh card per tongue, each turned to the camera here. Per card,
// INSTANCE_CUSTOM: x seed, y when it goes out (0..1 of fire_remaining).

uniform float fire_remaining : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec4 base_color : source_color = vec4(0.25, 0.45, 1.0, 1.0);
uniform vec4 body_color : source_color = vec4(1.0, 0.62, 0.2, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform vec4 ember_color : source_color = vec4(0.85, 0.22, 0.05, 1.0);
uniform float intensity : hint_range(0.0, 2.0, 0.01) = 0.9;
uniform float lick_speed : hint_range(0.0, 4.0, 0.05) = 1.6;
// Colour steps, for the pixel look; 0 keeps it smooth.
uniform float bands : hint_range(0.0, 8.0, 1.0) = 4.0;

varying float seed;
varying float out_at;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return 0.55 * noise(p) + 0.3 * noise(p * 2.1) + 0.15 * noise(p * 4.3);
}

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	out_at = INSTANCE_CUSTOM.y;
	// Billboard about the card's foot, keeping its own width and height.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1], MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = clamp(fire_remaining, 0.0, 1.0);
	// Cards go out one by one as the fire runs down; the last ones with it.
	float alive = step(out_at, r) * step(0.0001, r);
	float h = 1.0 - UV.y;
	float t = TIME * lick_speed + seed * 37.0;
	// A low sheet with a ragged top: several thin tips that rise and fall,
	// fading out at the card's sides so neighbours blend into one carpet.
	float sway = (noise(vec2(seed * 7.0, h * 2.0 - t * 0.8)) - 0.5) * 0.12 * h;
	float u = UV.x + sway;
	float side = sqrt(clamp(1.0 - pow(abs(u - 0.5) * 2.0, 2.0), 0.0, 1.0));
	float tips = fbm(vec2(u * 4.5 + seed * 13.0, t * 0.9));
	float top = side * mix(0.3, 1.0, smoothstep(0.3, 0.75, tips)) * mix(0.75, 1.0, r);
	float body = smoothstep(top, top - 0.25, h) * smoothstep(0.0, 0.3, side);
	// Upward streaks through the sheet.
	body *= mix(0.7, 1.0, fbm(vec2(u * 10.0 + seed * 3.0, h * 4.0 - t * 2.2)));
	// A soft foot, uneven along the ground.
	body *= smoothstep(0.0, 0.06 + 0.06 * noise(vec2(u * 8.0 + seed * 5.0, t * 0.5)), h);
	float core = body * smoothstep(0.6, 0.0, h / max(top, 0.05));
	if (bands > 0.0) {
		body = floor(body * bands + 0.5) / bands;
		core = floor(core * bands + 0.5) / bands;
	}
	// Blue where it meets the fuel, then the flame, pale at the tips; as it
	// runs down the flame reddens.
	vec3 flame = mix(ember_color.rgb, body_color.rgb, smoothstep(0.0, 0.6, r));
	vec3 c = mix(base_color.rgb, flame, smoothstep(0.03, 0.25, h / max(top, 0.05)));
	c = mix(c, core_color.rgb, core * 0.5);
	ALBEDO = c * intensity;
	ALPHA = clamp(body * alive * 0.85, 0.0, 1.0);
}
