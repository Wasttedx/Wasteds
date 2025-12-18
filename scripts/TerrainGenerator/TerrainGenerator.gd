extends Node3D
class_name TerrainGenerator

@export_group("Configs")
@export var world_config: WorldConfig
@export var noise_config: NoiseConfig
@export var height_pipeline: HeightPipelineConfig
@export var veg_config: VegetationConfig
@export var biome_configs: Array[BiomeConfig]

@export_group("Materials")
@export var terrain_shader: Shader = preload("res://shaders/terrain_shader.gdshader")
@export var tex_grass: TerrainTexture
@export var tex_dirt: TerrainTexture
@export var tex_rock: TerrainTexture
@export var tex_corrupt: TerrainTexture

@export_group("Target")
@export var player_path: NodePath

var noise_builder: NoiseBuilder
var material_lib: MaterialLibrary
var veg_spawner: VegetationSpawner
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator
var vegetation_manager: VegetationManager 

var chunks := {}
var generation_queue := []
var active_build_threads := {}
var threads_to_join := []
var player: Node3D

# --- LOD & SEAM SETTINGS ---
const LOD_HIGH_RES_DISTANCE: int = 1
# Keeps chunks loaded slightly beyond view distance to prevent load/unload loops at seams
const UNLOAD_HYSTERESIS_CHUNKS: int = 2
# Keeps chunks in High Res slightly beyond the threshold to prevent LOD flickering
const LOD_HYSTERESIS_CHUNKS: int = 1

var _initial_spawn_chunk_built: bool = false


func _ready():
	if player_path: player = get_node_or_null(player_path)
	
	_initialize_systems()
	
	if player:
		var spawn_pos = player.global_position
		var spawn_chunk_coords = Vector2i(
			floor(spawn_pos.x / world_config.chunk_world_size),
			floor(spawn_pos.z / world_config.chunk_world_size)
		)

		if not generation_queue.has(spawn_chunk_coords):
			generation_queue.append(spawn_chunk_coords)
			print("Queued initial spawn chunk: ", spawn_chunk_coords)
			
	_update_lods()


func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_stop_all_threads()

func _process(_delta):
	if not player: return
	
	if _initial_spawn_chunk_built:
		_update_chunks()
	
	_update_lods()
	_process_queue()


func _start_full_world_loading():
	_initial_spawn_chunk_built = true
	print("Full world loading initiated.")


func _initialize_systems():
	noise_builder = NoiseBuilder.new(noise_config, height_pipeline)
	biome_selector = BiomeSelector.new(biome_configs, noise_config.noise_seed, noise_builder)
	splat_map_generator = SplatMapGenerator.new(noise_builder, world_config)
	
	var textures = {
		"tex_grass": tex_grass,
		"tex_dirt": tex_dirt,
		"tex_rock": tex_rock,
		"tex_corrupt": tex_corrupt
	}
	
	material_lib = MaterialLibrary.new(terrain_shader, textures)
	veg_spawner = VegetationSpawner.new(veg_config, noise_builder, world_config.chunk_world_size)
	vegetation_manager = VegetationManager.new()
	add_child(vegetation_manager)


func _update_chunks():
	var p_pos = player.global_position if player else Vector3.ZERO
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	
	var view_range = world_config.view_distance_chunks
	
	# 1. Identify active chunks to LOAD (Strict View Distance)
	var required_coords = {}
	for z in range(-view_range, view_range + 1):
		for x in range(-view_range, view_range + 1):
			var c = Vector2i(p_cx + x, p_cz + z)
			required_coords[c] = true
			
			if not chunks.has(c) and not active_build_threads.has(c) and not generation_queue.has(c):
				generation_queue.append(c)
	
	# 2. Identify chunks to UNLOAD (View Distance + Hysteresis Buffer)
	# We iterate existing chunks and check if they are too far away
	var _unload_distance_sq = pow(view_range + UNLOAD_HYSTERESIS_CHUNKS, 2)
	
	for c in chunks.keys().duplicate(): 
		# Use squared distance logic for unloading circle rather than square grid to separate load/unload shapes
		var dist_x = c.x - p_cx
		var dist_z = c.y - p_cz
		# Using Chebyshev (Box) distance for consistency with Grid logic, but adding buffer
		var dist = max(abs(dist_x), abs(dist_z))
		
		if dist > (view_range + UNLOAD_HYSTERESIS_CHUNKS):
			if vegetation_manager:
				vegetation_manager.remove_chunk_vegetation(c)
			
			chunks[c].queue_free()
			chunks.erase(c)
	
	# 3. Clean up threads for chunks that went out of range while building
	for c in active_build_threads.keys().duplicate(): 
		var dist_x = c.x - p_cx
		var dist_z = c.y - p_cz
		var dist = max(abs(dist_x), abs(dist_z))
		
		# If the player moved so fast that a loading chunk is now way out of unload range
		if dist > (view_range + UNLOAD_HYSTERESIS_CHUNKS):
			var builder_thread: ChunkBuilderThread = active_build_threads.get(c)
			
			if is_instance_valid(builder_thread):
				var finished_thread = builder_thread.cleanup()
				active_build_threads.erase(c)
				# --- DEBUG OVERLAY ---
				DebugOverlay.monitor_increment("Threads", "Active Workers", -1)

				if is_instance_valid(finished_thread) and finished_thread.is_started():
					finished_thread.wait_to_finish()
			else:
				active_build_threads.erase(c)


func _update_lods():
	var p_pos = player.global_position if player else Vector3.ZERO
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	
	for c in chunks:
		var chunk = chunks[c]
		var dist_x = abs(c.x - p_cx)
		var dist_z = abs(c.y - p_cz)
		var dist = max(dist_x, dist_z)
		
		var current_lod = chunk.current_lod
		var target_lod = 1 # Default to Low Res
		
		# Hysteresis Logic:
		# If we are already High Res (0), stay High Res until we cross (Limit + Buffer)
		# If we are Low Res (1), only switch to High Res if we are strictly inside (Limit)
		
		if current_lod == 0:
			if dist > (LOD_HIGH_RES_DISTANCE + LOD_HYSTERESIS_CHUNKS):
				target_lod = 1
			else:
				target_lod = 0
		else:
			if dist <= LOD_HIGH_RES_DISTANCE:
				target_lod = 0
			else:
				target_lod = 1
			
		chunk.set_lod(target_lod)

func _process_queue():
	# --- DEBUG OVERLAY ---
	# Report Queue size
	DebugOverlay.monitor_set("Terrain", "Queue Size", generation_queue.size())
	
	if active_build_threads.size() < world_config.max_chunks_per_frame and not generation_queue.is_empty():
		var c = generation_queue.pop_front()
		
		var chunk = TerrainChunk.new()
		add_child(chunk)
		
		chunk.setup(c,
					world_config,
					noise_builder,
					material_lib,
					veg_spawner,
					biome_selector,
					splat_map_generator,
					vegetation_manager 
					)
		
		chunks[c] = chunk
		
		var builder_thread = ChunkBuilderThread.new()
		builder_thread.connect("build_finished", _on_chunk_build_finished)
		builder_thread.start_build(c, world_config, noise_builder, biome_selector, splat_map_generator, veg_spawner)
		active_build_threads[c] = builder_thread
		
		# --- DEBUG OVERLAY ---
		DebugOverlay.monitor_increment("Threads", "Active Workers", 1)
		
func _on_chunk_build_finished(coords: Vector2i, build_data: Dictionary):
	if active_build_threads.has(coords):
		var builder_thread: ChunkBuilderThread = active_build_threads[coords]
		
		active_build_threads.erase(coords)
		# --- DEBUG OVERLAY ---
		DebugOverlay.monitor_increment("Threads", "Active Workers", -1)
		
		if chunks.has(coords):
			var chunk: TerrainChunk = chunks[coords]
			chunk.apply_prebuilt_data(build_data)
			call_deferred("_update_lods")

		if player and not _initial_spawn_chunk_built:
			var h = noise_builder.get_height(player.global_position.x, player.global_position.z)
			player.global_position.y = h + 2.0
			print("✅ Initial Spawn Chunk built. Player placed at Y:", player.global_position.y)
			call_deferred("_start_full_world_loading")
		
		var finished_thread = builder_thread.cleanup()
		
		if finished_thread and finished_thread.is_started():
			threads_to_join.append(finished_thread)
			Callable(finished_thread, "wait_to_finish").call_deferred()

func _stop_all_threads():
	for coords in active_build_threads.keys().duplicate():
		if active_build_threads.has(coords):
			var builder_thread: ChunkBuilderThread = active_build_threads[coords]
			var finished_thread = builder_thread.cleanup()
			active_build_threads.erase(coords)
			
			if is_instance_valid(finished_thread) and finished_thread.is_started():
				finished_thread.wait_to_finish()
	
	var current_threads_to_join = threads_to_join.duplicate()
	threads_to_join.clear()
	
	for thread in current_threads_to_join:
		if is_instance_valid(thread) and thread.is_started():
			thread.wait_to_finish()
