class_name BiomeSelector

# --- Type-hinting assumptions ---
# We assume BiomeConfig and NoiseBuilder are classes you have defined elsewhere.

# --- Class Variables ---
var biome_configs: Array[BiomeConfig] = []
var weighted_biomes: Array[Dictionary] = [] 

# Renamed 'seed' to 'global_seed' to avoid shadowing the built-in function 'seed()'.
var global_seed: int = 0 
var noise_builder: NoiseBuilder

# --- Initialization ---
func _init(configs: Array[BiomeConfig], init_seed: int, noise_service: NoiseBuilder):
	biome_configs = configs
	
	# Use the new variable name
	global_seed = init_seed
	
	noise_builder = noise_service
	_calculate_weighted_list()

# --- Weight Calculation (No changes needed) ---
func _calculate_weighted_list():
	weighted_biomes.clear()
	var total_weight = 0.0
	for config in biome_configs:
		total_weight += config.spawn_probability
		# Using a typed dictionary for clarity
		weighted_biomes.append({"id": config.biome_id, "weight": total_weight})
	
	# Normalize weights
	for item in weighted_biomes:
		item.weight = float(item.weight) / total_weight

# --- Biome Selection Logic ---
func get_biome_for_coords(world_x: float, world_z: float) -> BiomeConfig:
	if biome_configs.is_empty():
		push_error("BiomeSelector: No BiomeConfigs provided.")
		return null
		
	# Use world coordinates to generate a deterministic seed for a random choice
	var deterministic_rng_seed = int(world_x * 10.0 + world_z * 73856093)
	
	var rng = RandomNumberGenerator.new()
	
	# CRITICAL FIX: Use the new variable name 'global_seed'
	rng.seed = deterministic_rng_seed + global_seed 
	
	# For simplicity, we currently use a single Perlin/Simplex noise layer 
	var biome_noise: float = noise_builder.get_biome_noise(world_x, world_z) # Range [0.0, 1.0]

	# --- Biome selection based on noise ---
	var current_weight: float = 0.0
	var total_biome_weight: float = noise_builder.get_total_biome_weight()
	
	for config in biome_configs:
		var normalized_weight: float = config.spawn_probability / total_biome_weight
		current_weight += normalized_weight
		
		# If the noise value falls within this biome's segment (0.0 to 1.0 range), select it
		if biome_noise <= current_weight:
			return config

	# Fallback 
	return biome_configs.back()

# --- Utility Function ---
func get_wetness_for_coords(world_x: float, world_z: float) -> float:
	var biome = get_biome_for_coords(world_x, world_z)
	
	# FIXED: Using the standard GDScript ternary operator to handle a null biome
	return biome.wetness if biome else 0.5
