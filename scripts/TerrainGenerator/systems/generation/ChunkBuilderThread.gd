extends RefCounted
class_name ChunkBuilderThread

# --- Dependencies (Must be thread-safe or passed by value) ---
var chunk_coords: Vector2i
var world_config: WorldConfig
var noise_builder: NoiseBuilder
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator
var veg_spawner: VegetationSpawner
var biome_config: BiomeConfig

# --- Output Data ---
var mesh_array_high_res: Array # For MeshFactory_HighRes
var mesh_array_low_res: Array  # For MeshFactory_LowRes
var splat_map_texture: ImageTexture
var collision_shapes: Array # The actual CollisionShape3D data, not the node
var vegetation_transforms: Array[Transform3D]

# Used to signal completion back to the main thread
signal build_finished(chunk_coords, build_data)

# --- Internal Thread Control ---
var thread: Thread
var is_running: bool = false

func start_build(coords: Vector2i, wc: WorldConfig, nb: NoiseBuilder, bs: BiomeSelector, smg: SplatMapGenerator, vs: VegetationSpawner):
	chunk_coords = coords
	world_config = wc
	
	# Pass systems as they are, but ONLY use their thread-safe methods (like noise)
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
	# This function runs in the separate thread
	
	# 1. Identify Biome
	var center_x = (chunk_coords.x * world_config.chunk_world_size) + (world_config.chunk_world_size * 0.5)
	var center_z = (chunk_coords.y * world_config.chunk_world_size) + (world_config.chunk_world_size * 0.5)
	biome_config = biome_selector.get_biome_for_coords(center_x, center_z)

	# 2. Push Biome Overrides (for noise generation)
	noise_builder.push_config_override(biome_config)

	# 3. Generate High Res Mesh and Collision Data
	var mesh_factory_high_res = load("res://scripts/TerrainGenerator/systems/generation/MeshFactory_HighRes.gd").new()
	var mesh_data_high = mesh_factory_high_res.build_terrain_mesh_data(chunk_coords, world_config, noise_builder)
	mesh_array_high_res = mesh_data_high.arrays
	
	# Build Collision
	var collision_builder = load("res://scripts/TerrainGenerator/systems/physics/CollisionBuilder.gd").new()
	collision_shapes = collision_builder.create_collision_data(mesh_data_high)
	
	# 4. Generate Low Res Mesh
	var mesh_factory_low_res = load("res://scripts/TerrainGenerator/systems/generation/MeshFactory_LowRes.gd").new()
	var mesh_data_low = mesh_factory_low_res.build_terrain_mesh_data(chunk_coords, world_config, noise_builder)
	mesh_array_low_res = mesh_data_low.arrays
	
	# 5. Generate Splat Map Texture
	var splat_image: Image = splat_map_generator.generate_splat_image(chunk_coords, world_config, noise_builder, biome_config)
	
	# 6. Generate Vegetation Transforms
	var veg_config: VegetationConfig = veg_spawner.config 
	vegetation_transforms = veg_spawner.generate_transforms(chunk_coords, world_config, noise_builder, veg_config, biome_config)
	
	# 7. Pop Biome Overrides
	noise_builder.pop_config_override()

	# 8. Prepare result dictionary
	var result_data = {
		"high_res_mesh_arrays": mesh_array_high_res,
		"low_res_mesh_arrays": mesh_array_low_res,
		"splat_map_image": splat_image, # Pass the Image back
		"collision_shapes": collision_shapes,
		"vegetation_transforms": vegetation_transforms,
		"biome_config": biome_config
	}
	
	# Signal back to the main thread
	# Important: Reset is_running BEFORE signaling, as the cleanup could be triggered 
	# immediately after the signal is received.
	is_running = false
	emit_signal("build_finished", chunk_coords, result_data)

func _notification(what):
	# FIX: Remove/Comment out the NOTIFICATION_PREDELETE block.
	# The thread has finished running by the time the signal is processed.
	# If the object is still alive when the thread finishes, this notification is 
	# likely running in the worker thread context, leading to the error.
	# The thread should only be manually waited for if it's stopped mid-run.
	# We rely on the thread finishing naturally and 'cleanup()' being called.
	pass
	# if what == NOTIFICATION_PREDELETE:
	# 	# Clean up thread if it's still running
	# 	if thread and is_running:
	# 		thread.wait_to_finish()
	# 		is_running = false

func cleanup():
	# The thread object is safe to clean up here since _build_data_threaded
	# already finished and set is_running = false.
	# We use wait_to_finish ONLY to clean up the thread resource itself, 
	# but only if it's not the current thread (which it isn't here).
	if thread and thread.is_started():
		# It's safer to check if the thread is still active before attempting to wait,
		# but since 'is_running' is set to false in _build_data_threaded,
		# we assume the worker thread has finished its work.
		# The call to wait_to_finish() here is technically correct for resource cleanup,
		# but since we are relying on the main thread calling this, it's safer
		# to just let the thread resource clean itself up.
		# If the error persists, you can simplify this to:
		thread = null
	is_running = false
