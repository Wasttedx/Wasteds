extends Resource
class_name BiomeConfig

# --- Biome Identification ---
@export_group("Identification")
@export var biome_name: String = "Default Biome"
@export var biome_id: int = 0 # Unique ID for lookups

# --- Biome Selection / Spawn Probability ---
@export_group("Selection")
@export var spawn_probability: float = 1.0 # Relative probability for BiomeSelector

# --- Noise Overrides ---
@export_group("Noise Overrides")
@export var noise_frequency_override: float = 0.0 # 0.0 means use WorldConfig value
@export var noise_height_multiplier_override: float = 0.0 # 0.0 means use WorldConfig value
@export var wetness: float = 0.5 # Affects both noise and material blend

# --- Material / Texture Sets ---
# This is a dictionary of texture resources (e.g., textures["tex_grass"] = new_grass_tex)
@export_group("Material Overrides")
@export var texture_overrides: Dictionary = {}
@export var color_tint: Color = Color.WHITE # Overall tint applied to the material

# --- Vegetation Rules ---
@export_group("Vegetation Rules")
# Keyed by item type (e.g. "grass_count", "tree_mesh")
@export var vegetation_overrides: Dictionary = {}

# --- Anomalies (Future Use) ---
# A resource or dictionary for special features (e.g. structures, special enemies)
@export_group("Anomalies")
@export var anomaly_data: Resource
