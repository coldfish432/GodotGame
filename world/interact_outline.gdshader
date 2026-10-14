// The yellow rim on a point of interest she can use, while she is near it
// (用户 2026-10-13: 可交互兴趣点经过时显示黄色描边). Drawn as a next pass of the
// model's own materials: the back faces, pushed out from the model's middle,
// left showing round its silhouette. Pushed from the middle rather than along
// the normals: the kit pieces are flat-shaded, and normals would split the
// rim open at every hard edge.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;
uniform vec3 rim_color : source_color = vec3(1.0, 0.82, 0.22);
// The model's middle and the rim's width, in the model's own units.
uniform vec3 centre = vec3(0.0, 0.4, 0.0);
uniform float grow = 0.05;
void vertex() {
	vec3 out_dir = VERTEX - centre;
	float reach = length(out_dir);
	if (reach > 0.0001) VERTEX += out_dir / reach * grow + NORMAL * grow * 0.35;
}
void fragment() {
	ALBEDO = rim_color;
}
