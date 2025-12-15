extends BaseNoiseLayer
class_name ErosionLayer

func _init():
	layer_name = "Erosion Layer"
	blend_mode = BlendMode.SUBTRACT

func get_height(x: float, z: float) -> float:
	if not enabled or not noise:
		return 0.0

	var sample_x = (x + noise_offset.x) * noise_scale.x
	var sample_z = (z + noise_offset.y) * noise_scale.y

	var n = noise.get_noise_2d(sample_x, sample_z)
	
	return abs(n) * weight
