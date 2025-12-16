extends BaseNoiseLayer
class_name CanyonLayer

@export_group("Canyon Settings")
@export var invert_noise: bool = false
@export_range(0.0, 1.0) var power_exponent: float = 1.5

func _init():
	layer_name = "Canyon Layer"
	blend_mode = BlendMode.SUBTRACT
	weight = 0.5

func get_height(x: float, z: float) -> float:
	if not enabled or not noise:
		return 0.0

	var sample_x = (x + noise_offset.x) * noise_scale.x
	var sample_z = (z + noise_offset.y) * noise_scale.y

	var n = noise.get_noise_2d(sample_x, sample_z)
	
	var canyon_value = n * 0.5 + 0.5
	
	if invert_noise:
		canyon_value = 1.0 - canyon_value

	canyon_value = pow(canyon_value, power_exponent)
	
	# Return the layer's influence (scaled by its weight)
	return canyon_value * weight
