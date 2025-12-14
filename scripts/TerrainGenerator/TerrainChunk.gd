extends Node3D
class_name TerrainChunk

# --- State ---
var chunk_coords: Vector2i
var current_lod: int = -1 # -1 implies not initialized
var is_ready: bool = false
var is_built: bool = false # New state: true once build_data is applied

# --- Dependencies ---
var world_config: WorldConfig
var noise: NoiseBuilder
var material_lib: MaterialLibrary
var veg_spawner: VegetationSpawner
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator

# --- Prebuilt Data (Set by Thread) ---
var build_data: Dictionary = {}

# --- Scene Components ---
var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D
var vegetation_root: Node3D

func setup(coords: Vector2i, wc: WorldConfig, nb: NoiseBuilder, ml: MaterialLibrary, vs: VegetationSpawner, bs: BiomeSelector, smg: SplatMapGenerator):
	chunk_coords = coords
	world_config = wc
	noise = nb
	material_lib = ml
	veg_spawner = vs
	biome_selector = bs
	splat_map_generator = smg
	
	# Position the chunk in the world
	position = Vector3(coords.x * world_config.chunk_world_size, 0, coords.y * world_config.chunk_world_size)
	
	# Name for debugging
	name = "Chunk_%d_%d" % [coords.x, coords.y]
	
	# Create MeshInstance container
	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	
	is_ready = true

func apply_prebuilt_data(data: Dictionary):
	# Called on the main thread when ChunkBuilderThread.gd finishes its job
	if is_built:
		# Should not happen, but a safeguard
		return
		
	build_data = data
	is_built = true
	# LOD will be set by TerrainGenerator._update_lods() on the next frame

# Sets the Level of Detail. 0 = High, >0 = Low
func set_lod(level: int):
	if not is_ready or not is_built: return # Wait for prebuilt data
	if current_lod == level: return # No change needed
	
	current_lod = level
	
	# 1. Clean up existing geometry/physics
	if mesh_instance.mesh:
		mesh_instance.mesh = null
	_clear_physics()
	_clear_vegetation()
	
	# 2. Get Biome config from prebuilt data
	var biome: BiomeConfig = build_data.biome_config
	
	# 3. Create Splat Map Texture (From Image created on the thread)
	var splat_image: Image = build_data.splat_map_image
	var splat_tex = ImageTexture.create_from_image(splat_image)
	
	# 4. Get Material
	var mat = material_lib.get_terrain_material(biome, splat_tex)
	
	# 5. Apply Mesh, Physics, Vegetation based on LOD
	if current_lod == 0:
		_apply_high_res(mat)
	else:
		_apply_low_res(mat)

func _apply_high_res(material: Material):
	# A. Geometry
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_data.high_res_mesh_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	
	# B. Physics (Collision)
	collision_body = StaticBody3D.new()
	add_child(collision_body)
	
	var collision_shapes: Array = build_data.collision_shapes
	for shape_data in collision_shapes:
		var shape_node = CollisionShape3D.new()
		shape_node.shape = shape_data.shape
		shape_node.transform = shape_data.transform
		collision_body.add_child(shape_node)

	# C. Vegetation
	vegetation_root = Node3D.new()
	add_child(vegetation_root)
	veg_spawner.apply_transforms(vegetation_root, build_data.vegetation_transforms, material_lib.vegetation_material)

func _apply_low_res(material: Material):
	# A. Geometry (Fast, Low Poly)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_data.low_res_mesh_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	
	# Note: No Physics or Vegetation on Low Res chunks to save performance

func _clear_physics():
	if collision_body:
		collision_body.queue_free()
		collision_body = null

func _clear_vegetation():
	if vegetation_root:
		vegetation_root.queue_free()
		vegetation_root = null
