shader_type spatial;

// Textures
uniform sampler2D splat_map : source_color; // Your Black/White Noise
uniform sampler2D tex_grass : source_color;
uniform sampler2D tex_dirt  : source_color;

// Settings
uniform vec2 splat_scale = vec2(64.0, 64.0); // How often the grass/dirt repeats
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec2 uv_world;

void vertex() {
    // We scale UV by splat_scale so the grass texture repeats many times
    // instead of stretching one giant blade of grass over the whole mountain
    uv_world = UV * splat_scale;
}

void fragment() {
    // 1. Get the noise value (0.0 is black, 1.0 is white)
    float noise_val = texture(splat_map, UV).r;

    // 2. Get the colors from your gradient textures
    vec3 grass = texture(tex_grass, uv_world).rgb;
    vec3 dirt = texture(tex_dirt, uv_world).rgb;

    // 3. Mix them based on the noise
    // If noise is Black -> Dirt. If White -> Grass.
    // We add a smoothstep to make the transition sharper/cleaner
    float weight = smoothstep(0.4, 0.6, noise_val);
    
    vec3 final_color = mix(dirt, grass, weight);

    ALBEDO = final_color;
    ROUGHNESS = roughness;
    METALLIC = 0.0;
    
    // This helps shadows appear correctly on the surface
    NORMAL = normalize(NORMAL);
}