extends CharacterBody3D

@export var walk_speed := 3.5
@export var run_speed := 6.0
@export var acceleration := 16.0
@export var jump_force := 5.5
@export var mouse_sensitivity := 0.004

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

var camera_yaw := 0.0
var camera_pitch := -0.28

var touch_move := Vector2.ZERO

var camera_pivot: Node3D
var camera: Camera3D

var look_touch_id := -1
var last_touch := Vector2.ZERO


func _ready() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

	_build_character()
	_build_camera()


# --------------------------------------------------
# CHARACTER
# --------------------------------------------------

func _build_character() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()

	capsule.radius = 0.38
	capsule.height = 1.8

	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	var model_scene: PackedScene = load("res://assets/character.glb")

	if model_scene:
		var model := model_scene.instantiate()
		model.name = "PlayerModel"
		add_child(model)
	else:
		_add_fallback_model()


func _add_fallback_model() -> void:
	var visual := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()

	capsule_mesh.radius = 0.38
	capsule_mesh.height = 1.8

	visual.mesh = capsule_mesh
	visual.position.y = 0.9

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.65, 0.95)
	visual.material_override = material

	add_child(visual)


# --------------------------------------------------
# CAMERA
# --------------------------------------------------

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.35
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.6, 6.2)
	camera.rotation = Vector3.ZERO
	camera.fov = 75.0
	camera.far = 1000.0
	camera.current = true

	camera_pivot.add_child(camera)

	camera_pivot.rotation.x = camera_pitch


func _input(event: InputEvent) -> void:
	# MOUSE CAMERA CONTROL

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_rotate_camera(event.relative)

	# TOUCH CAMERA CONTROL

	if event is InputEventScreenTouch:
		var viewport_size := get_viewport().get_visible_rect().size

		if event.pressed:
			if (
				event.position.x > viewport_size.x * 0.45
				and event.position.y < viewport_size.y * 0.78
				and look_touch_id == -1
			):
				look_touch_id = event.index
				last_touch = event.position

		elif event.index == look_touch_id:
			look_touch_id = -1

	if event is InputEventScreenDrag:
		if event.index == look_touch_id:
			var delta := event.position - last_touch
			last_touch = event.position
			_rotate_camera(delta)


func _rotate_camera(delta: Vector2) -> void:
	camera_yaw -= delta.x * mouse_sensitivity
	camera_pitch -= delta.y * mouse_sensitivity

	camera_pitch = clampf(camera_pitch, -0.85, 0.15)

	rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch


# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	if touch_move.length() > 0.05:
		input_vector = touch_move

	input_vector = input_vector.limit_length(1.0)

	var strength := input_vector.length()

	var local_direction := Vector3(
		input_vector.x,
		0,
		input_vector.y
	)

	var direction := (
		transform.basis * local_direction
	).normalized()

	var current_speed := walk_speed + (
		run_speed - walk_speed
	) * strength

	if direction.length() > 0.01:
		velocity.x = move_toward(
			velocity.x,
			direction.x * current_speed,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			direction.z * current_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			acceleration * delta
		)

	move_and_slide()
