class_name MeshFactory

# Static helper to generate a terrain plane mesh
static func build_terrain_mesh(coords: Vector2i, world_cfg: WorldConfig, noise: NoiseBuilder) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var res = world_cfg.chunk_resolution
	var size = world_cfg.chunk_world_size
	var step = size / float(res - 1)
	
	var chunk_origin_x = coords.x * size
	var chunk_origin_z = coords.y * size
	
	# --- 1. OPTIMIZATION: PRE-CALCULATE ALL HEIGHTS (res x res) ---
	# This ensures we call the expensive noise.get_height() function only once per vertex, not for every vertex, normal, and slope check.
	var height_map: Array = []
	for z in range(res):
		var row: Array = []
		for x in range(res):
			var wx = chunk_origin_x + x * step
			var wz = chunk_origin_z + z * step
			row.append(noise.get_height(wx, wz))
		height_map.append(row)
	# ---------------------------------------------------------------
	
	# --- 2. BUILD MESH ---
	for z in range(res - 1):
		for x in range(res - 1):
			var vx = x * step
			var vz = z * step
			
			# Calculate World Coordinates for Normal Check
			var wx1 = chunk_origin_x + vx
			var wz1 = chunk_origin_z + vz
			var wx2 = chunk_origin_x + vx + step
			var wz2 = chunk_origin_z + vz + step

			# UVs (Indices z, x)
			var uv1 = Vector2(float(x) / (res - 1), float(z) / (res - 1))
			var uv2 = Vector2(float(x+1) / (res - 1), float(z) / (res - 1))
			var uv3 = Vector2(float(x) / (res - 1), float(z+1) / (res - 1))
			var uv4 = Vector2(float(x+1) / (res - 1), float(z+1) / (res - 1))

			# Vertices (Get from pre-calculated height map)
			var p1 = Vector3(vx, height_map[z][x], vz)
			var p2 = Vector3(vx + step, height_map[z][x+1], vz)
			var p3 = Vector3(vx, height_map[z+1][x], vz + step)
			var p4 = Vector3(vx + step, height_map[z+1][x+1], vz + step)

			# --- Normals: Calculated by sampling continuous noise (fixes seams/lines) ---
			# We must sample the continuous noise function at the world coordinates 
			# to ensure the normal matches exactly in the adjacent chunk.
			var n1 = _calculate_normal(wx1, wz1, step, noise)
			var n2 = _calculate_normal(wx2, wz1, step, noise)
			var n3 = _calculate_normal(wx1, wz2, step, noise)
			var n4 = _calculate_normal(wx2, wz2, step, noise)

			# Triangle 1
			st.set_uv(uv1); st.set_normal(n1); st.add_vertex(p1) # << Godot 4 API
			st.set_uv(uv2); st.set_normal(n2); st.add_vertex(p2) # << Godot 4 API
			st.set_uv(uv3); st.set_normal(n3); st.add_vertex(p3) # << Godot 4 API

			# Triangle 2
			st.set_uv(uv2); st.set_normal(n2); st.add_vertex(p2) # << Godot 4 API
			st.set_uv(uv4); st.set_normal(n4); st.add_vertex(p4) # << Godot 4 API
			st.set_uv(uv3); st.set_normal(n3); st.add_vertex(p3) # << Godot 4 API

	# st.generate_normals() is REMOVED because we calculate them manually
	st.generate_tangents()
	return st.commit()


# NEW: Calculates a smooth normal vector by sampling the continuous noise function.
# This is called only (res-1) * (res-1) * 4 times total for normals, 
# which is far fewer than before, ensuring seam-free lighting.
static func _calculate_normal(wx: float, wz: float, step: float, noise: NoiseBuilder) -> Vector3:
	
	# Dx: Change in height along X-axis
	var h_right = noise.get_height(wx + step, wz)
	var h_left = noise.get_height(wx - step, wz)
	var dx = h_left - h_right
	
	# Dz: Change in height along Z-axis
	var h_forward = noise.get_height(wx, wz + step)
	var h_back = noise.get_height(wx, wz - step)
	var dz = h_back - h_forward
	
	# Normal Vector from heightmap derivative: Vector3(dx, 2*step, dz)
	var normal = Vector3(dx, 2.0 * step, dz).normalized()
	
	return normal
