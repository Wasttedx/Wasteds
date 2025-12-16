extends RefCounted
class_name PlacementUtility

## PlacementUtility
## A utility class for snapping objects to a surface using ray casting.
## This must be run on the main thread because it uses Godot's PhysicsServer.

static func snap_to_surface(origin_point: Vector3, ray_length: float = 1000.0, collision_mask: int = 1) -> Dictionary:
	"""
	Performs a ray cast down from an origin point to find the surface height.

	Args:
		origin_point (Vector3): The world position to start the ray cast from.
		ray_length (float): The length of the ray cast (should be large enough to hit the ground).
		collision_mask (int): The collision mask to check against (must include the terrain's layer).

	Returns:
		Dictionary: A dictionary containing collision information, including:
					"is_hit" (bool), 
					"position" (Vector3), 
					"normal" (Vector3),
					"collider" (Object/RID)
	"""
	
	# Get the Physics Space from the current active World3D
	var world_3d = Engine.get_main_loop().get_world_3d()
	if not world_3d:
		push_error("PlacementUtility: Could not access World3D.")
		return {"is_hit": false, "position": origin_point}
	
	var space = world_3d.get_space()
	
	if space.is_zero():
		# Fallback if no space is active
		return {"is_hit": false, "position": origin_point}

	var from = origin_point
	var to = origin_point + Vector3.DOWN * ray_length
	
	var parameters = PhysicsRayQueryParameters3D.new()
	parameters.from = from
	parameters.to = to
	parameters.collide_with_areas = false
	parameters.collide_with_bodies = true
	parameters.collision_mask = collision_mask
	
	# FIX: Use the Direct Space State to intersect ray
	var direct_state: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(space)
	
	# Execute the ray cast
	var result = direct_state.intersect_ray(parameters)
	
	if result.is_empty():
		return {"is_hit": false, "position": origin_point}
	else:
		return {
			"is_hit": true, 
			"position": result.position, 
			"normal": result.normal,
			"collider": result.collider
		}
