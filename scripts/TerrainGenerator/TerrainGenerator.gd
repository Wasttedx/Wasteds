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
var generation_queue := []
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

func _process(_delta):
	if not player: return
	_update_chunks()
	_update_lods() # Check for LOD transitions
	_process_queue()

func _initialize_systems():
	# 1. Initialize services with configs
	noise_builder = NoiseBuilder.new(noise_config)
	
	# 2. Initialize Biome Selector
	biome_selector = BiomeSelector.new(biome_configs, noise_config.seed, noise_builder)
	
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
			
			if not chunks.has(c) and not generation_queue.has(c):
				generation_queue.append(c)
	
	# Cleanup old chunks
	for c in chunks.keys():
		if not active_coords.has(c):
			chunks[c].queue_free()
			chunks.erase(c)

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
			
		# Apply LOD
		chunk.set_lod(target_lod)

func _process_queue():
	# Process one chunk per frame to avoid stutters
	var processed = 0
	while processed < world_config.max_chunks_per_frame and not generation_queue.is_empty():
		var c = generation_queue.pop_front()
		if chunks.has(c): continue
		
		# Create the chunk instance
		var chunk = TerrainChunk.new()
		add_child(chunk)
		
		# Dependency Injection
		chunk.setup(c, 
					world_config, 
					noise_builder, 
					material_lib, 
					veg_spawner, 
					biome_selector, 
					splat_map_generator
					) 
		
		# NOTE: We don't call set_lod here immediately. 
		# We add it to chunks list, and _update_lods() will catch it on the next pass 
		# and assign the correct initial LOD.
		
		chunks[c] = chunk
		processed += 1
