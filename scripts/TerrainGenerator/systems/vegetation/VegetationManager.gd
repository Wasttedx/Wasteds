extends Node3D
class_name VegetationManager

var _chunk_nodes := {}
var _player: Node3D
var _config: VegetationConfig
var _world_size: float

# Tracking for Debug Overlay
var _total_instances_active: int = 0

func setup(player_ref: Node3D, config: VegetationConfig, world_size: float):
	self._player = player_ref
	self._config = config
	self._world_size = world_size

func update_chunk_vegetation(chunk_coords: Vector2i, vegetation_data: Dictionary) -> void:
	# First, remove old data to keep tracking accurate
	remove_chunk_vegetation(chunk_coords)
	
	if vegetation_data.is_empty(): return
		
	var chunk_items = {}
	var chunk_instance_count = 0
	
	for item_idx in vegetation_data:
		var transforms: Array[Transform3D] = vegetation_data[item_idx]
		var item_res: VegetationItem = _config.items[item_idx]
		
		if transforms.is_empty() or not item_res.mesh: 
			continue
			
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = item_res.mesh
		mm.instance_count = transforms.size()
		
		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
			
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# Top level ensures absolute world coordinates are respected
		mmi.top_level = true 
		add_child(mmi)
		
		chunk_items[item_idx] = mmi
		chunk_instance_count += transforms.size()
	
	_chunk_nodes[chunk_coords] = chunk_items
	
	# Update Global Count for Debugging
	_total_instances_active += chunk_instance_count
	_update_debug_metrics()

func remove_chunk_vegetation(chunk_coords: Vector2i) -> void:
	if _chunk_nodes.has(chunk_coords):
		var chunk_items = _chunk_nodes[chunk_coords]
		for item_idx in chunk_items:
			var mmi = chunk_items[item_idx]
			if is_instance_valid(mmi):
				# Subtract instance count before freeing
				_total_instances_active -= mmi.multimesh.instance_count
				mmi.queue_free()
		_chunk_nodes.erase(chunk_coords)
		_update_debug_metrics()

func _update_debug_metrics():
	if has_node("/root/DebugOverlay"):
		get_node("/root/DebugOverlay").monitor_set("Vegetation", "Instance Count", _total_instances_active)

func reset() -> void:
	for coords in _chunk_nodes.keys():
		remove_chunk_vegetation(coords)
	_total_instances_active = 0
