extends Resource
class_name NoiseConfig

@export_group("Noise Parameters")
@export var seed: int = 1337
@export var frequency: float = 0.01
@export var octaves: int = 4
@export var lacunarity: float = 2.0
@export var persistence: float = 0.5
@export var height_multiplier: float = 20.0
@export var noise_offset: Vector2 = Vector2.ZERO
