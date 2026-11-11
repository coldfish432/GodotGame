// The buff / debuff lines round a figure (GPU粒子特效推广策划案 v0.6 §7a P6):
// thin vertical lines in a ring round her, each a long triangle narrowing the
// way it moves (a buff rises: wide foot, sharp top; a debuff falls: flipped),
// brightest at the tip, the wide tail fading. White, see-through; dimmer on
// the side of the ring in front of the figure (35%) than behind it (60%).
// Drawn on the particle quads; billboarded round the vertical axis.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The figure's centre (feet), set per emitter.
instance uniform vec3 centre = vec3(0.0);
// 0: rises (tip at the top); 1: falls (tip at the bottom).
uniform float falls = 0.0;
uniform float front_alpha = 0.35;
uniform float back_alpha = 0.6;

varying vec3 at;

void vertex() {
	// Billboard about Y, keeping the particle's own scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	at = MODEL_MATRIX[3].xyz;
}

void fragment() {
	// Along the line: 0 at the tip, 1 at the tail.
	float along = mix(UV.y, 1.0 - UV.y, falls);
	float half_width = along;
	float across = abs(UV.x - 0.5) * 2.0;
	float body = 1.0 - smoothstep(half_width - 0.18, half_width, across);
	float glow = mix(1.0, 0.3, along);
	// Which side of the figure: towards the camera is the front.
	vec2 out_dir = at.xz - centre.xz;
	vec2 to_camera = INV_VIEW_MATRIX[2].xz;
	float facing = dot(normalize(out_dir + vec2(1e-5)), normalize(to_camera + vec2(1e-5)));
	float side = mix(back_alpha, front_alpha, smoothstep(-0.25, 0.25, facing));
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(body * glow * side * COLOR.a, 0.0, 1.0);
}
