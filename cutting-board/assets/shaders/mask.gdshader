shader_type spatial;

// A carved wooden face mask, drawn procedurally on a flat quad: an oval narrowing to the
// chin, vertical wood grain, two almond eye holes and a mouth slit. One shader serves
// every faction; the materials only change colours and proportions.
//
// UV (0, 0) is the top-left of the quad as seen from the front.

render_mode cull_disabled, diffuse_lambert, specular_disabled;

#include "res://assets/shaders/include/psx.gdshaderinc"

uniform vec4 wood_color : source_color = vec4(0.851, 0.788, 0.627, 1.0);
uniform vec4 grain_color : source_color = vec4(0.62, 0.53, 0.38, 1.0);
uniform vec4 hole_color : source_color = vec4(0.027, 0.020, 0.039, 1.0);
// Lets the mask show a little in the dark, as a share of its own colour, so masked
// figures read before anything else in the frame.
uniform float self_glow : hint_range(0.0, 1.0) = 0.25;
// Light inside the eye holes; black means none.
uniform vec4 eye_glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float eye_glow_energy = 1.0;

// Shape, in units of the quad's half-size, y pointing down.
uniform float chin_taper : hint_range(0.0, 0.8) = 0.3;
uniform vec2 eye_center = vec2(0.36, -0.12);
uniform vec2 eye_size = vec2(0.2, 0.11);
uniform float eye_slant = 0.25;
uniform float mouth_y = 0.5;
uniform vec2 mouth_size = vec2(0.32, 0.045);
uniform float grain_density = 22.0;

varying vec3 psx_uv;


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


// 1 inside an almond-shaped eye centred at `c`, tilted by `slant` outward.
float eye(vec2 p, vec2 c, float slant) {
	vec2 d = p - c;
	d.y += d.x * slant;
	return step(length(d / eye_size), 1.0);
}


void vertex() {
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	psx_uv = psx_affine_uv_out(UV, POSITION);
}


void fragment() {
	vec2 p = (psx_affine_uv_in(psx_uv, UV) - 0.5) * 2.0;
	// Oval outline that narrows below the cheekbones.
	float width = 1.0 - max(p.y, 0.0) * chin_taper;
	if (length(vec2(p.x / width, p.y)) > 1.0) {
		discard;
	}
	// Grain: wavy vertical lines, broken up by noise.
	float wave = p.x * grain_density + value_noise(p * vec2(2.0, 5.0)) * 4.0;
	float grain = smoothstep(0.6, 1.0, sin(wave) * 0.5 + 0.5) * 0.7
			+ value_noise(p * vec2(30.0, 3.0)) * 0.3;
	vec3 colour = mix(wood_color.rgb, grain_color.rgb, grain);
	// Darker towards the rim, as if the face were carved hollow.
	colour *= mix(1.0, 0.7, smoothstep(0.6, 1.0, length(vec2(p.x / width, p.y))));

	float holes = max(eye(p, vec2(-eye_center.x, eye_center.y), -eye_slant),
			eye(p, eye_center, eye_slant));
	float mouth = step(abs(p.x), mouth_size.x) * step(abs(p.y - mouth_y), mouth_size.y);
	holes = max(holes, mouth);

	ALBEDO = mix(colour, hole_color.rgb, holes);
	EMISSION = colour * self_glow * (1.0 - holes) + eye_glow.rgb * eye_glow_energy * holes;
	ROUGHNESS = 1.0;
}
