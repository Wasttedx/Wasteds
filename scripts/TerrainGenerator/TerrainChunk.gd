extends Node3D
class_name TerrainChunk

var chunk_coords: Vector2i
var current_lod: int = -1
var is_ready: bool = false
var is_built: bool = false

var world_config: WorldConfig
var noise: NoiseBuilder
var material_lib: MaterialLibrary
var veg_spawner: VegetationSpawner
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator

var build_data: Dictionary = {}

var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D
var vegetation_root: Node3D

func setup(coords: Vector2i, wc: WorldConfig, nb: NoiseBuilder, ml: MaterialLibrary, vs: VegetationSpawner, bs: BiomeSelector, smg: SplatMapGenerator):
	chunk_coords = coords
	world_config = wc
	noise = nb
	material_lib = ml
	veg_spawner = vs
	biome_selector = bs
	splat_map_generator = smg
	
	position = Vector3(coords.x * world_config.chunk_world_size, 0, coords.y * world_config.chunk_world_size)
	
	name = "Chunk_%d_%d" % [coords.x, coords.y]
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	
	is_ready = true

func apply_prebuilt_data(data: Dictionary):
	if is_built:
		return
		
	build_data = data
	is_built = true

func set_lod(level: int):
	if not is_ready or not is_built: return
	if current_lod == level: return
	
	current_lod = level
	
	if mesh_instance.mesh:
		mesh_instance.mesh = null
	_clear_physics()
	_clear_vegetation()
	
	var biome: BiomeConfig = build_data.biome_config
	
	var splat_image: Image = build_data.splat_map_image
	var splat_tex = ImageTexture.create_from_image(splat_image)
	
	var mat = material_lib.get_terrain_material(biome, splat_tex)
	
	if current_lod == 0:
		_apply_high_res(mat)
	else:
		_apply_low_res(mat)

func _apply_high_res(material: Material):
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_data.high_res_mesh_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	
	collision_body = StaticBody3D.new()
	add_child(collision_body)
	
	var collision_shapes: Array = build_data.collision_shapes
	for shape_data in collision_shapes:
		var shape_node = CollisionShape3D.new()
		shape_node.shape = shape_data.shape
		shape_node.transform = shape_data.transform
		collision_body.add_child(shape_node)

	vegetation_root = Node3D.new()
	add_child(vegetation_root)
	veg_spawner.apply_transforms(vegetation_root, build_data.vegetation_transforms, material_lib.vegetation_material)

func _apply_low_res(material: Material):
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_data.low_res_mesh_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	

func _clear_physics():
	if collision_body:
		collision_body.queue_free()
		collision_body = null

func _clear_vegetation():
	if vegetation_root:
		vegetation_root.queue_free()
		vegetation_root = null
