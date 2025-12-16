extends BaseNoiseLayer
class_name RidgeLayer

@export_group("Ridge Settings")
@export var sharpness: float = 2.0
@export var offset_y: float = 0.0

func _init():
	layer_name = "Ridge Layer"
	blend_mode = BlendMode.ADD
	# Assume default weight is 1.0 if not specified

func get_height(x: float, z: float) -> float:
	if not enabled or not noise:
		return 0.0

	var sample_x = (x + noise_offset.x) * noise_scale.x
	var sample_z = (z + noise_offset.y) * noise_scale.y

	var n = noise.get_noise_2d(sample_x, sample_z)
	
	var ridge = 1.0 - abs(n)
	
	if sharpness != 1.0:
		ridge = pow(ridge, sharpness)
	
	# Return the layer's influence (scaled by its weight and offset)
	return (ridge + offset_y) * weight
