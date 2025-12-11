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
	
	for z in range(res - 1):
		for x in range(res - 1):
			var vx = x * step
			var vz = z * step

			# UVs
			var uv1 = Vector2(float(x) / (res - 1), float(z) / (res - 1))
			var uv2 = Vector2(float(x+1) / (res - 1), float(z) / (res - 1))
			var uv3 = Vector2(float(x) / (res - 1), float(z+1) / (res - 1))
			var uv4 = Vector2(float(x+1) / (res - 1), float(z+1) / (res - 1))

			# Vertices
			var p1 = _get_v(chunk_origin_x, chunk_origin_z, vx, vz, noise)
			var p2 = _get_v(chunk_origin_x, chunk_origin_z, vx + step, vz, noise)
			var p3 = _get_v(chunk_origin_x, chunk_origin_z, vx, vz + step, noise)
			var p4 = _get_v(chunk_origin_x, chunk_origin_z, vx + step, vz + step, noise)

			# Triangles
			st.set_uv(uv1); st.add_vertex(p1)
			st.set_uv(uv2); st.add_vertex(p2)
			st.set_uv(uv3); st.add_vertex(p3)

			st.set_uv(uv2); st.add_vertex(p2)
			st.set_uv(uv4); st.add_vertex(p4)
			st.set_uv(uv3); st.add_vertex(p3)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _get_v(ox: float, oz: float, lx: float, lz: float, noise: NoiseBuilder) -> Vector3:
	var h = noise.get_height(ox + lx, oz + lz)
	return Vector3(lx, h, lz)
