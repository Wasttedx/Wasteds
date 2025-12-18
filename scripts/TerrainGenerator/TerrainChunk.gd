extends Node3D
class_name TerrainChunk

var chunk_coords: Vector2i
var current_lod: int = -1
var is_ready: bool = false
var is_built: bool = false
var _is_loading: bool = false

var world_config: WorldConfig
var noise: NoiseBuilder
var material_lib: MaterialLibrary
var veg_spawner: VegetationSpawner
var biome_selector: BiomeSelector
var splat_map_generator: SplatMapGenerator
var vegetation_manager: VegetationManager

var build_data: Dictionary = {}
var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D

func setup(coords: Vector2i, wc: WorldConfig, nb: NoiseBuilder, ml: MaterialLibrary, vs: VegetationSpawner, bs: BiomeSelector, smg: SplatMapGenerator, vm: VegetationManager = null):
	chunk_coords = coords
	world_config = wc
	noise = nb
	material_lib = ml
	veg_spawner = vs
	biome_selector = bs
	splat_map_generator = smg
	vegetation_manager = vm
	
	position = Vector3(coords.x * world_config.chunk_world_size, 0, coords.y * world_config.chunk_world_size)
	name = "Chunk_%d_%d" % [coords.x, coords.y]
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	is_ready = true

func apply_prebuilt_data(data: Dictionary):
	if is_built: return
	build_data = data
	is_built = true

func set_lod(level: int):
	if not is_ready or not is_built: return
	if current_lod == level: return
	
	current_lod = level
	
	# Always clear existing specialized data before switching
	_clear_physics()
	_clear_vegetation()
	
	var biome: BiomeConfig = build_data.biome_config
	var splat_tex = ImageTexture.create_from_image(build_data.splat_map_image)
	var mat = material_lib.get_terrain_material(biome, splat_tex)
	
	if current_lod == 0:
		_apply_high_res(mat)
	else:
		_apply_low_res(mat)

func _apply_high_res(material: Material):
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_data.high_res_mesh_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	
	# Build Physics (Required for vegetation snapping and player walking)
	collision_body = StaticBody3D.new()
	collision_body.collision_layer = 1
	add_child(collision_body)
	
	for shape_data in build_data.collision_shapes:
		var shape_node = CollisionShape3D.new()
		shape_node.shape = shape_data.shape
		shape_node.transform = shape_data.transform
		collision_body.add_child(shape_node)

	# Trigger Vegetation Snapping ONLY in high res
	if build_data.has("vegetation_transforms") and vegetation_manager:
		# Small delay ensures physics server registers the body
		get_tree().create_timer(0.05).timeout.connect(_snap_vegetation)

func _apply_low_res(material: Material):
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_data.low_res_mesh_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	# Low res has no physics or vegetation (handled by clear calls in set_lod)

func _snap_vegetation():
	if not is_instance_valid(collision_body) or not is_inside_tree(): return
	if current_lod != 0: return # Safety check
	
	var snapped = _snap_vegetation_transforms(build_data.vegetation_transforms)
	vegetation_manager.update_chunk_vegetation(chunk_coords, snapped)

func _snap_vegetation_transforms(veg_data: Dictionary) -> Dictionary:
	var snapped_data = {}
	var space = PhysicsServer3D.body_get_space(collision_body.get_rid())
	if space == RID(): return {}
	
	var direct_state = PhysicsServer3D.space_get_direct_state(space)
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.collision_mask = 1
	
	for item_idx in veg_data:
		var original_transforms: Array[Transform3D] = veg_data[item_idx]
		var item_res: VegetationItem = vegetation_manager._config.items[item_idx]
		var new_transforms: Array[Transform3D] = []
		
		for t in original_transforms:
			var ray_start = global_position + Vector3(t.origin.x, 1500.0, t.origin.z)
			var ray_end = global_position + Vector3(t.origin.x, -1000.0, t.origin.z)
			
			ray_params.from = ray_start
			ray_params.to = ray_end
			
			var result = direct_state.intersect_ray(ray_params)
			if not result.is_empty():
				var new_t = t
				new_t.origin = result.position + (result.normal * item_res.y_offset)
				
				var normal = result.normal
				var basis_x = t.basis.x.normalized()
				var basis_z = normal.cross(basis_x).normalized()
				basis_x = basis_z.cross(normal).normalized()
				
				var scale = t.basis.get_scale()
				new_t.basis = Basis(basis_x, normal, basis_z)
				new_t.basis = new_t.basis.scaled(scale)
				
				new_transforms.append(new_t)
		
		if not new_transforms.is_empty():
			snapped_data[item_idx] = new_transforms
			
	return snapped_data

func _clear_physics():
	if collision_body:
		collision_body.queue_free()
		collision_body = null

func _clear_vegetation():
	if vegetation_manager:
		vegetation_manager.remove_chunk_vegetation(chunk_coords)
