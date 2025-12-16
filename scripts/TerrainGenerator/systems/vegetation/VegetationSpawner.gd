extends RefCounted
class_name VegetationSpawner

var config: VegetationConfig
var noise: NoiseBuilder
var world_size: float

func _init(cfg: VegetationConfig, ns: NoiseBuilder, chunk_size: float):
	config = cfg
	noise = ns
	world_size = chunk_size

# Returns a Dictionary: { Mesh : Array[Transform3D] }
static func generate_transforms(chunk_coords: Vector2i, world_config: WorldConfig, noise_builder: NoiseBuilder, veg_config: VegetationConfig, biome_config: BiomeConfig) -> Dictionary:
	
	var vegetation_data := {}
	var chunk_world_size = world_config.chunk_world_size

	var grass_count = biome_config.vegetation_overrides.get("grass_count", veg_config.grass_count)
	var tree_count = biome_config.vegetation_overrides.get("tree_count", veg_config.tree_count)
	var rock_count = biome_config.vegetation_overrides.get("rock_count", veg_config.rock_count)
	
	var grass_scale = biome_config.vegetation_overrides.get("grass_scale", veg_config.grass_scale)
	var tree_scale = biome_config.vegetation_overrides.get("tree_scale", veg_config.tree_scale)
	var rock_scale = biome_config.vegetation_overrides.get("rock_scale", veg_config.rock_scale)
	
	var max_slope = veg_config.max_slope	
	
	# NOTE: y_off (0.1, 0.0) is no longer used here; it's moved to TerrainChunk._snap_vegetation_transforms
	const Y_OFFSET_PLACEHOLDER = 0.0

	# Generate Grass
	if veg_config.grass_mesh and grass_count > 0:
		var transforms = _generate_layer_transforms(chunk_coords, chunk_world_size, noise_builder, grass_count, Y_OFFSET_PLACEHOLDER, grass_scale, max_slope, biome_config)
		if not transforms.is_empty():
			vegetation_data[veg_config.grass_mesh] = transforms

	# Generate Trees
	if "tree_mesh" in veg_config and veg_config.tree_mesh and tree_count > 0:
		var transforms = _generate_layer_transforms(chunk_coords, chunk_world_size, noise_builder, tree_count, Y_OFFSET_PLACEHOLDER, tree_scale, max_slope, biome_config)
		if not transforms.is_empty():
			vegetation_data[veg_config.tree_mesh] = transforms

	# Generate Rocks
	if "rock_mesh" in veg_config and veg_config.rock_mesh and rock_count > 0:
		var transforms = _generate_layer_transforms(chunk_coords, chunk_world_size, noise_builder, rock_count, Y_OFFSET_PLACEHOLDER, rock_scale, max_slope, biome_config)
		if not transforms.is_empty():
			vegetation_data[veg_config.rock_mesh] = transforms
	
	return vegetation_data

static func _generate_layer_transforms(coords: Vector2i, chunk_world_size: float, noise_builder: NoiseBuilder, count: int, y_off: float, scale_info: Vector2, max_slope: float, _biome_config: BiomeConfig) -> Array[Transform3D]:
	if count <= 0: return []
	
	var transforms: Array[Transform3D] = []
	
	# Use a unique seed per chunk/layer to ensure determinism
	var chunk_seed = int(coords.x) + int(coords.y) * 73856093 + int(count)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
	
	var ox = coords.x * chunk_world_size
	var oz = coords.y * chunk_world_size
	
	# FIX: Start the vegetation transforms high up in the chunk's local space (Y=0 is chunk bottom)
	# This guarantees the raycast will hit the surface below.
	const RAYCAST_START_HEIGHT = 500.0 
	
	for i in range(count):
		var lx = rng.randf_range(0.0, chunk_world_size)
		var lz = rng.randf_range(0.0, chunk_world_size)
		var wx = ox + lx
		var wz = oz + lz
		
		# Slope check still uses the approximate noise height
		var h = noise_builder.get_height(wx, wz)    
		var h_next = noise_builder.get_height(wx + 0.5, wz)
		var slope = abs(h_next - h)
		
		if slope > max_slope:
			continue
			
		var s = scale_info.x + rng.randf() * scale_info.y
		var rot = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		
		# FIX: Set local Y position to the guaranteed starting height for raycasting
		var t = Transform3D(rot.scaled(Vector3.ONE * s), Vector3(lx, RAYCAST_START_HEIGHT, lz))
		
		transforms.append(t)
		
	return transforms
