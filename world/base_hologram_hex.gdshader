// The sand table's Terra as hexagonal columns of light (基地建模改造案_v1 §十;
// the PRTS map of Terra is built the same way). One MultiMesh of hex prisms:
// each instance carries its map coordinate and height in INSTANCE_CUSTOM
// (u, v, height / top). The top face takes the 2D map's colour there (borders,
// coast) and glows more the higher the column; the sides are dimmer, darker
// towards the foot; a rim lights the top edge. Drawn solid so columns hide the
// ones behind them, with the hologram's scanlines and flicker.
shader_type spatial;
render_mode unshaded, cull_back;
// Raw values (no sRGB decode): the map is drawn as light levels.
uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform float strength = 1.0;
varying vec3 custom;
varying float side;
varying float up;
void vertex() {
	custom = INSTANCE_CUSTOM.xyz;
	side = 1.0 - step(0.5, abs(NORMAL.y));
	up = VERTEX.y + 0.5;  // the prism runs -0.5..0.5 before its scale
}
void fragment() {
	vec3 base = texture(map_tex, custom.xy).rgb;
	float h = custom.z;
	vec3 top_c = base * (1.0 + 2.4 * h) + vec3(0.03, 0.09, 0.14) * h;
	vec3 side_c = base * (0.35 + 0.9 * h) * (0.35 + 0.65 * up);
	vec3 c = mix(top_c, side_c, side);
	c += vec3(0.08, 0.25, 0.35) * side * smoothstep(0.88, 1.0, up);
	float scan = 0.78 + 0.22 * step(0.5, fract(FRAGCOORD.y / 3.0));
	float flicker = 0.94 + 0.06 * sin(TIME * 6.3) * sin(TIME * 1.7);
	ALBEDO = c * scan * flicker * strength;
}
