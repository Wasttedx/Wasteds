class_name NoiseBuilder

var config: NoiseConfig
var _noise: FastNoiseLite
var _biome_noise: FastNoiseLite # Dedicated noise for biome selection/blending
var _config_stack: Array[NoiseConfig] = [] # Stack for biome overrides

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
	
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = config.seed
	_biome_noise.frequency = 0.0005 # Very low frequency for large biomes
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_biome_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

# --- Biome Override System ---

# Push a biome config to override the current noise parameters
func push_config_override(biome_config: BiomeConfig):
	_config_stack.append(config) # Save current active config
	var new_config = config.duplicate() # Create a temporary new config
	
	# Apply overrides if values are not default (0.0)
	if biome_config.noise_frequency_override > 0.0:
		new_config.frequency = biome_config.noise_frequency_override
	if biome_config.noise_height_multiplier_override > 0.0:
		new_config.height_multiplier = biome_config.noise_height_multiplier_override
	
	config = new_config # Set the temporary config as the active one
	_setup_noise() # Re-initialize the noise generator with the new parameters

# Restore the previous active config
func pop_config_override():
	if _config_stack.is_empty(): return
	config = _config_stack.pop_back()
	_setup_noise() # Re-initialize the noise generator

# --- Height Generation (Now uses active config, potentially overriden) ---

func get_height(world_x: float, world_z: float) -> float:
	var nx = world_x + config.noise_offset.x
	var nz = world_z + config.noise_offset.y
	
	var n1 = _noise.get_noise_2d(nx, nz) * 0.5 + 0.5
	var n2 = _noise.get_noise_2d(nx * 2.0, nz * 2.0) * 0.5 + 0.5
	
	return (n1 * 0.7 + n2 * 0.3 - 0.5) * config.height_multiplier

# --- Biome-Specific Noise ---

# Get a very low-frequency noise value (0.0 to 1.0) for biome selection/blending
func get_biome_noise(world_x: float, world_z: float) -> float:
	var nx = world_x + config.noise_offset.x
	var nz = world_z + config.noise_offset.y
	
	# Remap from [-1, 1] to [0, 1]
	return _biome_noise.get_noise_2d(nx, nz) * 0.5 + 0.5

# Placeholder function, would normally sum probabilities from an array of biomes
func get_total_biome_weight() -> float:
	return 1.0 # Assuming all biomes in the BiomeSelector sum up to 1.0 for now
