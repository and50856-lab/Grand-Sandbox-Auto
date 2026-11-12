extends Node3D

const JOYSTICK = preload("res://scripts/virtual_joystick.gd")
const VEHICLE = preload("res://scripts/vehicle.gd")
const NPC = preload("res://scripts/npc.gd")
const PROP = preload("res://scripts/physics_prop.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var menu: CanvasLayer

var vehicles: Array[Node3D] = []
var npcs: Array[Node3D] = []

var game_started := false
var world_created := false

var status_label: Label
var sun: DirectionalLight3D


func _ready() -> void:
	_setup_input()
	_setup_environment()
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

	var exists := false

	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if event.physical_keycode == key:
				exists = true

	if not exists:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _setup_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()

	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()

	sky_material.sky_top_color = Color(0.12, 0.30, 0.55)
	sky_material.sky_horizon_color = Color(0.65, 0.76, 0.88)
	sky_material.ground_bottom_color = Color(0.12, 0.14, 0.12)
	sky_material.ground_horizon_color = Color(0.55, 0.62, 0.58)

	sky.sky_material = sky_material
	environment.sky = sky

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	environment.fog_enabled = true
	environment.fog_light_color = Color(0.60, 0.70, 0.78)
	environment.fog_density = 0.0008

	environment_node.environment = environment
	add_child(environment_node)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	add_child(sun)


func _apply_graphics_settings() -> void:
	if not is_instance_valid(sun):
		return

	sun.shadow_enabled = Settings.shadow_quality > 0

	if Settings.shadow_quality == 1:
		sun.directional_shadow_max_distance = 35.0
	elif Settings.shadow_quality >= 2:
		sun.directional_shadow_max_distance = 75.0

	if is_instance_valid(player) and is_instance_valid(player.camera):
		player.camera.far = Settings.view_distance


func _create_world() -> void:
	if world_created:
		return

	world_created = true

	_create_ground()
	_create_roads()
	_create_buildings()
	_create_trees()
	_create_props()
	_create_vehicles()
	_create_npcs()

	_apply_graphics_settings()


func _create_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(520, 1, 520)
	collision.shape = shape
	collision.position.y = -0.5
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(520, 1, 520)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.5
	mesh_instance.material_override = _material(
		Color(0.25, 0.39, 0.22)
	)
	body.add_child(mesh_instance)


func _create_roads() -> void:
	var road_material := _material(Color(0.105, 0.115, 0.13))
	var sidewalk_material := _material(Color(0.40, 0.41, 0.40))

	for i in range(-3, 4):
		var p := float(i) * 70.0

		_add_visual_box(
			"RoadVertical",
			Vector3(15, 0.08, 520),
			Vector3(p, 0.01, 0),
			road_material
		)

		_add_visual_box(
			"RoadHorizontal",
			Vector3(520, 0.08, 15),
			Vector3(0, 0.015, p),
			road_material
		)

		for side in [-1.0, 1.0]:
			_add_visual_box(
				"SidewalkVertical",
				Vector3(2.5, 0.12, 520),
				Vector3(p + side * 8.8, 0.07, 0),
				sidewalk_material
			)

			_add_visual_box(
				"SidewalkHorizontal",
				Vector3(520, 0.12, 2.5),
				Vector3(0, 0.07, p + side * 8.8),
				sidewalk_material
			)


func _add_visual_box(
	object_name: String,
	object_size: Vector3,
	object_position: Vector3,
	mat: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = object_name

	var mesh := BoxMesh.new()
	mesh.size = object_size

	instance.mesh = mesh
	instance.position = object_position
	instance.material_override = mat

	add_child(instance)
	return instance


func _create_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516

	var colors := [
		Color(0.53, 0.57, 0.62),
		Color(0.64, 0.48, 0.36),
		Color(0.40, 0.49, 0.56),
		Color(0.72, 0.69, 0.59),
		Color(0.34, 0.39, 0.43),
		Color(0.62, 0.63, 0.59)
	]

	for x in range(-3, 3):
		for z in range(-3, 3):
			var center := Vector3(
				float(x) * 70.0 + 35.0,
				0,
				float(z) * 70.0 + 35.0
			)

			if absf(center.x) < 60.0 and absf(center.z) < 60.0:
				continue

			if center.z > 85.0 and center.z < 165.0:
				continue

			var width := rng.randf_range(13.0, 20.0)
			var depth := rng.randf_range(13.0, 20.0)
			var height := rng.randf_range(10.0, 27.0)

			var offset := Vector3(
				rng.randf_range(-9.0, 9.0),
				height * 0.5,
				rng.randf_range(-9.0, 9.0)
			)

			_create_building(
				center + offset,
				Vector3(width, height, depth),
				colors[rng.randi_range(0, colors.size() - 1)]
			)


func _create_building(
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> void:
	var building := StaticBody3D.new()
	building.name = "Building"
	building.position = position_value
	add_child(building)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	building.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	building.add_child(mesh_instance)


func _create_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 998877

	var positions: Array[Transform3D] = []

	for i in range(70):
		var x := rng.randf_range(-240.0, 240.0)
		var z := rng.randf_range(-240.0, 240.0)

		if fposmod(absf(x) + 7.5, 70.0) < 15.0:
			continue

		if fposmod(absf(z) + 7.5, 70.0) < 15.0:
			continue

		if absf(x) < 38.0 and absf(z) < 38.0:
			continue

		var transform := Transform3D(
			Basis.IDENTITY,
			Vector3(x, 0, z)
		)

		positions.append(transform)

	_add_tree_multimesh(
		"Crowns",
		_sphere_mesh(1.0),
		_material(Color(0.10, 0.34, 0.12)),
		positions,
		Vector3(1.7, 2.0, 1.7),
		Vector3(0, 3.0, 0)
	)

	_add_tree_multimesh(
		"Trunks",
		_cylinder_mesh(),
		_material(Color(0.25, 0.14, 0.07)),
		positions,
		Vector3(0.35, 1.5, 0.35),
		Vector3(0, 1.0, 0)
	)


func _sphere_mesh(radius_value: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius_value
	mesh.height = radius_value * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


func _cylinder_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 6
	return mesh


func _add_tree_multimesh(
	object_name: String,
	mesh: Mesh,
	mat: Material,
	positions: Array[Transform3D],
	scale_value: Vector3,
	offset: Vector3
) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = positions.size()

	for i in range(positions.size()):
		var transform := Transform3D(
			Basis.IDENTITY.scaled(scale_value),
			positions[i].origin + offset
		)
		multi.set_instance_transform(i, transform)

	var instance := MultiMeshInstance3D.new()
	instance.name = object_name
	instance.multimesh = multi
	instance.material_override = mat
	add_child(instance)


func _create_props() -> void:
	for i in range(4):
		var prop := RigidBody3D.new()
		prop.set_script(PROP)

		prop.position = Vector3(
			-8.0 + float(i) * 3.0,
			1.0,
			-8.0
		)

		prop.set("object_color", Color(0.55, 0.30, 0.13))
		add_child(prop)


func _create_vehicles() -> void:
	var positions := [
		Vector3(8, 0.8, 10),
		Vector3(-16, 0.8, 5),
		Vector3(18, 0.8, -20),
		Vector3(-30, 0.8, -10)
	]

	var colors := [
		Color(0.75, 0.12, 0.10),
		Color(0.12, 0.30, 0.78),
		Color(0.80, 0.72, 0.16),
		Color(0.12, 0.52, 0.32)
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
	rng.seed = 123456

	var amount := clampi(Settings.npc_amount, 0, 10)

	for i in range(amount):
		var npc := CharacterBody3D.new()
		npc.set_script(NPC)

		npc.position = Vector3(
			rng.randf_range(-35.0, 35.0),
			0,
			rng.randf_range(-35.0, 35.0)
		)

		add_child(npc)
		npcs.append(npc)


func _show_menu() -> void:
	menu = CanvasLayer.new()
	menu.layer = 10
	add_child(menu)

	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.07, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "GRAND SANDBOX AUTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "OPEN WORLD • PHYSICS • FREEDOM"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	_menu_button(column, "ИГРАТЬ", _start_sandbox)
	_menu_button(column, "НАСТРОЙКИ", _show_settings)
	_menu_button(column, "ВЫХОД", func(): get_tree().quit())


func _menu_button(
	parent: VBoxContainer,
	text_value: String,
	action: Callable
) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 55)
	button.pressed.connect(action)
	parent.add_child(button)


func _show_settings() -> void:
	if is_instance_valid(menu):
		menu.queue_free()

	menu = CanvasLayer.new()
	menu.layer = 10
	add_child(menu)

	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.07, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)

	var title := Label.new()
	title.text = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	column.add_child(title)

	_add_setting_option(
		column,
		"Качество графики",
		["Низкое", "Среднее", "Высокое"],
		Settings.graphics_quality - 1,
		func(index: int):
			Settings.graphics_quality = index + 1
			Settings.apply_settings()
	)

	_add_setting_option(
		column,
		"Качество текстур",
		["Низкое", "Среднее", "Высокое"],
		Settings.texture_quality - 1,
		func(index: int):
			Settings.texture_quality = index + 1
	)

	_add_setting_option(
		column,
		"Тени",
		["Выключены", "Низкие", "Высокие"],
		Settings.shadow_quality,
		func(index: int):
			Settings.shadow_quality = index
			_apply_graphics_settings()
	)

	_add_setting_option(
		column,
		"Дальность прорисовки",
		["80 м", "120 м", "180 м", "250 м", "350 м", "500 м"],
		_distance_to_index(Settings.view_distance),
		func(index: int):
			var distances := [80.0, 120.0, 180.0, 250.0, 350.0, 500.0]
			Settings.view_distance = distances[index]
			_apply_graphics_settings()
	)

	_add_setting_option(
		column,
		"Количество NPC",
		["0", "2", "4", "6", "8", "10"],
		_npc_to_index(Settings.npc_amount),
		func(index: int):
			var amounts := [0, 2, 4, 6, 8, 10]
			Settings.npc_amount = amounts[index]
	)

	_add_setting_option(
		column,
		"Лимит FPS",
		["30", "45", "60", "90", "120"],
		_fps_to_index(Settings.target_fps),
		func(index: int):
			var values := [30, 45, 60, 90, 120]
			Settings.target_fps = values[index]
			Settings.apply_settings()
	)

	_menu_button(column, "СОХРАНИТЬ", func():
		Settings.save_settings()
		_show_menu()
	)

	_menu_button(column, "НАЗАД", _show_menu)


func _add_setting_option(
	parent: VBoxContainer,
	label_text: String,
	options: Array,
	selected_index: int,
	callback: Callable
) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	row.add_child(label)

	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for option in options:
		selector.add_item(str(option))

	selector.select(clampi(selected_index, 0, options.size() - 1))
	selector.item_selected.connect(callback)
	row.add_child(selector)


func _distance_to_index(value: float) -> int:
	var values := [80.0, 120.0, 180.0, 250.0, 350.0, 500.0]
	var best := 0
	var difference := INF

	for i in range(values.size()):
		var current := absf(values[i] - value)
		if current < difference:
			difference = current
			best = i

	return best


func _npc_to_index(value: int) -> int:
	var values := [0, 2, 4, 6, 8, 10]
	return values.find(value) if values.has(value) else 1


func _fps_to_index(value: int) -> int:
	var values := [30, 45, 60, 90, 120]
	return values.find(value) if values.has(value) else 2


func _start_sandbox() -> void:
	_start_game()


func _start_game() -> void:
	if game_started:
		return

	game_started = true

	if is_instance_valid(menu):
		menu.queue_free()

	_create_world()

	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0, 0.05, 15)
	add_child(player)

	_create_hud()
	_apply_graphics_settings()


func _create_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var joystick = JOYSTICK.new()
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 30.0
	joystick.offset_top = -205.0
	joystick.offset_right = 210.0
	joystick.offset_bottom = -25.0
	joystick.vector_changed.connect(_on_joystick)
	root.add_child(joystick)

	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.anchor_left = 1.0
	jump.anchor_top = 1.0
	jump.anchor_right = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -155.0
	jump.offset_top = -100.0
	jump.offset_right = -25.0
	jump.offset_bottom = -35.0
	jump.button_down.connect(func(): Input.action_press("jump"))
	jump.button_up.connect(func(): Input.action_release("jump"))
	root.add_child(jump)

	interact_button = Button.new()
	interact_button.text = "ВЗАИМОДЕЙСТВИЕ"
	interact_button.anchor_left = 1.0
	interact_button.anchor_top = 1.0
	interact_button.anchor_right = 1.0
	interact_button.anchor_bottom = 1.0
	interact_button.offset_left = -205.0
	interact_button.offset_top = -185.0
	interact_button.offset_right = -25.0
	interact_button.offset_bottom = -120.0
	interact_button.pressed.connect(_interact)
	root.add_child(interact_button)

	var menu_button := Button.new()
	menu_button.text = "МЕНЮ"
	menu_button.position = Vector2(20, 20)
	menu_button.size = Vector2(110, 50)
	menu_button.pressed.connect(_pause_to_menu)
	root.add_child(menu_button)

	status_label = Label.new()
	status_label.text = "SANDBOX | Пешком"
	status_label.anchor_left = 1.0
	status_label.anchor_right = 1.0
	status_label.offset_left = -300.0
	status_label.offset_right = -15.0
	status_label.offset_top = 20.0
	status_label.offset_bottom = 60.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(status_label)


func _on_joystick(value: Vector2) -> void:
	if is_instance_valid(player):
		player.set_touch_input(value)


func _interact() -> void:
	if is_instance_valid(player):
		player.interact()


func _pause_to_menu() -> void:
	get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	if not game_started or not is_instance_valid(player):
		return

	if player.in_vehicle:
		status_label.text = "SANDBOX | За рулём"
	else:
		status_label.text = "SANDBOX | Пешком"
