extends RefCounted
class_name VegetationSpawner

var config: VegetationConfig
var noise: NoiseBuilder
var chunk_size: float

func _init(p_config: VegetationConfig, p_noise: NoiseBuilder, p_chunk_size: float):
	self.config = p_config
	self.noise = p_noise
	self.chunk_size = p_chunk_size

static func generate_transforms(chunk_coords: Vector2i, world_config: WorldConfig, noise_builder: NoiseBuilder, veg_config: VegetationConfig, splat_image: Image) -> Dictionary:
	var vegetation_data := {}
	var c_size = world_config.chunk_world_size
	var res = world_config.chunk_resolution

	if veg_config.items.is_empty():
		return {}

	for item_idx in range(veg_config.items.size()):
		var item: VegetationItem = veg_config.items[item_idx]
		var transforms: Array[Transform3D] = []
		
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(str(chunk_coords) + item.name)
		
		for i in range(item.density):
			var lx = rng.randf_range(0.0, c_size)
			var lz = rng.randf_range(0.0, c_size)
			
			var wx = (chunk_coords.x * c_size) + lx
			var wz = (chunk_coords.y * c_size) + lz
			
			# 1. Height Check (Absolute World Height)
			var h = noise_builder.get_height(wx, wz)
			if h < item.min_height or h > item.max_height:
				continue
				
			# 2. Slope Check
			var normal = noise_builder.get_normal(wx, wz)
			var slope = 1.0 - normal.dot(Vector3.UP) # 0 = flat, 1 = vertical
			if slope > item.max_slope:
				continue
			
			# 3. Splat Map / Biome Check
			var px = clamp(int((lx / c_size) * (res - 1)), 0, res - 1)
			var pz = clamp(int((lz / c_size) * (res - 1)), 0, res - 1)
			var splat_color = splat_image.get_pixel(px, pz)
			
			var weight = 0.0
			match item.splat_channel:
				0: weight = splat_color.r
				1: weight = splat_color.g
				2: weight = splat_color.b
				
			if weight < item.splat_weight_threshold:
				continue
				
			# 4. Create Transform
			var s = rng.randf_range(item.scale_range.x, item.scale_range.y)
			var basis = Basis()
			if item.random_rotation:
				basis = basis.rotated(Vector3.UP, rng.randf_range(0, TAU))
			basis = basis.scaled(Vector3.ONE * s)
			
			# Store relative to chunk for the raycaster to find later
			# We set Y high so the raycast starts above any possible terrain
			var t = Transform3D(basis, Vector3(lx, 1000.0, lz))
			transforms.append(t)
			
		if not transforms.is_empty():
			vegetation_data[item_idx] = transforms
			
	return vegetation_data
