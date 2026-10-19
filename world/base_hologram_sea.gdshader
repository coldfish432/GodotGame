// The sea round Terra on the sand table (用户 2026-10-18: 海也建模): low hex
// columns, one MultiMesh, each with its depth in INSTANCE_CUSTOM.w (0 by the
// coast, 1 far out). The shallows glow lighter, the deep dark; swells of light
// roll across, and the tops rise and fall a little with them. Solid, like the
// land's columns, with the hologram's scanlines.
shader_type spatial;
render_mode unshaded, cull_back;
uniform float strength = 1.0;
varying float depth;
varying float side;
varying float swell;
void vertex() {
	depth = INSTANCE_CUSTOM.w;
	side = 1.0 - step(0.5, abs(NORMAL.y));
	vec3 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	swell = sin(at.x * 1.3 + at.z * 0.6 - TIME * 1.4) * 0.5 + 0.5;
	swell *= 0.6 + 0.4 * sin(at.z * 0.9 - at.x * 0.4 - TIME * 0.9);
	// the top rises with the swell (VERTEX is before the column's height scale)
	float lift = step(0.0, VERTEX.y) * swell * 0.012 * (0.4 + 0.6 * depth);
	VERTEX.y += lift / max(MODEL_MATRIX[1][1], 0.001);
}
void fragment() {
	vec3 shallow = vec3(0.02, 0.075, 0.14);
	vec3 deep = vec3(0.003, 0.012, 0.03);
	vec3 c = mix(shallow, deep, depth);
	c += vec3(0.015, 0.06, 0.1) * swell * (1.0 - side);
	c *= mix(1.0, 0.5, side);
	float scan = 0.78 + 0.22 * step(0.5, fract(FRAGCOORD.y / 3.0));
	float flicker = 0.94 + 0.06 * sin(TIME * 6.3) * sin(TIME * 1.7);
	ALBEDO = c * scan * flicker * strength;
}
