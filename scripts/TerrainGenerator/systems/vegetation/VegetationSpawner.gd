class_name VegetationSpawner

var config: VegetationConfig
var noise: NoiseBuilder
var world_size: float

func _init(cfg: VegetationConfig, ns: NoiseBuilder, chunk_size: float):
	config = cfg
	noise = ns
	world_size = chunk_size


# ==============================================================================
# THREAD-SAFE GENERATION METHOD (Called by ChunkBuilderThread)
# ==============================================================================
static func generate_transforms(chunk_coords: Vector2i, world_config: WorldConfig, noise_builder: NoiseBuilder, veg_config: VegetationConfig, biome_config: BiomeConfig) -> Array[Transform3D]:
	
	var all_transforms: Array[Transform3D] = []
	var chunk_world_size = world_config.chunk_world_size

	# --- 1. Determine counts and scales (using biome overrides) ---
	var grass_count = biome_config.vegetation_overrides.get("grass_count", veg_config.grass_count)
	var tree_count = biome_config.vegetation_overrides.get("tree_count", veg_config.tree_count)
	var rock_count = biome_config.vegetation_overrides.get("rock_count", veg_config.rock_count)
	
	var grass_scale = biome_config.vegetation_overrides.get("grass_scale", veg_config.grass_scale)
	var tree_scale = biome_config.vegetation_overrides.get("tree_scale", veg_config.tree_scale)
	var rock_scale = biome_config.vegetation_overrides.get("rock_scale", veg_config.rock_scale)
	
	var max_slope = veg_config.max_slope 
	
	# --- 2. Generate transforms for each layer ---
	
	all_transforms.append_array(
		_generate_layer_transforms(chunk_coords, chunk_world_size, noise_builder, grass_count, 0.1, grass_scale, max_slope, biome_config)
	)
	
	all_transforms.append_array(
		_generate_layer_transforms(chunk_coords, chunk_world_size, noise_builder, tree_count, 0.0, tree_scale, max_slope, biome_config)
	)
	
	all_transforms.append_array(
		_generate_layer_transforms(chunk_coords, chunk_world_size, noise_builder, rock_count, 0.0, rock_scale, max_slope, biome_config)
	)
	
	return all_transforms

# --- Private Static Helper (Generation) ---
static func _generate_layer_transforms(coords: Vector2i, world_size: float, noise_builder: NoiseBuilder, count: int, y_off: float, scale_info: Vector2, max_slope: float, biome_config: BiomeConfig) -> Array[Transform3D]:
	if count <= 0: return []
	
	var transforms: Array[Transform3D] = []
	
	var chunk_seed = int(coords.x) + int(coords.y) * 73856093
	
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
	
	var ox = coords.x * world_size
	var oz = coords.y * world_size
	
	for i in range(count):
		var lx = rng.randf_range(0.0, world_size)
		var lz = rng.randf_range(0.0, world_size)
		var wx = ox + lx
		var wz = oz + lz
		
		var h = noise_builder.get_height(wx, wz)    
		var h_next = noise_builder.get_height(wx + 0.5, wz)
		var slope = abs(h_next - h)
		
		if slope > max_slope:
			continue
			
		var s = scale_info.x + rng.randf() * scale_info.y
		var rot = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var t = Transform3D(rot.scaled(Vector3.ONE * s), Vector3(lx, h + y_off, lz))
		
		transforms.append(t)
	
	return transforms


# ==============================================================================
# MAIN-THREAD NODE APPLICATION METHOD
# ==============================================================================
func apply_transforms(parent: Node3D, transforms: Array[Transform3D], material: Material):
	
	# For simplicity, we use the default grass mesh and spawn all transforms into one MultiMesh.
	if config.grass_mesh:
		_apply_layer_multimesh(parent, transforms, config.grass_mesh, material)


func _apply_layer_multimesh(parent: Node3D, transforms: Array[Transform3D], mesh: Mesh, mat: Material):
	if transforms.is_empty() or not mesh: return

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		
	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat: inst.material_override = mat
	
	parent.add_child(inst)

# --- Obsolete methods kept empty for structure ---

func spawn_all(parent: Node3D, chunk_coords: Vector2i, fallback_mat: StandardMaterial3D, biome_config: BiomeConfig):
	pass
