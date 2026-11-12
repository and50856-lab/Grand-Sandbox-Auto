extends CharacterBody3D

@export var walk_speed := 5.0
@export var run_speed := 8.0
@export var acceleration := 18.0
@export var jump_force := 6.0
@export var mouse_sensitivity := 0.004

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var touch_move := Vector2.ZERO
var camera_yaw := 0.0
var camera_pitch := -0.22

var camera_pivot: Node3D
var camera: Camera3D
var model: Node3D

var look_touch_id := -1
var last_touch := Vector2.ZERO

var in_vehicle := false
var current_vehicle: Node3D


func _ready() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	_build_collision()
	_build_model()
	_build_camera()


func _build_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.8

	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)


func _build_model() -> void:
	var character_scene: PackedScene = load("res://assets/character.glb")

	if character_scene:
		model = character_scene.instantiate()
		model.name = "PlayerModel"
		model.position.y = 0.0
		add_child(model)
	else:
		var fallback := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.38
		mesh.height = 1.8
		fallback.mesh = mesh
		fallback.position.y = 0.9

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.48, 0.95)
		fallback.material_override = mat
		add_child(fallback)


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.35
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.0, 7.0)
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 500.0
	camera.current = true
	camera_pivot.add_child(camera)


func set_touch_input(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

	if in_vehicle and is_instance_valid(current_vehicle):
		current_vehicle.set_touch_input(touch_move)


func _input(event: InputEvent) -> void:
	if in_vehicle:
		return

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_rotate_camera(event.relative)

	if event is InputEventScreenTouch:
		var screen := get_viewport().get_visible_rect().size

		if event.pressed:
			if event.position.x > screen.x * 0.42 and look_touch_id == -1:
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
	camera_pitch = clampf(camera_pitch, -0.85, 0.25)

	rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch


func _physics_process(delta: float) -> void:
	if in_vehicle:
		return

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

	var local_dir := Vector3(input_vector.x, 0, input_vector.y)
	var direction := (transform.basis * local_dir).normalized()

	var speed := walk_speed

	if Input.is_action_pressed("run") or input_vector.length() > 0.9:
		speed = run_speed

	if direction.length() > 0.01:
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)

		if model:
			model.rotation.y = lerp_angle(
				model.rotation.y,
				atan2(direction.x, direction.z) - rotation.y,
				delta * 10.0
			)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	move_and_slide()


func interact() -> void:
	if in_vehicle:
		if is_instance_valid(current_vehicle):
			current_vehicle.exit_vehicle(self)
		return

	var nearest: Node3D = null
	var nearest_distance := 5.0

	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if not is_instance_valid(vehicle):
			continue

		var distance := global_position.distance_to(vehicle.global_position)

		if distance < nearest_distance:
			nearest = vehicle
			nearest_distance = distance

	if nearest and nearest.has_method("enter_vehicle"):
		nearest.enter_vehicle(self)


func enter_vehicle(vehicle: Node3D) -> void:
	in_vehicle = true
	current_vehicle = vehicle
	velocity = Vector3.ZERO
	visible = false
	set_physics_process(false)
	camera.current = false


func exit_vehicle(position_out: Vector3) -> void:
	global_position = position_out
	velocity = Vector3.ZERO
	in_vehicle = false
	current_vehicle = null
	touch_move = Vector2.ZERO
	visible = true
	set_physics_process(true)
	camera.current = true
