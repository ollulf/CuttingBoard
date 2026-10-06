shader_type canvas_item;

// The fun-house mirror hurt effect: warps the finished world image, which it reads back
// from the screen, so that it bulges on a hit and ripples with colour fringes at low
// health. FunhouseMirror drives the numbers; this only bends the picture.
//
// It moves whole pixels of the retro render rather than resampling them: every output
// block of `pixel_size` window pixels takes the colour of exactly one source block,
// read at that block's centre with nearest filtering, so the palette and the dither stay
// crisp however hard the world wobbles. With the retro screen off a block is one window
// pixel. All distances are in units of 1/360 of the screen height, the units the concept
// page worked in, so the effect looks the same at any window size.

uniform sampler2D screen : hint_screen_texture, filter_nearest;

// Window pixels per pixel of the retro render, and where in the window that render's
// pixel grid starts (PsxScreen centres it and may crop a few pixels off the edges).
uniform float pixel_size = 1.0;
uniform vec2 grid_offset = vec2(0.0);

// Lens bulge: 0 = flat, positive pushes the middle outwards towards the viewer.
uniform float bulge = 0.0;
// Where the bulge is centred, 0..1 across the screen.
uniform vec2 bulge_centre = vec2(0.5);
// Squash and stretch of the whole frame: positive is wide and short.
uniform float squash = 0.0;
// Ripple strength; the waves run on `time`.
uniform float wobble = 0.0;
uniform float time = 0.0;
// Red/cyan fringe in units at the edges of the screen, fading to none in the middle.
uniform float fringe = 0.0;

const float UNITS = 360.0;


// The same squarish-ellipse edge distance as hurt_vignette.gdshader: 0 in the middle,
// 1 at the middle of each edge, about 1.19 in the corners.
float edge_distance(vec2 uv) {
	vec2 c = abs(uv * 2.0 - 1.0);
	return pow(pow(c.x, 4.0) + pow(c.y, 4.0), 0.25);
}


// The colour of the source block under `px` (window pixels).
vec4 read_block(vec2 px, vec2 window) {
	vec2 cell = floor((px - grid_offset) / pixel_size);
	// Keep to blocks whose centre is on screen, so the edges repeat instead of reading
	// past the frame.
	vec2 first = ceil((-grid_offset) / pixel_size - 0.5);
	vec2 last = floor((window - grid_offset) / pixel_size - 0.5);
	cell = clamp(cell, first, last);
	return texture(screen, ((cell + 0.5) * pixel_size + grid_offset) / window);
}


void fragment() {
	vec2 window = 1.0 / SCREEN_PIXEL_SIZE;
	// The centre of the block this fragment is in, in window pixels and in units.
	vec2 cell = floor((SCREEN_UV * window - grid_offset) / pixel_size);
	vec2 here = (cell + 0.5) * pixel_size + grid_offset;
	float unit = window.y / UNITS;
	vec2 size = window / unit;
	vec2 p = here / unit;

	// Squash and stretch about the middle of the screen.
	vec2 stretch = vec2(1.0 - squash * 0.12, 1.0 + squash * 0.25);
	p = size * 0.5 + (p - size * 0.5) / stretch;

	// A Gaussian lens: pulling the samples towards the centre magnifies what is there.
	vec2 centre = bulge_centre * size;
	vec2 d = p - centre;
	p = centre + d * (1.0 - bulge * exp(-dot(d, d) / 12100.0));

	// Two crossed sine waves.
	if (wobble > 0.003) {
		p.x += wobble * 10.0 * sin(p.y * 0.045 + time * 3.1);
		p.y += wobble * 6.0 * sin(p.x * 0.032 + time * 2.3);
	}

	// Fringe: red and blue read whole blocks to either side of green.
	vec2 src = p * unit;
	float shift = round(fringe * edge_distance(here / window) * unit / pixel_size) * pixel_size;
	COLOR = vec4(
		read_block(src + vec2(shift, 0.0), window).r,
		read_block(src, window).g,
		read_block(src - vec2(shift, 0.0), window).b,
		1.0
	);
}
