class_name VegetationSpawner

var config: VegetationConfig
var noise: NoiseBuilder
var world_size: float

func _init(cfg: VegetationConfig, ns: NoiseBuilder, chunk_size: float):
	config = cfg
	noise = ns
	world_size = chunk_size

# UPDATED: Added biome_config argument here
func spawn_all(parent: Node3D, chunk_coords: Vector2i, fallback_mat: StandardMaterial3D, biome_config: BiomeConfig):
	
	# Determine counts and meshes, prioritizing biome overrides
	var grass_count = biome_config.vegetation_overrides.get("grass_count", config.grass_count)
	var tree_count = biome_config.vegetation_overrides.get("tree_count", config.tree_count)
	var rock_count = biome_config.vegetation_overrides.get("rock_count", config.rock_count)
	
	var grass_mesh = biome_config.vegetation_overrides.get("grass_mesh", config.grass_mesh)
	var tree_mesh = biome_config.vegetation_overrides.get("tree_mesh", config.tree_mesh)
	var rock_mesh = biome_config.vegetation_overrides.get("rock_mesh", config.rock_mesh)
	
	var grass_scale = biome_config.vegetation_overrides.get("grass_scale", config.grass_scale)
	var tree_scale = biome_config.vegetation_overrides.get("tree_scale", config.tree_scale)
	var rock_scale = biome_config.vegetation_overrides.get("rock_scale", config.rock_scale)
	
	# 1. Grass
	_spawn_layer(parent, chunk_coords, grass_mesh, grass_count, 0.1, grass_scale, fallback_mat, biome_config)
	# 2. Trees (No material override for trees/rocks to preserve Blender textures)
	_spawn_layer(parent, chunk_coords, tree_mesh, tree_count, 0.0, tree_scale, null, biome_config)
	# 3. Rocks
	_spawn_layer(parent, chunk_coords, rock_mesh, rock_count, 0.0, rock_scale, null, biome_config)

func _spawn_layer(parent: Node, coords: Vector2i, mesh: Mesh, count: int, y_off: float, scale_info: Vector2, mat: Material, biome_config: BiomeConfig):
	if count <= 0 or not mesh: return

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	
	# Calculate a deterministic seed from the Vector2i coordinates.
	var chunk_seed = int(coords.x) + int(coords.y) * 73856093
	
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
	
	var ox = coords.x * world_size
	var oz = coords.y * world_size
	
	# Max slope rule from config
	var max_slope = config.max_slope # BiomeConfig does not override this for now

	for i in range(count):
		var lx = rng.randf_range(0.0, world_size)
		var lz = rng.randf_range(0.0, world_size)
		var wx = ox + lx
		var wz = oz + lz
		
		# Ensure NoiseBuilder is using the correct (potentially overridden) height function
		var h = noise.get_height(wx, wz) 
		# Simple slope check. Should use surface normal for better accuracy.
		var h_next = noise.get_height(wx + 0.5, wz)
		var slope = abs(h_next - h)
		
		if slope > max_slope:
			mm.set_instance_transform(i, Transform3D().scaled(Vector3.ZERO))
			continue
			
		var s = scale_info.x + rng.randf() * scale_info.y
		var rot = Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var t = Transform3D(rot.scaled(Vector3.ONE * s), Vector3(lx, h + y_off, lz))
		
		mm.set_instance_transform(i, t)
	
	var inst = MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat: inst.material_override = mat
	parent.add_child(inst)
