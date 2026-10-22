// Rock standing in front of Lappland opens round her (用户 2026-10-20: 矿洞
// 应该有遮挡视线的岩壁和通天的石柱; 2026-10-21: 挡视野时突然消失 → only the
// part over her goes, with a soft edge, opening and closing over a moment).
// A fragment above her feet by `above` metres and nearer the camera than she
// is is dithered out inside `radius` metres of her on screen, thinning over
// the outer `band`. field_cut (0..1, eased by GameManager while rock stands
// between her and the camera) opens the hole. Needs field_light.gdshaderinc.
global uniform float field_cut;

float bayer4(vec2 frag) {
	ivec2 p = ivec2(mod(floor(frag), 4.0));
	int i = p.x + p.y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

bool cut_away(vec3 view_vertex, vec3 world_pos, mat4 view, vec2 frag, float radius, float above) {
	if (field_cut <= 0.001 || world_pos.y <= field_player.y + above) return false;
	vec3 her = (view * vec4(field_player + vec3(0.0, 0.9, 0.0), 1.0)).xyz;
	if (view_vertex.z <= her.z + 0.5) return false;
	// And between her and the camera along the ground: a column standing
	// behind her rises nearer the camera too, but hides nothing of her.
	vec2 toward = normalize(vec2(view[0][2], view[2][2]));
	if (dot(world_pos.xz - field_player.xz, toward) < -0.5) return false;
	float band = radius * 0.4;
	float keep = smoothstep(radius - band, radius, length(view_vertex.xy - her.xy)) + (1.0 - field_cut);
	return keep < bayer4(frag);
}
