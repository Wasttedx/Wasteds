extends RefCounted
class_name NoiseBuilder

var config: NoiseConfig
var height_pipeline: HeightPipelineConfig

var _noise: FastNoiseLite
var _biome_noise: FastNoiseLite
var _config_stack: Array[NoiseConfig] = []

func _init(cfg: NoiseConfig, pipeline_cfg: HeightPipelineConfig = null):
	config = cfg
	height_pipeline = pipeline_cfg
	_initialize_noise_objects()

func _initialize_noise_objects():
	_noise = FastNoiseLite.new()
	_biome_noise = FastNoiseLite.new()
	
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_lacunarity = config.lacunarity
	_noise.fractal_gain = config.persistence
	
	_biome_noise.frequency = 0.0005
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_biome_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	_apply_noise_config(config)
	
	if height_pipeline:
		_initialize_pipeline_seeds()

func _initialize_pipeline_seeds():
	if height_pipeline.layers.is_empty():
		return

	var layer_idx = 0
	for layer in height_pipeline.layers:
		if layer.noise == null:
			layer.noise = FastNoiseLite.new()
			layer.noise.noise_type = FastNoiseLite.TYPE_PERLIN
			layer.noise.fractal_type = FastNoiseLite.FRACTAL_FBM
			
		if layer.use_global_seed:
			layer.noise.seed = config.noise_seed + (layer_idx * 1327)    
			
		layer_idx += 1

func _apply_noise_config(cfg: NoiseConfig):
	_noise.seed = cfg.noise_seed    
	
	_noise.frequency = cfg.frequency
	_noise.fractal_octaves = cfg.octaves
	
	_biome_noise.seed = cfg.noise_seed    
	
	if height_pipeline:
		_initialize_pipeline_seeds()

# --- NEW: NORMAL CALCULATION FOR SLOPE CHECKS ---

func get_normal(world_x: float, world_z: float) -> Vector3:
	# Small offset used to sample neighboring heights
	var step := 0.2 
	
	var h_l = get_height(world_x - step, world_z)
	var h_r = get_height(world_x + step, world_z)
	var h_d = get_height(world_x, world_z - step)
	var h_u = get_height(world_x, world_z + step)
	
	# Central difference method to find the slope vectors
	# The normal is the cross product of the X-tangent and Z-tangent
	var normal = Vector3(h_l - h_r, step * 2.0, h_d - h_u).normalized()
	
	return normal

# -----------------------------------------------

func push_config_override(biome_config: BiomeConfig):
	_config_stack.append(config)
	var new_config = config.duplicate()
	
	if biome_config.noise_frequency_override > 0.0:
		new_config.frequency = biome_config.noise_frequency_override
	if biome_config.noise_height_multiplier_override > 0.0:
		new_config.height_multiplier = biome_config.noise_height_multiplier_override
	
	config = new_config
	_apply_noise_config(config)

func pop_config_override():
	if _config_stack.is_empty(): return
	config = _config_stack.pop_back()
	_apply_noise_config(config)

func _get_base_height_unscaled(world_x: float, world_z: float) -> float:
	var nx = world_x + config.noise_offset.x
	var nz = world_z + config.noise_offset.y
	
	var n1 = _noise.get_noise_2d(nx, nz) * 0.5 + 0.5    
	var n2 = _noise.get_noise_2d(nx * 2.0, nz * 2.0) * 0.5 + 0.5
	
	return (n1 * 0.7 + n2 * 0.3 - 0.5)

func get_height(world_x: float, world_z: float) -> float:
	if height_pipeline and not height_pipeline.layers.is_empty():
		return _get_pipeline_height(world_x, world_z)
	
	return _get_base_height_unscaled(world_x, world_z) * config.height_multiplier

func _get_pipeline_height(x: float, z: float) -> float:
	var total_height: float = _get_base_height_unscaled(x, z) * config.height_multiplier
	
	for layer in height_pipeline.layers:
		if not layer.enabled:
			continue
			
		var layer_val = layer.get_height(x, z) 
		
		match layer.blend_mode:
			BaseNoiseLayer.BlendMode.ADD:
				total_height += layer_val * config.height_multiplier
			BaseNoiseLayer.BlendMode.SUBTRACT:
				total_height -= layer_val * config.height_multiplier
			BaseNoiseLayer.BlendMode.MULTIPLY:
				total_height *= layer_val
			BaseNoiseLayer.BlendMode.MIN:
				total_height = min(total_height, layer_val) 
			BaseNoiseLayer.BlendMode.MAX:
				total_height = max(total_height, layer_val)
			BaseNoiseLayer.BlendMode.REPLACE:
				total_height = layer_val * config.height_multiplier
				
	return total_height

func get_biome_noise(world_x: float, world_z: float) -> float:
	var nx = world_x + config.noise_offset.x
	var nz = world_z + config.noise_offset.y
	
	return _biome_noise.get_noise_2d(nx, nz) * 0.5 + 0.5

func get_total_biome_weight() -> float:
	return 1.0
