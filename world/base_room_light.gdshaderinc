// Room lights for the Rhodes Island base, shared by the floor, north-wall and
// overhead shaders (and mirrored by Sprite3D modulate in BaseMap.set_room_bands).
// A room is cut into up to four strips across the world x axis, each with its
// own light level: the warehouse lights come on strip by strip from its door,
// and light spills into the strips not yet lit (world/room_reveal.gd).
// The defaults light everything, so rooms that never touch these stay as drawn.

uniform vec3 band_edges = vec3(0.0);       // world x of the far edge of strips 0, 1, 2
uniform float band_sign = 1.0;             // (world x - edge) * sign < 0 means past that edge
uniform vec4 band_levels = vec4(1.0);      // light level of strips 0..3

float room_light(vec3 world) {
	int strip = 0;
	for (int k = 0; k < 3; k++) {
		if ((world.x - band_edges[k]) * band_sign < 0.0) strip = k + 1;
	}
	return band_levels[strip];
}
