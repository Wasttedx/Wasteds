extends Resource
class_name NoiseConfig

@export_group("Noise Parameters")
@export var noise_seed: int = 84291
@export var frequency: float = 0.004
@export var octaves: int = 5
@export var lacunarity: float = 2.1
@export var persistence: float = 0.45
@export var height_multiplier: float = 35.0
@export var noise_offset: Vector2 = Vector2(1000, 1000)
