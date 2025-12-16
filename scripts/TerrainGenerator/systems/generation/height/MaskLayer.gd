extends BaseNoiseLayer
class_name MaskLayer

@export_group("Mask Settings")
@export_range(-1.0, 1.0) var threshold: float = 0.0
@export_range(0.0, 1.0) var feather: float = 0.1

func _init():
	layer_name = "Mask Layer"
	blend_mode = BlendMode.MULTIPLY

func get_height(x: float, z: float) -> float:
	if not enabled or not noise:
		return 1.0

	var sample_x = (x + noise_offset.x) * noise_scale.x
	var sample_z = (z + noise_offset.y) * noise_scale.y

	var n = noise.get_noise_2d(sample_x, sample_z)
	
	var value = n * 0.5 + 0.5
	
	var mask_val = smoothstep(threshold - feather, threshold + feather, value)
	
	return lerp(1.0, mask_val, weight)
