shader_type spatial;

// The Splat Map is the crucial texture (RGB) that tells the shader how to blend
uniform sampler2D splat_map;

// Textures loaded from TerrainGenerator.gd / MaterialLibrary.gd
uniform sampler2D tex_grass;
uniform sampler2D tex_dirt;
uniform sampler2D tex_rock;
uniform sampler2D tex_corrupt;

// Biome parameters
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wetness_level : hint_range(0.0, 1.0) = 0.0;

// Scaling for texture tiling
const float TILE_SCALE = 16.0;

void fragment() {
	// 1. Get UV coordinates for texture sampling
	vec2 uv = UV * TILE_SCALE;

	// 2. Read the splat map
	vec4 blend_factors = texture(splat_map, UV);

	// FIX 1: Normalize blend factors and force Alpha to 0
	// This ensures the RGB channels sum to 1.0, preventing incorrect saturation/washout.
	float total_weight = blend_factors.r + blend_factors.g + blend_factors.b;

	// Avoid division by zero, but this is usually safe for splat maps
	if (total_weight > 0.0) {
		blend_factors.rgb /= total_weight;
	} else {
		// Default to pure grass if all weights are zero
		blend_factors.r = 1.0;
	}
	blend_factors.a = 0.0; // Still keeping alpha at 0 to avoid corruption mix issues

	// 3. Sample the textures
	vec4 grass_color = texture(tex_grass, uv);
	vec4 dirt_color = texture(tex_dirt, uv);
	vec4 rock_color = texture(tex_rock, uv);
	vec4 corrupt_color = texture(tex_corrupt, uv);

	// 4. Blend using additive, weighted contribution
	vec4 final_color = vec4(0.0);

	// Red (Grass)
	final_color += grass_color * blend_factors.r;

	// Green (Dirt)
	final_color += dirt_color * blend_factors.g;

	// Blue (Rock)
	final_color += rock_color * blend_factors.b;

	// Alpha (Corrupt) - Note: A is 0.0 now, so this line does nothing, which is correct for debugging.
	final_color += corrupt_color * blend_factors.a;

	// Apply biome tint (now white)
	final_color.rgb *= color_tint.rgb;

	// Apply wetness (Simple example: makes surface more reflective)
	METALLIC = 0.0;
	ROUGHNESS = mix(0.8, 0.2, wetness_level);

	ALBEDO = final_color.rgb;
}