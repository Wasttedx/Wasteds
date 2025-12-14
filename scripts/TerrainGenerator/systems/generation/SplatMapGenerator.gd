class_name SplatMapGenerator

const MAX_HEIGHT = 40.0
const ROCK_SLOPE_START = 0.8
const ROCK_SLOPE_END = 1.5
const ROCK_HEIGHT_START = 0.7
const ROCK_HEIGHT_END = 0.9
const DIRT_CENTER_H = 0.4
const DIRT_RANGE_H = 0.3
const DIRT_SLOPE_END = 0.9

var noise_builder_service: NoiseBuilder
var world_config_data: WorldConfig

func _init(noise_service: NoiseBuilder, w_config: WorldConfig):
	noise_builder_service = noise_service
	world_config_data = w_config

static func generate_splat_image(coords: Vector2i, world_config: WorldConfig, noise_builder: NoiseBuilder, _biome_config: BiomeConfig) -> Image:
	
	var res = world_config.chunk_resolution
	var size = world_config.chunk_world_size
	var step = size / float(res - 1)
	
	var chunk_origin_x = coords.x * size
	var chunk_origin_z = coords.y * size
	
	var img = Image.create(res, res, false, Image.FORMAT_RGBA8)
	
	for z in range(res):
		for x in range(res):
			var lx = x * step
			var lz = z * step
			var wx = chunk_origin_x + lx
			var wz = chunk_origin_z + lz
			
			var height = noise_builder.get_height(wx, wz)
			var normalized_height = clamp(height / MAX_HEIGHT, 0.0, 1.0)
			
			var slope = _calculate_slope_robust(wx, wz, step, noise_builder)
			
			var weights = _calculate_weights(normalized_height, slope)
			
			var splat_color = Color(weights.grass, weights.dirt, weights.rock, weights.corrupt)
			
			img.set_pixel(x, z, splat_color)

	return img


func generate_splat_map(coords: Vector2i, biome_config: BiomeConfig) -> ImageTexture:
	var img = generate_splat_image(coords, world_config_data, noise_builder_service, biome_config)
	
	var tex = ImageTexture.create_from_image(img)
	return tex


static func _calculate_slope_robust(wx: float, wz: float, step: float, noise_builder: NoiseBuilder) -> float:
	
	var h_right = noise_builder.get_height(wx + step, wz)
	var h_left = noise_builder.get_height(wx - step, wz)
	var dx = abs(h_right - h_left)
	var slope_x = dx / (2.0 * step)
	
	var h_forward = noise_builder.get_height(wx, wz + step)
	var h_back = noise_builder.get_height(wx, wz - step)
	var dz = abs(h_forward - h_back)
	var slope_z = dz / (2.0 * step)
	
	return sqrt(slope_x * slope_x + slope_z * slope_z)

class TextureWeights:
	var grass: float = 0.0
	var dirt: float = 0.0
	var rock: float = 0.0
	var corrupt: float = 0.0

static func _calculate_weights(normalized_height: float, slope: float) -> TextureWeights:
	var weights = TextureWeights.new()
	
	var slope_rock_w = clamp( (slope - ROCK_SLOPE_START) / (ROCK_SLOPE_END - ROCK_SLOPE_START), 0.0, 1.0)
	
	var height_diff = ROCK_HEIGHT_END - ROCK_HEIGHT_START
	if height_diff == 0.0: height_diff = 0.001
	var height_rock_w = clamp( (normalized_height - ROCK_HEIGHT_START) / height_diff, 0.0, 1.0)
	
	weights.rock = max(slope_rock_w, height_rock_w)
	
	
	var height_dirt_w = 1.0 - abs(normalized_height - DIRT_CENTER_H) / DIRT_RANGE_H
	height_dirt_w = clamp(height_dirt_w, 0.0, 1.0)
	
	var slope_dirt_w = 1.0 - clamp(slope / DIRT_SLOPE_END, 0.0, 1.0)
	
	weights.dirt = height_dirt_w * slope_dirt_w
	
	weights.dirt = weights.dirt * (1.0 - weights.rock)
	
	
	weights.grass = 1.0 - max(weights.rock, weights.dirt)
	
	
	var total_w = weights.grass + weights.dirt + weights.rock + weights.corrupt
	
	if total_w > 0.0:
		weights.grass /= total_w
		weights.dirt /= total_w
		weights.rock /= total_w
		weights.corrupt /= total_w
	else:
		weights.grass = 1.0
		
	return weights
