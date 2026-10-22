// The body of cliff_face.gdshader, shared with cliff_face_cave.gdshader, which
// defines CUTAWAY: a discard anywhere in a shader costs every material that
// uses it its fast depth path (Lungmen fell from 106 to 41 fps).
uniform sampler2D background_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float world_scale = 4.0;
uniform vec3 tint = vec3(1.0);
// Tops (the rock mass seen from above) take the region's ground grain, not the
// face swatch, whose strata would streak across a flat top.
uniform sampler2D top_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float top_scale = 12.0;
uniform vec3 top_tint = vec3(1.0);
// The city: its pavement runs on from the road to the buildings' feet. The
// rock top there carries COLOR.g = 0 (TerrainSurface._color), and its shade
// in COLOR.r alone.
uniform bool city_pave = false;
uniform sampler2D pave_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float pave_scale = 3.0;
uniform float pave_gain = 0.92;
// The cave (TerrainSurface CAVE_WALL): rock this far above its bank (UV2.y)
// fades to black over void_span, the dark the walls and pillars rise into.
uniform float void_from = 1000.0;
// How dark the stone gets up there: dark, its grain still showing (恐怖黎明).
uniform float void_floor = 0.22;
uniform float void_span = 5.0;
// Rock standing in front of Lappland opens round her (cutaway.gdshaderinc).
uniform float cut_radius = 4.0;
uniform float cut_above = 1.4;
varying vec3 world_position;
varying vec3 world_normal;
varying float rise;
#include "res://art/terrain_sampling.gdshaderinc"
#include "res://world/field_light.gdshaderinc"
#include "res://world/cutaway.gdshaderinc"
// The rock tops go through the same mirrored, patch-offset sampling as the
// terrain's banks, so the ground grain does not show its tile.
vec3 top_sample(vec2 uv, vec2 dx, vec2 dy) {
	vec2 repeated = mod(uv, 2.0);
	vec2 mirrored = abs(repeated - 1.0);
	vec2 direction = step(vec2(1.0), repeated) * 2.0 - 1.0;
	return textureGrad(top_tex, mirrored * 0.998 + 0.001, dx * direction * 0.998, dy * direction * 0.998).rgb;
}
vec3 top_texture(vec2 point) {
	vec2 uv = point / top_scale;
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec2 cell = floor(uv);
	vec2 weight = smoothstep(vec2(0.35), vec2(0.65), fract(uv));
	vec3 a = top_sample(uv + patch_offset(cell), dx, dy);
	vec3 b = top_sample(uv + patch_offset(cell + vec2(1.0, 0.0)), dx, dy);
	vec3 c = top_sample(uv + patch_offset(cell + vec2(0.0, 1.0)), dx, dy);
	vec3 d = top_sample(uv + patch_offset(cell + vec2(1.0, 1.0)), dx, dy);
	return mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	rise = UV2.y;
}
void fragment() {
#ifdef CUTAWAY
	if (cut_away(VERTEX, world_position, VIEW_MATRIX, FRAGCOORD.xy, cut_radius, cut_above)) discard;
#endif
	vec3 weight = pow(abs(world_normal), vec3(3.0));
	weight /= weight.x + weight.y + weight.z;
	vec3 side = surface_texture(vec2(world_position.z, -world_position.y)) * weight.x
		+ surface_texture(vec2(world_position.x, -world_position.y)) * weight.z;
	vec3 top = top_texture(world_position.xz) * top_tint;
	vec3 tone = COLOR.rgb;
	if (city_pave) {
		vec3 slabs = texture(pave_tex, world_position.xz / pave_scale).rgb * pave_gain;
		top = mix(top, slabs, step(COLOR.g, 0.5));
		tone = vec3(COLOR.r);
	}
	// COLOR.a: shade that holds over snow (a causeway's fallen-away side).
	ALBEDO = field_lit_px(field_snowed((side * tint + top * weight.y) * tone, world_normal, world_position) * COLOR.a, world_position, FRAGCOORD.xy);
	// The wall's face keeps its grain up into the dark; the flat top beyond
	// it, out of sight above the screen in the cave's reading, goes black.
	float up_dark = mix(void_floor, 0.03, smoothstep(0.55, 0.85, world_normal.y));
	ALBEDO *= mix(1.0, up_dark, smoothstep(void_from, void_from + void_span, rise));
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
