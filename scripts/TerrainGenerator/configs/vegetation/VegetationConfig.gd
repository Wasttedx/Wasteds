extends Resource
class_name VegetationConfig

@export_group("Spawn Settings")
@export var spawn_radius_chunks: int = 2

@export_group("Object Definitions")
@export var items: Array[VegetationItem] = []

# Inner class for easy definition
@export_group("Global Defaults")
@export var max_slope: float = 1.5
