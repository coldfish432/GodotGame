// A shaft of daylight through a crack in the mine's roof (用户 2026-10-20:
// 矿洞…表示是在洞窟内; 参考《恐怖黎明》's caves): an open cone drawn additive,
// brightest at its axis and its foot, gone towards the roof and its rim.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 colour = vec3(0.55, 0.65, 0.8);
uniform float strength = 0.07;
varying float along;
varying vec3 world_normal;
void vertex() {
	along = UV.y;   // 0 at the roof, 1 at the floor (CylinderMesh)
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	// Facing the camera reads as the shaft's middle; grazing as its rim.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float body = pow(facing, 5.0) * smoothstep(0.0, 0.9, along) * mix(0.5, 1.0, along);
	ALBEDO = colour * strength * body;
}
