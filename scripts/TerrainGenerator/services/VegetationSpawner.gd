class_name VegetationSpawner

var config: VegetationConfig
var noise: NoiseBuilder
var world_size: float

func _init(cfg: VegetationConfig, ns: NoiseBuilder, chunk_size: float):
	config = cfg
	noise = ns
	world_size = chunk_size

func spawn_all(parent: Node3D, chunk_coords: Vector2i, fallback_mat: StandardMaterial3D):
	# 1. Grass
	_spawn_layer(parent, chunk_coords, config.grass_mesh, config.grass_count, 0.1, config.grass_scale, fallback_mat)
	# 2. Trees (No material override for trees/rocks to preserve Blender textures)
	_spawn_layer(parent, chunk_coords, config.tree_mesh, config.tree_count, 0.0, config.tree_scale, null)
	# 3. Rocks
	_spawn_layer(parent, chunk_coords, config.rock_mesh, config.rock_count, 0.0, config.rock_scale, null)

func _spawn_layer(parent: Node, coords: Vector2i, mesh: Mesh, count: int, y_off: float, scale_info: Vector2, mat: Material):
	if count <= 0 or not mesh: return

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	
	# --- FIX START ---
	# Calculate a deterministic seed from the Vector2i coordinates.
	# This formula (or similar bitwise operations) is commonly used to create
	# a unique integer from two integers, ensuring the same chunk always gets the same seed.
	var chunk_seed = int(coords.x) + int(coords.y) * 73856093 
	# Note: I used a large prime number to combine the coordinates for better distribution.
	
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed # Set the unique seed for this chunk
	# --- FIX END ---

	var ox = coords.x * world_size
	var oz = coords.y * world_size

	for i in range(count):
		var lx = rng.randf_range(0.0, world_size)
		var lz = rng.randf_range(0.0, world_size)
		var wx = ox + lx
		var wz = oz + lz
		
		var h = noise.get_height(wx, wz)
		var h_next = noise.get_height(wx + 0.5, wz)
		var slope = abs(h_next - h)
		
		if slope > config.max_slope:
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
