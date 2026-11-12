extends CharacterBody3D

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var acceleration := 18.0
@export var jump_force := 5.5
@export var mouse_sensitivity := 0.004

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_yaw := 0.0
var camera_pitch := -0.15

var touch_move := Vector2.ZERO
var camera_pivot: Node3D
var camera: Camera3D

var look_touch_id := -1
var last_touch := Vector2.ZERO

func _ready() -> void:
	floor_snap_length = 0.3
	_build_character()
	_build_camera()

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
		push_error("Не найдена модель character.glb")

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.45
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0, 0.8, 4.5)
	camera.current = true
	camera.fov = 75.0
	camera_pivot.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rotate_camera(event.relative)

	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().size.x * 0.45:
			look_touch_id = event.index
			last_touch = event.position
		elif not event.pressed and event.index == look_touch_id:
			look_touch_id = -1

	if event is InputEventScreenDrag and event.index == look_touch_id:
		var delta := event.position - last_touch
		last_touch = event.position
		_rotate_camera(delta)

func _rotate_camera(delta: Vector2) -> void:
	camera_yaw -= delta.x * mouse_sensitivity
	camera_pitch -= delta.y * mouse_sensitivity
	camera_pitch = clampf(camera_pitch, -1.0, 0.65)

	rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch

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

	var strength := input_vector.length()
	var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()

	var current_speed := walk_speed + (run_speed - walk_speed) * strength

	if direction.length() > 0.01:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	move_and_slide()
