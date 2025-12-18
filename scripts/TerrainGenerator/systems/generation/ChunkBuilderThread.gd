extends RefCounted
class_name ChunkBuilderThread

var chunk_coords: Vector2i
var world_config: WorldConfig
var noise_builder: NoiseBuilder
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator
var veg_spawner: VegetationSpawner

var mesh_array_high_res: Array
var mesh_array_low_res: Array
var collision_shapes: Array
var vegetation_transforms: Dictionary 

signal build_finished(chunk_coords: Vector2i, build_data: Dictionary)

var thread: Thread
var is_running: bool = false

func start_build(coords: Vector2i, wc: WorldConfig, nb: NoiseBuilder, bs: BiomeSelector, smg: SplatMapGenerator, vs: VegetationSpawner):
	chunk_coords = coords
	world_config = wc
	noise_builder = nb
	biome_selector = bs
	splat_map_generator = smg
	veg_spawner = vs
	
	is_running = true
	thread = Thread.new()
	
	var err = thread.start(_build_data_threaded)
	if err != OK:
		push_error("Failed to start chunk builder thread: ", err)
		is_running = false

func _build_data_threaded():
	# 1. Determine Biome
	var center_x = (chunk_coords.x * world_config.chunk_world_size) + (world_config.chunk_world_size * 0.5)
	var center_z = (chunk_coords.y * world_config.chunk_world_size) + (world_config.chunk_world_size * 0.5)
	var biome_config = biome_selector.get_biome_for_coords(center_x, center_z)

	# Apply biome settings to noise
	noise_builder.push_config_override(biome_config)

	# 2. Build Mesh Data (High Res)
	var mesh_factory_high_res = load("res://scripts/TerrainGenerator/systems/generation/MeshFactory_HighRes.gd").new()
	var mesh_data_high = mesh_factory_high_res.build_terrain_mesh_data(chunk_coords, world_config, noise_builder)
	mesh_array_high_res = mesh_data_high.arrays
	
	# 3. Build Collision
	var collision_builder = load("res://scripts/TerrainGenerator/systems/physics/CollisionBuilder.gd").new()
	collision_shapes = collision_builder.create_collision_data(mesh_data_high)
	
	# 4. Build Mesh Data (Low Res)
	var mesh_factory_low_res = load("res://scripts/TerrainGenerator/systems/generation/MeshFactory_LowRes.gd").new()
	var mesh_data_low = mesh_factory_low_res.build_terrain_mesh_data(chunk_coords, world_config, noise_builder)
	mesh_array_low_res = mesh_data_low.arrays
	
	# 5. Generate Splat Map Image
	var splat_image: Image = SplatMapGenerator.generate_splat_image(chunk_coords, world_config, noise_builder, biome_config)
	
	# 6. Generate Vegetation Transforms
	# FIX: Passing splat_image instead of biome_config as the 5th argument
	var veg_config: VegetationConfig = veg_spawner.config
	vegetation_transforms = VegetationSpawner.generate_transforms(
		chunk_coords, 
		world_config, 
		noise_builder, 
		veg_config, 
		splat_image # <--- This matches the Image requirement in VegetationSpawner
	)
	
	noise_builder.pop_config_override()

	var result_data = {
		"high_res_mesh_arrays": mesh_array_high_res,
		"low_res_mesh_arrays": mesh_array_low_res,
		"splat_map_image": splat_image,
		"collision_shapes": collision_shapes,
		"vegetation_transforms": vegetation_transforms,
		"biome_config": biome_config
	}
	
	is_running = false
	
	# Thread-safe signal emission
	emit_signal.call_deferred("build_finished", chunk_coords, result_data)

func cleanup() -> Thread:
	var thread_to_join = thread
	thread = null
	is_running = false
	return thread_to_join
