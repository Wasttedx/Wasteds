class_name MaterialLibrary

var terrain_shader: Shader
var base_textures: Dictionary # Stores all the textures loaded in TerrainGenerator.gd

var vegetation_material: StandardMaterial3D

func _init(shader: Shader, textures: Dictionary):
	terrain_shader = shader
	base_textures = textures
	
	# Generic Vegetation Material (Fallback)
	vegetation_material = StandardMaterial3D.new()
	vegetation_material.albedo_color = Color(0.15, 0.6, 0.15)
	vegetation_material.flags_receive_shadows = true

# UPDATED: Now accepts the per-chunk splat_map
func get_terrain_material(biome: BiomeConfig, chunk_splat_map: ImageTexture) -> ShaderMaterial: # <<< ADD SPLAT MAP ARG
	var mat = ShaderMaterial.new()
	mat.shader = terrain_shader
	
	# 1. Apply ALL BASE TEXTURES/PARAMETERS (tex_grass, tex_dirt, etc.)
	for key in base_textures:
		# The static splat_map is no longer in base_textures, only the texture maps
		if base_textures[key] is Texture2D or base_textures[key] is Texture:
			mat.set_shader_parameter(key, base_textures[key])
	
	# --- NEW: Set the dynamically generated Splat Map ---
	mat.set_shader_parameter("splat_map", chunk_splat_map)
	# ---------------------------------------------------
	
	# 2. Apply BIOME SPECIFIC TEXTURE OVERRIDES
	for key in biome.texture_overrides:
		if biome.texture_overrides[key] is Texture2D or biome.texture_overrides[key] is Texture:
			mat.set_shader_parameter(key, biome.texture_overrides[key])
			
	# 3. Apply biome specific values
	mat.set_shader_parameter("color_tint", biome.color_tint)
	mat.set_shader_parameter("wetness_level", biome.wetness)
	
	return mat
