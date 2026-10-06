// PS1-style vertex snapping and affine texture mapping, shared by every spatial shader
// that wants to wobble like the rest of the world.
//
// Both are driven by global shader uniforms (Project Settings > Shader Globals), which
// PsxScreen sets at runtime so that switching the retro screen off also switches these
// off everywhere:
//   psx_snap_res   the grid vertices snap to, in screen pixels; (0, 0) turns snapping off
//   psx_affine     0 = perspective-correct UVs, 1 = full PS1 affine texture swim
//
// Usage in a spatial shader:
//   #include "res://assets/shaders/include/psx.gdshaderinc"
//   varying vec3 psx_uv;
//   void vertex() {
//       ... move VERTEX ...
//       POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
//       psx_uv = psx_affine_uv_out(UV, POSITION);
//   }
//   void fragment() {
//       vec2 uv = psx_affine_uv_in(psx_uv, UV);
//   }

global uniform vec2 psx_snap_res;
global uniform float psx_affine;


// Snaps a clip-space position to the low-resolution pixel grid.
vec4 psx_snap(vec4 clip) {
	if (psx_snap_res.x <= 0.0 || clip.w <= 0.0001) {
		return clip;
	}
	vec2 half_res = psx_snap_res * 0.5;
	clip.xy = round(clip.xy / clip.w * half_res) / half_res * clip.w;
	return clip;
}


// UV pre-multiplied by w, so interpolating it and dividing by the interpolated w in the
// fragment shader undoes the perspective correction the GPU applies.
vec3 psx_affine_uv_out(vec2 uv, vec4 clip) {
	return vec3(uv * clip.w, clip.w);
}


vec2 psx_affine_uv_in(vec3 affine_uv, vec2 perspective_uv) {
	if (psx_affine <= 0.0 || affine_uv.z <= 0.0) {
		return perspective_uv;
	}
	return mix(perspective_uv, affine_uv.xy / affine_uv.z, psx_affine);
}
