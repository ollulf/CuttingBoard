shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001);
uniform ivec2 albedo_texture_size;

// === Global wind controls (same on all tree materials) ===
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.3); // XZ direction
uniform float wind_strength : hint_range(0.0, 2.0, 0.01) = 1.0; // overall sway
uniform float wind_frequency : hint_range(0.1, 5.0, 0.01) = 0.8; // speed of big sway

// === How much the tree bends with height ===
// 0 = totally rigid, 1 = full bend at top
uniform float bend_top_amount : hint_range(0.0, 2.0, 0.01) = 0.5;
uniform float bend_power : hint_range(0.1, 4.0, 0.01) = 1.5; // curve of falloff

// Optional: scale height if your tree isn’t modeled around y = 0 at the base
uniform float height_scale : hint_range(0.1, 100.0, 0.1) = 25.0;

// Bottom part that should stay mostly rigid (0 = none, 0.3 = bottom 30%)
uniform float base_rigidity : hint_range(0.0, 0.9, 0.01) = 0.3;

// === Wind noise texture ===
uniform sampler2D wind_noise;              // tiling noise texture
uniform float noise_scale : hint_range(0.001, 1.0, 0.001) = 0.05;   // how stretched the noise is in world space
uniform float noise_speed : hint_range(0.0, 2.0, 0.01) = 0.2;       // how fast the noise “moves”
uniform float noise_influence : hint_range(0.0, 2.0, 0.01) = 0.6;   // how strongly noise affects sway

void vertex() {
    vec3 pos = VERTEX;

    // ---- 1. Height-based factor: base barely moves, top moves a lot ----
    float raw_height = clamp(pos.y / height_scale, 0.0, 1.0);

    // make the bottom base_rigidity portion rigid
    float t = clamp((raw_height - base_rigidity) / (1.0 - base_rigidity), 0.0, 1.0);

    // shape it so it ramps up more at the top
    float height_factor = pow(t, bend_power) * bend_top_amount;

    // ---- 2. Large-scale trunk/branch sway with noise ----
    vec3 wind_dir = normalize(vec3(wind_direction.x, 0.0, wind_direction.z));

    // world position for per-tree variation and noise sampling
    vec3 world_pos = (MODEL_MATRIX * vec4(pos, 1.0)).xyz;

    // base phase so nearby trees are different
    float phase = dot(world_pos.xz, vec2(0.1, 0.13));

    // noise UVs: use world XZ so noise is stable in world space
    vec2 noise_uv = world_pos.xz * noise_scale
        + vec2(TIME * noise_speed, TIME * noise_speed * 1.37);

    // sample noise texture (assume grayscale), remap 0..1 -> -1..1
    float noise_sample = texture(wind_noise, noise_uv).r * 2.0 - 1.0;

    // combine base sine motion with noise perturbation
    float sway = sin(TIME * wind_frequency + phase + noise_sample * noise_influence);

    vec3 sway_offset = wind_dir * sway * wind_strength * height_factor;
    pos += sway_offset;

    VERTEX = pos;
}

void fragment() {
    vec2 base_uv = UV;

    vec4 albedo_tex = texture(texture_albedo, base_uv);
    ALBEDO = albedo.rgb * albedo_tex.rgb;

    ALPHA *= albedo.a * albedo_tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
