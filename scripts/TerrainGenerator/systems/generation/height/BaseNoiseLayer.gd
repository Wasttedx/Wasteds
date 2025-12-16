extends Resource
class_name BaseNoiseLayer

enum BlendMode {ADD, SUBTRACT, MULTIPLY, MIN, MAX, REPLACE}

@export_group("Base Settings")
@export var enabled: bool = true
@export var blend_mode: BlendMode = BlendMode.ADD
@export_range(0.0, 1.0) var weight: float = 1.0 # Multiplier for the layer's influence
@export var use_global_seed: bool = false
var layer_name: String = "Base Layer"

@export_group("Noise Sampling")
@export var noise_scale: Vector2 = Vector2(1.0, 1.0)
@export var noise_offset: Vector2 = Vector2(0.0, 0.0)

var noise: FastNoiseLite

# The actual height calculation logic, to be overridden by child classes
func get_height(_x: float, _z: float) -> float:
	return 0.0 # Must be overridden
