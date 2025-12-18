extends Resource
class_name VegetationItem

@export var name: String = "New Item"
@export var mesh: Mesh
@export var density: int = 100 

@export_group("Transform")
@export var scale_range: Vector2 = Vector2(1.0, 1.5)
@export var random_rotation: bool = true
@export var y_offset: float = 0.0

@export_group("Placement Rules")
# Updated ranges to allow negative values (e.g., underwater or caves)
@export_range(-2000, 2000) var min_height: float = -100.0
@export_range(-2000, 2000) var max_height: float = 500.0
@export var max_slope: float = 0.5 # 0.0 is flat, 1.0 is 45 degrees
@export_range(0, 1) var splat_weight_threshold: float = 0.5
@export_enum("Grass(R)", "Dirt(G)", "Rock(B)") var splat_channel: int = 0
