extends Node3D
class_name TerrainChunk

func setup(coords: Vector2i, 
		   w_conf: WorldConfig, 
		   noise: NoiseBuilder, 
		   mat_lib: MaterialLibrary, 
		   veg: VegetationSpawner):
	
	name = "chunk_%d_%d" % [coords.x, coords.y]
	position = Vector3(coords.x * w_conf.chunk_world_size, 0, coords.y * w_conf.chunk_world_size)
	
	# 1. Build Mesh
	var mesh = MeshFactory.build_terrain_mesh(coords, w_conf, noise)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.material_override = mat_lib.terrain_material
	add_child(mi)
	
	# 2. Build Collision
	var col = CollisionBuilder.create_collision(mesh)
	add_child(col)
	
	# 3. Spawn Vegetation
	veg.spawn_all(self, coords, mat_lib.vegetation_material)
