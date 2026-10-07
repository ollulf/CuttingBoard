shader_type spatial;

// Concept C: plywood cut-out flats. Long grain runs along the board's x axis, with a
// slow wobble; the sawn edges (faces not pointing along z) are darker end grain.

uniform vec3 wood_light : source_color = vec3(0.86, 0.72, 0.52);
uniform vec3 wood_dark : source_color = vec3(0.62, 0.44, 0.27);
uniform vec3 edge_color : source_color = vec3(0.42, 0.27, 0.15);
uniform float grain_density = 1.6;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

void fragment() {
	float wobble = sin(obj_pos.x * 0.35) * 0.8 + sin(obj_pos.x * 1.3 + obj_pos.y) * 0.15;
	float g = fract((obj_pos.y + wobble) * grain_density);
	float line = smoothstep(0.0, 0.12, g) * (1.0 - smoothstep(0.55, 0.7, g));
	vec3 col = mix(wood_dark, wood_light, line);
	float face = abs(obj_normal.z);
	ALBEDO = mix(edge_color, col, step(0.5, face));
	ROUGHNESS = 0.9;
}
