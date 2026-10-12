shader_type spatial;
// Ground warning (新敌人攻击动画与预警设计案 v1.2): a see-through red patch with a
// solid red rim, so the fight under it stays visible, and rings that spread
// from the middle as the countdown — the strike lands when the lead ring
// reaches the rim. Lanes count down the same way from their near end.
// An unstoppable attack adds a white edge outside the red rim (§一第 6 条).
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 colour : source_color = vec4(1.0, 0.08, 0.05, 1.0);
// World size of the quad, white edge included.
uniform vec2 size = vec2(2.0, 2.0);
uniform float progress = 0.0;
// 0 circle, 1 lane.
uniform int shape = 0;
uniform float rim = 0.08;
uniform float ring = 0.07;
uniform float white_rim = 0.0;
uniform float fill_alpha = 0.10;

float countdown(float d, float lead, float span) {
	float a = 0.0;
	// The lead ring and two fainter ones behind it: concentric ripples.
	for (int k = 0; k < 3; k++) {
		float r = lead - float(k) * span * 0.14;
		if (r > 0.0 && abs(d - r) <= ring * 0.5) a = max(a, 0.85 - 0.3 * float(k));
	}
	return a;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float a = fill_alpha;
	if (shape == 0) {
		float outer = size.x * 0.5;
		float radius = outer - white_rim;
		float d = length(p);
		if (d > outer) discard;
		if (d > radius) {
			ALBEDO = vec3(1.0);
			ALPHA = 0.95;
		} else {
			if (d > radius - rim) a = 0.9;
			a = max(a, countdown(d, progress * radius, radius));
			ALBEDO = colour.rgb;
			ALPHA = a;
		}
	} else {
		vec2 half_size = size * 0.5 - vec2(white_rim);
		vec2 q = abs(p);
		if (q.x > half_size.x || q.y > half_size.y) {
			ALBEDO = vec3(1.0);
			ALPHA = 0.95;
		} else {
			if (q.x > half_size.x - rim || q.y > half_size.y - rim) a = 0.9;
			// UV.y = 1 is the near end (where the attacker stands).
			float along = half_size.y - p.y;
			a = max(a, countdown(along, progress * half_size.y * 2.0, half_size.y * 2.0));
			ALBEDO = colour.rgb;
			ALPHA = a;
		}
	}
}
