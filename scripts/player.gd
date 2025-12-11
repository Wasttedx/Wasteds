extends CharacterBody3D

# Movement parameters
@export var speed = 5.0
@export var rotation_speed = 3.0
var jump_velocity = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Capture the mouse for smooth, standard first-person control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Make the camera the active camera
	$Camera3D.make_current()

func _unhandled_input(event):
	# Handle camera rotation based on mouse movement
	if event is InputEventMouseMotion:
		var delta = event.relative
		
		# Rotate the player body (Y-axis/Horizontal)
		rotate_y(-deg_to_rad(delta.x * rotation_speed * 0.01))
		
		# Rotate the camera (X-axis/Vertical)
		var camera = $Camera3D
		camera.rotate_x(-deg_to_rad(delta.y * rotation_speed * 0.01))
		
		# Clamp the camera rotation to prevent flipping
		var rot_x = camera.rotation.x
		camera.rotation.x = clamp(rot_x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	# 1. Apply Gravity
	var new_velocity = velocity
	if not is_on_floor():
		new_velocity.y -= gravity * delta
	
	# 2. Get Input Direction (WASD)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# 3. Calculate Horizontal Movement
	if direction:
		new_velocity.x = direction.x * speed
		new_velocity.z = direction.z * speed
	else:
		# Apply friction/stop if no input
		new_velocity.x = move_toward(new_velocity.x, 0, speed)
		new_velocity.z = move_toward(new_velocity.z, 0, speed)
		
	# 4. Jump (Optional: Simple jump for testing)
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		new_velocity.y = jump_velocity
		
	velocity = new_velocity
	move_and_slide()
