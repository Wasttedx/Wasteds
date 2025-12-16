extends Node3D
class_name TerrainChunk

var chunk_coords: Vector2i
var current_lod: int = -1
var is_ready: bool = false
var is_built: bool = false

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

# Note: Added veg_manager to setup arguments
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

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_clear_vegetation()

func apply_prebuilt_data(data: Dictionary):
	if is_built:
		return
		
	build_data = data
	is_built = true

func set_lod(level: int):
	if not is_ready or not is_built: return
	if current_lod == level: return
	
	current_lod = level
	
	if mesh_instance.mesh:
		mesh_instance.mesh = null
	
	_clear_physics()
	_clear_vegetation()
	
	var biome: BiomeConfig = build_data.biome_config
	
	var splat_image: Image = build_data.splat_map_image
	var splat_tex = ImageTexture.create_from_image(splat_image)
	
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
	
	collision_body = StaticBody3D.new()
	# Set the collision layer/mask here if you are using specific layers for terrain
	add_child(collision_body)
	
	var collision_shapes: Array = build_data.collision_shapes
	for shape_data in collision_shapes:
		var shape_node = CollisionShape3D.new()
		shape_node.shape = shape_data.shape
		shape_node.transform = shape_data.transform
		collision_body.add_child(shape_node)

	# --- FIX START: Snap Transforms to Collision Mesh ---
	if build_data.has("vegetation_transforms"):
		var veg_config: VegetationConfig = veg_spawner.config	
		
		# Perform the raycast snapping on the main thread now that collision is ready
		var snapped_transforms = _snap_vegetation_transforms(build_data.vegetation_transforms, veg_config)
		
		# Register the corrected vegetation transforms with the global manager
		if vegetation_manager:
			vegetation_manager.update_chunk_vegetation(chunk_coords, snapped_transforms)
	# --- FIX END ---


func _apply_low_res(material: Material):
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, build_data.low_res_mesh_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material

func _clear_physics():
	if collision_body:
		collision_body.queue_free()
		collision_body = null

func _clear_vegetation():
	# Tell the manager to remove our vegetation
	if vegetation_manager:
		vegetation_manager.remove_chunk_vegetation(chunk_coords)


# --- NEW FUNCTION: Snaps vegetation to the actual collision surface and ALIGNS TO NORMAL ---
func _snap_vegetation_transforms(veg_data: Dictionary, veg_config: VegetationConfig) -> Dictionary:
	if not collision_body or collision_body.get_child_count() == 0:
		return veg_data
		
	var snapped_data = {}
	
	# Get the collision space of the StaticBody3D for raycasting
	var space = PhysicsServer3D.body_get_space(collision_body.get_rid())
	
	# FIX: Compare the RID to an empty RID()
	if space == RID():
		push_error("Failed to get Physics Space for Chunk Collision Body (RID is null).")
		return veg_data
		
	var direct_state: PhysicsDirectSpaceState3D = PhysicsServer3D.space_get_direct_state(space)
	
	# Mapping offsets from VegetationSpawner's logic
	var vegetation_y_offsets = {
		veg_config.grass_mesh: 0.1, # Grass slightly above terrain
		veg_config.tree_mesh: 0.0,	# Trees start at ground level
		veg_config.rock_mesh: 0.0,	# Rocks start at ground level
	}

	var ray_length = 1000.0 # Length of the raycast
	var parameters = PhysicsRayQueryParameters3D.new()
	
	for mesh_res in veg_data:
		var original_transforms: Array[Transform3D] = veg_data[mesh_res]
		var new_transforms: Array[Transform3D] = []
		
		var y_offset = vegetation_y_offsets.get(mesh_res, 0.0)
		var ray_start_y = 500.0 # Must match the value used in VegetationSpawner
		
		parameters.collision_mask = collision_body.collision_mask	
		parameters.exclude = [collision_body.get_rid()]
		parameters.collide_with_areas = false
		parameters.collide_with_bodies = true

		for t in original_transforms:
			var local_pos = t.origin

			# Ray starts high and goes down in the chunk's local space.
			parameters.from = Vector3(local_pos.x, ray_start_y, local_pos.z)
			parameters.to = Vector3(local_pos.x, ray_start_y - ray_length, local_pos.z)

			var result = direct_state.intersect_ray(parameters)
			
			if result.is_empty():
				continue
			else:
				var snapped_y = result.position.y # The exact hit point Y
				var surface_normal = result.normal # Get the surface normal for alignment
				
				var new_t = t
				
				# --- ALIGNMENT LOGIC START ---
				
				# 1. Store original scale and rotation
				var current_basis = t.basis
				var current_scale = current_basis.get_scale()
				
				# 2. Calculate the rotation required to align the object's UP vector (Vector3.UP) 
				#    to the surface normal using the Quaternion constructor.
				# THIS IS THE CORRECT GODOT 4 CONSTRUCTOR
				var rotation_quat: Quaternion = Quaternion(Vector3.UP, surface_normal)
				
				# 3. Apply the alignment rotation to the object's existing orientation.
				# This maintains the random Yaw rotation while applying the new tilt.
				var pure_rotation_basis = current_basis.orthonormalized()
				var aligned_quat = rotation_quat * pure_rotation_basis.get_rotation_quaternion()
				new_t.basis = Basis(aligned_quat)
				
				# 4. Apply the original scale back
				new_t.basis = new_t.basis.scaled(current_scale)
				
				# --- ALIGNMENT LOGIC END ---
				
				# 5. Set the final snapped Y position
				new_t.origin.y = snapped_y + y_offset	
				
				new_transforms.append(new_t)
				
		snapped_data[mesh_res] = new_transforms
		
	return snapped_data
