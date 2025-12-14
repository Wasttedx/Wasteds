class_name CollisionBuilder

static func create_collision(mesh: ArrayMesh) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = "ChunkCollision"
	
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape"
	
	var vertex_array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(vertex_array)
	
	cs.shape = shape
	sb.add_child(cs)
	return sb

static func create_collision_data(mesh_data: Dictionary) -> Array:
	var collision_data: Array = []
	
	var vertex_array = mesh_data.arrays[Mesh.ARRAY_VERTEX]
	
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(vertex_array)
	
	collision_data.append({
		"shape": shape,
		"transform": Transform3D.IDENTITY
	})
	
	return collision_data
