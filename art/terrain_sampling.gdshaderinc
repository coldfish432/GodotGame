// Shared by road edges, banks and the outer backdrop. Continuous patch
// weights plus deterministic offsets hide regular tile/mirror repetition.
vec2 patch_offset(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453) * 8.0;
}

vec3 mirrored_sample(vec2 uv, vec2 dx, vec2 dy) {
	vec2 repeated = mod(uv, 2.0);
	vec2 mirrored = abs(repeated - 1.0);
	vec2 direction = step(vec2(1.0), repeated) * 2.0 - 1.0;
	// Derivatives come from continuous world UVs, never the hashed offsets.
	// Otherwise distant mip selection exposes a grid at patch boundaries.
	return textureGrad(background_tex, mirrored * 0.998 + 0.001, dx * direction * 0.998, dy * direction * 0.998).rgb;
}

vec3 surface_texture(vec2 point) {
	vec2 uv = point / world_scale;
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec2 cell = floor(uv);
	vec2 weight = smoothstep(vec2(0.35), vec2(0.65), fract(uv));
	vec3 a = mirrored_sample(uv + patch_offset(cell), dx, dy);
	vec3 b = mirrored_sample(uv + patch_offset(cell + vec2(1.0, 0.0)), dx, dy);
	vec3 c = mirrored_sample(uv + patch_offset(cell + vec2(0.0, 1.0)), dx, dy);
	vec3 d = mirrored_sample(uv + patch_offset(cell + vec2(1.0, 1.0)), dx, dy);
	return mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
}
