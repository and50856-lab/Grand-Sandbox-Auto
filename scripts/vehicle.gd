extends RigidBody3D

@export var body_color := Color(0.75, 0.12, 0.10)
@export var engine_power := 25.0
@export var steering_power := 1.8
@export var max_speed := 32.0
@export var brake_power := 18.0

var driver: Node3D
var driving := false
var touch_input := Vector2.ZERO

var vehicle_camera: Camera3D
var wheel_nodes: Array[Node3D] = []

var health := 100.0
var previous_speed := 0.0


func _ready() -> void:
	add_to_group("vehicles")
	mass = 1150.0
	gravity_scale = 1.0
	linear_damp = 0.15
	angular_damp = 2.0
	_build_body()
	_build_wheels()
	_build_camera()


func _build_body() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 0.75, 4.0)

	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.75
	add_child(collision)

	var chassis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.9, 0.75, 4.0)
	chassis.mesh = mesh
	chassis.position.y = 0.75

	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.metallic = 0.45
	mat.roughness = 0.3
	chassis.material_override = mat
	add_child(chassis)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.55, 0.8, 1.9)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.45, -0.25)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.17, 0.23, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.2
	glass.roughness = 0.15
	cabin.material_override = glass
	add_child(cabin)

	_add_light(Vector3(-0.62, 0.8, -2.02), Color(1.0, 0.92, 0.72))
	_add_light(Vector3(0.62, 0.8, -2.02), Color(1.0, 0.92, 0.72))
	_add_light(Vector3(-0.62, 0.8, 2.02), Color(0.9, 0.04, 0.02))
	_add_light(Vector3(0.62, 0.8, 2.02), Color(0.9, 0.04, 0.02))


func _add_light(pos: Vector3, color: Color) -> void:
	var light_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.2, 0.08)
	light_mesh.mesh = box
	light_mesh.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	light_mesh.material_override = mat
	add_child(light_mesh)


func _build_wheels() -> void:
	for x in [-0.98, 0.98]:
		for z in [-1.25, 1.25]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.43
			mesh.bottom_radius = 0.43
			mesh.height = 0.28
			wheel.mesh = mesh
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(x, 0.43, z)

			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.035, 0.04, 0.045)
			mat.roughness = 0.95
			wheel.material_override = mat

			add_child(wheel)
			wheel_nodes.append(wheel)


func _build_camera() -> void:
	vehicle_camera = Camera3D.new()
	vehicle_camera.position = Vector3(0, 4.0, 8.0)
	vehicle_camera.rotation_degrees = Vector3(-12, 0, 0)
	vehicle_camera.fov = 78.0
	vehicle_camera.near = 0.05
	vehicle_camera.far = 500.0
	add_child(vehicle_camera)


func set_touch_input(value: Vector2) -> void:
	touch_input = value.limit_length(1.0)


func enter_vehicle(player: Node3D) -> void:
	if driving:
		return

	driver = player
	driving = true
	touch_input = Vector2.ZERO

	if driver.has_method("enter_vehicle"):
		driver.enter_vehicle(self)

	vehicle_camera.make_current()


func exit_vehicle(player: Node3D) -> void:
	if not driving:
		return

	driving = false
	touch_input = Vector2.ZERO

	var exit_position := global_position + global_transform.basis.x * 2.4
	exit_position.y = 0.2

	if player.has_method("exit_vehicle"):
		player.exit_vehicle(exit_position)

	driver = null


func _physics_process(delta: float) -> void:
	if not driving:
		return

	var input := Input.get_axis("move_back", "move_forward")
	var steering := Input.get_axis("move_left", "move_right")

	if absf(touch_input.y) > 0.05:
		input = -touch_input.y

	if absf(touch_input.x) > 0.05:
		steering = touch_input.x

	var forward := -global_transform.basis.z
	var speed := linear_velocity.dot(forward)

	if absf(speed) < max_speed:
		apply_central_force(forward * input * engine_power * mass)

	if Input.is_action_pressed("jump"):
		apply_central_force(-linear_velocity.normalized() * brake_power * mass)

	var steer_factor := clampf(absf(speed) / 8.0, 0.15, 1.0)
	apply_torque(Vector3.UP * steering * steering_power * mass * steer_factor)

	# Визуальное вращение колёс.
	for wheel in wheel_nodes:
		wheel.rotate_x(-speed * delta * 0.7)

	# Сильный удар отнимает прочность.
	var current_speed := linear_velocity.length()

	if current_speed - previous_speed > 9.0:
		health = maxf(0.0, health - (current_speed - previous_speed) * 1.5)

	previous_speed = current_speed

	if health <= 0.0:
		engine_power = 0.0
