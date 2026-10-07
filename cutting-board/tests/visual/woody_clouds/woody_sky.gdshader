shader_type sky;

// Concept B: a sky whose clouds are wood. Cloud shapes come from drifting value noise
// projected on a flat ceiling; inside each cloud the same noise is cut into bands, so the
// cloud reads as an end-grain slice of a log (growth rings) with a dark bark rim.

uniform vec3 sky_top : source_color = vec3(0.32, 0.52, 0.78);
uniform vec3 sky_horizon : source_color = vec3(0.70, 0.76, 0.82);
uniform vec3 wood_light : source_color = vec3(0.90, 0.76, 0.54);
uniform vec3 wood_dark : source_color = vec3(0.66, 0.46, 0.28);
uniform vec3 bark : source_color = vec3(0.30, 0.18, 0.10);
uniform float coverage : hint_range(0.0, 1.0) = 0.48;
uniform float rings = 7.0;
uniform float scale = 1.1;
uniform vec2 wind = vec2(0.012, 0.004);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	float up = max(EYEDIR.y, 0.0);
	vec3 col = mix(sky_horizon, sky_top, pow(up, 0.6));
	if (EYEDIR.y > 0.02) {
		// Flat cloud ceiling: farther clouds bunch up toward the horizon.
		vec2 uv = EYEDIR.xz / (EYEDIR.y + 0.08) * scale + TIME * wind;
		float n = fbm(uv);
		float edge = 1.0 - coverage;
		float cloud = smoothstep(edge, edge + 0.015, n);
		// Growth rings: bands of the same noise, so they follow the cloud outline.
		float band = fract((n - edge) * rings * 6.0);
		float grain = smoothstep(0.35, 0.5, band) * (1.0 - smoothstep(0.85, 1.0, band));
		vec3 wood = mix(wood_light, wood_dark, grain * 0.7);
		// Bark rim just inside the outline.
		float rim = 1.0 - smoothstep(edge + 0.015, edge + 0.035, n);
		wood = mix(wood, bark, rim);
		// Fade into the horizon haze.
		float fade = smoothstep(0.02, 0.18, EYEDIR.y);
		col = mix(col, wood, cloud * fade);
	}
	COLOR = col;
}
