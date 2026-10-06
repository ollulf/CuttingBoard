shader_type spatial;

// A small glowing mote, such as a will-o'-wisp: a camera-facing disc with a hot core and
// a soft falloff. Unshaded, and outside the fog, so it carries across the dark meadow
// further than the light it casts.

render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

#include "res://assets/shaders/include/psx.gdshaderinc"

uniform vec4 core_color : source_color = vec4(0.941, 0.659, 0.220, 1.0);
uniform vec4 glow_color : source_color = vec4(0.659, 0.392, 0.165, 1.0);
uniform float intensity = 2.0;
// Radius of the solid core, as a share of the quad.
uniform float core_size : hint_range(0.0, 0.5) = 0.12;


void vertex() {
	// Billboard: keep the quad's centre and scale, face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}


void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(core_size, core_size + 0.05, r * 0.5);
	float glow = pow(clamp(1.0 - r, 0.0, 1.0), 2.5);
	ALBEDO = (core_color.rgb * core + glow_color.rgb * glow * 0.8) * intensity;
}
