extends Resource
class_name TerrainTexture

# --- Texture Maps ---
@export_group("Texture Maps")
@export var diffuse: Texture2D # Albedo/Color
@export var normal: Texture2D # Normal Map
@export var roughness: Texture2D # Roughness Map (Grey-scale)
@export var displacement: Texture2D # Displacement/Height Map (Grey-scale)

# --- Texture Tiling/Scaling ---
@export_group("Tiling")
@export var tiling_scale: float = 0.1 # Tiling factor for the texture UVs (smaller = more tiling)
