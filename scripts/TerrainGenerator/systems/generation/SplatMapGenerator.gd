class_name SplatMapGenerator

# --- Exported Parameters for Fine-Tuning ---
# These constants are now defined in one place for easy adjustment.
const MAX_HEIGHT = 40.0         # Global height normalization constant.
const ROCK_SLOPE_START = 0.8    # Slope where rock starts to appear.
const ROCK_SLOPE_END = 1.5      # Slope where rock is fully dominant.
const ROCK_HEIGHT_START = 0.7   # Normalized height where rock starts to appear (e.g., snowy peaks).
const ROCK_HEIGHT_END = 0.9     # Normalized height where rock is fully dominant.
const DIRT_CENTER_H = 0.4       # Normalized height for peak dirt coverage.
const DIRT_RANGE_H = 0.3        # Range around DIRT_CENTER_H for strong dirt coverage.
const DIRT_SLOPE_END = 0.9      # Slope where dirt fades out.

# RESOLVED: 'noise_builder' shadowing issue from previous iteration.
var noise_builder_service: NoiseBuilder
# RESOLVED: Renamed to 'world_config_data' to prevent shadowing of the parameter.
var world_config_data: WorldConfig # Changed line 16

# Constructor requires the services needed to sample data
func _init(noise_service: NoiseBuilder, w_config: WorldConfig):
	noise_builder_service = noise_service
	# Updated assignment:
	world_config_data = w_config

# ==============================================================================
# THREAD-SAFE GENERATION METHOD (Called by ChunkBuilderThread)
# This method generates and returns a raw Image object.
# ==============================================================================
# RESOLVED: 'world_config' parameter is fine because the class member was renamed.
# RESOLVED: 'biome_config' is prefixed with underscore to silence UNUSED_PARAMETER warning.
static func generate_splat_image(coords: Vector2i, world_config: WorldConfig, noise_builder: NoiseBuilder, _biome_config: BiomeConfig) -> Image:
	
	var res = world_config.chunk_resolution
	var size = world_config.chunk_world_size
	var step = size / float(res - 1)
	
	var chunk_origin_x = coords.x * size
	var chunk_origin_z = coords.y * size
	
	# 1. Initialize Image
	var img = Image.create(res, res, false, Image.FORMAT_RGBA8)
	
	# 2. Loop through every "pixel" (which corresponds to a vertex)
	for z in range(res):
		for x in range(res):
			var lx = x * step
			var lz = z * step
			var wx = chunk_origin_x + lx
			var wz = chunk_origin_z + lz
			
			# Calculate necessary parameters
			var height = noise_builder.get_height(wx, wz)
			var normalized_height = clamp(height / MAX_HEIGHT, 0.0, 1.0)
			
			# Calculate slope using the robust Central Difference Method
			var slope = _calculate_slope_robust(wx, wz, step, noise_builder)
			
			# 3. Determine Texture Weights using a dedicated function
			var weights = _calculate_weights(normalized_height, slope)
			
			# 4. Assign Color (R=Grass, G=Dirt, B=Rock, A=Corrupt/Water)
			var splat_color = Color(weights.grass, weights.dirt, weights.rock, weights.corrupt)
			
			img.set_pixel(x, z, splat_color)

	return img


# ==============================================================================
# MAIN-THREAD METHOD (Kept for compatibility)
# This method is NOT thread-safe due to ImageTexture creation.
# ==============================================================================
# Generates and returns a new ImageTexture (Splat Map) for a single chunk
func generate_splat_map(coords: Vector2i, biome_config: BiomeConfig) -> ImageTexture:
	# Use the thread-safe static function to generate the raw data
	# Updated with renamed class member variable:
	var img = generate_splat_image(coords, world_config_data, noise_builder_service, biome_config)
	
	# 5. Create Texture and Return (MUST run on main thread)
	var tex = ImageTexture.create_from_image(img)
	return tex


# --- Private Helper Functions for Readability and Reusability ---

# Calculates the slope using a central difference method for accuracy across chunk boundaries.
static func _calculate_slope_robust(wx: float, wz: float, step: float, noise_builder: NoiseBuilder) -> float:
	
	# Dx: Change in height along X-axis (sampling 2*step apart)
	var h_right = noise_builder.get_height(wx + step, wz)
	var h_left = noise_builder.get_height(wx - step, wz)
	var dx = abs(h_right - h_left)
	var slope_x = dx / (2.0 * step)
	
	# Dz: Change in height along Z-axis (sampling 2*step apart)
	var h_forward = noise_builder.get_height(wx, wz + step)
	var h_back = noise_builder.get_height(wx, wz - step)
	var dz = abs(h_forward - h_back)
	var slope_z = dz / (2.0 * step)
	
	# Slope is the magnitude of the 2D gradient
	return sqrt(slope_x * slope_x + slope_z * slope_z)

# Struct-like dictionary to return clear weight values
class TextureWeights:
	var grass: float = 0.0
	var dirt: float = 0.0
	var rock: float = 0.0
	var corrupt: float = 0.0

# Calculates the texture weights based on height and slope using smooth blending functions.
static func _calculate_weights(normalized_height: float, slope: float) -> TextureWeights:
	var weights = TextureWeights.new()
	
	# --- ROCK WEIGHT (B) ---
	# Contribution from steepness (smoothstep-like function)
	var slope_rock_w = clamp( (slope - ROCK_SLOPE_START) / (ROCK_SLOPE_END - ROCK_SLOPE_START), 0.0, 1.0)
	
	# Contribution from high altitude (smoothstep-like function)
	var height_diff = ROCK_HEIGHT_END - ROCK_HEIGHT_START
	if height_diff == 0.0: height_diff = 0.001 # Prevent division by zero
	var height_rock_w = clamp( (normalized_height - ROCK_HEIGHT_START) / height_diff, 0.0, 1.0)
	
	weights.rock = max(slope_rock_w, height_rock_w)
	
	
	# --- DIRT WEIGHT (G) ---
	# Height contribution (peaks around DIRT_CENTER_H) - using a triangular falloff
	var height_dirt_w = 1.0 - abs(normalized_height - DIRT_CENTER_H) / DIRT_RANGE_H
	height_dirt_w = clamp(height_dirt_w, 0.0, 1.0)
	
	# Slope contribution (fades out as slope increases)
	var slope_dirt_w = 1.0 - clamp(slope / DIRT_SLOPE_END, 0.0, 1.0)
	
	weights.dirt = height_dirt_w * slope_dirt_w
	
	# Remove rock's influence from dirt to prevent double-counting
	weights.dirt = weights.dirt * (1.0 - weights.rock)
	
	
	# --- GRASS WEIGHT (R) ---
	# Grass fills the remaining space (low slope/altitude)
	weights.grass = 1.0 - max(weights.rock, weights.dirt)
	
	
	# --- NORMALIZATION ---
	# Ensure all weights sum to 1.0 (for 100% texture coverage)
	var total_w = weights.grass + weights.dirt + weights.rock + weights.corrupt
	
	if total_w > 0.0:
		weights.grass /= total_w
		weights.dirt /= total_w
		weights.rock /= total_w
		weights.corrupt /= total_w
	else:
		# Fallback to pure grass if normalization fails
		weights.grass = 1.0
		
	return weights
