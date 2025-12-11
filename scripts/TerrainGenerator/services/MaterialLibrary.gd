class_name MaterialLibrary

var terrain_material: ShaderMaterial
var vegetation_material: StandardMaterial3D

func _init(shader: Shader, textures: Dictionary):
	# Terrain Shader Material
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = shader
	for key in textures:
		if textures[key]:
			terrain_material.set_shader_parameter(key, textures[key])

	# Generic Vegetation Material (Fallback)
	vegetation_material = StandardMaterial3D.new()
	vegetation_material.albedo_color = Color(0.15, 0.6, 0.15)
	vegetation_material.flags_receive_shadows = true
