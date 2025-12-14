class_name MeshFactory_LowRes

static func build_terrain_mesh(coords: Vector2i, world_cfg: WorldConfig, noise: NoiseBuilder) -> ArrayMesh:
	var mesh_data = build_terrain_mesh_data(coords, world_cfg, noise)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data.arrays)
	return mesh

static func build_terrain_mesh_data(coords: Vector2i, world_cfg: WorldConfig, noise: NoiseBuilder) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var res = max(8, int(world_cfg.chunk_resolution / 4.0))
	var size = world_cfg.chunk_world_size
	
	var step = size / float(res - 1)
	
	var chunk_origin_x = coords.x * size
	var chunk_origin_z = coords.y * size
	
	for z in range(res - 1):
		for x in range(res - 1):
			var vx = x * step
			var vz = z * step
			
			var wx = chunk_origin_x + vx
			var wz = chunk_origin_z + vz
			
			var uv1 = Vector2(float(x) / (res - 1), float(z) / (res - 1))
			var uv2 = Vector2(float(x+1) / (res - 1), float(z) / (res - 1))
			var uv3 = Vector2(float(x) / (res - 1), float(z+1) / (res - 1))
			var uv4 = Vector2(float(x+1) / (res - 1), float(z+1) / (res - 1))

			var p1 = Vector3(vx, noise.get_height(wx, wz), vz)
			var p2 = Vector3(vx + step, noise.get_height(wx + step, wz), vz)
			var p3 = Vector3(vx, noise.get_height(wx, wz + step), vz + step)
			var p4 = Vector3(vx + step, noise.get_height(wx + step, wz + step), vz + step)

			st.set_uv(uv1); st.add_vertex(p1)
			st.set_uv(uv2); st.add_vertex(p2)
			st.set_uv(uv3); st.add_vertex(p3)

			st.set_uv(uv2); st.add_vertex(p2)
			st.set_uv(uv4); st.add_vertex(p4)
			st.set_uv(uv3); st.add_vertex(p3)

	st.generate_normals()
	
	var mesh_arrays = st.commit_to_arrays()
	
	return {"arrays": mesh_arrays}
