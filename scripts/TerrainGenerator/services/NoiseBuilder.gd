class_name NoiseBuilder

var config: NoiseConfig
var _noise: FastNoiseLite

func _init(cfg: NoiseConfig):
	config = cfg
	_setup_noise()

func _setup_noise():
	_noise = FastNoiseLite.new()
	_noise.seed = config.seed
	_noise.frequency = config.frequency
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = config.octaves
	_noise.fractal_lacunarity = config.lacunarity
	_noise.fractal_gain = config.persistence

func get_height(world_x: float, world_z: float) -> float:
	var nx = world_x + config.noise_offset.x
	var nz = world_z + config.noise_offset.y
	
	var n1 = _noise.get_noise_2d(nx, nz) * 0.5 + 0.5
	var n2 = _noise.get_noise_2d(nx * 2.0, nz * 2.0) * 0.5 + 0.5
	
	return (n1 * 0.7 + n2 * 0.3 - 0.5) * config.height_multiplier
