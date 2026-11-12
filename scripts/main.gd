extends Node3D

const JOYSTICK = preload("res://scripts/virtual_joystick.gd")
const VEHICLE = preload("res://scripts/vehicle.gd")
const NPC = preload("res://scripts/npc.gd")
const PROP = preload("res://scripts/physics_prop.gd")
const AUDIO = preload("res://scripts/audio_manager.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var menu: CanvasLayer
var audio_manager: Node

var vehicles: Array[Node3D] = []
var npcs: Array[Node3D] = []

var game_started := false
var current_mode := "sandbox"
var world_seed := 481516

var status_label: Label
var interact_button: Button


func _ready() -> void:
	_setup_input()
	_setup_environment()
	_generate_world()
	_create_audio()
	_show_menu()


func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("interact", KEY_E)
	_add_key("run", KEY_SHIFT)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.30, 0.55)
	sky_material.sky_horizon_color = Color(0.65, 0.76, 0.88)
	sky_material.ground_bottom_color = Color(0.12, 0.14, 0.12)
	sky_material.ground_horizon_color = Color(0.55, 0.62, 0.58)
	sky.sky_material = sky_material

	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.60, 0.70, 0.78)
	env.fog_density = 0.0015

	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _generate_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	_create_ground()
	_create_roads()
	_create_city(rng)
	_create_park(rng)
	_create_trees(rng)
	_create_props()
	_create_vehicles()
	_create_npcs()


func _material(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _box(
	parent: Node3D,
	name: String,
	size: Vector3,
	pos: Vector3,
	color: Color,
	collision := true,
	roughness := 0.85,
	metallic := 0.0
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _material(color, roughness, metallic)
	parent.add_child(mesh_instance)

	if collision:
		var body := StaticBody3D.new()
		body.name = name + "_Collision"
		body.position = pos

		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		parent.add_child(body)

	return mesh_instance


func _create_ground() -> void:
	_box(
		self,
		"WorldGround",
		Vector3(640, 1, 640),
		Vector3(0, -0.55, 0),
		Color(0.25, 0.39, 0.22)
	)


func _create_roads() -> void:
	var road_mat := Color(0.105, 0.115, 0.13)
	var sidewalk_mat := Color(0.42, 0.43, 0.42)
	var line_mat := Color(0.92, 0.83, 0.56)

	# Главные улицы.
	for i in range(-3, 4):
		var p := float(i) * 80.0

		_box(
			self, "Road_X",
			Vector3(18, 0.12, 640),
			Vector3(p, 0.02, 0),
			road_mat, false
		)

		_box(
			self, "Road_Z",
			Vector3(640, 0.12, 18),
			Vector3(0, 0.025, p),
			road_mat, false
		)

		# Тротуары по краям дорог.
		for side in [-1.0, 1.0]:
			_box(
				self, "Sidewalk_X",
				Vector3(3.0, 0.22, 640),
				Vector3(p + side * 10.5, 0.08, 0),
				sidewalk_mat, false
			)

			_box(
				self, "Sidewalk_Z",
				Vector3(640, 0.22, 3.0),
				Vector3(0, 0.08, p + side * 10.5),
				sidewalk_mat, false
			)

	# Пунктирная разметка.
	for i in range(-31, 32):
		var p := float(i) * 10.0

		for j in range(-3, 4):
			var road_pos := float(j) * 80.0

			_box(
				self, "RoadMark_X",
				Vector3(0.22, 0.035, 3.2),
				Vector3(road_pos, 0.095, p),
				line_mat, false
			)

			_box(
				self, "RoadMark_Z",
				Vector3(3.2, 0.035, 0.22),
				Vector3(p, 0.095, road_pos),
				line_mat, false
			)


func _create_city(rng: RandomNumberGenerator) -> void:
	var building_colors := [
		Color(0.53, 0.57, 0.62),
		Color(0.64, 0.48, 0.36),
		Color(0.40, 0.49, 0.56),
		Color(0.72, 0.69, 0.59),
		Color(0.34, 0.39, 0.43),
		Color(0.62, 0.63, 0.59),
		Color(0.48, 0.43, 0.40)
	]

	for x in range(-3, 3):
		for z in range(-3, 3):
			var center := Vector3(
				float(x) * 80.0 + 40.0,
				0,
				float(z) * 80.0 + 40.0
			)

			# Не застраиваем центральную стартовую зону.
			if absf(center.x) < 65.0 and absf(center.z) < 65.0:
				continue

			var count := rng.randi_range(2, 4)

			for n in range(count):
				var width := rng.randf_range(12.0, 22.0)
				var depth := rng.randf_range(12.0, 22.0)
				var height := rng.randf_range(9.0, 35.0)

				var offset := Vector3(
					rng.randf_range(-24.0, 24.0),
					height * 0.5,
					rng.randf_range(-24.0, 24.0)
				)

				var building := Node3D.new()
				building.name = "Building"
				building.position = center + offset
				add_child(building)

				var color: Color = building_colors[
					rng.randi_range(0, building_colors.size() - 1)
				]

				_box(
					building, "BuildingBody",
					Vector3(width, height, depth),
					Vector3.ZERO,
					color
				)

				# Крыша.
				_box(
					building, "Roof",
					Vector3(width + 0.3, 0.35, depth + 0.3),
					Vector3(0, height * 0.5 + 0.17, 0),
					Color(0.19, 0.21, 0.23)
				)

				# Полосы окон на фасадах.
				var floors := int(height / 3.2)

				for floor_index in range(floors):
					var y := -height * 0.5 + 2.0 + float(floor_index) * 3.0

					for side in [-1.0, 1.0]:
						for window_index in range(2):
							var wx := -width * 0.25 + float(window_index) * width * 0.5

							_box(
								building, "Window",
								Vector3(width * 0.27, 1.35, 0.12),
								Vector3(wx, y, side * (depth * 0.5 + 0.07)),
								Color(0.13, 0.27, 0.36),
								false,
								0.25,
								0.25
							)

				# Дверь.
				_box(
					building, "Entrance",
					Vector3(2.0, 2.7, 0.15),
					Vector3(0, -height * 0.5 + 1.35, depth * 0.5 + 0.09),
					Color(0.18, 0.12, 0.09),
					false,
					0.5
				)


func _create_park(rng: RandomNumberGenerator) -> void:
	var park := Node3D.new()
	park.name = "CentralPark"
	park.position = Vector3(0, 0.04, 125)
	add_child(park)

	_box(
		park, "ParkGrass",
		Vector3(55, 0.12, 48),
		Vector3.ZERO,
		Color(0.19, 0.43, 0.19),
		false
	)

	_box(
		park, "ParkPath",
		Vector3(5, 0.08, 45),
		Vector3.ZERO,
		Color(0.56, 0.52, 0.42),
		false
	)

	for i in range(18):
		var x := rng.randf_range(-24.0, 24.0)
		var z := rng.randf_range(-20.0, 20.0)

		if absf(x) < 4.0:
			continue

		_add_tree(Vector3(x, 0, z + 125), rng)


func _create_trees(rng: RandomNumberGenerator) -> void:
	for i in range(100):
		var pos := Vector3(
			rng.randf_range(-300.0, 300.0),
			0,
			rng.randf_range(-300.0, 300.0)
		)

		# Не ставим деревья на проезжей части.
		if fposmod(absf(pos.x) + 10.0, 80.0) < 18.0:
			continue
		if fposmod(absf(pos.z) + 10.0, 80.0) < 18.0:
			continue

		_add_tree(pos, rng)


func _add_tree(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = pos
	add_child(tree)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 2.8
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.4
	trunk.material_override = _material(Color(0.25, 0.14, 0.07))
	tree.add_child(trunk)

	var leaves := MeshInstance3D.new()
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = rng.randf_range(1.3, 2.1)
	leaf_mesh.height = 3.8
	leaves.mesh = leaf_mesh
	leaves.position.y = 3.6
	leaves.material_override = _material(
		Color(
			rng.randf_range(0.07, 0.16),
			rng.randf_range(0.28, 0.43),
			0.10
		)
	)
	tree.add_child(leaves)

	var body := StaticBody3D.new()
	body.position.y = 1.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 2.8
	shape.shape = capsule
	body.add_child(shape)
	tree.add_child(body)


func _create_props() -> void:
	for i in range(12):
		var prop := RigidBody3D.new()
		prop.set_script(PROP)
		prop.position = Vector3(
			-12.0 + float(i % 4) * 3.0,
			1.5 + float(i / 4) * 2.0,
			-12.0 - float(i % 3) * 2.0
		)
		prop.set("object_color", Color(0.55, 0.30, 0.13))
		add_child(prop)


func _create_vehicles() -> void:
	var positions := [
		Vector3(7, 0.8, 10),
		Vector3(-16, 0.8, 5),
		Vector3(18, 0.8, -20),
		Vector3(-30, 0.8, -10),
		Vector3(40, 0.8, 20)
	]

	var colors := [
		Color(0.75, 0.12, 0.10),
		Color(0.12, 0.30, 0.78),
		Color(0.80, 0.72, 0.16),
		Color(0.12, 0.52, 0.32),
		Color(0.16, 0.17, 0.19)
	]

	for i in range(positions.size()):
		var car := RigidBody3D.new()
		car.set_script(VEHICLE)
		car.position = positions[i]
		car.rotation.y = PI if i % 2 == 0 else 0.0
		car.set("body_color", colors[i])
		car.name = "Vehicle_%02d" % i
		add_child(car)
		vehicles.append(car)


func _create_npcs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in range(14):
		var npc := CharacterBody3D.new()
		npc.set_script(NPC)
		npc.position = Vector3(
			rng.randf_range(-55.0, 55.0),
			0,
			rng.randf_range(-55.0, 55.0)
		)
		add_child(npc)
		npcs.append(npc)


func _create_audio() -> void:
	audio_manager = Node.new()
	audio_manager.set_script(AUDIO)
	add_child(audio_manager)


func _show_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)

	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.07, 0.96)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title := Label.new()
	title.text = "GRAND SANDBOX AUTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "OPEN WORLD  •  PHYSICS  •  FREEDOM"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	_menu_button(column, "ИГРАТЬ", _start_sandbox)
	_menu_button(column, "ИСПЫТАНИЯ", _start_challenges)
	_menu_button(column, "ВЫХОД", func(): get_tree().quit())


func _menu_button(parent: VBoxContainer, text_value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 58)
	button.pressed.connect(action)
	parent.add_child(button)


func _start_sandbox() -> void:
	_start_game("sandbox")


func _start_challenges() -> void:
	_start_game("challenges")


func _start_game(mode: String) -> void:
	if game_started:
		return

	game_started = true
	current_mode = mode

	if is_instance_valid(menu):
		menu.queue_free()

	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0, 0, 12)
	player.name = "Player"
	add_child(player)

	_create_hud()


func _create_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var joystick = JOYSTICK.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(35, -215)
	joystick.size = Vector2(190, 190)
	joystick.vector_changed.connect(_on_joystick)
	root.add_child(joystick)

	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump.position = Vector2(-180, -115)
	jump.size = Vector2(145, 70)
	jump.button_down.connect(func(): Input.action_press("jump"))
	jump.button_up.connect(func(): Input.action_release("jump"))
	root.add_child(jump)

	interact_button = Button.new()
	interact_button.text = "ВЗАИМОДЕЙСТВИЕ"
	interact_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.position = Vector2(-190, -205)
	interact_button.size = Vector2(170, 65)
	interact_button.pressed.connect(_interact)
	root.add_child(interact_button)

	var menu_button := Button.new()
	menu_button.text = "МЕНЮ"
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu_button.position = Vector2(20, 20)
	menu_button.size = Vector2(110, 52)
	menu_button.pressed.connect(func(): get_tree().reload_current_scene())
	root.add_child(menu_button)

	status_label = Label.new()
	status_label.text = "SANDBOX  |  Пешком"
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_label.position = Vector2(-330, 22)
	status_label.size = Vector2(310, 45)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(status_label)


func _on_joystick(value: Vector2) -> void:
	if not is_instance_valid(player):
		return

	if player.has_method("set_touch_input"):
		player.set_touch_input(value)


func _interact() -> void:
	if is_instance_valid(player) and player.has_method("interact"):
		player.interact()


func _process(_delta: float) -> void:
	if not game_started or not is_instance_valid(player):
		return

	if player.get("in_vehicle") == true:
		status_label.text = "SANDBOX  |  За рулём"
	else:
		status_label.text = "SANDBOX  |  Пешком"
