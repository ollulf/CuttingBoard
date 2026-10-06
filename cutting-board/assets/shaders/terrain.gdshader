shader_type spatial;

// Ground material for the generated Terrain. Textures are projected from above in world
// space, so the terrain needs no UVs. What shows where:
//   - grass everywhere, broken up by patches of forest floor so the tiling does not show
//   - rocky forest floor on steep slopes
//   - dirt on paths; the Terrain paints path coverage into the vertex colour's red channel
//     and village squares get gravel through the green channel

render_mode diffuse_burley, specular_disabled;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_texture : source_color, filter_linear_mipmap, repeat_enable;

// Metres covered by one repeat of a texture.
uniform float tile_size = 4.0;
// Size of the forest-floor patches mixed into the grass, in metres.
uniform float patch_size = 28.0;
uniform float patch_amount : hint_range(0.0, 1.0) = 0.35;
// Slope (1 - normal.y) where rock starts and where it has fully taken over.
uniform float slope_start = 0.12;
uniform float slope_end = 0.3;
uniform vec4 grass_tint : source_color = vec4(1.0);
uniform vec4 forest_tint : source_color = vec4(1.0);
uniform vec4 path_tint : source_color = vec4(1.0);
uniform vec4 gravel_tint : source_color = vec4(1.0);

varying vec3 world_pos;
varying vec3 world_normal;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec2 uv = world_pos.xz / tile_size;
	// A second, rotated and larger sample of the grass hides the repeat at a distance.
	vec2 uv_far = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37;
	vec3 grass = mix(texture(grass_texture, uv).rgb, texture(grass_texture, uv_far).rgb, 0.35);
	grass *= grass_tint.rgb;
	vec3 forest = texture(forest_texture, uv).rgb * forest_tint.rgb;
	vec3 path = texture(path_texture, uv * 0.75).rgb * path_tint.rgb;
	vec3 gravel = texture(gravel_texture, uv).rgb * gravel_tint.rgb;

	float patches = value_noise(world_pos.xz / patch_size) * 0.65
			+ value_noise(world_pos.xz / (patch_size * 0.3)) * 0.35;
	float forest_weight = smoothstep(1.0 - patch_amount, 1.0 - patch_amount + 0.2, patches);
	float slope = 1.0 - world_normal.y;
	forest_weight = max(forest_weight, smoothstep(slope_start, slope_end, slope));

	// Ragged edges on paths: the painted coverage is nudged by fine noise.
	float edge_noise = value_noise(world_pos.xz * 1.3) * 0.35 - 0.17;
	float path_weight = smoothstep(0.35, 0.65, COLOR.r + edge_noise);
	float gravel_weight = smoothstep(0.35, 0.65, COLOR.g + edge_noise);

	vec3 albedo = mix(grass, forest, forest_weight);
	albedo = mix(albedo, gravel, gravel_weight);
	albedo = mix(albedo, path, path_weight);
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
}
