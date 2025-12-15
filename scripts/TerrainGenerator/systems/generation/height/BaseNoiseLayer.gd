extends Resource
class_name BaseNoiseLayer

enum BlendMode {
	ADD,
	SUBTRACT,
	MULTIPLY,
	MIN,
	MAX,
	REPLACE
}

@export var enabled: bool = true
@export var layer_name: String = "Base Layer"
@export var blend_mode: BlendMode = BlendMode.ADD
@export_range(0.0, 250.0) var weight: float = 1.0

@export_group("Noise Settings")
@export var noise: FastNoiseLite
@export var noise_scale: Vector2 = Vector2(1.0, 1.0)
@export var noise_offset: Vector2 = Vector2.ZERO
@export var use_global_seed: bool = true

func get_height(x: float, z: float) -> float:
	if not enabled or not noise:
		return 0.0
	
	var sample_x = (x + noise_offset.x) * noise_scale.x
	var sample_z = (z + noise_offset.y) * noise_scale.y
	
	return noise.get_noise_2d(sample_x, sample_z) * weight
