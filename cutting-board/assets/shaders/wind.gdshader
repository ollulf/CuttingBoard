shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform bool wind_enabled = true;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0);
uniform ivec2 albedo_texture_size;

// Wind controls (assume wind_direction is already normalized in XZ)
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.3);
uniform float wind_strength = 1.0;
uniform float wind_frequency = 0.8;

// Bending
uniform float bend_top_amount = 0.5;
uniform float bend_power = 1.5;
uniform float height_scale = 25.0;
uniform float base_rigidity = 0.3;

// Distance where wind stops
uniform float wind_max_distance = 400.0;

void vertex() {
    if(wind_enabled)
	{
		   vec3 pos = VERTEX;
		
		    // Translation column of MODEL_MATRIX = object/world position of origin
    vec3 tree_center = MODEL_MATRIX[3].xyz;

    vec3 to_cam = tree_center - CAMERA_POSITION_WORLD;
    float dist2 = dot(to_cam, to_cam);
    float max_dist2 = wind_max_distance * wind_max_distance;

    // If tree is far away -> no wind work at all
    if (dist2 < max_dist2) {
        float dist = sqrt(dist2); // only for trees close enough
        float fade = smoothstep(wind_max_distance, wind_max_distance * 0.5, dist);

        // --- 2. Height-based bending ---

        float raw_height = clamp(pos.y / height_scale, 0.0, 1.0);
        float t = clamp((raw_height - base_rigidity) / (1.0 - base_rigidity), 0.0, 1.0);
        float height_factor = pow(t, bend_power) * bend_top_amount;

        // Use only XZ wind direction, pre-normalized in the uniform
        vec3 wind_dir = normalize(vec3(wind_direction.x, 0.0, wind_direction.z));

        // World position for phase
        vec3 world_pos = (MODEL_MATRIX * vec4(pos, 1.0)).xyz;
        float phase = dot(world_pos.xz, vec2(0.1, 0.13));
        float sway = sin(TIME * wind_frequency + phase);

        pos += wind_dir * sway * wind_strength * height_factor * fade;
    }

    VERTEX = pos;
	}


}

void fragment() {
    vec4 albedo_tex = texture(texture_albedo, UV);
    ALBEDO = albedo.rgb * albedo_tex.rgb;
    ALPHA  = albedo.a * albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
