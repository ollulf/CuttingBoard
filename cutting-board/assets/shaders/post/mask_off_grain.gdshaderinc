// The mask-off look shared by mask_off_vision.gdshader (the full-screen layer) and
// mask_off_backdrop.gdshader (the same look drawn behind the pause menu's mask): black
// with dark wood grain flowing through it, PS1-style at a low resolution with a 4x4
// ordered dither and six colour bands. The includer declares `time`, `pixel_rows` and
// `intensity`.

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * n(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0));
	const float m[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };
	return m[y * 4 + x] / 16.0 - 0.5;
}

vec3 grain(vec2 uv) {
	vec2 w = uv * vec2(1.0, 3.0) + vec2(fbm(uv * 2.0 + time * 0.05) * 1.5, time * 0.04);
	float g = abs(sin(w.y * 9.0 + fbm(w * 1.3) * 6.0));
	return vec3(0.10, 0.06, 0.03) * (1.0 - g) * 1.4;
}

// `frag` is the fragment's pixel position (FRAGCOORD.xy) in a target `screen` pixels big.
// Returns the colour and alpha for `amount` (0 = the world shows, 1 = black with the grain
// fully revealed): the black closes in first, then the grain comes in from the centre.
vec4 mask_off(vec2 frag, vec2 screen, float amount) {
	float px = screen.y / pixel_rows;
	// Retro pixel coordinates, flipped so y runs up as in the concept.
	vec2 fc = floor(vec2(frag.x, screen.y - frag.y) / px) + 0.5;
	vec2 res = floor(screen / px);
	vec2 uv = (fc - 0.5 * res) / res.y;
	vec3 c = grain(uv);
	float reveal = max(0.0, (amount - 0.3) / 0.7);
	float rr = length(uv) / 0.9;
	c *= intensity * 1.6 * smoothstep(rr - 0.2, rr, reveal * 1.25);
	c += bayer(fc) * 0.07;
	c = floor(clamp(c, 0.0, 1.0) * 6.0 + 0.5) / 6.0;
	return vec4(c, smoothstep(0.0, 0.3, amount));
}
