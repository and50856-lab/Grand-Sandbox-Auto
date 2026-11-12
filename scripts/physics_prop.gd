extends RigidBody3D

@export var object_color := Color(0.55, 0.30, 0.13)
@export var object_size := Vector3(1.3, 1.3, 1.3)

var mesh_instance: MeshInstance3D


func _ready() -> void:
	mass = 12.0
	gravity_scale = 1.0
	linear_damp = 0.12
	angular_damp = 0.5

	_build_object()


func _build_object() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = object_size
	collision.shape = shape
	add_child(collision)

	mesh_instance = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = object_size
	mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = object_color
	mat.roughness = 0.82
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	add_to_group("physics_props")
