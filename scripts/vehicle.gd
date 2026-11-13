extends RigidBody3D

@export var body_color: Color = Color(0.75, 0.12, 0.10)

@export_group("Engine")
@export var engine_force: float = 8200.0
@export var max_speed: float = 38.0
@export var reverse_speed: float = 12.0
@export var brake_force: float = 14500.0

@export_group("Suspension")
@export var suspension_rest_length: float = 0.95
@export var suspension_travel: float = 0.45
@export var suspension_stiffness: float = 35000.0
@export var suspension_damping: float = 4800.0
@export var wheel_radius: float = 0.43

@export_group("Tyres")
@export var tire_grip: float = 2.2
@export var lateral_grip: float = 3.5
@export var rolling_resistance: float = 0.025

@export_group("Steering")
@export var steering_angle: float = 0.48
@export var steering_response: float = 3.5

@export_group("Stability")
@export var upright_strength: float = 8500.0
@export var upright_damping: float = 1800.0

var driver: Node3D = null
var driving: bool = false
var ai_driving: bool = false
var ai_reserved_by: Node3D = null

var mobile_steering: float = 0.0
var mobile_throttle: float = 0.0
var current_steering: float = 0.0

var camera_rig: Node3D
var camera_spring_arm: SpringArm3D
var vehicle_camera: Camera3D

var camera_yaw: float = 0.0
var camera_pitch: float = -0.16
var camera_distance: float = 8.5
var camera_height: float = 1.6

var camera_active: bool = false

var wheel_nodes: Array[MeshInstance3D] = []
var wheel_positions: Array[Vector3] = []
var wheel_steering: Array[bool] = []

var brake_timer: float = 0.0
var ai_driver: Node3D = null
var ai_destination: Vector3 = Vector3.ZERO
var ai_time_left: float = 0.0
var ai_stuck_time: float = 0.0
var ai_last_position: Vector3 = Vector3.ZERO
var ai_steer_override: float = 0.0
var ai_throttle_override: float = 0.0

const COLLISION_MASK: int = 0xFFFFFFFF


func _ready() -> void:
	add_to_group("vehicles")

	mass = 1150.0
	gravity_scale = 1.0
	linear_damp = 0.12
	angular_damp = 2.2
	can_sleep = false
	continuous_cd = true
	max_contacts_reported = 8
	contact_monitor = true

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.38, 0.0)

	_build_body()
	_build_wheels()
	_build_camera()


func _process(delta: float) -> void:
	if not camera_active or not driving:
		return

	if not is_instance_valid(driver):
		return

	if driver.get("current_vehicle") != self:
		return

	if not is_instance_valid(camera_rig):
		return

	# Камера следует за положением именно этой машины.
	# Её поворот при этом не зависит от поворота кузова.
	var target_position := global_position + Vector3.UP * camera_height
	var follow_weight := 1.0 - exp(-delta * 14.0)

	camera_rig.global_position = camera_rig.global_position.lerp(
		target_position,
		follow_weight
	)

	camera_rig.global_rotation = Vector3(
		camera_pitch,
		camera_yaw,
		0.0
	)


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
	# Отдельная камера-преследователь.
	# Она принадлежит этой машине, но не наследует её вращение.
	camera_rig = Node3D.new()
	camera_rig.name = "VehicleCameraRig"
	camera_rig.top_level = true
	add_child(camera_rig)

	camera_rig.global_position = global_position + Vector3.UP * camera_height
	camera_rig.global_rotation = Vector3(camera_pitch, camera_yaw, 0.0)

	camera_spring_arm = SpringArm3D.new()
	camera_spring_arm.name = "VehicleCameraSpringArm"
	camera_spring_arm.spring_length = camera_distance
	camera_spring_arm.margin = 0.25
	camera_spring_arm.collision_mask = 1
	camera_rig.add_child(camera_spring_arm)

	# Исключаем кузов этой машины из проверки столкновений камеры.
	camera_spring_arm.add_excluded_object(get_rid())

	vehicle_camera = Camera3D.new()
	vehicle_camera.name = "VehicleCamera"
	vehicle_camera.fov = 75.0
	vehicle_camera.near = 0.08
	vehicle_camera.far = Settings.view_distance
	camera_spring_arm.add_child(vehicle_camera)

	vehicle_camera.current = false


func _update_camera_transform(snap: bool = false) -> void:
	if not is_instance_valid(camera_rig):
		return

	var target_position := global_position + Vector3.UP * camera_height

	if snap:
		camera_rig.global_position = target_position

	camera_rig.global_rotation = Vector3(
		camera_pitch,
		camera_yaw,
		0.0
	)


func rotate_vehicle_camera(movement: Vector2, sensitivity: float) -> void:
	camera_yaw -= movement.x * sensitivity
	camera_pitch -= movement.y * sensitivity

	# Yaw не ограничиваем: можно облететь машину на 360 градусов.
	camera_pitch = clampf(camera_pitch, -0.65, 0.25)

	_update_camera_transform()


func apply_settings() -> void:
	if is_instance_valid(vehicle_camera):
		vehicle_camera.far = Settings.view_distance


func set_mobile_steering(value: float) -> void:
	mobile_steering = clampf(value, -1.0, 1.0)


func set_mobile_throttle(value: float) -> void:
	mobile_throttle = clampf(value, -1.0, 1.0)


func set_touch_input(value: Vector2) -> void:
	set_mobile_steering(value.x)
	set_mobile_throttle(-value.y)


func brake() -> void:
	brake_timer = maxf(brake_timer, 0.3)


func enter_vehicle(player: Node3D) -> void:
	if driving or ai_driving:
		return
	if not is_instance_valid(player):
		return

	driver = player
	driving = true
	camera_active = true

	mobile_steering = 0.0
	mobile_throttle = 0.0
	brake_timer = 0.0

	if driver.has_method("enter_vehicle"):
		driver.call("enter_vehicle", self)

	_update_camera_transform(true)

	# Переключаем активную камеру именно на эту машину.
	vehicle_camera.make_current()


func exit_vehicle(player: Node3D) -> void:
	if not driving or not is_instance_valid(player):
		return
	if player != driver:
		return

	driving = false
	camera_active = false

	mobile_steering = 0.0
	mobile_throttle = 0.0
	brake_timer = 0.0

	var exit_position := global_position + global_transform.basis.x * 2.5
	exit_position.y = maxf(exit_position.y, 1.0)

	if player.has_method("exit_vehicle"):
		player.call("exit_vehicle", exit_position)

	driver = null


func reserve_ai_driver(npc: Node3D) -> bool:
	if driving or ai_driving:
		return false
	if not is_instance_valid(npc):
		return false
	if is_instance_valid(ai_reserved_by) and ai_reserved_by != npc:
		return false

	ai_reserved_by = npc
	return true


func release_ai_reservation(npc: Node3D) -> void:
	if ai_reserved_by == npc:
		ai_reserved_by = null


func assign_ai_driver(npc: Node3D, destination: Vector3) -> bool:
	if driving or ai_driving or not is_instance_valid(npc):
		return false

	if is_instance_valid(ai_reserved_by) and ai_reserved_by != npc:
		return false

	ai_reserved_by = npc
	ai_driver = npc
	ai_destination = destination
	ai_time_left = 35.0
	ai_stuck_time = 0.0
	ai_last_position = global_position
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
	ai_reserved_by = null
	ai_time_left = 0.0
	ai_stuck_time = 0.0

	if is_instance_valid(old_driver):
		var exit_position := global_position + global_transform.basis.x * 2.5
		exit_position.y = maxf(exit_position.y, 1.0)

		if old_driver.has_method("exit_vehicle"):
			old_driver.call("exit_vehicle", exit_position)


func reset_upright() -> void:
	var current_position := global_position
	current_position.y = maxf(current_position.y, 1.0)
	global_position = current_position

	var flat_forward := -global_transform.basis.z
	flat_forward.y = 0.0

	if flat_forward.length_squared() < 0.01:
		flat_forward = Vector3.FORWARD

	flat_forward = flat_forward.normalized()

	var new_basis := Basis.looking_at(flat_forward, Vector3.UP)
	global_transform = Transform3D(new_basis, global_position)

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	mobile_steering = 0.0
	mobile_throttle = 0.0

	if camera_active:
		_update_camera_transform(true)


func _get_player_controls() -> Vector2:
	var steering := Input.get_axis("move_left", "move_right")
	var throttle := Input.get_axis("move_back", "move_forward")

	if absf(mobile_steering) > 0.04:
		steering = mobile_steering

	if absf(mobile_throttle) > 0.04:
		throttle = mobile_throttle

	return Vector2(steering, throttle)


func _get_ai_controls() -> Vector2:
	var local_target := global_transform.basis.inverse() * (ai_destination - global_position)
	var distance := global_position.distance_to(ai_destination)

	if distance < 7.0:
		ai_time_left = 0.0
		return Vector2.ZERO

	var desired_angle := atan2(local_target.x, -local_target.z)
	var steer := clampf(desired_angle * 1.5, -1.0, 1.0)

	var throttle := 0.65

	if absf(desired_angle) > 1.3:
		throttle = 0.18

	if local_target.z > 0.0:
		throttle = -0.3

	var space_state := get_world_3d().direct_space_state
	var forward := -global_transform.basis.z
	var ray_start := global_position + Vector3.UP * 0.8
	var ray_end := ray_start + forward * 5.0

	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, COLLISION_MASK, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var obstacle := space_state.intersect_ray(query)

	if not obstacle.is_empty():
		var normal: Vector3 = obstacle["normal"]
		var side := global_transform.basis.x.dot(normal)

		if absf(side) < 0.15:
			steer = 1.0 if randf() > 0.5 else -1.0
		else:
			steer = signf(side)

		throttle = -0.35

	if global_position.distance_to(ai_last_position) < 0.5:
		ai_stuck_time += get_physics_process_delta_time()
	else:
		ai_stuck_time = 0.0
		ai_last_position = global_position

	if ai_stuck_time > 3.0:
		throttle = -0.55
		steer = -1.0 if steer >= 0.0 else 1.0

	return Vector2(steer, throttle)


func _physics_process(delta: float) -> void:
	if ai_driving:
		ai_time_left -= delta
		if ai_time_left <= 0.0:
			release_ai_driver()

	if not driving and not ai_driving and linear_velocity.length() < 0.15:
		_apply_upright_stability()
		return

	var controls := Vector2.ZERO

	if driving:
		controls = _get_player_controls()
	elif ai_driving:
		controls = _get_ai_controls()

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
		var wants_opposite_direction := (
			(speed > 1.5 and throttle < 0.0)
			or (speed < -1.5 and throttle > 0.0)
		)

		if wants_opposite_direction:
			braking = true
		elif throttle > 0.0 and speed < max_speed:
			acceleration_force = engine_force * throttle
		elif throttle < 0.0 and speed > -reverse_speed:
			acceleration_force = engine_force * throttle * 0.55

	var state := get_world_3d().direct_space_state
	var up := global_transform.basis.y.normalized()

	for i in range(wheel_positions.size()):
		var mount_local: Vector3 = wheel_positions[i]
		var mount_global := global_transform * mount_local

		var ray_start := mount_global
		var ray_end := mount_global - up * (
			suspension_rest_length + suspension_travel + wheel_radius
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

		var hit_position: Vector3 = hit["position"]
		var distance := mount_global.distance_to(hit_position)
		var suspension_length := distance - wheel_radius

		var compression := clampf(
			suspension_rest_length - suspension_length,
			0.0,
			suspension_travel
		)

		var offset := hit_position - global_position
		var point_velocity := linear_velocity + angular_velocity.cross(offset)
		var suspension_velocity := point_velocity.dot(up)

		var spring_force := (
			compression * suspension_stiffness
			- suspension_velocity * suspension_damping
		)

		spring_force = clampf(spring_force, 0.0, 52000.0)
		apply_force(up * spring_force, offset)

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
			-lateral_speed * mass * lateral_grip,
			-friction_limit,
			friction_limit
		)

		apply_force(wheel_right * lateral_force_value, offset)

		if not wheel_steering[i] and absf(acceleration_force) > 0.0:
			apply_force(wheel_forward * acceleration_force * 0.5, offset)

		if braking:
			var brake_value := clampf(
				-longitudinal_speed * brake_force * 0.25,
				-brake_force * 0.25,
				brake_force * 0.25
			)
			apply_force(wheel_forward * brake_value, offset)

		var rolling_force := (
			-wheel_forward
			* longitudinal_speed
			* rolling_resistance
			* spring_force
		)
		apply_force(rolling_force, offset)

		wheel.rotation.x -= longitudinal_speed * delta / maxf(wheel_radius, 0.1)
		wheel.rotation.y = steer_angle

	if linear_velocity.length() > 0.5:
		apply_central_force(-linear_velocity * linear_velocity.length() * 0.32)

	_apply_upright_stability()

	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)

	if horizontal_velocity.length() > max_speed + 5.0:
		var limited := horizontal_velocity.normalized() * (max_speed + 5.0)
		linear_velocity.x = limited.x
		linear_velocity.z = limited.z

	if driving or ai_driving:
		AudioManager.set_engine_speed(absf(speed))
	else:
		AudioManager.stop_engine()


func _apply_upright_stability() -> void:
	var current_up := global_transform.basis.y.normalized()
	var correction_axis := current_up.cross(Vector3.UP)

	if correction_axis.length_squared() > 0.0001:
		var local_angular := angular_velocity
		var correction_torque := (
			correction_axis * upright_strength
			- local_angular * upright_damping
		)
		apply_torque(correction_torque)
