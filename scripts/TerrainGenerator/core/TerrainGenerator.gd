extends Node3D

# --- Dependencies (Configs) ---
@export_group("Configs")
@export var world_config: WorldConfig
@export var noise_config: NoiseConfig
@export var veg_config: VegetationConfig

# --- Assets ---
@export_group("Materials")
@export var terrain_shader: Shader = preload("res://shaders/terrain_shader.gdshader")
@export var splat_map: Texture2D
@export var tex_grass: Texture2D
@export var tex_dirt: Texture2D
@export var tex_rock: Texture2D
@export var tex_corrupt: Texture2D

@export_group("Target")
@export var player_path: NodePath

# --- Systems ---
var noise_builder: NoiseBuilder
var material_lib: MaterialLibrary
var veg_spawner: VegetationSpawner

var chunks := {}
var generation_queue := []
var player: Node3D

func _ready():
	if player_path: player = get_node_or_null(player_path)
	
	_initialize_systems()
	_create_defaults_if_missing()
	
	# Initial generation
	_update_chunks()
	
	# Snap player to ground
	if player:
		var h = noise_builder.get_height(player.global_position.x, player.global_position.z)
		player.global_position.y = h + 2.0

func _process(_delta):
	if not player: return
	_update_chunks()
	_process_queue()

func _initialize_systems():
	# Initialize services with configs
	noise_builder = NoiseBuilder.new(noise_config)
	
	var textures = {
		"splat_map": splat_map, "tex_grass": tex_grass,
		"tex_dirt": tex_dirt, "tex_rock": tex_rock, "tex_corrupt": tex_corrupt
	}
	material_lib = MaterialLibrary.new(terrain_shader, textures)
	
	veg_spawner = VegetationSpawner.new(veg_config, noise_builder, world_config.chunk_world_size)

func _create_defaults_if_missing():
	# Creates temporary placeholders if Config resources are empty
	if not veg_config.grass_mesh:
		var p = QuadMesh.new(); p.size = Vector2(0.4, 0.8); p.center_offset = Vector3(0,0.4,0)
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
			
			if not chunks.has(c) and not generation_queue.has(c):
				generation_queue.append(c)
	
	# Cleanup old chunks
	for c in chunks.keys():
		if not active_coords.has(c):
			chunks[c].queue_free()
			chunks.erase(c)

func _process_queue():
	var processed = 0
	while processed < world_config.max_chunks_per_frame and not generation_queue.is_empty():
		var c = generation_queue.pop_front()
		if chunks.has(c): continue
		
		var chunk = TerrainChunk.new()
		add_child(chunk)
		# Dependency Injection: Give the chunk exactly what it needs
		chunk.setup(c, world_config, noise_builder, material_lib, veg_spawner)
		chunks[c] = chunk
		processed += 1
