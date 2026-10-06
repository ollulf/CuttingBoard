shader_type canvas_item;

// The red edge the screen gets when the player is hurt. Drawn on the HUD, above
// PsxScreen's palette grade: the Tallow Fair palette has no red, so a red drawn into the
// world would be quantised into brown ember. Instead the overlay does its own retro
// treatment: it works in blocks the size of the retro screen's pixels and fades through
// the same 4x4 Bayer pattern, so it reads as part of the PS1 image while staying red.

// Blood and blood-hi from the HUD concept: the body of the edge, and its outermost rim.
uniform vec4 colour : source_color = vec4(0.698, 0.227, 0.180, 1.0);
uniform vec4 rim_colour : source_color = vec4(0.902, 0.349, 0.302, 1.0);
// 0 = invisible, 1 = the strongest hit or the brink of death. Grows both how far in the
// red reaches and how opaque it is.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Window pixels per block; HurtOverlay matches it to the retro screen's scale.
uniform float pixel_size = 2.0;
// Off fades smoothly instead of through the dither, for when the retro screen is off.
uniform bool dither = true;
// How many opacity steps the dither picks between.
uniform float levels = 4.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);


void fragment() {
	vec2 block = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (block + 0.5) * pixel_size * SCREEN_PIXEL_SIZE;
	// A squarish ellipse, so the red runs along all four edges rather than only filling
	// the corners: 1 at the middle of each edge, about 1.19 in the corners.
	vec2 c = abs(uv * 2.0 - 1.0);
	float d = pow(pow(c.x, 4.0) + pow(c.y, 4.0), 0.25);

	float inner = mix(0.95, 0.58, amount);
	float edge = smoothstep(inner, 1.12, d);
	float alpha = edge * mix(0.25, 0.7, amount) * step(0.001, amount);

	if (dither) {
		ivec2 cell = ivec2(block);
		float threshold = BAYER[(cell.y & 3) * 4 + (cell.x & 3)] / 16.0;
		alpha = floor(alpha * levels + threshold) / levels;
	}
	COLOR = vec4(mix(colour.rgb, rim_colour.rgb, edge * edge * edge), clamp(alpha, 0.0, 1.0));
}
