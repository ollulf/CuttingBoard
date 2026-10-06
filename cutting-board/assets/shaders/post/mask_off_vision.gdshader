shader_type canvas_item;

// What a puppet sees with no face on: the world is black and dark wood grain flows
// through it (concept A, docs/concepts/mask-off-vision.md; the look itself lives in
// mask_off_grain.gdshaderinc). Drawn by MaskOffVision on a full-screen ColorRect;
// `fade` closes the black in and then reveals the grain from the centre outwards.

// 0 = the world shows, 1 = black with the grain fully revealed.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
// Seconds of game time, fed by the script.
uniform float time = 0.0;
// Rows of retro pixels the grain is drawn at.
uniform float pixel_rows = 180.0;
uniform float intensity = 1.0;

#include "res://assets/shaders/post/mask_off_grain.gdshaderinc"

void fragment() {
	COLOR = mask_off(FRAGCOORD.xy, 1.0 / SCREEN_PIXEL_SIZE, fade);
}
