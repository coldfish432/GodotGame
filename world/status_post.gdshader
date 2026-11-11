// The full-screen status look (GPU粒子特效推广策划案 v0.6 §7 P5): one overlay
// over the 3D view, under the HUD and under the warning circles (render
// priority between the figures and the markers), pressing in from the edges
// with the centre kept clear. Every status adds into this one layer (用户裁决
// 8); the edge cover is capped at `cap`. Desaturation and contrast ride the
// Environment's adjustment (StatusPost), so nothing here reads the screen.
//   contamination: orange-black crystal veins growing in from the edges;
//   cold: white frost from the corners;
//   debt: a dark red-brown rim pulsing like a heartbeat;
//   threat: the edges pressed darker;
//   low life: the edges dark;
//   blizzard: the whole view whitened evenly (light 90 → medium 100), gusts on top.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform float contamination = 0.0;
uniform float cold = 0.0;
uniform float debt = 0.0;
uniform float debt_rate = 1.0;
uniform float threat = 0.0;
uniform float low_life = 0.0;
uniform float whiteout = 0.0;
uniform float cap = 0.6;
uniform float clear_radius = 0.4;
uniform float clock = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
// Distance to the nearest cell edge of a Voronoi pattern: thin crystal veins.
float veins(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 aspect = vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	vec2 c = (uv - 0.5) * aspect;
	// 0 inside the clear centre, 1 at the far corners.
	float edge = smoothstep(clear_radius, 0.5 * length(aspect) + 0.02, length(c));
	vec4 sum = vec4(0.0);
	// Each layer: colour and how much it covers here.
	if (contamination > 0.0) {
		float v = veins(c * 9.0 + vec2(3.0));
		float reach = edge * (0.6 + 0.6 * fbm(c * 3.0)) - (1.0 - contamination) * 0.9;
		float crystal = clamp(reach * 1.6, 0.0, 1.0);
		float line = smoothstep(0.08, 0.0, v) * crystal;
		vec3 col = mix(vec3(0.08, 0.04, 0.02), vec3(1.0, 0.55, 0.16), line);
		float a = clamp(crystal * 0.55 + line * 0.35, 0.0, 1.0) * contamination;
		sum = vec4(sum.rgb + col * a, sum.a + a);
	}
	if (cold > 0.0) {
		float frost = fbm(c * 7.0 + 11.0) * 0.6 + fbm(c * 21.0) * 0.4;
		float reach = edge * (0.7 + 0.5 * frost) - (1.0 - cold) * 0.75;
		float a = clamp(reach * 1.8, 0.0, 1.0) * (0.55 + 0.45 * smoothstep(0.55, 0.75, frost)) * cold;
		sum = vec4(sum.rgb + vec3(0.9, 0.95, 1.0) * a, sum.a + a);
	}
	if (debt > 0.0) {
		// A heartbeat: two quick swells, then rest.
		float t = fract(clock * debt_rate);
		float beat = exp(-pow((t - 0.1) * 14.0, 2.0)) + 0.7 * exp(-pow((t - 0.28) * 14.0, 2.0));
		float a = edge * (0.5 + 0.5 * beat) * debt * 1.1;
		sum = vec4(sum.rgb + vec3(0.42, 0.08, 0.05) * a, sum.a + a);
	}
	if (threat > 0.0) {
		float a = edge * edge * threat * 0.45;
		sum = vec4(sum.rgb + vec3(0.02, 0.02, 0.03) * a, sum.a + a);
	}
	if (low_life > 0.0) {
		float a = edge * low_life * 0.7;
		sum = vec4(sum.rgb + vec3(0.03, 0.0, 0.0) * a, sum.a + a);
	}
	// The edges together never cover more than `cap`; colours keep their mix.
	float cover = min(sum.a, cap);
	vec3 col = sum.a > 0.0 ? sum.rgb / sum.a : vec3(0.0);
	// The blizzard's even whitening goes over the lot (not capped by the edge rule).
	float w = clamp(whiteout, 0.0, 0.6);
	float out_a = cover + w - cover * w;
	ALBEDO = out_a > 0.0 ? mix(col, vec3(0.9, 0.92, 0.95), w / max(out_a, 1e-4)) : vec3(0.0);
	ALPHA = out_a;
}
