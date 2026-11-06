shader_type spatial;
// The arena's way out, closed until the boss falls (用户 2026-11-05: 不要门，直接加
// 空气墙，靠近后逐渐显示红色斜警戒透明墙). An invisible wall that shows red
// warning stripes only round where she stands, fading in as she comes close.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 her = vec3(0.0, -1000.0, 0.0);
uniform vec4 stripe : source_color = vec4(0.91, 0.27, 0.23, 1.0);
uniform vec4 gap : source_color = vec4(0.25, 0.04, 0.04, 1.0);
// Fully shown within `near` metres of her, gone past `far`.
uniform float near = 1.2;
uniform float far = 4.5;
uniform float height = 4.0;
uniform float fade = 1.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(world.xz, her.xz);
	float reveal = 1.0 - smoothstep(near, far, d);
	float base_y = world.y - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y + height * 0.5;
	float top = 1.0 - smoothstep(height * 0.45, height, base_y);
	// Diagonal stripes in world metres, so they line up across the whole wall.
	float s = fract((world.x + world.z + base_y) * 1.4);
	float on = step(0.5, s);
	float rim = 1.0 - smoothstep(0.0, 0.12, base_y);
	ALBEDO = mix(gap.rgb, stripe.rgb, max(on, rim));
	ALPHA = clamp(reveal * top * fade * (0.22 + 0.4 * on + 0.4 * rim), 0.0, 1.0);
}
