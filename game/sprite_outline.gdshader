shader_type spatial;
// A 1-texel light ring just outside a billboarded sprite cell: the body of an
// enemy winding up an attack that cannot be interrupted (新敌人攻击案 §一第 6 条).
// Draws only where the cell is empty and a neighbour is not, so it can share
// the sprite's plane without hiding a single painted texel.
// Drawn in the transparent pass, writing no depth: as an opaque quad its
// whole square reached the depth prepass, and the outline post and SSAO
// drew it as a box round the enemy (用户 2026-10-21).
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D atlas : filter_nearest, source_color;
// The cell inside the atlas, in UV: x, y, width, height.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// Texels per cell side.
uniform vec2 cell = vec2(64.0, 64.0);
uniform vec4 colour : source_color = vec4(0.96, 0.94, 0.88, 1.0);
// Mirrors the cell like Sprite3D.flip_h.
uniform bool flip = false;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float filled(vec2 texel) {
	if (texel.x < 0.0 || texel.y < 0.0 || texel.x >= cell.x || texel.y >= cell.y) return 0.0;
	return texture(atlas, region.xy + (texel + 0.5) / cell * region.zw).a;
}

void fragment() {
	vec2 uv = flip ? vec2(1.0 - UV.x, UV.y) : UV;
	vec2 texel = floor(uv * cell);
	if (filled(texel) > 0.5) discard;
	float near = max(max(filled(texel + vec2(1, 0)), filled(texel - vec2(1, 0))), max(filled(texel + vec2(0, 1)), filled(texel - vec2(0, 1))));
	if (near < 0.5) discard;
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
}
