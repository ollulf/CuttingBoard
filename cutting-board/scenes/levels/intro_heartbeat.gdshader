shader_type canvas_item;

// The black over the opening, with a hole at the centre of the screen that each
// heartbeat pushes wider (IntroSequence): the grain comes in from the middle outward.

// Hole radius, in screen heights from the centre.
uniform float hole = 0.0;
// Width of the soft edge between the hole and the black.
uniform float softness = 0.12;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float d = length(p);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(hole - softness, hole, d) * COLOR.a);
}
