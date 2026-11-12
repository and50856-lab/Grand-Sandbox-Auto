extends RigidBody3D

@export var body_color: Color = Color(0.75, 0.12, 0.10)

@export_group("Engine")
@export var engine_force: float = 8200.0
@export var max_speed: float = 38.0
@export var reverse_speed: float = 12.0
@export var brake_force: float = 14500.0

@export_group("Suspension")
@export var suspension_rest_length: float = 1.0
@export var suspension_travel: float = 0.45
@export var suspension_stiffness: float = 35000.0
@export var suspension_damping: float = 4500.0
@export var wheel_radius: float = 0.43

@export_group("Tyres")
@export var tire_grip: float = 2.2
@export var lateral_grip: float = 3.5
@export var rolling_resistance: float = 0.025

@export_group("Steering")
@export var steering_angle: float = 0.48
@export var steering_response: float = 3.5

var driver: Node3D = null
var driving: bool = false
var ai_driving: bool = false

var touch_input: Vector2 = Vector2.ZERO
var vehicle_camera: Camera3D

var wheel_nodes: Array[MeshInstance3D] = []
var wheel_positions: Array[Vector3] = []
var wheel_steering: Array[bool] = []

var health: float = 100.0
var brake_timer: float = 0.0
var current_steering: float = 0.0

var ai_driver: Node3D = null
var ai_destination: Vector3 = Vector3.ZERO
var ai_time_left: float = 0.0

var engine_sound_speed: float = 0.0

const COLLISION_MASK := 0xFFFFFFFF


func _ready() -> void:
	add_to_group("vehicles")

	mass = 1150.0
	gravity_scale = 1.0
	linear_damp = 0.08
	angular_damp = 0.8
	can_sleep = false
	continuous_cd = true
	max_contacts_reported = 8
	contact_monitor = true

	_build_body()
	_build_wheels()
	_build_camera()


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
	material.metallic = 0.3
	material.roughness = 0.42
	chassis.material_override = material
	add_child(chassis)

	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.55, 0.8, 1.9)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 1.45, -0.25)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.06, 0.13, 0.19)
	glass.metallic = 0.25
	glass.roughness = 0.16
	cabin.material_override = glass
	add_child(cabin)

	_add_light(Vector3(-0.62, 0.8, -2.02), Color(1.0, 0.92, 0.72))
	_add_light(Vector3(0.62, 0.8, -2.02), Color(1.0, 0.92, 0.72))
	_add_light(Vector3(-0.62, 0.8, 2.02), Color(0.9, 0.04, 0.02))
	_add_light(Vector3(0.62, 0.8, 2.02), Color(0.9, 0.04, 0.02))


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
	material.emission_energy_multiplier = 0.8
	instance.material_override = material
	add_child(instance)


func _build_wheels() -> void:
	wheel_positions.clear()
	wheel_nodes.clear()
	wheel_steering.clear()

	for x in [-0.98, 0.98]:
		for z in [-1.25, 1.25]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = wheel_radius
			mesh.bottom_radius = wheel_radius
			mesh.height = 0.28
			mesh.radial_segments = 20
			mesh.rings = 2

			wheel.mesh = mesh
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(x, 0.43, z)

			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.025, 0.028, 0.032)
			material.roughness = 0.96
			wheel.material_override = material

			add_child(wheel)
			wheel_nodes.append(wheel)

			wheel_positions.append(Vector3(x, 0.43, z))
			wheel_steering.append(z < 0.0)


func _build_camera() -> void:
	vehicle_camera = Camera3D.new()
	vehicle_camera.position = Vector3(0.0, 4.0, 8.0)
	vehicle_camera.rotation_degrees = Vector3(-15.0, 0.0, 0.0)
	vehicle_camera.fov = 78.0
	vehicle_camera.near = 0.08
	vehicle_camera.far = Settings.view_distance
	add_child(vehicle_camera)


func apply_settings() -> void:
	if is_instance_valid(vehicle_camera):
		vehicle_camera.far = Settings.view_distance


func set_touch_input(value: Vector2) -> void:
	touch_input = value.limit_length(1.0)


func brake() -> void:
	brake_timer = maxf(brake_timer, 0.3)


func enter_vehicle(player: Node3D) -> void:
	if driving or ai_driving:
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

	var exit_position := global_position + global_transform.basis.x * 2.5
	exit_position.y = 1.0

	if player.has_method("exit_vehicle"):
		player.call("exit_vehicle", exit_position)

	driver = null


func assign_ai_driver(npc: Node3D, destination: Vector3) -> bool:
	if driving or ai_driving or not is_instance_valid(npc):
		return false

	ai_driver = npc
	ai_destination = destination
	ai_time_left = 35.0
	ai_driving = true

	if npc.has_method("enter_vehicle"):
		npc.call("enter_vehicle", self)

	return true


func release_ai_driver() -> void:
	if not ai_driving:
		return

	var old_driver := ai_driver
	ai_driving = false
	ai_driver = null
	ai_time_left = 0.0

	if is_instance_valid(old_driver):
		var exit_position := global_position + global_transform.basis.x * 2.5
		exit_position.y = 1.0

		if old_driver.has_method("exit_vehicle"):
			old_driver.call("exit_vehicle", exit_position)


func _get_controls() -> Vector2:
	if driving:
		var throttle := Input.get_axis("move_back", "move_forward")
		var steering := Input.get_axis("move_left", "move_right")

		if absf(touch_input.y) > 0.05:
			throttle = -touch_input.y

		if absf(touch_input.x) > 0.05:
			steering = touch_input.x

		return Vector2(steering, throttle)

	if ai_driving:
		var local_target := global_transform.basis.inverse() * (
			ai_destination - global_position
		)

		var distance := global_position.distance_to(ai_destination)

		if distance < 7.0:
			ai_time_left = 0.0

		var steer := clampf(
			local_target.x / maxf(absf(local_target.z), 2.0) * 2.0,
			-1.0,
			1.0
		)

		var throttle := 0.65

		if local_target.z > 0.0:
			throttle = -0.25

		return Vector2(steer, throttle)

	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	if ai_driving:
		ai_time_left -= delta
		if ai_time_left <= 0.0:
			release_ai_driver()

	if not driving and not ai_driving:
		if linear_velocity.length() < 0.15:
			return

	var controls := _get_controls()
	var steering_input := controls.x
	var throttle := controls.y

	current_steering = move_toward(
		current_steering,
		steering_input * steering_angle,
		steering_response * delta
	)

	var forward := -global_transform.basis.z
	var speed := linear_velocity.dot(forward)

	var braking := brake_timer > 0.0

	if driving and Input.is_action_pressed("jump"):
		braking = true

	if brake_timer > 0.0:
		brake_timer = maxf(brake_timer - delta, 0.0)

	var acceleration_force := 0.0

	if absf(throttle) > 0.05:
		if throttle > 0.0 and speed < max_speed:
			acceleration_force = engine_force * throttle
		elif throttle < 0.0 and speed > -reverse_speed:
			acceleration_force = engine_force * throttle * 0.55

	var state := get_world_3d().direct_space_state
	var up := global_transform.basis.y.normalized()

	var total_normal_force := 0.0
	var grounded_wheels := 0

	for i in range(wheel_positions.size()):
		var mount_local: Vector3 = wheel_positions[i]
		var mount_global := global_transform * mount_local

		var ray_start := mount_global
		var ray_end := mount_global - up * (
			suspension_rest_length
			+ suspension_travel
			+ wheel_radius
		)

		var query := PhysicsRayQueryParameters3D.create(
			ray_start,
			ray_end,
			COLLISION_MASK,
			[get_rid()]
		)

		query.collide_with_areas = false
		query.collide_with_bodies = true

		var hit := state.intersect_ray(query)

		var wheel := wheel_nodes[i]

		if hit.is_empty():
			wheel.position = mount_local - Vector3(
				0.0,
				suspension_rest_length + suspension_travel,
				0.0
			)
			continue

		grounded_wheels += 1

		var hit_position: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]

		var distance := mount_global.distance_to(hit_position)
		var suspension_length := distance - wheel_radius

		var compression := suspension_rest_length - suspension_length
		compression = clampf(compression, 0.0, suspension_travel)

		var offset := hit_position - global_position
		var point_velocity := linear_velocity + angular_velocity.cross(offset)
		var suspension_velocity := point_velocity.dot(up)

		var spring_force := (
			compression * suspension_stiffness
			- suspension_velocity * suspension_damping
		)

		spring_force = maxf(spring_force, 0.0)

		var normal_force := up * spring_force
		apply_force(normal_force, offset)

		total_normal_force += spring_force

		var wheel_position_global := mount_global - up * suspension_length
		wheel.position = to_local(wheel_position_global)

		var steer_angle := current_steering if wheel_steering[i] else 0.0

		var wheel_forward := (
			global_transform.basis
			* Vector3(sin(steer_angle), 0.0, -cos(steer_angle))
		).normalized()

		var wheel_right := (
			global_transform.basis
			* Vector3(cos(steer_angle), 0.0, sin(steer_angle))
		).normalized()

		var lateral_speed := point_velocity.dot(wheel_right)
		var longitudinal_speed := point_velocity.dot(wheel_forward)

		var friction_limit := spring_force * tire_grip
		var lateral_force_value := clampf(
			-lateral_speed * mass * 1.8,
			-friction_limit,
			friction_limit
		)

		var lateral_force := wheel_right * lateral_force_value
		apply_force(lateral_force, offset)

		# Задний привод: двигатель действует на задние колёса.
		if not wheel_steering[i] and absf(acceleration_force) > 0.0:
			var drive_force := wheel_forward * acceleration_force * 0.5
			apply_force(drive_force, offset)

		if braking:
			var brake_value := clampf(
				-longitudinal_speed * brake_force * 0.25,
				-brake_force * 0.25,
				brake_force * 0.25
			)
			apply_force(wheel_forward * brake_value, offset)

		# Сопротивление качению.
		var rolling_force := (
			-wheel_forward
			* longitudinal_speed
			* rolling_resistance
			* spring_force
		)
		apply_force(rolling_force, offset)

		wheel.rotation.x -= longitudinal_speed * delta / maxf(wheel_radius, 0.1)
		wheel.rotation.y = steer_angle

	# Аэродинамическое сопротивление.
	if linear_velocity.length() > 0.5:
		var drag := -linear_velocity * linear_velocity.length() * 0.32
		apply_central_force(drag)

	# Стабилизация кузова.
	var local_angular := global_transform.basis.inverse() * angular_velocity
	apply_torque(
		global_transform.basis * Vector3(
			-local_angular.x * 1800.0,
			0.0,
			-local_angular.z * 2200.0
		)
	)

	# Ограничение скорости без резкого обрыва движения.
	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if horizontal_velocity.length() > max_speed + 5.0:
		var limited := horizontal_velocity.normalized() * (max_speed + 5.0)
		linear_velocity.x = limited.x
		linear_velocity.z = limited.z

	if driving or ai_driving:
		AudioManager.set_engine_speed(absf(speed))
	else:
		AudioManager.stop_engine()
