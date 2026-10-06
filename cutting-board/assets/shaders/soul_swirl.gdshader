shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

// The caught soul inside a soul bottle: a smoky swirl turning round and round, with a
// scared face (wide eyes, an "O" mouth) dragged about in it, now half seen, now gone.
//
// Drawn on a small sphere in the bottle's hollow. The pattern is laid out on the disc the
// sphere shows the camera (its view-space normal), so the face always looks out at you.
// Added on top of what is behind, so dark parts of the pattern simply vanish.

// The soul's colour. Kept on the palette's flame/amber side so the retro grade keeps it
// yellow; SoulBottle sets it, together with its light.
uniform vec3 soul_colour : source_color = vec3(1.0, 0.72, 0.16);
uniform float brightness = 1.1;
// How many arms the swirl has, how hard it twists towards the middle, how fast it turns.
uniform float arms = 3.0;
uniform float twist = 5.0;
uniform float speed = 1.3;
// Seconds for the face to surface and sink once.
uniform float face_period = 4.5;
// Per-bottle offset so neighbouring bottles don't swirl in step.
uniform float seed = 0.0;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


// An ellipse ring: 1 on the outline of the ellipse at centre c with radii r, 0 away from it.
float ring(vec2 p, vec2 c, vec2 r, float width) {
	float d = length((p - c) / r) - 1.0;
	return 1.0 - smoothstep(0.0, width, abs(d));
}


// A filled ellipse, soft-edged.
float blob(vec2 p, vec2 c, vec2 r) {
	return 1.0 - smoothstep(0.7, 1.0, length((p - c) / r));
}


void fragment() {
	float t = TIME + seed;
	vec2 p = NORMAL.xy;
	float r = length(p);
	float a = atan(p.y, p.x);

	// The swirl: arms wound tighter towards the middle, roughened by drifting noise.
	float wound = a + twist * (1.0 - r) - t * speed;
	float smoke = noise(vec2(wound * 1.3, r * 4.0 - t * 0.6)) * 0.9;
	float bands = 0.5 + 0.5 * sin(wound * arms + smoke * 3.0);
	bands = smoothstep(0.25, 0.95, bands);

	// The face, warped by the same swirl: dragged round a little more near the middle,
	// and wobbling as if pulled through water.
	float drag = 0.55 * sin(t * 0.9) * (1.0 - r);
	vec2 f = mat2(vec2(cos(drag), sin(drag)), vec2(-sin(drag), cos(drag))) * p;
	f += 0.06 * vec2(sin(f.y * 9.0 + t * 2.3), cos(f.x * 8.0 - t * 1.9));
	f.y *= 1.0 + 0.18 * sin(t * 1.4);  // stretched long, then squashed
	float eyes = blob(f, vec2(-0.27, 0.2), vec2(0.13, 0.19))
		+ blob(f, vec2(0.27, 0.2), vec2(0.13, 0.19));
	float pupils = blob(f, vec2(-0.27, 0.17), vec2(0.04, 0.05))
		+ blob(f, vec2(0.27, 0.17), vec2(0.04, 0.05));
	float mouth = blob(f, vec2(0.0, -0.32), vec2(0.13, 0.17));
	float rims = ring(f, vec2(-0.27, 0.2), vec2(0.13, 0.19), 0.35)
		+ ring(f, vec2(0.27, 0.2), vec2(0.13, 0.19), 0.35)
		+ ring(f, vec2(0.0, -0.32), vec2(0.13, 0.17), 0.35)
		// Raised brows, pinched up in the middle: the scared bit.
		+ ring(f, vec2(-0.25, 0.48), vec2(0.16, 0.06), 0.5) * step(f.x, -0.12)
		+ ring(f, vec2(0.25, 0.48), vec2(0.16, 0.06), 0.5) * step(0.12, f.x);
	// Surfaces and sinks again; never fully crisp.
	float seen = mix(0.3, 0.9, smoothstep(0.15, 0.85, 0.5 + 0.5 * sin(TAU * t / face_period)));

	float glow = mix(0.25, 1.0, bands) * (1.0 - smoothstep(0.75, 1.0, r) * 0.6);
	// Eyes and mouth are hollows in the smoke, ringed with brighter wisps; the pupils
	// are pinpricks of light in the dark eyes.
	glow *= 1.0 - seen * clamp(eyes + mouth, 0.0, 1.0) * 0.9;
	glow += seen * (clamp(rims, 0.0, 1.0) * 0.6 + clamp(pupils, 0.0, 1.0) * 1.2);
	// A hot core so the whole thing reads as a light.
	glow += (1.0 - smoothstep(0.0, 0.6, r)) * 0.25;

	ALBEDO = soul_colour * glow * brightness;
}
