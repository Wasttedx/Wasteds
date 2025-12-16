extends Resource
class_name VegetationConfig

@export_group("Placement Rules")
@export var max_slope: float = 1.5

@export_group("Counts")
@export var grass_count: int = 1200
@export var tree_count: int = 12
@export var rock_count: int = 30

@export_group("Scaling")
@export var grass_scale: Vector2 = Vector2(1.0, 0.4)
@export var tree_scale: Vector2 = Vector2(1.0, 0.4)
@export var rock_scale: Vector2 = Vector2(1.0, 0.4)

@export_group("Meshes")
# IMPORTANT: Preload the meshes from your Models/vegetation directory
# Assuming these are actual Mesh resources (like ArrayMesh or PrimitiveMesh)
@export var grass_mesh: Mesh = preload("res://Models/vegetation/grass.res")
@export var tree_mesh: Mesh = preload("res://Models/vegetation/tree.res")
@export var rock_mesh: Mesh = preload("res://Models/vegetation/rock.res")
