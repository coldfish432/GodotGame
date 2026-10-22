// A thin dark line where depth or normals break, so the modelled scene
// carries the same outline as the baked pixel sprites (场景渲染统一改造案_v1
// §4.5). A full-screen quad on the camera; GameManager shows it in the base.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform float depth_threshold = 0.18;
uniform float normal_threshold = 0.45;
uniform vec4 line_color : source_color = vec4(0.03, 0.035, 0.04, 0.8);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 normal_at(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float c = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n = normal_at(SCREEN_UV);
	float dd = 0.0;
	float nd = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i];
		dd = max(dd, view_depth(uv, INV_PROJECTION_MATRIX) - c);
		nd = max(nd, 1.0 - dot(n, normal_at(uv)));
	}
	float edge = max(step(depth_threshold, dd), step(normal_threshold, nd));
	ALBEDO = line_color.rgb;
	ALPHA = edge * line_color.a;
}
