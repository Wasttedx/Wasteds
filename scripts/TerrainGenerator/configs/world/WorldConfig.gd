extends Resource
class_name WorldConfig

@export_group("Grid Settings")
@export var chunk_resolution: int = 64
@export var chunk_world_size: float = 32.0
@export var view_distance_chunks: int = 2
@export var max_chunks_per_frame: int = 1

@export var sea_level: float = 0.0
@export var min_height: float = -200.0
@export var max_height: float = 300.0
