extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var acceleration: float = 20.0
@export var jump_force: float = 6.0
@export var mouse_sensitivity: float = 0.004

var gravity: float = float(
	ProjectSettings.get_setting("physics/3d/default_gravity")
)

var touch_move: Vector2 = Vector2.ZERO

var camera_yaw: float = 0.0
var camera_pitch: float = -0.18

var camera_pivot: Node3D
var camera: Camera3D
var model: Node3D

var look_touch_id: int = -1
var last_touch: Vector2 = Vector2.ZERO

var in_vehicle: bool = false
var current_vehicle: Node3D = null

var saved_collision_layer: int = 1
var saved_collision_mask: int = 1


func _ready() -> void:
	name = "Player"
	add_to_group("player")

	saved_collision_layer = collision_layer
	saved_collision_mask = collision_mask

	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	_build_collision()
	_build_model()
	_build_camera()


# ==================================================
# КОЛЛИЗИЯ
# ==================================================

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()

	shape.radius = 0.34
	shape.height = 1.75

	collision.shape = shape
	collision.position.y = 0.875

	add_child(collision)


# ==================================================
# МОДЕЛЬ ПЕРСОНАЖА
# ==================================================

func _build_model() -> void:
	model = Node3D.new()
	model.name = "PlayerVisual"
	add_child(model)

	var loaded := false

	if ResourceLoader.exists("res://assets/character.glb"):
		var resource: Resource = load("res://assets/character.glb")

		if resource is PackedScene:
			var instance := (resource as PackedScene).instantiate()

			if instance is Node3D:
				model.add_child(instance)
				_normalize_model(instance)
				loaded = true

	if not loaded:
		_create_fallback_model()


func _normalize_model(root: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)

	if meshes.is_empty():
		return

	var bounds := AABB()
	var first := true

	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue

		var local_bounds := mesh_instance.get_aabb()
		var transformed := mesh_instance.transform * local_bounds

		if first:
			bounds = transformed
			first = false
		else:
			bounds = bounds.merge(transformed)

	if first or bounds.size.y <= 0.01:
		return

	var scale_factor := 1.7 / bounds.size.y

	root.scale = Vector3.ONE * scale_factor
	root.position.y = -bounds.position.y * scale_factor


func _collect_meshes(
	node: Node,
	output: Array[MeshInstance3D]
) -> void:
	if node is MeshInstance3D:
		output.append(node)

	for child in node.get_children():
		_collect_meshes(child, output)


func _create_fallback_model() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()

	capsule.radius = 0.34
	capsule.height = 1.75

	body.mesh = capsule
	body.position.y = 0.875

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.48, 0.95)
	material.roughness = 0.8

	body.material_override = material
	model.add_child(body)


# ==================================================
# КАМЕРА
# ==================================================

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.35
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 2.2, 6.0)
	camera.fov = 75.0
	camera.near = 0.08
	camera.far = Settings.view_distance
	camera.current = true

	camera_pivot.add_child(camera)


func _unhandled_input(event: InputEvent) -> void:
	if in_vehicle:
		return

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_rotate_camera(event.relative)

	elif event is InputEventScreenTouch:
		var screen := get_viewport().get_visible_rect().size

		if event.pressed:
			if (
				event.position.x > screen.x * 0.48
				and event.position.y < screen.y * 0.78
				and look_touch_id == -1
			):
				look_touch_id = event.index
				last_touch = event.position

		elif event.index == look_touch_id:
			look_touch_id = -1

	elif event is InputEventScreenDrag:
		if event.index == look_touch_id:
			var delta := event.position - last_touch
			last_touch = event.position
			_rotate_camera(delta)


func _rotate_camera(delta: Vector2) -> void:
	camera_yaw -= delta.x * mouse_sensitivity
	camera_pitch -= delta.y * mouse_sensitivity

	camera_pitch = clampf(
		camera_pitch,
		-0.75,
		0.35
	)

	rotation.y = camera_yaw
	camera_pivot.rotation.x = camera_pitch


# ==================================================
# СЕНСОРНЫЙ ДЖОЙСТИК
# ==================================================

func set_touch_input(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

	if in_vehicle and is_instance_valid(current_vehicle):
		if current_vehicle.has_method("set_touch_input"):
			current_vehicle.call("set_touch_input", touch_move)


# ==================================================
# ПРЫЖОК
# ==================================================

func jump() -> void:
	if in_vehicle:
		if is_instance_valid(current_vehicle):
			if current_vehicle.has_method("brake"):
				current_vehicle.call("brake")
		return

	if is_on_floor():
		velocity.y = jump_force


# ==================================================
# ДВИЖЕНИЕ
# ==================================================

func _physics_process(delta: float) -> void:
	if in_vehicle:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	if Input.is_action_just_pressed("jump"):
		jump()

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	if touch_move.length() > 0.05:
		input_vector = touch_move

	input_vector = input_vector.limit_length(1.0)

	var local_direction := Vector3(
		input_vector.x,
		0.0,
		input_vector.y
	)

	var direction := (
		global_transform.basis * local_direction
	).normalized()

	var speed := walk_speed

	if Input.is_action_pressed("run"):
		speed = run_speed

	if direction.length() > 0.01:
		velocity.x = move_toward(
			velocity.x,
			direction.x * speed,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			direction.z * speed,
			acceleration * delta
		)

		var local_dir := (
			global_transform.basis.inverse() * direction
		)

		model.rotation.y = lerp_angle(
			model.rotation.y,
			atan2(local_dir.x, local_dir.z),
			delta * 10.0
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


# ==================================================
# ВЗАИМОДЕЙСТВИЕ
# ==================================================

func interact() -> void:
	if in_vehicle:
		if is_instance_valid(current_vehicle):
			if current_vehicle.has_method("exit_vehicle"):
				current_vehicle.call("exit_vehicle", self)
		return

	var nearest: Node3D = null
	var nearest_distance: float = 4.5

	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if not is_instance_valid(vehicle):
			continue

		if not vehicle is Node3D:
			continue

		var candidate := vehicle as Node3D

		var distance := global_position.distance_to(
			candidate.global_position
		)

		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance

	if is_instance_valid(nearest):
		if nearest.has_method("enter_vehicle"):
			nearest.call("enter_vehicle", self)


# ==================================================
# ПОСАДКА В МАШИНУ
# ==================================================

func enter_vehicle(vehicle: Node3D) -> void:
	if in_vehicle:
		return

	if not is_instance_valid(vehicle):
		return

	in_vehicle = true
	current_vehicle = vehicle

	velocity = Vector3.ZERO
	touch_move = Vector2.ZERO

	# Отключаем коллизию игрока,
	# чтобы он не мешал физике автомобиля.
	collision_layer = 0
	collision_mask = 0

	visible = false
	camera.current = false


func exit_vehicle(position_out: Vector3) -> void:
	global_position = position_out
	velocity = Vector3.ZERO

	in_vehicle = false
	current_vehicle = null
	touch_move = Vector2.ZERO

	# Восстанавливаем исходную коллизию.
	collision_layer = saved_collision_layer
	collision_mask = saved_collision_mask

	visible = true
	camera.make_current()
