// The swept cliff faces (CliffFace): one continuous surface per cliff line,
// textured with a Blender-baked rock swatch sampled triplanar in world space
// through the terrain's mirrored, patch-offset sampler, so the grain carries
// across the whole face with no tile seam. Height runs along the swatch's v
// on both side projections, so its strata lie level. Unshaded like the
// terrain; vertex colour holds the sweep's occlusion (foot, ledge undersides),
// and the same fixed sun as TerrainSurface._triangle shades the facets.
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D background_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float world_scale = 4.0;
uniform vec3 tint = vec3(1.0);
// Tops (the rock mass seen from above) take the region's ground grain, not the
// face swatch, whose strata would streak across a flat top.
uniform sampler2D top_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float top_scale = 12.0;
uniform vec3 top_tint = vec3(1.0);
varying vec3 world_position;
varying vec3 world_normal;
#include "res://art/terrain_sampling.gdshaderinc"
#include "res://world/field_light.gdshaderinc"
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
}
void fragment() {
	vec3 weight = pow(abs(world_normal), vec3(3.0));
	weight /= weight.x + weight.y + weight.z;
	vec3 side = surface_texture(vec2(world_position.z, -world_position.y)) * weight.x
		+ surface_texture(vec2(world_position.x, -world_position.y)) * weight.z;
	vec3 top = top_texture(world_position.xz) * top_tint;
	// Snow reads its relief by light alone: a wider light-to-shade range there.
	float sun = abs(dot(world_normal, normalize(vec3(-0.4, 0.8, -0.4))));
	float shade = field_snow > 0.0 ? 0.5 + sun * 0.55 : 0.72 + sun * 0.28;
	// COLOR.a: shade that holds over snow (a causeway's fallen-away side).
	ALBEDO = field_lit_px(field_snowed((side * tint + top * weight.y) * COLOR.rgb, world_normal, world_position) * shade * COLOR.a, world_position, FRAGCOORD.xy);
}
