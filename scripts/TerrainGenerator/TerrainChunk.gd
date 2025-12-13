extends Node3D
class_name TerrainChunk

# --- State ---
var chunk_coords: Vector2i
var current_lod: int = -1 # -1 implies not initialized
var is_ready: bool = false

# --- Dependencies ---
var world_config: WorldConfig
var noise: NoiseBuilder
var material_lib: MaterialLibrary
var veg_spawner: VegetationSpawner
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator

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

# Sets the Level of Detail. 0 = High, >0 = Low
func set_lod(level: int):
	if not is_ready: return
	if current_lod == level: return # No change needed
	
	current_lod = level
	
	# 1. Clean up existing geometry/physics to prevent overlap or memory leaks
	if mesh_instance.mesh:
		mesh_instance.mesh = null
	_clear_physics()
	_clear_vegetation()
	
	# 2. Identify Biome
	# We use the center of the chunk to determine the dominant biome for the shader
	var center_x = (chunk_coords.x * world_config.chunk_world_size) + (world_config.chunk_world_size * 0.5)
	var center_z = (chunk_coords.y * world_config.chunk_world_size) + (world_config.chunk_world_size * 0.5)
	var biome = biome_selector.get_biome_for_coords(center_x, center_z)
	
	# 3. Push Biome Overrides (for noise generation)
	noise.push_config_override(biome)
	
	# 4. Generate Mesh based on LOD
	if current_lod == 0:
		_build_high_res(biome)
	else:
		_build_low_res(biome)
		
	# 5. Pop Biome Overrides
	noise.pop_config_override()

func _build_high_res(biome: BiomeConfig):
	# A. Geometry
	var mesh = MeshFactory_HighRes.build_terrain_mesh(chunk_coords, world_config, noise)
	mesh_instance.mesh = mesh
	
	# B. Splat Map & Material
	var splat_tex = splat_map_generator.generate_splat_map(chunk_coords, biome)
	var mat = material_lib.get_terrain_material(biome, splat_tex)
	mesh_instance.material_override = mat
	
	# C. Physics (Collision) - Only for High Res
	collision_body = CollisionBuilder.create_collision(mesh)
	add_child(collision_body)
	
	# D. Vegetation - Only for High Res
	vegetation_root = Node3D.new()
	add_child(vegetation_root)
	veg_spawner.spawn_all(vegetation_root, chunk_coords, material_lib.vegetation_material, biome)

func _build_low_res(biome: BiomeConfig):
	# A. Geometry (Fast, Low Poly)
	var mesh = MeshFactory_LowRes.build_terrain_mesh(chunk_coords, world_config, noise)
	mesh_instance.mesh = mesh
	
	# B. Splat Map & Material
	# For optimization, LowRes could use a cached or lower-res splat map, 
	# but for now, we generate it to ensure colors match.
	var splat_tex = splat_map_generator.generate_splat_map(chunk_coords, biome)
	var mat = material_lib.get_terrain_material(biome, splat_tex)
	mesh_instance.material_override = mat
	
	# Note: No Physics or Vegetation on Low Res chunks to save performance

func _clear_physics():
	if collision_body:
		collision_body.queue_free()
		collision_body = null

func _clear_vegetation():
	if vegetation_root:
		vegetation_root.queue_free()
		vegetation_root = null
