extends Resource
class_name TerrainTexture

@export_group("Texture Maps")
@export var diffuse: Texture2D
@export var normal: Texture2D
@export var roughness: Texture2D
@export var displacement: Texture2D

@export_group("Tiling")
@export var tiling_scale: float = 0.1
