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

const LOD_HIGH_RES_DISTANCE: int = 1
const UNLOAD_HYSTERESIS_CHUNKS: int = 2

var _initial_spawn_chunk_built: bool = false

func _ready():
	player = get_node_or_null(player_path)
	_initialize_systems()
	
	if player:
		_queue_chunk(Vector2i(
			floor(player.global_position.x / world_config.chunk_world_size),
			floor(player.global_position.z / world_config.chunk_world_size)
		))

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_stop_all_threads()

func _process(_delta):
	if not player: return
	
	_update_debug()

	if _initial_spawn_chunk_built:
		_update_chunks()
	
	_update_lods()
	_process_queue()
	_clean_finished_threads()

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
	vegetation_manager.setup(player, veg_config, world_config.chunk_world_size)

func _update_chunks():
	var p_pos = player.global_position
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	var view_range = world_config.view_distance_chunks
	
	for z in range(-view_range, view_range + 1):
		for x in range(-view_range, view_range + 1):
			var c = Vector2i(p_cx + x, p_cz + z)
			if not chunks.has(c) and not active_build_threads.has(c) and not generation_queue.has(c):
				generation_queue.append(c)
	
	var unload_limit = view_range + UNLOAD_HYSTERESIS_CHUNKS
	for c in chunks.keys().duplicate(): 
		var dist = max(abs(c.x - p_cx), abs(c.y - p_cz))
		if dist > unload_limit:
			chunks[c].queue_free()
			chunks.erase(c)

func _update_lods():
	if not player: return
	var p_pos = player.global_position
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	
	for c in chunks:
		var dist = max(abs(c.x - p_cx), abs(c.y - p_cz))
		chunks[c].set_lod(0 if dist <= LOD_HIGH_RES_DISTANCE else 1)

func _process_queue():
	while active_build_threads.size() < world_config.max_chunks_per_frame and not generation_queue.is_empty():
		var c = generation_queue.pop_front()
		var chunk = TerrainChunk.new()
		add_child(chunk)
		chunk.setup(c, world_config, noise_builder, material_lib, veg_spawner, biome_selector, splat_map_generator, vegetation_manager)
		chunks[c] = chunk
		
		var builder_thread = ChunkBuilderThread.new()
		builder_thread.build_finished.connect(_on_chunk_build_finished)
		builder_thread.start_build(c, world_config, noise_builder, biome_selector, splat_map_generator, veg_spawner)
		active_build_threads[c] = builder_thread

func _on_chunk_build_finished(coords: Vector2i, build_data: Dictionary):
	if active_build_threads.has(coords):
		var builder_thread = active_build_threads[coords]
		active_build_threads.erase(coords)
		
		if chunks.has(coords):
			chunks[coords].apply_prebuilt_data(build_data)
			_update_lods()

		if not _initial_spawn_chunk_built:
			var h = noise_builder.get_height(player.global_position.x, player.global_position.z)
			player.global_position.y = h + 5.0
			_initial_spawn_chunk_built = true
		
		var t = builder_thread.cleanup()
		if t: threads_to_join.append(t)

func _update_debug():
	if has_node("/root/DebugOverlay"):
		var overlay = get_node("/root/DebugOverlay")
		overlay.monitor_set("Player", "Position", player.global_position)
		overlay.monitor_set("World", "Total Chunks", chunks.size())
		overlay.monitor_set("World", "In Queue", generation_queue.size())
		overlay.monitor_set("World", "Active Threads", active_build_threads.size())
		
		var high_res_count = 0
		var low_res_count = 0
		for c in chunks:
			if chunks[c].current_lod == 0:
				high_res_count += 1
			else:
				low_res_count += 1
		
		overlay.monitor_set("LOD", "High Res (LOD0)", high_res_count)
		overlay.monitor_set("LOD", "Low Res (LOD1)", low_res_count)
		# Track if vegetation matches the high res count
		overlay.monitor_set("LOD", "Veg Expected", high_res_count)

func _clean_finished_threads():
	for i in range(threads_to_join.size() - 1, -1, -1):
		var t = threads_to_join[i]
		if t and not t.is_alive():
			t.wait_to_finish()
			threads_to_join.remove_at(i)

func _queue_chunk(c: Vector2i):
	if not chunks.has(c) and not active_build_threads.has(c) and not generation_queue.has(c):
		generation_queue.append(c)

func _stop_all_threads():
	for coords in active_build_threads:
		var t = active_build_threads[coords].cleanup()
		if t: t.wait_to_finish()
	active_build_threads.clear()
	for t in threads_to_join:
		if t and t.is_started(): t.wait_to_finish()
	threads_to_join.clear()
