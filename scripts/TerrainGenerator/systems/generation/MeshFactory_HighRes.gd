class_name MeshFactory_HighRes

static func build_terrain_mesh(coords: Vector2i, world_cfg: WorldConfig, noise: NoiseBuilder) -> ArrayMesh:
	var mesh_data = build_terrain_mesh_data(coords, world_cfg, noise)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data.arrays)
	return mesh

static func build_terrain_mesh_data(coords: Vector2i, world_cfg: WorldConfig, noise: NoiseBuilder) -> Dictionary:
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var res = world_cfg.chunk_resolution
	var size = world_cfg.chunk_world_size
	var step = size / float(res - 1)
	
	var chunk_origin_x = coords.x * size
	var chunk_origin_z = coords.y * size
	
	var height_map: Array = []
	for z in range(res):
		var row: Array = []
		for x in range(res):
			var wx = chunk_origin_x + x * step
			var wz = chunk_origin_z + z * step
			row.append(noise.get_height(wx, wz))
		height_map.append(row)
	
	for z in range(res - 1):
		for x in range(res - 1):
			var vx = x * step
			var vz = z * step
			
			var wx1 = chunk_origin_x + vx
			var wz1 = chunk_origin_z + vz
			var wx2 = chunk_origin_x + vx + step
			var wz2 = chunk_origin_z + vz + step

			var uv1 = Vector2(float(x) / (res - 1), float(z) / (res - 1))
			var uv2 = Vector2(float(x+1) / (res - 1), float(z) / (res - 1))
			var uv3 = Vector2(float(x) / (res - 1), float(z+1) / (res - 1))
			var uv4 = Vector2(float(x+1) / (res - 1), float(z+1) / (res - 1))

			var p1 = Vector3(vx, height_map[z][x], vz)
			var p2 = Vector3(vx + step, height_map[z][x+1], vz)
			var p3 = Vector3(vx, height_map[z+1][x], vz + step)
			var p4 = Vector3(vx + step, height_map[z+1][x+1], vz + step)

			var n1 = _calculate_normal(wx1, wz1, step, noise)
			var n2 = _calculate_normal(wx2, wz1, step, noise)
			var n3 = _calculate_normal(wx1, wz2, step, noise)
			var n4 = _calculate_normal(wx2, wz2, step, noise)

			st.set_uv(uv1); st.set_normal(n1); st.add_vertex(p1)
			st.set_uv(uv2); st.set_normal(n2); st.add_vertex(p2)
			st.set_uv(uv3); st.set_normal(n3); st.add_vertex(p3)

			st.set_uv(uv2); st.set_normal(n2); st.add_vertex(p2)
			st.set_uv(uv4); st.set_normal(n4); st.add_vertex(p4)
			st.set_uv(uv3); st.set_normal(n3); st.add_vertex(p3)

	st.generate_tangents()
	var mesh_arrays = st.commit_to_arrays()
	
	return {"arrays": mesh_arrays}

static func _calculate_normal(wx: float, wz: float, step: float, noise: NoiseBuilder) -> Vector3:
	var h_right = noise.get_height(wx + step, wz)
	var h_left = noise.get_height(wx - step, wz)
	var dx = h_left - h_right
	
	var h_forward = noise.get_height(wx, wz + step)
	var h_back = noise.get_height(wx, wz - step)
	var dz = h_back - h_forward
	
	return Vector3(dx, 2.0 * step, dz).normalized()
