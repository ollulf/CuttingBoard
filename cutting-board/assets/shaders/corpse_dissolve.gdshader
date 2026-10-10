shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 9.0;
uniform float edge_width : hint_range(0.0, 0.3) = 0.08;
uniform vec4 char_color : source_color = vec4(0.12, 0.06, 0.03, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.18, 1.0);
uniform float edge_energy = 4.0;
uniform float height_bias = 0.0;
uniform float split : hint_range(0.0, 1.0) = 0.0;
uniform float seam_weight : hint_range(0.5, 1.0) = 0.97;

varying vec3 local_pos;
varying vec3 world_pos;
varying float rigid;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rigid = max(max(BONE_WEIGHTS.x, BONE_WEIGHTS.y), max(BONE_WEIGHTS.z, BONE_WEIGHTS.w));
}

void fragment() {
	if (split > 0.5 && rigid < seam_weight) {
		discard;
	}
	float n = fbm(local_pos * noise_scale) + world_pos.y * height_bias;
	float cut = progress * (1.0 + edge_width * 2.0 + abs(height_bias) * 2.0) - edge_width;
	if (n < cut) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, edge_width, n - cut);
	float charred = 1.0 - smoothstep(0.0, edge_width * 2.5, n - cut);
	vec3 base = mix(albedo.rgb, char_color.rgb, charred * step(0.001, progress));
	ALBEDO = base;
	ROUGHNESS = roughness;
	EMISSION = edge_color.rgb * edge_energy * edge * edge * step(0.001, progress);
}
