extends CharacterBody3D

@export var move_speed := 1.8

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var direction := Vector3.ZERO
var change_timer := 0.0
var body: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var animation_time := 0.0


func _ready() -> void:
	_build_collision()
	_build_character()
	_choose_direction()


func _build_collision() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7

	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.85
	add_child(collision)


func _part(
	name_value: String,
	mesh: PrimitiveMesh,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = name_value
	part.mesh = mesh
	part.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	part.material_override = mat
	body.add_child(part)
	return part


func _build_character() -> void:
	body = Node3D.new()
	body.name = "NPCModel"
	add_child(body)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var shirt_colors := [
		Color(0.15, 0.35, 0.75),
		Color(0.65, 0.18, 0.15),
		Color(0.18, 0.48, 0.28),
		Color(0.55, 0.42, 0.18),
		Color(0.30, 0.30, 0.34)
	]

	var shirt: Color = shirt_colors[rng.randi_range(0, shirt_colors.size() - 1)]

	var torso := CapsuleMesh.new()
	torso.radius = 0.27
	torso.height = 0.78
	_part("Torso", torso, Vector3(0, 1.0, 0), shirt)

	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	_part("Head", head, Vector3(0, 1.62, 0), Color(0.78, 0.58, 0.42))

	var pants := CapsuleMesh.new()
	pants.radius = 0.14
	pants.height = 0.75

	left_leg = Node3D.new()
	left_leg.position = Vector3(-0.14, 0.55, 0)
	body.add_child(left_leg)

	var leg_a := MeshInstance3D.new()
	leg_a.mesh = pants
	leg_a.position.y = -0.16
	leg_a.material_override = _simple_material(Color(0.12, 0.15, 0.20))
	left_leg.add_child(leg_a)

	right_leg = Node3D.new()
	right_leg.position = Vector3(0.14, 0.55, 0)
	body.add_child(right_leg)

	var leg_b := MeshInstance3D.new()
	leg_b.mesh = pants
	leg_b.position.y = -0.16
	leg_b.material_override = _simple_material(Color(0.12, 0.15, 0.20))
	right_leg.add_child(leg_b)

	left_arm = _create_arm(Vector3(-0.34, 1.18, 0), shirt)
	right_arm = _create_arm(Vector3(0.34, 1.18, 0), shirt)


func _simple_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _create_arm(pos: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	body.add_child(pivot)

	var arm := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.105
	mesh.height = 0.62
	arm.mesh = mesh
	arm.position.y = -0.23
	arm.material_override = _simple_material(color)
	pivot.add_child(arm)

	return pivot


func _choose_direction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var angle := rng.randf_range(0.0, TAU)
	direction = Vector3(cos(angle), 0, sin(angle))
	change_timer = rng.randf_range(2.0, 6.0)


func _physics_process(delta: float) -> void:
	animation_time += delta
	change_timer -= delta

	if change_timer <= 0.0:
		_choose_direction()

	if not is_on_floor():
		velocity.y -= gravity * delta

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

	move_and_slide()

	if direction.length() > 0.1:
		rotation.y = lerp_angle(
			rotation.y,
			atan2(direction.x, direction.z),
			delta * 4.0
		)

	var walking := Vector2(velocity.x, velocity.z).length() > 0.2
	var swing := sin(animation_time * 7.0) * 0.45 if walking else 0.0

	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing * 0.7
	right_arm.rotation.x = swing * 0.7
