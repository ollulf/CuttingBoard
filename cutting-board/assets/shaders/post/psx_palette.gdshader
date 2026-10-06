shader_type canvas_item;

// The retro screen's grade: draws the low-resolution 3D render at whole-pixel scale,
// pulls it into a fixed palette through a 4x4 Bayer ordered dither, and darkens the
// corners. Runs on PsxScreen's display rect, which sits below every UI layer, so the HUD
// is never dithered.
//
// Colours are compared in sRGB, the space the viewport texture is stored in, which is
// also how the art pitch's previews quantised them.

// Size of the 3D render in pixels; PsxScreen keeps it up to date.
uniform vec2 render_size = vec2(640.0, 360.0);

// 0 shows the plain low-res render, 1 the fully quantised image.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// How far the Bayer pattern pushes a pixel before it is matched to the palette, in
// 0..1 colour units. Larger values blend neighbouring palette colours more.
uniform float dither_spread : hint_range(0.0, 0.5) = 0.1;
// Grade applied before quantising, for tuning the overall level without touching lights.
uniform float exposure : hint_range(0.0, 4.0) = 1.0;
uniform vec4 tint = vec4(1.0);
// Corner darkening: 0 = none.
uniform float vignette : hint_range(0.0, 3.0) = 1.2;

// Tallow Fair: ink, void, hill, sky, dusk, fog, soil, ember, amber, flame, moon, mask.
// Plain sRGB values, the space the texture is in. (Shader uniforms cannot have array
// defaults, so the palette is a constant; edit it here.)
const vec3 PALETTE[12] = vec3[12](
	vec3(0.027, 0.020, 0.039),
	vec3(0.051, 0.031, 0.071),
	vec3(0.102, 0.063, 0.125),
	vec3(0.165, 0.094, 0.188),
	vec3(0.227, 0.141, 0.251),
	vec3(0.290, 0.173, 0.290),
	vec3(0.169, 0.114, 0.063),
	vec3(0.353, 0.227, 0.110),
	vec3(0.659, 0.392, 0.165),
	vec3(0.941, 0.659, 0.220),
	vec3(0.910, 0.831, 0.541),
	vec3(0.851, 0.788, 0.627)
);

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);


vec3 nearest_in_palette(vec3 colour) {
	vec3 best = PALETTE[0];
	float best_distance = 1e9;
	for (int i = 0; i < 12; i++) {
		vec3 d = colour - PALETTE[i];
		float distance = dot(d, d);
		if (distance < best_distance) {
			best_distance = distance;
			best = PALETTE[i];
		}
	}
	return best;
}


void fragment() {
	// The display rect is a whole multiple of the render, and the texture is sampled
	// nearest, so every render pixel becomes a crisp square block.
	vec3 colour = texture(TEXTURE, UV).rgb * exposure * tint.rgb;

	vec2 centred = UV - 0.5;
	colour *= clamp(1.08 - dot(centred, centred) * vignette, 0.0, 1.0);

	ivec2 pixel = ivec2(floor(UV * render_size));
	float threshold = BAYER[(pixel.y & 3) * 4 + (pixel.x & 3)] / 16.0 - 0.5;
	vec3 quantised = nearest_in_palette(colour + threshold * dither_spread);

	COLOR = vec4(mix(colour, quantised, strength), 1.0);
}
