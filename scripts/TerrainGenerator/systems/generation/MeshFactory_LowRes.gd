class_name MeshFactory_LowRes

# Static helper to generate a low-detail terrain mesh for distant chunks
# NOTE: This method is NOT thread-safe due to ArrayMesh/SurfaceTool usage.
# Use build_terrain_mesh_data for multithreading.
static func build_terrain_mesh(coords: Vector2i, world_cfg: WorldConfig, noise: NoiseBuilder) -> ArrayMesh:
	var mesh_data = build_terrain_mesh_data(coords, world_cfg, noise)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data.arrays)
	return mesh

# Static helper to generate mesh arrays for thread-safe transfer.
# Returns a Dictionary with the ArrayMesh data arrays.
static func build_terrain_mesh_data(coords: Vector2i, world_cfg: WorldConfig, noise: NoiseBuilder) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# LOD Reduction: Divide resolution by 4 (e.g. 64 -> 16)
	# We clamp to a minimum of 8 to prevent broken meshes
	var res = max(8, int(world_cfg.chunk_resolution / 4.0))
	var size = world_cfg.chunk_world_size
	
	# Recalculate step size for lower resolution to cover the same physical area
	var step = size / float(res - 1)
	
	var chunk_origin_x = coords.x * size
	var chunk_origin_z = coords.y * size
	
	# --- Generate Mesh Directly (No pre-calc heightmap needed for speed) ---
	for z in range(res - 1):
		for x in range(res - 1):
			var vx = x * step
			var vz = z * step
			
			# World coordinates for height sampling
			var wx = chunk_origin_x + vx
			var wz = chunk_origin_z + vz
			
			# UVs
			var uv1 = Vector2(float(x) / (res - 1), float(z) / (res - 1))
			var uv2 = Vector2(float(x+1) / (res - 1), float(z) / (res - 1))
			var uv3 = Vector2(float(x) / (res - 1), float(z+1) / (res - 1))
			var uv4 = Vector2(float(x+1) / (res - 1), float(z+1) / (res - 1))

			# Vertices
			var p1 = Vector3(vx, noise.get_height(wx, wz), vz)
			var p2 = Vector3(vx + step, noise.get_height(wx + step, wz), vz)
			var p3 = Vector3(vx, noise.get_height(wx, wz + step), vz + step)
			var p4 = Vector3(vx + step, noise.get_height(wx + step, wz + step), vz + step)

			# Triangle 1
			st.set_uv(uv1); st.add_vertex(p1)
			st.set_uv(uv2); st.add_vertex(p2)
			st.set_uv(uv3); st.add_vertex(p3)

			# Triangle 2
			st.set_uv(uv2); st.add_vertex(p2)
			st.set_uv(uv4); st.add_vertex(p4)
			st.set_uv(uv3); st.add_vertex(p3)

	# Use automatic normal generation for performance (less accurate but faster)
	st.generate_normals()
	# Note: We skip tangents for distant chunks to save memory/time
	
	var mesh_arrays = st.commit_to_arrays()
	
	return {"arrays": mesh_arrays}
