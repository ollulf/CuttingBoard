shader_type spatial;

// The Tallow Fair moon: a pale disc that is too large, with an iris and a pupil that
// watch the player. Drawn on a quad that Moon keeps facing the camera from far away;
// unshaded and outside the fog so it always reads, but depth-tested so trees and hills
// cover it.

render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;

#include "res://assets/shaders/include/psx.gdshaderinc"

uniform vec4 moon_color : source_color = vec4(0.910, 0.831, 0.541, 1.0);
uniform vec4 shade_color : source_color = vec4(0.78, 0.66, 0.42, 1.0);
uniform vec4 iris_color : source_color = vec4(0.659, 0.392, 0.165, 1.0);
uniform vec4 pupil_color : source_color = vec4(0.027, 0.020, 0.039, 1.0);
uniform vec4 halo_color : source_color = vec4(0.910, 0.831, 0.541, 1.0);

// Radii in UV units of the quad (0.5 = the quad's edge).
uniform float disc_radius = 0.36;
uniform float iris_radius = 0.15;
uniform float pupil_radius = 0.085;
// Where the eye is looking, in disc radii from the centre; Moon drives this.
uniform vec2 pupil_offset = vec2(0.0);
// Faint ring of light around the disc.
uniform float halo_strength : hint_range(0.0, 1.0) = 0.22;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


void vertex() {
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}


void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	if (r > disc_radius) {
		// Halo: fades out from the rim to the quad's edge.
		float halo = 1.0 - smoothstep(disc_radius, 0.5, r);
		ALBEDO = halo_color.rgb;
		ALPHA = halo * halo * halo_strength;
	} else {
		// Blotchy maria so the disc is not a flat sticker.
		float maria = value_noise(p * 9.0 + 3.1) * 0.6 + value_noise(p * 23.0) * 0.4;
		vec3 colour = mix(moon_color.rgb, shade_color.rgb, smoothstep(0.5, 0.8, maria) * 0.6);
		// The eye. The pupil wanders; the iris follows it more lazily, as if the
		// eyeball itself were turning.
		vec2 pupil_at = pupil_offset * disc_radius;
		float iris = length(p - pupil_at * 0.8);
		float pupil = length(p - pupil_at);
		colour = mix(colour, iris_color.rgb, 1.0 - smoothstep(iris_radius - 0.012, iris_radius, iris));
		colour = mix(colour, pupil_color.rgb, 1.0 - smoothstep(pupil_radius - 0.01, pupil_radius, pupil));
		ALBEDO = colour;
		ALPHA = 1.0;
	}
}
