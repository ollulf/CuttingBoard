shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// The mask-off look (mask_off_grain.gdshaderinc) drawn on a camera-fixed sheet just
// behind the pause menu's mask: while the mask is off the face the world goes black and
// grained, but the mask, its carved words and chips still draw in front (depth-tested).
// Driven by PauseMenu.

// 0 = the world shows, 1 = black with the grain fully revealed.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
// Seconds of game time, fed by the script.
uniform float time = 0.0;
// Rows of retro pixels the grain is drawn at.
uniform float pixel_rows = 180.0;
uniform float intensity = 1.0;

#include "res://assets/shaders/post/mask_off_grain.gdshaderinc"

void fragment() {
	vec4 c = mask_off(FRAGCOORD.xy, VIEWPORT_SIZE, fade);
	// The canvas layer writes sRGB; a spatial ALBEDO is linear, so convert to match it.
	ALBEDO = pow(c.rgb, vec3(2.2));
	ALPHA = c.a;
}
