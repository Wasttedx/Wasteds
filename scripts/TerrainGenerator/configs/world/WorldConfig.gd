extends Resource
class_name WorldConfig

@export_group("Grid Settings")
@export var chunk_resolution: int = 64
@export var chunk_world_size: float = 32.0
@export var view_distance_chunks: int = 2
@export var max_chunks_per_frame: int = 1

@export_group("Optimization")
@export var grass_render_distance: float = 20.0
