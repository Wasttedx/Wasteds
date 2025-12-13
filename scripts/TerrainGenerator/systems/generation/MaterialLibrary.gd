class_name MaterialLibrary

var terrain_shader: Shader
var base_textures: Dictionary # Stores all the TerrainTexture resources loaded in TerrainGenerator.gd

var vegetation_material: StandardMaterial3D

func _init(shader: Shader, textures: Dictionary):
	terrain_shader = shader
	base_textures = textures
	
	# Generic Vegetation Material (Fallback)
	vegetation_material = StandardMaterial3D.new()
	vegetation_material.albedo_color = Color(0.15, 0.6, 0.15)
	vegetation_material.flags_receive_shadows = true

# Private helper method to set all shader parameters for a single texture layer
# We pass the ShaderMaterial 'mat' as an argument, and call this using 'self._set_texture_layer'
# MaterialLibrary.gd helper function (this is the one we fixed earlier)
func _set_texture_layer(mat: ShaderMaterial, tex_key: String, terrain_tex: TerrainTexture):
	if not terrain_tex: return
	
	# Base Map (Diffuse)
	mat.set_shader_parameter("%s_diffuse" % tex_key, terrain_tex.diffuse)
	
	# Additional Maps
	mat.set_shader_parameter("%s_normal" % tex_key, terrain_tex.normal)
	mat.set_shader_parameter("%s_roughness" % tex_key, terrain_tex.roughness)
	mat.set_shader_parameter("%s_displacement" % tex_key, terrain_tex.displacement)
	
	# Tiling
	mat.set_shader_parameter("%s_scale" % tex_key, terrain_tex.tiling_scale)


# UPDATED: Now processes TerrainTexture resources to set all maps
func get_terrain_material(biome: BiomeConfig, chunk_splat_map: ImageTexture) -> ShaderMaterial: # <<< ADD SPLAT MAP ARG
	var mat = ShaderMaterial.new()
	mat.shader = terrain_shader
	
	# 1. Apply ALL BASE TEXTURE SETS (tex_grass, tex_dirt, etc.)
	for key in base_textures:
		if base_textures[key] is TerrainTexture: # Check if it's the new Resource type
			# CALLS THE NEW CLASS METHOD
			_set_texture_layer(mat, key, base_textures[key])

	# --- NEW: Set the dynamically generated Splat Map ---
	mat.set_shader_parameter("splat_map", chunk_splat_map)
	# ---------------------------------------------------
	
	# 2. Apply BIOME SPECIFIC TEXTURE OVERRIDES
	for key in biome.texture_overrides:
		if biome.texture_overrides[key] is TerrainTexture: # Check if it's the new Resource type
			# CALLS THE NEW CLASS METHOD
			_set_texture_layer(mat, key, biome.texture_overrides[key])
			
	# 3. Apply biome specific values
	mat.set_shader_parameter("color_tint", biome.color_tint)
	mat.set_shader_parameter("wetness_level", biome.wetness)
	
	return mat
