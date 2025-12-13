extends Node3D
class_name TerrainChunk

func setup(coords: Vector2i, 
		   w_conf: WorldConfig, 
		   noise: NoiseBuilder, 
		   mat_lib: MaterialLibrary, 
		   veg: VegetationSpawner,
		   biome_selector: BiomeSelector): # <<< ADDED BiomeSelector
	
	name = "chunk_%d_%d" % [coords.x, coords.y]
	position = Vector3(coords.x * w_conf.chunk_world_size, 0, coords.y * w_conf.chunk_world_size)
	
	# 1. Determine Biome (Use center of chunk for simplicity)
	var center_x = coords.x * w_conf.chunk_world_size + w_conf.chunk_world_size / 2.0
	var center_z = coords.y * w_conf.chunk_world_size + w_conf.chunk_world_size / 2.0
	var biome_config = biome_selector.get_biome_for_coords(center_x, center_z)
	
	# 2. Apply Biome Overrides to services
	
	# --- NOISE OVERRIDES ---
	noise.push_config_override(biome_config)
	
	# --- MATERIAL OVERRIDES ---
	# Get the material *before* mesh creation, as it will be used for noise sampling
	var chunk_material = mat_lib.get_terrain_material(biome_config)
	
	# 3. Build Mesh (Uses the overriden noise settings)
	var mesh = MeshFactory.build_terrain_mesh(coords, w_conf, noise)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.material_override = chunk_material # Use Biome-specific material
	add_child(mi)
	
	# 4. Restore original noise config for other chunks
	noise.pop_config_override()
	
	# 5. Build Collision
	var col = CollisionBuilder.create_collision(mesh)
	add_child(col)
	
	# 6. Spawn Vegetation (Passing biome for specific rules)
	veg.spawn_all(self, coords, mat_lib.vegetation_material, biome_config) # <<< ADDED BiomeConfig
