extends Resource
class_name BiomeConfig

@export_group("Identification")
@export var biome_name: String = "Default Biome"
@export var biome_id: int = 0

@export_group("Selection")
@export var spawn_probability: float = 1.0

@export_group("Noise Overrides")
@export var noise_frequency_override: float = 0.0
@export var noise_height_multiplier_override: float = 0.0
@export var wetness: float = 0.5

@export_group("Material Overrides")
@export var texture_overrides: Dictionary = {}
@export var color_tint: Color = Color.WHITE

@export_group("Vegetation Rules")
@export var vegetation_overrides: Dictionary = {}

@export_group("Anomalies")
@export var anomaly_data: Resource
