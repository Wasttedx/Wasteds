class_name BiomeSelector

var biome_configs: Array[BiomeConfig] = []
var weighted_biomes: Array = [] # Array of {id, weight} for random selection
var seed: int = 0
var noise_builder: NoiseBuilder

func _init(configs: Array[BiomeConfig], init_seed: int, noise_service: NoiseBuilder):
	biome_configs = configs
	seed = init_seed
	noise_builder = noise_service
	_calculate_weighted_list()

func _calculate_weighted_list():
	weighted_biomes.clear()
	var total_weight = 0.0
	for config in biome_configs:
		total_weight += config.spawn_probability
		weighted_biomes.append({"id": config.biome_id, "weight": total_weight})
	
	# Normalize weights
	for item in weighted_biomes:
		item.weight /= total_weight

# Simple random-based selection for now, based on world coordinates
# In a full system, this would use noise (e.g. Biome Noise)
func get_biome_for_coords(world_x: float, world_z: float) -> BiomeConfig:
	if biome_configs.is_empty():
		push_error("BiomeSelector: No BiomeConfigs provided.")
		return null
		
	# Use world coordinates to generate a deterministic seed for a random choice
	var deterministic_rng_seed = int(world_x * 10.0 + world_z * 73856093)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = deterministic_rng_seed + seed # Combine world-coord seed with global seed
	
	# For simplicity, we currently use a single Perlin/Simplex noise layer 
	# as a 'biome' noise map, scaled down heavily.
	var biome_noise = noise_builder.get_biome_noise(world_x, world_z) # Range [0.0, 1.0]

	# --- Biome selection based on noise (instead of random weight) ---
	# For the initial implementation, let's keep it simple:
	# Use Biome Noise to select one of the biomes linearly
	
	# Map biome_noise (0 to 1) to an index in the weighted list
	var current_weight = 0.0
	for config in biome_configs:
		var normalized_weight = config.spawn_probability / noise_builder.get_total_biome_weight()
		current_weight += normalized_weight
		if biome_noise <= current_weight:
			return config

	# Fallback (should not happen with normalized weights)
	return biome_configs.back()

func get_wetness_for_coords(world_x: float, world_z: float) -> float:
	var biome = get_biome_for_coords(world_x, world_z)
	return biome.wetness if biome else 0.5
