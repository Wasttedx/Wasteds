class_name NoiseBuilder

var config: NoiseConfig
var _noise: FastNoiseLite
var _biome_noise: FastNoiseLite
var _config_stack: Array[NoiseConfig] = []

func _init(cfg: NoiseConfig):
	config = cfg
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

func _apply_noise_config(cfg: NoiseConfig):
	_noise.seed = cfg.noise_seed 
	
	_noise.frequency = cfg.frequency
	_noise.fractal_octaves = cfg.octaves
	
	_biome_noise.seed = cfg.noise_seed 

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

func get_height(world_x: float, world_z: float) -> float:
	var nx = world_x + config.noise_offset.x
	var nz = world_z + config.noise_offset.y
	
	var n1 = _noise.get_noise_2d(nx, nz) * 0.5 + 0.5 
	var n2 = _noise.get_noise_2d(nx * 2.0, nz * 2.0) * 0.5 + 0.5
	
	return (n1 * 0.7 + n2 * 0.3 - 0.5) * config.height_multiplier

func get_biome_noise(world_x: float, world_z: float) -> float:
	var nx = world_x + config.noise_offset.x
	var nz = world_z + config.noise_offset.y
	
	return _biome_noise.get_noise_2d(nx, nz) * 0.5 + 0.5

func get_total_biome_weight() -> float:
	return 1.0
