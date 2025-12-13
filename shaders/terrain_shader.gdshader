shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

// --- Uniforms from MaterialLibrary.gd ---

// Global Blending Map (R=Grass, G=Dirt, B=Rock, A=Corrupt/Water)
uniform sampler2D splat_map : repeat_enable; 

// Biome Properties
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wetness_level : hint_range(0.0, 1.0) = 0.5;

// Global constants
const float DISPLACEMENT_SCALE = 1.0; 

// --- Grass Layer (R) ---
uniform sampler2D tex_grass_diffuse : source_color, repeat_enable;
uniform sampler2D tex_grass_normal : hint_normal, repeat_enable;
uniform sampler2D tex_grass_roughness : repeat_enable;
uniform sampler2D tex_grass_displacement : repeat_enable;
uniform float tex_grass_scale = 0.1;

// --- Dirt Layer (G) ---
uniform sampler2D tex_dirt_diffuse : source_color, repeat_enable;
uniform sampler2D tex_dirt_normal : hint_normal, repeat_enable;
uniform sampler2D tex_dirt_roughness : repeat_enable;
uniform sampler2D tex_dirt_displacement : repeat_enable;
uniform float tex_dirt_scale = 0.1;

// --- Rock Layer (B) ---
uniform sampler2D tex_rock_diffuse : source_color, repeat_enable;
uniform sampler2D tex_rock_normal : hint_normal, repeat_enable;
uniform sampler2D tex_rock_roughness : repeat_enable;
uniform sampler2D tex_rock_displacement : repeat_enable;
uniform float tex_rock_scale = 0.1;

// --- Corrupt Layer (A) <<< RESTORED ---
uniform sampler2D tex_corrupt_diffuse : source_color, repeat_enable;
uniform sampler2D tex_corrupt_normal : hint_normal, repeat_enable;
uniform sampler2D tex_corrupt_roughness : repeat_enable;
uniform sampler2D tex_corrupt_displacement : repeat_enable;
uniform float tex_corrupt_scale = 0.1;

// --- Vertex Displacement ---
// Pass the world UV coordinates from vertex() to fragment() using a varying
varying vec2 world_uv;

void vertex() {
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	
	vec4 blend_weights = texture(splat_map, UV).rgba;
	
	// Corrupt layer displacement must also be sampled if you want it to displace
	float total_displacement = 0.0;
	total_displacement += texture(tex_grass_displacement, world_uv * tex_grass_scale).r * blend_weights.r;
	total_displacement += texture(tex_dirt_displacement, world_uv * tex_dirt_scale).r * blend_weights.g;
	total_displacement += texture(tex_rock_displacement, world_uv * tex_rock_scale).r * blend_weights.b;
	total_displacement += texture(tex_corrupt_displacement, world_uv * tex_corrupt_scale).r * blend_weights.a; // <<< ADDED CORRUPT
	
	if (total_displacement > 0.0) {
		float displacement = (total_displacement - 0.5) * DISPLACEMENT_SCALE;
		VERTEX += NORMAL * displacement;
		world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	}
}


// --- Fragment Lighting ---
void fragment() {
	vec2 uv_world = world_uv;
	
	// Get Blending Weights (R=Grass, G=Dirt, B=Rock, A=Corrupt)
	vec4 blend_weights = texture(splat_map, UV).rgba;
	
	// Normalize the RGB weights (Red, Green, Blue) for the primary textures 
	// This ensures that RGB blending components always sum to 1.0.
	float rgb_total = blend_weights.r + blend_weights.g + blend_weights.b;
	
	if (rgb_total > 0.0) {
		blend_weights.rgb /= rgb_total;
	} else {
		// Fallback to pure grass if no texture is specified in RGB channels
		blend_weights.r = 1.0;
	}

	// Corrupt layer (Alpha channel) is treated separately and mixed *on top* // or after the RGB blend, depending on how you want it to behave.
	// We'll treat it as a final additive layer for simplicity, but we still 
	// need to normalize the RGB part.

	// --- Diffuse/Albedo Calculation ---
	vec3 albedo_out = vec3(0.0);
	
	// 1. Blend Primary (RGB) Textures
	albedo_out += texture(tex_grass_diffuse, uv_world * tex_grass_scale).rgb * blend_weights.r;
	albedo_out += texture(tex_dirt_diffuse, uv_world * tex_dirt_scale).rgb * blend_weights.g;
	albedo_out += texture(tex_rock_diffuse, uv_world * tex_rock_scale).rgb * blend_weights.b;
	
	// 2. Blend Corrupt Texture (Alpha channel)
	// We use `mix` to blend the blended RGB texture with the corrupt texture.
	// blend_weights.a is the amount of the corrupt texture to show (0.0 to 1.0).
	vec3 corrupt_color = texture(tex_corrupt_diffuse, uv_world * tex_corrupt_scale).rgb; // <<< ADDED CORRUPT
	albedo_out = mix(albedo_out, corrupt_color, blend_weights.a);
	
	ALBEDO = albedo_out * color_tint.rgb;
	
	// --- Roughness Calculation ---
	float roughness_out = 0.0;
	
	// 1. Blend Primary Roughness
	roughness_out += texture(tex_grass_roughness, uv_world * tex_grass_scale).r * blend_weights.r;
	roughness_out += texture(tex_dirt_roughness, uv_world * tex_dirt_scale).r * blend_weights.g;
	roughness_out += texture(tex_rock_roughness, uv_world * tex_rock_scale).r * blend_weights.b;
	
	// 2. Blend Corrupt Roughness
	float corrupt_roughness = texture(tex_corrupt_roughness, uv_world * tex_corrupt_scale).r; // <<< ADDED CORRUPT
	ROUGHNESS = mix(roughness_out, corrupt_roughness, blend_weights.a);
	
	// --- Normal Map Blending (REMAINS SIMPLE DUE TO TBN ERROR) ---
	// NORMAL retains the geometric normal after displacement.
	
	// --- Wetness and final properties ---
	METALLIC = 0.0;
	ROUGHNESS = mix(ROUGHNESS, 0.1, wetness_level);
}