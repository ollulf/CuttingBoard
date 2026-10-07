shader_type canvas_item;

// What still shows through the mask-off grain: MaskBeacon meshes (the Mask-Monger),
// rendered alone by MaskOffVision's beacon camera into `beacon` (transparent elsewhere),
// drawn here as a warm glowing silhouette with a soft halo, its brightest parts (the
// lantern) brightest. Same retro pixel grid, ordered dither and colour bands as the grain
// (mask_off_grain.gdshaderinc), so it reads as part of the spirit view.

uniform sampler2D beacon : filter_nearest, repeat_disable;
// MaskOffVision's fade, 0..1; the silhouette comes in with the grain.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform float pixel_rows = 180.0;
uniform vec3 tint : source_color = vec3(1.0, 0.58, 0.24);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0));
	const float m[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };
	return m[y * 4 + x] / 16.0 - 0.5;
}

void fragment() {
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	float px = screen.y / pixel_rows;
	vec2 fc = floor(FRAGCOORD.xy / px) + 0.5;
	vec2 cell = px / screen;
	vec2 uv = fc * px / screen;
	vec4 c = texture(beacon, uv);
	// Halo: the most covered neighbour within two cells, minus the cell itself.
	float near = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			float w = 1.0 - length(vec2(float(i), float(j))) / 3.0;
			near = max(near, texture(beacon, uv + vec2(float(i), float(j)) * cell).a * w);
		}
	}
	float halo = max(near - c.a, 0.0);
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	float flicker = 0.9 + 0.1 * sin(time * 3.1) * sin(time * 1.7 + 1.0);
	vec3 col = tint * (0.22 + 1.6 * lum) * c.a * flicker + tint * halo * 0.45;
	col += bayer4(fc) * 0.07;
	col = floor(clamp(col, 0.0, 1.0) * 6.0 + 0.5) / 6.0;
	float a = max(c.a, halo * 0.8) * smoothstep(0.3, 1.0, fade);
	COLOR = vec4(col, a);
}
