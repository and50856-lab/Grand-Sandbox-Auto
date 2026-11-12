extends CharacterBody3D

@export var move_speed := 1.5

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

var direction := Vector3.ZERO
var change_timer := 0.0
var animation_time := 0.0

var left_leg: Node3D
var right_leg: Node3D


func _ready() -> void:
	_build_collision()
	_build_character()
	_choose_direction()


func _build_collision() -> void:
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

	var shirt := colors[rng.randi_range(0, colors.size() - 1)]
	var pants := Color(0.12, 0.15, 0.20)
	var skin := Color(0.78, 0.58, 0.42)

	_add_capsule(
		self, 0.27, 0.78,
		Vector3(0, 1.0, 0), shirt
	)

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

	_add_capsule(
		left_leg, 0.14, 0.75,
		Vector3(0, -0.16, 0), pants
	)

	right_leg = Node3D.new()
	right_leg.position = Vector3(0.14, 0.55, 0)
	add_child(right_leg)

	_add_capsule(
		right_leg, 0.14, 0.75,
		Vector3(0, -0.16, 0), pants
	)


func _choose_direction() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var angle := rng.randf_range(0.0, TAU)
	direction = Vector3(cos(angle), 0, sin(angle))
	change_timer = rng.randf_range(2.0, 5.0)


func _physics_process(delta: float) -> void:
	animation_time += delta
	change_timer -= delta

	if change_timer <= 0.0:
		_choose_direction()

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = -0.5

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

	move_and_slide()

	if direction.length() > 0.1:
		rotation.y = lerp_angle(
			rotation.y,
			atan2(direction.x, direction.z),
			delta * 4.0
		)

	var walking := Vector2(
		velocity.x,
		velocity.z
	).length() > 0.2

	var swing := sin(animation_time * 6.0) * 0.4 if walking else 0.0

	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
