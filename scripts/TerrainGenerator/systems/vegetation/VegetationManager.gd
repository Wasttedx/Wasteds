extends Node3D
class_name VegetationManager

# Storage for active multimeshes: { chunk_coords (Vector2i): [MultiMeshInstance3D] }
var _active_chunks := {}

func update_chunk_vegetation(chunk_coords: Vector2i, vegetation_data: Dictionary) -> void:
	remove_chunk_vegetation(chunk_coords)
	
	if vegetation_data.is_empty():
		return
		
	var instances: Array[MultiMeshInstance3D] = []
	var total_added_this_chunk = 0
	
	for mesh_res in vegetation_data:
		var transforms: Array[Transform3D] = vegetation_data[mesh_res]
		
		if transforms.is_empty() or not mesh_res:
			continue
			
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_res
		mm.instance_count = transforms.size()
		
		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
			
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)
		
		instances.append(mmi)
		total_added_this_chunk += transforms.size()
	
	_active_chunks[chunk_coords] = instances
	
	# --- DEBUG OVERLAY ---
	DebugOverlay.monitor_increment("Vegetation", "Instance Count", total_added_this_chunk)

func remove_chunk_vegetation(chunk_coords: Vector2i) -> void:
	if _active_chunks.has(chunk_coords):
		var instances = _active_chunks[chunk_coords]
		var total_removed = 0
		
		for mmi in instances:
			if mmi.multimesh:
				total_removed += mmi.multimesh.instance_count
			mmi.queue_free()
			
		_active_chunks.erase(chunk_coords)

		# --- DEBUG OVERLAY ---
		DebugOverlay.monitor_increment("Vegetation", "Instance Count", -total_removed)

func reset() -> void:
	for coords in _active_chunks.keys():
		remove_chunk_vegetation(coords)
