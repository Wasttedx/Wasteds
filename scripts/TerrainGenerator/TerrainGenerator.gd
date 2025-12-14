extends Node3D
class_name TerrainGenerator

# --- Dependencies (Configs) ---
@export_group("Configs")
@export var world_config: WorldConfig
@export var noise_config: NoiseConfig
@export var veg_config: VegetationConfig
@export var biome_configs: Array[BiomeConfig]

# --- Assets ---
@export_group("Materials")
@export var terrain_shader: Shader = preload("res://shaders/terrain_shader.gdshader")
@export var tex_grass: TerrainTexture 
@export var tex_dirt: TerrainTexture 
@export var tex_rock: TerrainTexture 
@export var tex_corrupt: TerrainTexture 

@export_group("Target")
@export var player_path: NodePath

# --- Systems ---
var noise_builder: NoiseBuilder
var material_lib: MaterialLibrary
var veg_spawner: VegetationSpawner
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator

var chunks := {}
var generation_queue := [] # Chunk coordinates to be generated
var active_build_threads := {} # Maps chunk_coords to ChunkBuilderThread
var threads_to_join := [] # Array to hold strong references to Thread objects waiting for deferred cleanup
var player: Node3D

# LOD Settings: Chunks within this radius (in chunk units) become High Res (LOD 0)
# Everything else within view distance becomes Low Res (LOD 1)
const LOD_HIGH_RES_DISTANCE: int = 1 

func _ready():
	if player_path: player = get_node_or_null(player_path)
	
	_initialize_systems()
	_create_defaults_if_missing()
	
	# Initial generation
	_update_chunks()
	_update_lods() # Force LOD update immediately
	
	# Snap player to ground
	if player:
		# Use the height from the noise builder
		var h = noise_builder.get_height(player.global_position.x, player.global_position.z)
		player.global_position.y = h + 2.0

# Handles synchronous cleanup when the game/node exits
func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_stop_all_threads()

func _process(_delta):
	if not player: return
	_update_chunks()
	_update_lods() # Check for LOD transitions
	_process_queue()

func _initialize_systems():
	# 1. Initialize services with configs
	noise_builder = NoiseBuilder.new(noise_config)
	
	# 2. Initialize Biome Selector
	# FIX: Changed noise_config.seed to noise_config.noise_seed
	biome_selector = BiomeSelector.new(biome_configs, noise_config.noise_seed, noise_builder)
	
	# 3. Initialize SplatMap Generator
	splat_map_generator = SplatMapGenerator.new(noise_builder, world_config)
	
	# 4. Prepare Textures Dictionary (For MaterialLibrary)
	var textures = {
		"tex_grass": tex_grass, 
		"tex_dirt": tex_dirt, 
		"tex_rock": tex_rock, 
		"tex_corrupt": tex_corrupt 
	}
	
	# 5. Initialize Material Library
	material_lib = MaterialLibrary.new(terrain_shader, textures)
	
	# 6. Initialize Vegetation Spawner
	veg_spawner = VegetationSpawner.new(veg_config, noise_builder, world_config.chunk_world_size)

func _create_defaults_if_missing():
	# Creates temporary placeholders if Config resources are empty
	if not veg_config.grass_mesh:
		# Simple QuadMesh placeholder
		var p = QuadMesh.new(); p.size = Vector2(0.4, 0.8); p.center_offset = Vector3(0, 0.4, 0)
		veg_config.grass_mesh = p

func _update_chunks():
	# Calculate player chunk coordinates
	var p_pos = player.global_position if player else Vector3.ZERO
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	
	var range_c = world_config.view_distance_chunks
	var active_coords = {}
	
	# Loop through the view distance grid
	for z in range(-range_c, range_c + 1):
		for x in range(-range_c, range_c + 1):
			var c = Vector2i(p_cx + x, p_cz + z)
			active_coords[c] = true
			
			# Check if chunk exists, is being built, or is queued
			if not chunks.has(c) and not active_build_threads.has(c) and not generation_queue.has(c):
				generation_queue.append(c)
	
	# Cleanup old chunks
	for c in chunks.keys():
		if not active_coords.has(c):
			chunks[c].queue_free()
			chunks.erase(c)
	
	# Cleanup threads for chunks that have moved out of range
	for c in active_build_threads.keys():
		if not active_coords.has(c):
			var builder_thread: ChunkBuilderThread = active_build_threads.get(c)

			# 1. Clean up the worker and get the finished Thread object reference
			var finished_thread = builder_thread.cleanup()

			# 2. Remove the reference from the map (The thread is now orphaned)
			active_build_threads.erase(c)

			# 3. MANDATORY: Synchronously join the thread to prevent the C++ warning/leak
			if is_instance_valid(finished_thread) and finished_thread.is_started():
				finished_thread.wait_to_finish() # <-- This line is the solution!


func _update_lods():
	var p_pos = player.global_position if player else Vector3.ZERO
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	
	for c in chunks:
		var chunk = chunks[c]
		
		# Chebyshev distance (Grid distance)
		var dist_x = abs(c.x - p_cx)
		var dist_z = abs(c.y - p_cz)
		var dist = max(dist_x, dist_z)
		
		var target_lod = 0
		if dist > LOD_HIGH_RES_DISTANCE:
			target_lod = 1
			
		# Apply LOD - This is a call on the main thread
		chunk.set_lod(target_lod)

func _process_queue():
	# Start new build jobs up to the max parallel threads (e.g., 8-16, or just one per frame)
	
	# Check if we can start a new job
	if active_build_threads.size() < world_config.max_chunks_per_frame and not generation_queue.is_empty():
		var c = generation_queue.pop_front()
		
		# Create the chunk instance immediately to have a container
		var chunk = TerrainChunk.new()
		add_child(chunk)
		
		# Dependency Injection - pass all systems and configs
		chunk.setup(c, 
					 world_config, 
					 noise_builder, 
					 material_lib, 
					 veg_spawner, 
					 biome_selector, 
					 splat_map_generator
					 ) 
		
		chunks[c] = chunk
		
		# Start the thread job
		var builder_thread = ChunkBuilderThread.new()
		builder_thread.connect("build_finished", _on_chunk_build_finished)
		builder_thread.start_build(c, world_config, noise_builder, biome_selector, splat_map_generator, veg_spawner)
		active_build_threads[c] = builder_thread
		
func _on_chunk_build_finished(coords: Vector2i, build_data: Dictionary):
	# This function is called on the main thread when the worker finishes
	if active_build_threads.has(coords):
		var builder_thread: ChunkBuilderThread = active_build_threads[coords]
		
		# Remove reference to ChunkBuilderThread from active list
		active_build_threads.erase(coords)
		
		# Apply data to chunk on main thread
		if chunks.has(coords):
			var chunk: TerrainChunk = chunks[coords]
			chunk.apply_prebuilt_data(build_data) 
			
			call_deferred("_update_lods")

		# Get the finished thread reference and DEFER the mandatory wait_to_finish() call.
		var finished_thread = builder_thread.cleanup()
		
		# Hold a strong reference in threads_to_join to keep the Thread object 
		# alive until the deferred call executes, preventing the warning.
		if finished_thread and finished_thread.is_started():
			threads_to_join.append(finished_thread) 
			
			# Defer the final, mandatory cleanup call.
			Callable(finished_thread, "wait_to_finish").call_deferred() 

func _stop_all_threads():
	# 1. Clean up threads that are still actively building
	# Use .keys().duplicate() to safely iterate while modifying the dictionary
	for coords in active_build_threads.keys().duplicate(): 
		if active_build_threads.has(coords):
			var builder_thread: ChunkBuilderThread = active_build_threads[coords]
			
			# Clean up the worker and get the Thread reference
			var finished_thread = builder_thread.cleanup()
			# Remove worker from map
			active_build_threads.erase(coords) 
			
			# Check for validity and if the Thread is still active before joining
			if is_instance_valid(finished_thread) and finished_thread.is_started():
				# Mandatory synchronous join on exit to prevent thread object warning
				finished_thread.wait_to_finish()
	
	# 2. Clean up threads that were waiting in the deferred queue (threads_to_join)
	var current_threads_to_join = threads_to_join.duplicate()
	threads_to_join.clear() # Clear the main array immediately
	
	for thread in current_threads_to_join:
		# Check for validity and if the Thread is still active before joining
		if is_instance_valid(thread) and thread.is_started():
			# Mandatory synchronous join on exit
			thread.wait_to_finish()
			
	# The combination of deferred joins and this synchronous exit cleanup 
	# should eliminate all thread destruction warnings.
