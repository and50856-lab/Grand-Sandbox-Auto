extends CharacterBody3D

@export var move_speed: float = 3.0
@export var vehicle_search_distance: float = 42.0
@export var vehicle_drive_distance: float = 55.0

enum NPCState {
	WANDERING,
	APPROACHING_VEHICLE,
	DRIVING
}

var state: NPCState = NPCState.WANDERING

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

var direction := Vector3.ZERO
var change_timer := 0.0
var animation_time := 0.0
var vehicle_cooldown := 0.0
var obstacle_timer := 0.0

var left_leg: Node3D
var right_leg: Node3D

var target_vehicle: Node3D = null
var current_vehicle: Node3D = null
var approach_position := Vector3.ZERO

const WORLD_LIMIT := 180.0


func _ready() -> void:
	add_to_group("npcs")
	_build_collision()
	_build_character()
	_choose_direction()


func _build_collision() -> void:
	# NPC находится на отдельном слое.
	# Он взаимодействует с миром и транспортом,
	# но не сталкивается с игроком и другими NPC.
	collision_layer = 2
	collision_mask = 1

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	add_child(collision)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _add_capsule(
	parent: Node3D,
	radius: float,
	height: float,
	position_value: Vector3,
	color: Color
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _make_material(color)
	parent.add_child(instance)
	return instance


func _build_character() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var colors := [
		Color(0.15, 0.35, 0.75),
		Color(0.65, 0.18, 0.15),
		Color(0.18, 0.48, 0.28),
		Color(0.55, 0.42, 0.18),
		Color(0.30, 0.30, 0.34)
	]

	var shirt: Color = colors[rng.randi_range(0, colors.size() - 1)]
	var pants := Color(0.12, 0.15, 0.20)
	var skin := Color(0.78, 0.58, 0.42)

	_add_capsule(self, 0.27, 0.78, Vector3(0, 1.0, 0), shirt)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position = Vector3(0, 1.62, 0)
	head.material_override = _make_material(skin)
	add_child(head)

	left_leg = Node3D.new()
	left_leg.position = Vector3(-0.14, 0.55, 0)
	add_child(left_leg)
	_add_capsule(left_leg, 0.14, 0.75, Vector3(0, -0.16, 0), pants)

	right_leg = Node3D.new()
	right_leg.position = Vector3(0.14, 0.55, 0)
	add_child(right_leg)
	_add_capsule(right_leg, 0.14, 0.75, Vector3(0, -0.16, 0), pants)


func _choose_direction() -> void:
	var angle := randf_range(0.0, TAU)
	direction = Vector3(cos(angle), 0.0, sin(angle))
	change_timer = randf_range(2.0, 5.0)


func _release_target_reservation() -> void:
	if is_instance_valid(target_vehicle):
		if target_vehicle.has_method("release_ai_reservation"):
			target_vehicle.call("release_ai_reservation", self)

	target_vehicle = null


func _find_vehicle() -> void:
	if vehicle_cooldown > 0.0:
		return

	var nearest: Node3D = null
	var nearest_distance := vehicle_search_distance

	for item in get_tree().get_nodes_in_group("vehicles"):
		if not item is Node3D:
			continue

		var vehicle := item as Node3D

		if not is_instance_valid(vehicle):
			continue
		if vehicle.get("driving") == true:
			continue
		if vehicle.get("ai_driving") == true:
			continue
		if vehicle.get("ai_reserved_by") != null:
			continue
		if not vehicle.has_method("reserve_ai_driver"):
			continue

		var distance := global_position.distance_to(vehicle.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = vehicle

	if not is_instance_valid(nearest):
		return

	var reserved: bool = nearest.call("reserve_ai_driver", self)

	if not reserved:
		return

	target_vehicle = nearest

	var side := nearest.global_transform.basis.x
	approach_position = nearest.global_position + side * 1.9
	approach_position.y = global_position.y

	state = NPCState.APPROACHING_VEHICLE


func _physics_process(delta: float) -> void:
	animation_time += delta
	vehicle_cooldown = maxf(vehicle_cooldown - delta, 0.0)
	obstacle_timer = maxf(obstacle_timer - delta, 0.0)

	if state == NPCState.DRIVING:
		_update_walking_animation(false)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	match state:
		NPCState.WANDERING:
			_update_wandering(delta)
		NPCState.APPROACHING_VEHICLE:
			_update_approaching(delta)

	move_and_slide()

	var walking := Vector2(velocity.x, velocity.z).length() > 0.2
	_update_walking_animation(walking)


func _update_wandering(delta: float) -> void:
	change_timer -= delta

	# Не даём NPC уйти за пределы игрового мира.
	if absf(global_position.x) > WORLD_LIMIT or absf(global_position.z) > WORLD_LIMIT:
		direction = Vector3(
			-global_position.x,
			0.0,
			-global_position.z
		).normalized()

		change_timer = 2.5

	if change_timer <= 0.0:
		_choose_direction()

		if randf() < 0.35:
			_find_vehicle()

	if obstacle_timer <= 0.0:
		_check_walking_obstacle()

	velocity.x = move_toward(
		velocity.x,
		direction.x * move_speed,
		4.0 * delta
	)

	velocity.z = move_toward(
		velocity.z,
		direction.z * move_speed,
		4.0 * delta
	)

	if direction.length() > 0.1:
		rotation.y = lerp_angle(
			rotation.y,
			atan2(direction.x, direction.z),
			delta * 4.0
		)


func _check_walking_obstacle() -> void:
	obstacle_timer = 0.45

	if direction.length_squared() < 0.01:
		return

	var space_state := get_world_3d().direct_space_state
	var start := global_position + Vector3.UP * 0.8
	var finish := start + direction.normalized() * 2.0

	var query := PhysicsRayQueryParameters3D.create(
		start,
		finish,
		0xFFFFFFFF,
		[get_rid()]
	)

	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := space_state.intersect_ray(query)

	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]
		var tangent := direction.slide(normal)

		if tangent.length_squared() > 0.01:
			direction = tangent.normalized()
		else:
			_choose_direction()

		change_timer = 1.5


func _update_approaching(delta: float) -> void:
	if not is_instance_valid(target_vehicle):
		_release_target_reservation()
		state = NPCState.WANDERING
		_choose_direction()
		return

	if target_vehicle.get("driving") == true or target_vehicle.get("ai_driving") == true:
		_release_target_reservation()
		state = NPCState.WANDERING
		_choose_direction()
		return

	var to_target := approach_position - global_position
	to_target.y = 0.0

	if to_target.length() < 1.8:
		var destination := global_position + Vector3(
			randf_range(-vehicle_drive_distance, vehicle_drive_distance),
			0.0,
			randf_range(-vehicle_drive_distance, vehicle_drive_distance)
		)

		destination.x = clampf(destination.x, -150.0, 150.0)
		destination.z = clampf(destination.z, -150.0, 150.0)

		var accepted: bool = target_vehicle.call(
			"assign_ai_driver",
			self,
			destination
		)

		if accepted:
			return

		_release_target_reservation()
		state = NPCState.WANDERING
		_choose_direction()
		return

	direction = to_target.normalized()

	velocity.x = move_toward(
		velocity.x,
		direction.x * move_speed,
		5.0 * delta
	)

	velocity.z = move_toward(
		velocity.z,
		direction.z * move_speed,
		5.0 * delta
	)

	rotation.y = lerp_angle(
		rotation.y,
		atan2(direction.x, direction.z),
		delta * 5.0
	)


func enter_vehicle(vehicle: Node3D) -> void:
	_release_target_reservation()

	current_vehicle = vehicle
	target_vehicle = null
	state = NPCState.DRIVING

	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	visible = false


func exit_vehicle(position_out: Vector3) -> void:
	global_position = position_out
	velocity = Vector3.ZERO

	collision_layer = 2
	collision_mask = 1
	visible = true

	current_vehicle = null
	target_vehicle = null
	state = NPCState.WANDERING
	vehicle_cooldown = 30.0
	_choose_direction()


func _update_walking_animation(walking: bool) -> void:
	var swing := sin(animation_time * 6.0) * 0.4 if walking else 0.0

	if is_instance_valid(left_leg):
		left_leg.rotation.x = swing

	if is_instance_valid(right_leg):
		right_leg.rotation.x = -swing
