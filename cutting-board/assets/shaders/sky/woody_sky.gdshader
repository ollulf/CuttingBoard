shader_type sky;

// A sky whose clouds are wood. Cloud shapes come from drifting value noise projected on a
// flat ceiling; inside each cloud the same noise is cut into bands, so the cloud reads as
// an end-grain slice of a log (growth rings) with a dark bark rim.
//
// The gradient behind the clouds follows ProceduralSkyMaterial (same colours and curves),
// and the clouds are left out of the radiance cubemap, so ambient light and reflections
// stay what the plain procedural sky gave.

group_uniforms sky;
uniform vec3 sky_top : source_color = vec3(0.385, 0.454, 0.55);
uniform vec3 sky_horizon : source_color = vec3(0.6463, 0.6558, 0.6708);
uniform float sky_curve : hint_range(0.001, 1.0) = 0.15;
uniform vec3 ground_bottom : source_color = vec3(0.2, 0.169, 0.133);
uniform vec3 ground_horizon : source_color = vec3(0.6463, 0.6558, 0.6708);
uniform float ground_curve : hint_range(0.001, 1.0) = 0.02;
// Angular radius of the sun disc drawn for the first directional light; 0 hides it.
uniform float sun_size_degrees : hint_range(0.0, 10.0) = 1.5;

group_uniforms clouds;
uniform vec3 wood_light : source_color = vec3(0.90, 0.76, 0.54);
uniform vec3 wood_dark : source_color = vec3(0.66, 0.46, 0.28);
uniform vec3 bark : source_color = vec3(0.30, 0.18, 0.10);
// Share of the sky covered by clouds.
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.48;
// Growth rings per cloud, roughly.
uniform float ring_density : hint_range(0.0, 20.0) = 7.0;
// How strongly the dark rings show against the light wood.
uniform float ring_strength : hint_range(0.0, 1.0) = 0.7;
// Width of the bark rim inside the cloud outline.
uniform float bark_width : hint_range(0.0, 0.1) = 0.02;
// Size of the cloud pattern; bigger values make smaller clouds.
uniform float cloud_scale = 1.1;
uniform vec2 drift_direction = vec2(0.95, 0.3);
uniform float drift_speed = 0.0126;

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
	// Gradient as ProceduralSkyMaterial draws it.
	float v_angle = acos(clamp(EYEDIR.y, -1.0, 1.0));
	vec3 col;
	if (EYEDIR.y >= 0.0) {
		float c = 1.0 - v_angle / (PI * 0.5);
		col = mix(sky_horizon, sky_top, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	} else {
		float c = (v_angle - PI * 0.5) / (PI * 0.5);
		col = mix(ground_horizon, ground_bottom, clamp(1.0 - pow(1.0 - c, 1.0 / ground_curve), 0.0, 1.0));
	}
	if (LIGHT0_ENABLED && sun_size_degrees > 0.0) {
		float sun_angle = acos(clamp(dot(EYEDIR, LIGHT0_DIRECTION), -1.0, 1.0));
		float disc = 1.0 - smoothstep(radians(sun_size_degrees) * 0.8, radians(sun_size_degrees), sun_angle);
		col = mix(col, LIGHT0_COLOR * LIGHT0_ENERGY, disc);
	}
	// Clouds only in the visible sky, not in the radiance cubemap behind ambient light.
	if (!AT_CUBEMAP_PASS && EYEDIR.y > 0.02) {
		// Flat cloud ceiling: farther clouds bunch up toward the horizon.
		vec2 drift = normalize(drift_direction + vec2(1e-5)) * drift_speed;
		vec2 uv = EYEDIR.xz / (EYEDIR.y + 0.08) * cloud_scale + TIME * drift;
		float n = fbm(uv);
		float edge = 1.0 - cloud_cover;
		float cloud = smoothstep(edge, edge + 0.015, n);
		// Growth rings: bands of the same noise, so they follow the cloud outline.
		float band = fract((n - edge) * ring_density * 6.0);
		float grain = smoothstep(0.35, 0.5, band) * (1.0 - smoothstep(0.85, 1.0, band));
		vec3 wood = mix(wood_light, wood_dark, grain * ring_strength);
		// Bark rim just inside the outline.
		float rim = 1.0 - smoothstep(edge + 0.015, edge + 0.015 + bark_width, n);
		wood = mix(wood, bark, rim);
		// Fade into the horizon haze.
		float fade = smoothstep(0.02, 0.18, EYEDIR.y);
		col = mix(col, wood, cloud * fade);
	}
	COLOR = col;
}
