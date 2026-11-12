extends RigidBody3D

@export var body_color: Color = Color(0.75, 0.12, 0.10)
@export var engine_power: float = 16.0
@export var steering_power: float = 1.2
@export var max_speed: float = 30.0
@export var brake_power: float = 24.0

var driver: Node3D
var driving: bool = false
var touch_input: Vector2 = Vector2.ZERO

var vehicle_camera: Camera3D
var wheel_nodes: Array[Node3D] = []

var health: float = 100.0
var brake_timer: float = 0.0


func _ready() -> void:
	add_to_group("vehicles")

	mass = 1150.0
	gravity_scale = 1.0
	linear_damp = 0.35
	angular_damp = 2.5
	can_sleep = false

	_build_body()
	_build_wheels()
	_build_camera()


# ==================================================
# КОРПУС
# ==================================================

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()

	shape.size = Vector3(1.9, 0.75, 4.0)
	collision.shape = shape
	collision.position.y = 0.75

	add_child(collision)

	var chassis := MeshInstance3D.new()
	var mesh := BoxMesh.new()

	mesh.size = Vector3(1.9, 0.75, 4.0)
	chassis.mesh = mesh
	chassis.position.y = 0.75

	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	material.metallic = 0.25
	material.roughness = 0.48

	chassis.material_override = material
	add_child(chassis)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()

	cabin_mesh.size = Vector3(1.55, 0.8, 1.9)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.45, -0.25)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.17, 0.23)
	glass.roughness = 0.2

	cabin.material_override = glass
	add_child(cabin)

	_add_light(
		Vector3(-0.62, 0.8, -2.02),
		Color(1.0, 0.92, 0.72)
	)

	_add_light(
		Vector3(0.62, 0.8, -2.02),
		Color(1.0, 0.92, 0.72)
	)

	_add_light(
		Vector3(-0.62, 0.8, 2.02),
		Color(0.9, 0.04, 0.02)
	)

	_add_light(
		Vector3(0.62, 0.8, 2.02),
		Color(0.9, 0.04, 0.02)
	)


func _add_light(pos: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()

	mesh.size = Vector3(0.35, 0.2, 0.08)
	instance.mesh = mesh
	instance.position = pos

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.6

	instance.material_override = material
	add_child(instance)


# ==================================================
# КОЛЁСА
# ==================================================

func _build_wheels() -> void:
	for x in [-0.98, 0.98]:
		for z in [-1.25, 1.25]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()

			mesh.top_radius = 0.43
			mesh.bottom_radius = 0.43
			mesh.height = 0.28
			mesh.radial_segments = 8

			wheel.mesh = mesh
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(x, 0.43, z)

			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.035, 0.04, 0.045)
			material.roughness = 0.95

			wheel.material_override = material

			add_child(wheel)
			wheel_nodes.append(wheel)


# ==================================================
# КАМЕРА
# ==================================================

func _build_camera() -> void:
	vehicle_camera = Camera3D.new()
	vehicle_camera.position = Vector3(0, 4.0, 8.0)
	vehicle_camera.rotation_degrees = Vector3(-15, 0, 0)
	vehicle_camera.fov = 78.0
	vehicle_camera.near = 0.08
	vehicle_camera.far = Settings.view_distance

	add_child(vehicle_camera)


func apply_settings() -> void:
	if is_instance_valid(vehicle_camera):
		vehicle_camera.far = Settings.view_distance


# ==================================================
# УПРАВЛЕНИЕ
# ==================================================

func set_touch_input(value: Vector2) -> void:
	touch_input = value.limit_length(1.0)


func brake() -> void:
	brake_timer = maxf(brake_timer, 0.25)


func enter_vehicle(player: Node3D) -> void:
	if driving:
		return

	if not is_instance_valid(player):
		return

	driver = player
	driving = true
	touch_input = Vector2.ZERO

	if driver.has_method("enter_vehicle"):
		driver.call("enter_vehicle", self)

	vehicle_camera.make_current()


func exit_vehicle(player: Node3D) -> void:
	if not driving:
		return

	if not is_instance_valid(player):
		return

	driving = false
	touch_input = Vector2.ZERO
	brake_timer = 0.0

	var exit_position := (
		global_position + global_transform.basis.x * 2.5
	)

	exit_position.y = 0.1

	if player.has_method("exit_vehicle"):
		player.call("exit_vehicle", exit_position)

	driver = null


# ==================================================
# ФИЗИКА И ДВИЖЕНИЕ
# ==================================================

func _physics_process(delta: float) -> void:
	if not driving:
		return

	var throttle := Input.get_axis(
		"move_back",
		"move_forward"
	)

	var steering := Input.get_axis(
		"move_left",
		"move_right"
	)

	if absf(touch_input.y) > 0.05:
		throttle = -touch_input.y

	if absf(touch_input.x) > 0.05:
		steering = touch_input.x

	var forward := -global_transform.basis.z
	var forward_speed := linear_velocity.dot(forward)

	if absf(throttle) > 0.05:
		var can_accelerate := (
			(throttle > 0.0 and forward_speed < max_speed)
			or
			(throttle < 0.0 and forward_speed > -max_speed * 0.5)
		)

		if can_accelerate:
			apply_central_force(
				forward * throttle * engine_power * mass
			)

	if Input.is_action_pressed("jump"):
		brake_timer = maxf(brake_timer, 0.05)

	if brake_timer > 0.0:
		brake_timer = maxf(brake_timer - delta, 0.0)

		apply_central_force(
			-linear_velocity * brake_power * mass * 0.01
		)

	var steering_factor := clampf(
		absf(forward_speed) / 5.0,
		0.0,
		1.0
	)

	if absf(forward_speed) > 0.5:
		var reverse_factor := 1.0

		if forward_speed < 0.0:
			reverse_factor = -1.0

		apply_torque(
			Vector3.UP
			* steering
			* steering_power
			* mass
			* steering_factor
			* reverse_factor
		)

	for wheel in wheel_nodes:
		wheel.rotate_x(-forward_speed * delta * 0.7)

	linear_velocity = linear_velocity.limit_length(max_speed + 3.0)
