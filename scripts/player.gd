extends CharacterBody3D

@export var speed = 5.0
@export var rotation_speed = 3.0
var jump_velocity = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$Camera3D.make_current()

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		var delta = event.relative
		
		rotate_y(-deg_to_rad(delta.x * rotation_speed * 0.01))
		
		var camera = $Camera3D
		camera.rotate_x(-deg_to_rad(delta.y * rotation_speed * 0.01))
		
		var rot_x = camera.rotation.x
		camera.rotation.x = clamp(rot_x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	var new_velocity = velocity
	if not is_on_floor():
		new_velocity.y -= gravity * delta
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		new_velocity.x = direction.x * speed
		new_velocity.z = direction.z * speed
	else:
		new_velocity.x = move_toward(new_velocity.x, 0, speed)
		new_velocity.z = move_toward(new_velocity.z, 0, speed)
		
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		new_velocity.y = jump_velocity
		
	velocity = new_velocity
	move_and_slide()

	# --- DEBUG OVERLAY UPDATE ---
	DebugOverlay.monitor_set("Game", "Player Pos", global_position)
	# Assuming chunks are e.g. 64 units, roughly calc coord
	# You can replace 64 with your actual chunk size config if you access it here
	var approx_chunk = Vector2i(floor(global_position.x / 64.0), floor(global_position.z / 64.0)) 
	DebugOverlay.monitor_set("Game", "Chunk Coord", approx_chunk)
