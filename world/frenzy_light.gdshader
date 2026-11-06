shader_type spatial;
// 源石狂暴地板's light (用户 2026-11-05: 周围有红色向上的光影; 光更稀疏一些; 四周都有，
// 随机在某几个边闪烁): one thin red beam rising off the tile's rim, turned to face
// the camera about its upright axis so every edge reads from any view. Each edge
// keeps a faint glow and, in windows of its own chosen at random, flares up and
// dies down — at any moment a few edges flicker and the others rest.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.16, 0.08, 1.0);
uniform float strength = 1.8;
uniform float speed = 0.6;
// An edge at rest shows this share of its light; its flares come flare_rate a second.
uniform float rest = 0.25;
uniform float flare_rate = 0.8;
uniform float flare_share = 0.5;
// Which edge (0..3) and this beam's own seed.
instance uniform float edge = 0.0;
instance uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void vertex() {
	// Upright billboard: the beam stands up and turns to the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	// UV.y: 0 at the top, 1 at the floor.
	float rise = pow(UV.y, 1.4);
	float beam = smoothstep(0.0, 0.5, UV.x) * smoothstep(1.0, 0.5, UV.x);
	float shimmer = 0.6 + 0.4 * sin(TIME * (1.5 + seed * 2.0) + seed * 20.0);
	float drift = 0.6 + 0.4 * sin((UV.y + TIME * speed * (0.7 + seed)) * 10.0);
	float t = TIME * flare_rate + hash(edge + 0.5) * 10.0;
	float on_now = step(1.0 - flare_share, hash(floor(t) + edge * 1.37));
	float flare = mix(rest, 1.0, on_now * sin(fract(t) * 3.14159));
	ALBEDO = colour.rgb;
	ALPHA = clamp(strength * beam * rise * shimmer * drift * flare, 0.0, 1.0);
}
