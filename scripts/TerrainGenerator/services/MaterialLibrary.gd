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

func get_terrain_material(biome: BiomeConfig) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = terrain_shader
	
	# 1. Apply ALL BASE TEXTURES/PARAMETERS (Crucial for splat_map and default textures)
	for key in base_textures:
		# Check if the value is a valid resource before setting
		if base_textures[key] is Texture2D or base_textures[key] is Texture:
			mat.set_shader_parameter(key, base_textures[key])
		# Note: In your setup, the splat_map is passed here via the key "splat_map"
	
	# 2. Apply BIOME SPECIFIC TEXTURE OVERRIDES
	for key in biome.texture_overrides:
		if biome.texture_overrides[key] is Texture2D or biome.texture_overrides[key] is Texture:
			mat.set_shader_parameter(key, biome.texture_overrides[key])
			
	# 3. Apply biome specific values
	mat.set_shader_parameter("color_tint", biome.color_tint)
	mat.set_shader_parameter("wetness_level", biome.wetness)
	
	return mat
