shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// --- Uniforms from MaterialLibrary.gd ---

// Global Blending Map (R=Grass, G=Dirt, B=Rock, A=Corrupt)
uniform sampler2D splat_map : repeat_enable, filter_linear_mipmap;

// Biome Properties
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wetness_level : hint_range(0.0, 1.0) = 0.5;
uniform float height_blend_strength : hint_range(0.0, 1.0) = 0.8; // Controls how sharp the blend is

// --- Anti-Tiling Settings ---
uniform float distance_fade_start = 10.0;
uniform float distance_fade_length = 40.0;
uniform float macro_variation_scale = 0.05; // Scale for the "far away" texture layer

// --- Grass Layer (R) ---
uniform sampler2D tex_grass_diffuse : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_grass_normal : hint_normal, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_grass_roughness : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_grass_displacement : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform float tex_grass_scale = 0.5;

// --- Dirt Layer (G) ---
uniform sampler2D tex_dirt_diffuse : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_dirt_normal : hint_normal, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_dirt_roughness : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_dirt_displacement : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform float tex_dirt_scale = 0.5;

// --- Rock Layer (B) ---
uniform sampler2D tex_rock_diffuse : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_rock_normal : hint_normal, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_rock_roughness : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_rock_displacement : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform float tex_rock_scale = 0.5;

// --- Corrupt Layer (A) ---
uniform sampler2D tex_corrupt_diffuse : source_color, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_corrupt_normal : hint_normal, repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_corrupt_roughness : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_corrupt_displacement : repeat_enable, filter_nearest_mipmap_anisotropic;
uniform float tex_corrupt_scale = 0.5;

uniform float displacement_strength = 2.0;

// Varyings
varying vec2 world_uv;
varying float blend_distance_factor; // Used to mix near/far textures

void vertex() {
    // 1. Calculate World UVs
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_uv = world_pos.xz;
    
    // 2. Calculate Distance for Anti-Tiling in Fragment
    float dist = length(world_pos - CAMERA_POSITION_WORLD);
    blend_distance_factor = clamp((dist - distance_fade_start) / distance_fade_length, 0.0, 1.0);

    // 3. Vertex Displacement
    vec4 blend_weights = texture(splat_map, UV).rgba;
    
    // Normalize RGB weights for displacement calculation
    float rgb_sum = blend_weights.r + blend_weights.g + blend_weights.b;
    vec3 rgb_norm = (rgb_sum > 0.0) ? blend_weights.rgb / rgb_sum : vec3(1.0, 0.0, 0.0);
    
    float h_grass = texture(tex_grass_displacement, world_uv * tex_grass_scale).r;
    float h_dirt = texture(tex_dirt_displacement, world_uv * tex_dirt_scale).r;
    float h_rock = texture(tex_rock_displacement, world_uv * tex_rock_scale).r;
    float h_corrupt = texture(tex_corrupt_displacement, world_uv * tex_corrupt_scale).r;

    float base_height = (h_grass * rgb_norm.r) + (h_dirt * rgb_norm.g) + (h_rock * rgb_norm.b);
    
    // Corrupt displaces on top/mixes in
    float total_height = mix(base_height, h_corrupt, blend_weights.a);

    VERTEX += NORMAL * (total_height - 0.5) * displacement_strength;
    
    // Recalculate UVs after displacement if you want extreme precision, 
    // but usually, doing it before is stable enough for terrain.
}

// --- HELPER: Height Blending Function ---
// This calculates new weights based on the texture's height map.
// The "Higher" texture effectively covers the "Lower" texture.
vec3 get_height_blended_weights(vec3 weights, float h1, float h2, float h3) {
    // Bias the heights by the splat map weights
    vec3 h = vec3(h1, h2, h3) + (weights * height_blend_strength);
    
    // Find the highest layer
    float max_h = max(h.r, max(h.g, h.b));
    
    // Subtract max to normalize, then clamp. 0.1 controls the "softness" of the edge.
    // Lower value = sharper transition between stones and dirt.
    vec3 result = max(h - max_h + (1.0 - height_blend_strength) * 0.2, vec3(0.0));
    
    // Renormalize
    return result / (result.r + result.g + result.b + 0.0001);
}

// --- HELPER: Texture Fetch with Anti-Tiling ---
// Fetches the texture at normal scale AND macro scale, mixing them by distance.
vec4 sample_dual_scale(sampler2D tex, vec2 uv, float scale, float dist_factor) {
    vec4 near = texture(tex, uv * scale);
    vec4 far = texture(tex, uv * macro_variation_scale); // Macro scale
    
    // We can just mix them, or use 'overlay' logic for detail preservation.
    // Simple mixing is best for performance.
    return mix(near, far, dist_factor);
}

void fragment() {
    // --- 1. Get Base Weights ---
    vec4 splat = texture(splat_map, UV).rgba;
    
    // Normalize RGB (Biome) weights
    float rgb_sum = splat.r + splat.g + splat.b;
    vec3 w_biomes = (rgb_sum > 0.001) ? splat.rgb / rgb_sum : vec3(1.0, 0.0, 0.0);
    float w_corrupt = splat.a;

    // --- 2. Height Blending (The Next Level Part) ---
    // We must sample displacement first to decide how to blend the other maps.
    // Note: We only sample the "Near" displacement for blending logic to save cost,
    // or you can use the dual_scale helper if you want perfect tiling on height too.
    float h_g = texture(tex_grass_displacement, world_uv * tex_grass_scale).r;
    float h_d = texture(tex_dirt_displacement, world_uv * tex_dirt_scale).r;
    float h_r = texture(tex_rock_displacement, world_uv * tex_rock_scale).r;
    
    // Calculate new sharp weights based on height
    w_biomes = get_height_blended_weights(w_biomes, h_g, h_d, h_r);

    // --- 3. Sample Textures (With Distance Anti-Tiling) ---
    // Grass
    vec3 col_g = sample_dual_scale(tex_grass_diffuse, world_uv, tex_grass_scale, blend_distance_factor).rgb;
    vec3 nrm_g = sample_dual_scale(tex_grass_normal, world_uv, tex_grass_scale, blend_distance_factor).rgb;
    float rgh_g = sample_dual_scale(tex_grass_roughness, world_uv, tex_grass_scale, blend_distance_factor).r;

    // Dirt
    vec3 col_d = sample_dual_scale(tex_dirt_diffuse, world_uv, tex_dirt_scale, blend_distance_factor).rgb;
    vec3 nrm_d = sample_dual_scale(tex_dirt_normal, world_uv, tex_dirt_scale, blend_distance_factor).rgb;
    float rgh_d = sample_dual_scale(tex_dirt_roughness, world_uv, tex_dirt_scale, blend_distance_factor).r;

    // Rock
    vec3 col_r = sample_dual_scale(tex_rock_diffuse, world_uv, tex_rock_scale, blend_distance_factor).rgb;
    vec3 nrm_r = sample_dual_scale(tex_rock_normal, world_uv, tex_rock_scale, blend_distance_factor).rgb;
    float rgh_r = sample_dual_scale(tex_rock_roughness, world_uv, tex_rock_scale, blend_distance_factor).r;

    // Corrupt
    vec3 col_c = sample_dual_scale(tex_corrupt_diffuse, world_uv, tex_corrupt_scale, blend_distance_factor).rgb;
    vec3 nrm_c = sample_dual_scale(tex_corrupt_normal, world_uv, tex_corrupt_scale, blend_distance_factor).rgb;
    float rgh_c = sample_dual_scale(tex_corrupt_roughness, world_uv, tex_corrupt_scale, blend_distance_factor).r;

    // --- 4. Combine Biomes (RGB) ---
    vec3 base_albedo = col_g * w_biomes.r + col_d * w_biomes.g + col_r * w_biomes.b;
    vec3 base_normal = nrm_g * w_biomes.r + nrm_d * w_biomes.g + nrm_r * w_biomes.b;
    float base_rough = rgh_g * w_biomes.r + rgh_d * w_biomes.g + rgh_r * w_biomes.b;

    // --- 5. Apply Corruption (Alpha Layer) ---
    // We treat corruption as an overlay that grows over the terrain
    vec3 final_albedo = mix(base_albedo, col_c, w_corrupt);
    vec3 final_normal = mix(base_normal, nrm_c, w_corrupt);
    float final_rough = mix(base_rough, rgh_c, w_corrupt);

    // --- 6. Wetness Physics ---
    // Wetness darkens albedo (porous materials get darker) and smooths roughness
    float wet_factor = wetness_level;
    // Darken albedo slightly where wet
    final_albedo = final_albedo * mix(1.0, 0.6, wet_factor); 
    // Force roughness towards 0.05 (shiny water) based on wet level
    // We clamp minimum roughness to simulate water film
    final_rough = mix(final_rough, 0.05, wet_factor * 0.8); 

    // --- 7. Output ---
    ALBEDO = final_albedo * color_tint.rgb;
    ROUGHNESS = final_rough;
    METALLIC = 0.0;
    
    // Normal Map: Since we blended colors, we just assign them to NORMAL_MAP.
    // Godot handles the TBN automatically.
    NORMAL_MAP = final_normal;
    // Adjust normal strength if needed, or decrease where wet to make it flatter (water filling cracks)
    NORMAL_MAP_DEPTH = mix(1.0, 0.5, wet_factor); 
}