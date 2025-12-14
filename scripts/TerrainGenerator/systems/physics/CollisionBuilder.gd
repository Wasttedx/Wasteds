class_name CollisionBuilder

# NOTE: This method is NOT thread-safe due to StaticBody3D/CollisionShape3D usage.
# Use create_collision_data for multithreading.
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

# Creates thread-safe data required to build the collision shape on the main thread.
# 'mesh_data' is the dictionary returned by MeshFactory.build_terrain_mesh_data.
# Returns an Array of dictionaries: [{"shape": ConcavePolygonShape3D, "transform": Transform3D}]
static func create_collision_data(mesh_data: Dictionary) -> Array:
	var collision_data: Array = []
	
	# The arrays are at index 0 because only one surface is generated
	var vertex_array = mesh_data.arrays[Mesh.ARRAY_VERTEX]
	
	# ConcavePolygonShape3D is a Resource and can be created on a worker thread
	# as long as we don't manipulate nodes/scene tree here.
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(vertex_array)
	
	# We return the shape and its transform (Identity for terrain chunks)
	collision_data.append({
		"shape": shape,
		"transform": Transform3D.IDENTITY
	})
	
	return collision_data
