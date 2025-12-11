extends Resource
class_name WorldConfig

@export_group("Grid Settings")
@export var chunk_resolution: int = 64          # vertices per side
@export var chunk_world_size: float = 32.0      # meters per chunk
@export var view_distance_chunks: int = 2       # chunks radius
@export var max_chunks_per_frame: int = 1
