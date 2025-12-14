class_name BiomeSelector

var biome_configs: Array[BiomeConfig] = []
var weighted_biomes: Array[Dictionary] = [] 

var global_seed: int = 0 
var noise_builder: NoiseBuilder

func _init(configs: Array[BiomeConfig], init_seed: int, noise_service: NoiseBuilder):
	biome_configs = configs
	
	global_seed = init_seed
	
	noise_builder = noise_service
	_calculate_weighted_list()

func _calculate_weighted_list():
	weighted_biomes.clear()
	var total_weight = 0.0
	for config in biome_configs:
		total_weight += config.spawn_probability
		weighted_biomes.append({"id": config.biome_id, "weight": total_weight})
	
	for item in weighted_biomes:
		item.weight = float(item.weight) / total_weight

func get_biome_for_coords(world_x: float, world_z: float) -> BiomeConfig:
	if biome_configs.is_empty():
		push_error("BiomeSelector: No BiomeConfigs provided.")
		return null
		
	var deterministic_rng_seed = int(world_x * 10.0 + world_z * 73856093)
	
	var rng = RandomNumberGenerator.new()
	
	rng.seed = deterministic_rng_seed + global_seed 
	
	var biome_noise: float = noise_builder.get_biome_noise(world_x, world_z)

	var current_weight: float = 0.0
	var total_biome_weight: float = noise_builder.get_total_biome_weight()
	
	for config in biome_configs:
		var normalized_weight: float = config.spawn_probability / total_biome_weight
		current_weight += normalized_weight
		
		if biome_noise <= current_weight:
			return config

	return biome_configs.back()

func get_wetness_for_coords(world_x: float, world_z: float) -> float:
	var biome = get_biome_for_coords(world_x, world_z)
	
	return biome.wetness if biome else 0.5
