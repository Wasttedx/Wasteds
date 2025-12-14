extends Node3D
class_name TerrainGenerator

@export_group("Configs")
@export var world_config: WorldConfig
@export var noise_config: NoiseConfig
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

var chunks := {}
var generation_queue := []
var active_build_threads := {}
var threads_to_join := []
var player: Node3D

const LOD_HIGH_RES_DISTANCE: int = 1 

func _ready():
	if player_path: player = get_node_or_null(player_path)
	
	_initialize_systems()
	_create_defaults_if_missing()
	
	_update_chunks()
	_update_lods()
	
	if player:
		var h = noise_builder.get_height(player.global_position.x, player.global_position.z)
		player.global_position.y = h + 2.0

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_stop_all_threads()

func _process(_delta):
	if not player: return
	_update_chunks()
	_update_lods()
	_process_queue()

func _initialize_systems():
	noise_builder = NoiseBuilder.new(noise_config)
	
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

func _create_defaults_if_missing():
	if not veg_config.grass_mesh:
		var p = QuadMesh.new(); p.size = Vector2(0.4, 0.8); p.center_offset = Vector3(0, 0.4, 0)
		veg_config.grass_mesh = p

func _update_chunks():
	var p_pos = player.global_position if player else Vector3.ZERO
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	
	var range_c = world_config.view_distance_chunks
	var active_coords = {}
	
	for z in range(-range_c, range_c + 1):
		for x in range(-range_c, range_c + 1):
			var c = Vector2i(p_cx + x, p_cz + z)
			active_coords[c] = true
			
			if not chunks.has(c) and not active_build_threads.has(c) and not generation_queue.has(c):
				generation_queue.append(c)
	
	for c in chunks.keys():
		if not active_coords.has(c):
			chunks[c].queue_free()
			chunks.erase(c)
	
	for c in active_build_threads.keys():
		if not active_coords.has(c):
			var builder_thread: ChunkBuilderThread = active_build_threads.get(c)

			var finished_thread = builder_thread.cleanup()

			active_build_threads.erase(c)

			if is_instance_valid(finished_thread) and finished_thread.is_started():
				finished_thread.wait_to_finish()


func _update_lods():
	var p_pos = player.global_position if player else Vector3.ZERO
	var p_cx = int(floor(p_pos.x / world_config.chunk_world_size))
	var p_cz = int(floor(p_pos.z / world_config.chunk_world_size))
	
	for c in chunks:
		var chunk = chunks[c]
		
		var dist_x = abs(c.x - p_cx)
		var dist_z = abs(c.y - p_cz)
		var dist = max(dist_x, dist_z)
		
		var target_lod = 0
		if dist > LOD_HIGH_RES_DISTANCE:
			target_lod = 1
			
		chunk.set_lod(target_lod)

func _process_queue():
	
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
					splat_map_generator
					) 
		
		chunks[c] = chunk
		
		var builder_thread = ChunkBuilderThread.new()
		builder_thread.connect("build_finished", _on_chunk_build_finished)
		builder_thread.start_build(c, world_config, noise_builder, biome_selector, splat_map_generator, veg_spawner)
		active_build_threads[c] = builder_thread
		
func _on_chunk_build_finished(coords: Vector2i, build_data: Dictionary):
	if active_build_threads.has(coords):
		var builder_thread: ChunkBuilderThread = active_build_threads[coords]
		
		active_build_threads.erase(coords)
		
		if chunks.has(coords):
			var chunk: TerrainChunk = chunks[coords]
			chunk.apply_prebuilt_data(build_data) 
			
			call_deferred("_update_lods")

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
