class_name MaterialLibrary

var terrain_shader: Shader
var base_textures: Dictionary

var vegetation_material: StandardMaterial3D

func _init(shader: Shader, textures: Dictionary):
	terrain_shader = shader
	base_textures = textures
	
	vegetation_material = StandardMaterial3D.new()
	vegetation_material.albedo_color = Color(0.15, 0.6, 0.15)

func _set_texture_layer(mat: ShaderMaterial, tex_key: String, terrain_tex: TerrainTexture):
	if not terrain_tex: return
	
	mat.set_shader_parameter("%s_diffuse" % tex_key, terrain_tex.diffuse)
	
	mat.set_shader_parameter("%s_normal" % tex_key, terrain_tex.normal)
	mat.set_shader_parameter("%s_roughness" % tex_key, terrain_tex.roughness)
	mat.set_shader_parameter("%s_displacement" % tex_key, terrain_tex.displacement)
	
	mat.set_shader_parameter("%s_scale" % tex_key, terrain_tex.tiling_scale)


func get_terrain_material(biome: BiomeConfig, chunk_splat_map: ImageTexture) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = terrain_shader
	
	for key in base_textures:
		if base_textures[key] is TerrainTexture:
			_set_texture_layer(mat, key, base_textures[key])

	mat.set_shader_parameter("splat_map", chunk_splat_map)
	
	for key in biome.texture_overrides:
		if biome.texture_overrides[key] is TerrainTexture:
			_set_texture_layer(mat, key, biome.texture_overrides[key])
			
	mat.set_shader_parameter("color_tint", biome.color_tint)
	mat.set_shader_parameter("wetness_level", biome.wetness)
	
	return mat
