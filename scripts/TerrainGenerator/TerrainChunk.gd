extends Node3D
class_name TerrainChunk

func setup(coords: Vector2i,
	w_conf: WorldConfig,
	noise: NoiseBuilder,
	mat_lib: MaterialLibrary,
	veg: VegetationSpawner,
	biome_selector: BiomeSelector,
	splat_gen: SplatMapGenerator): # <<< RECEIVE NEW SERVICE
	
	name = "chunk_%d_%d" % [coords.x, coords.y]
	position = Vector3(coords.x * w_conf.chunk_world_size, 0, coords.y * w_conf.chunk_world_size)
	
	# 1. Determine Biome (Use center of chunk for simplicity)
	var center_x = coords.x * w_conf.chunk_world_size + w_conf.chunk_world_size / 2.0
	var center_z = coords.y * w_conf.chunk_world_size + w_conf.chunk_world_size / 2.0
	var biome_config = biome_selector.get_biome_for_coords(center_x, center_z)
	
	# 2. Apply Biome Overrides to services
	# --- NOISE OVERRIDES ---
	noise.push_config_override(biome_config)
	
	# --- NEW: Generate Splat Map ---
	# Uses the noise service (which may have been overridden by the biome)
	var chunk_splat_map = splat_gen.generate_splat_map(coords, biome_config)
	# -------------------------------
	
	# --- MATERIAL OVERRIDES ---
	# Pass the GENERATED splat map to the material library along with the biome config
	var chunk_material = mat_lib.get_terrain_material(biome_config, chunk_splat_map)
	
	# 3. Generate Mesh
	var chunk_mesh: ArrayMesh = MeshFactory.build_terrain_mesh(coords, w_conf, noise)
	
	# --- POP NOISE OVERRIDES ---
	noise.pop_config_override() # <<< RESTORE NOISE CONFIG AFTER GENERATION
	
	# 4. Create Visual Mesh Instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = chunk_mesh
	
	# --- FIX START ---
	# Change 'surface_set_material' to 'set_surface_override_material'
	mesh_instance.set_surface_override_material(0, chunk_material) # <<< CORRECT GODOT 4 FUNCTION
	# --- FIX END ---
	
	add_child(mesh_instance)
	
	# 5. Create Collision (Uses the same mesh)
	var chunk_collision = CollisionBuilder.create_collision(chunk_mesh)
	add_child(chunk_collision)
	
	# 6. Spawn Vegetation (Requires the chunk to be a child of the TerrainGenerator for global coordinates to be correct)
	veg.spawn_all(self, coords, mat_lib.vegetation_material, biome_config)
