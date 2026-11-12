extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const VEHICLE_SCRIPT = preload("res://scripts/vehicle.gd")
const NPC_SCRIPT = preload("res://scripts/npc.gd")
const PROP_SCRIPT = preload("res://scripts/physics_prop.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")

const WORLD_SIZE := 420.0
const ROAD_WIDTH := 12.0
const BUILDING_SPACING := 42.0
const TREE_COUNT := 36

var player: CharacterBody3D
var joystick: Control
var interact_button: Button
var jump_button: Button
var hud_layer: CanvasLayer
var menu_layer: CanvasLayer
var settings_layer: CanvasLayer
var status_label: Label

var game_started := false
var current_mode := "sandbox"


func _ready() -> void:
	_apply_graphics_settings()
	_show_main_menu()


func _process(_delta: float) -> void:
	if not game_started:
		return

	if is_instance_valid(player):
		var in_vehicle: bool = player.get("in_vehicle") == true

		if is_instance_valid(interact_button):
			interact_button.text = "Выйти из машины" if in_vehicle else "Взаимодействие"

		if is_instance_valid(status_label):
			status_label.text = "В машине" if in_vehicle else "ПЕШЕХОД"


# ==================================================
# ГЛАВНОЕ МЕНЮ
# ==================================================

func _show_main_menu() -> void:
	_clear_layer(menu_layer)

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.025, 0.035, 0.055, 1.0)
	menu_layer.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "GRAND SANDBOX AUTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Открытый мир · Песочница"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	column.add_child(subtitle)

	_add_menu_button(column, "ИГРАТЬ", _start_game)
	_add_menu_button(column, "НАСТРОЙКИ", _show_settings)
	_add_menu_button(column, "ВЫХОД", _exit_game)


func _add_menu_button(
	parent: VBoxContainer,
	caption: String,
	callback: Callable
) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)


func _exit_game() -> void:
	get_tree().quit()


# ==================================================
# ЗАПУСК ИГРЫ
# ==================================================

func _start_game() -> void:
	if game_started:
		return

	game_started = true
	current_mode = "sandbox"

	_clear_layer(menu_layer)
	menu_layer = null

	_create_world()
	_create_player()
	_create_vehicles()
	_create_npcs()
	_create_props()
	_create_hud()


func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	add_child(player)
	player.global_position = Vector3(0, 1.5, 0)


# ==================================================
# МИР
# ==================================================

func _create_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.72, 0.85)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = Settings.shadow_quality > 0
	add_child(sun)

	_create_ground()
	_create_roads()
	_create_buildings()
	_create_trees()


func _create_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(WORLD_SIZE, 1.0, WORLD_SIZE)

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position.y = -0.5
	visual.material_override = _make_material(Color(0.19, 0.31, 0.18))
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position.y = -0.5
	body.add_child(collision)


func _create_roads() -> void:
	var road_material := _make_material(Color(0.12, 0.13, 0.15))
	var marking_material := _make_material(Color(0.85, 0.78, 0.48))

	for i in range(-3, 4):
		var offset := float(i) * BUILDING_SPACING

		_add_box_visual(
			"Road_X_%d" % i,
			Vector3(WORLD_SIZE, 0.12, ROAD_WIDTH),
			Vector3(0, 0.07, offset),
			road_material
		)

		_add_box_visual(
			"Road_Z_%d" % i,
			Vector3(ROAD_WIDTH, 0.12, WORLD_SIZE),
			Vector3(offset, 0.075, 0),
			road_material
		)

		for mark in range(-4, 5):
			_add_box_visual(
				"Mark_X_%d_%d" % [i, mark],
				Vector3(4.0, 0.025, 0.18),
				Vector3(float(mark) * 35.0, 0.145, offset),
				marking_material
			)

			_add_box_visual(
				"Mark_Z_%d_%d" % [i, mark],
				Vector3(0.18, 0.025, 4.0),
				Vector3(offset, 0.15, float(mark) * 35.0),
				marking_material
			)


func _create_buildings() -> void:
	var building_materials: Array[Material] = [
		_make_material(Color(0.43, 0.46, 0.51)),
		_make_material(Color(0.53, 0.42, 0.34)),
		_make_material(Color(0.36, 0.43, 0.48)),
		_make_material(Color(0.48, 0.49, 0.40))
	]

	for x in range(-3, 4):
		for z in range(-3, 4):
			if x == 0 or z == 0:
				continue

			var position := Vector3(
				float(x) * BUILDING_SPACING + 20.0,
				0,
				float(z) * BUILDING_SPACING + 20.0
			)

			var height := 10.0 + float((abs(x * 7 + z * 3)) % 4) * 3.0

			_add_building(
				"Building_%d_%d" % [x, z],
				position,
				Vector3(17.0, height, 17.0),
				building_materials[abs(x + z) % building_materials.size()]
			)


func _add_building(
	building_name: String,
	position: Vector3,
	building_size: Vector3,
	material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = building_name
	body.position = position + Vector3(0, building_size.y * 0.5, 0)
	add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = building_size

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = building_size
	collision.shape = shape
	body.add_child(collision)


func _create_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 2.8

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.5
	crown_mesh.height = 3.0

	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = TREE_COUNT

	var crown_multi := MultiMesh.new()
	crown_multi.transform_format = MultiMesh.TRANSFORM_3D
	crown_multi.mesh = crown_mesh
	crown_multi.instance_count = TREE_COUNT

	var index := 0

	for x in range(-3, 4):
		for z in range(-3, 4):
			if x == 0 or z == 0:
				continue

			if index >= TREE_COUNT:
				break

			var px := float(x) * BUILDING_SPACING + 8.0
			var pz := float(z) * BUILDING_SPACING + 8.0
			var position := Vector3(px, 1.4, pz)

			trunk_multi.set_instance_transform(
				index,
				Transform3D(Basis.IDENTITY, position)
			)

			crown_multi.set_instance_transform(
				index,
				Transform3D(Basis.IDENTITY, position + Vector3(0, 2.5, 0))
			)

			index += 1

		if index >= TREE_COUNT:
			break

	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.multimesh = trunk_multi
	trunk_instance.material_override = _make_material(Color(0.28, 0.17, 0.10))
	add_child(trunk_instance)

	var crown_instance := MultiMeshInstance3D.new()
	crown_instance.multimesh = crown_multi
	crown_instance.material_override = _make_material(Color(0.12, 0.34, 0.14))
	add_child(crown_instance)


# ==================================================
# ТРАНСПОРТ И ОБЪЕКТЫ
# ==================================================

func _create_vehicles() -> void:
	var positions: Array[Vector3] = [
		Vector3(7, 1.0, 7),
		Vector3(-18, 1.0, 7),
		Vector3(7, 1.0, -18),
		Vector3(22, 1.0, 22)
	]

	for i in range(positions.size()):
		var vehicle := RigidBody3D.new()
		vehicle.name = "Vehicle_%d" % i
		vehicle.set_script(VEHICLE_SCRIPT)
		add_child(vehicle)
		vehicle.global_position = positions[i]


func _create_npcs() -> void:
	var count: int = clampi(Settings.npc_amount, 0, 10)

	for i in range(count):
		var npc := CharacterBody3D.new()
		npc.name = "NPC_%d" % i
		npc.set_script(NPC_SCRIPT)
		add_child(npc)

		var angle := TAU * float(i) / maxf(float(count), 1.0)
		npc.global_position = Vector3(
			cos(angle) * 16.0,
			1.2,
			sin(angle) * 16.0
		)


func _create_props() -> void:
	var positions: Array[Vector3] = [
		Vector3(5, 1.0, 15),
		Vector3(-5, 1.0, 15),
		Vector3(15, 1.0, -5),
		Vector3(-15, 1.0, -5)
	]

	for i in range(positions.size()):
		var prop := RigidBody3D.new()
		prop.name = "PhysicsProp_%d" % i
		prop.set_script(PROP_SCRIPT)
		add_child(prop)
		prop.global_position = positions[i]


func _add_box_visual(
	object_name: String,
	box_size: Vector3,
	position: Vector3,
	material: Material
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size

	var visual := MeshInstance3D.new()
	visual.name = object_name
	visual.mesh = mesh
	visual.position = position
	visual.material_override = material
	add_child(visual)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


# ==================================================
# HUD И УПРАВЛЕНИЕ
# ==================================================

func _create_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_layer.add_child(root)

	joystick = Control.new()
	joystick.set_script(JOYSTICK_SCRIPT)
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 35
	joystick.offset_top = -205
	joystick.offset_right = 215
	joystick.offset_bottom = -25
	root.add_child(joystick)

	if joystick.has_signal("vector_changed"):
		joystick.connect("vector_changed", _on_joystick)

	var right_column := VBoxContainer.new()
	right_column.anchor_left = 1.0
	right_column.anchor_top = 1.0
	right_column.anchor_right = 1.0
	right_column.anchor_bottom = 1.0
	right_column.offset_left = -190
	right_column.offset_top = -250
	right_column.offset_right = -25
	right_column.offset_bottom = -25
	right_column.add_theme_constant_override("separation", 10)
	root.add_child(right_column)

	jump_button = Button.new()
	jump_button.text = "ПРЫЖОК"
	jump_button.custom_minimum_size = Vector2(155, 55)
	jump_button.pressed.connect(_jump)
	right_column.add_child(jump_button)

	interact_button = Button.new()
	interact_button.text = "ВЗАИМОДЕЙСТВИЕ"
	interact_button.custom_minimum_size = Vector2(155, 55)
	interact_button.pressed.connect(_interact)
	right_column.add_child(interact_button)

	var menu_button := Button.new()
	menu_button.text = "МЕНЮ"
	menu_button.custom_minimum_size = Vector2(155, 50)
	menu_button.pressed.connect(_return_to_menu)
	right_column.add_child(menu_button)

	status_label = Label.new()
	status_label.text = "ПЕШЕХОД"
	status_label.position = Vector2(25, 20)
	status_label.add_theme_font_size_override("font_size", 20)
	root.add_child(status_label)


func _on_joystick(value: Vector2) -> void:
	if is_instance_valid(player) and player.has_method("set_touch_input"):
		player.call("set_touch_input", value)


func _jump() -> void:
	if not is_instance_valid(player):
		return

	if player.has_method("jump"):
		player.call("jump")


func _interact() -> void:
	if not is_instance_valid(player):
		return

	if player.has_method("interact"):
		player.call("interact")


func _return_to_menu() -> void:
	game_started = false

	if is_instance_valid(hud_layer):
		hud_layer.queue_free()
		hud_layer = null

	if is_instance_valid(player):
		player.queue_free()
		player = null

	for child in get_children():
		var child_name := str(child.name)

		if child is WorldEnvironment or child is DirectionalLight3D:
			child.queue_free()
		elif child_name == "Ground" \
		or child_name.begins_with("Road_") \
		or child_name.begins_with("Mark_") \
		or child_name.begins_with("Building_") \
		or child is MultiMeshInstance3D \
		or child_name.begins_with("Vehicle_") \
		or child_name.begins_with("NPC_") \
		or child_name.begins_with("PhysicsProp_"):
			child.queue_free()

	_show_main_menu()


# ==================================================
# НАСТРОЙКИ
# ==================================================

func _show_settings() -> void:
	_clear_layer(settings_layer)

	settings_layer = CanvasLayer.new()
	settings_layer.layer = 20
	add_child(settings_layer)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.025, 0.04, 0.96)
	settings_layer.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)

	_add_option(
		column, "Графика",
		["Низкая", "Средняя", "Высокая"],
		Settings.graphics_quality - 1,
		_set_graphics
	)

	_add_option(
		column, "Тени",
		["Выкл.", "Низкие", "Высокие"],
		Settings.shadow_quality,
		_set_shadows
	)

	_add_option(
		column, "Дальность",
		["80 м", "120 м", "180 м", "250 м"],
		_distance_index(),
		_set_distance
	)

	_add_option(
		column, "NPC",
		["0", "2", "4", "6", "10"],
		_npc_index(),
		_set_npcs
	)

	_add_option(
		column, "FPS",
		["30", "45", "60", "90", "120"],
		_fps_index(),
		_set_fps
	)

	_add_menu_button(column, "СОХРАНИТЬ", _save_settings)
	_add_menu_button(column, "НАЗАД", _close_settings)


func _add_option(
	parent: VBoxContainer,
	caption: String,
	options: Array,
	selected: int,
	callback: Callable
) -> void:
	var row := VBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = caption
	row.add_child(label)

	var option := OptionButton.new()

	for item in options:
		option.add_item(str(item))

	option.select(clampi(selected, 0, options.size() - 1))
	option.item_selected.connect(callback)
	row.add_child(option)


func _set_graphics(index: int) -> void:
	Settings.graphics_quality = index + 1
	_apply_graphics_settings()


func _set_shadows(index: int) -> void:
	Settings.shadow_quality = index
	_apply_graphics_settings()


func _set_distance(index: int) -> void:
	var distances: Array[float] = [80.0, 120.0, 180.0, 250.0]
	Settings.view_distance = distances[index]
	_apply_graphics_settings()


func _set_npcs(index: int) -> void:
	var amounts: Array[int] = [0, 2, 4, 6, 10]
	Settings.npc_amount = amounts[index]


func _set_fps(index: int) -> void:
	var values: Array[int] = [30, 45, 60, 90, 120]
	Settings.target_fps = values[index]
	_apply_graphics_settings()


func _distance_index() -> int:
	var distances: Array[float] = [80.0, 120.0, 180.0, 250.0]
	var closest := 0

	for i in range(distances.size()):
		if absf(Settings.view_distance - distances[i]) < absf(
			Settings.view_distance - distances[closest]
		):
			closest = i

	return closest


func _npc_index() -> int:
	var amounts: Array[int] = [0, 2, 4, 6, 10]
	return amounts.find(Settings.npc_amount) if amounts.has(Settings.npc_amount) else 1


func _fps_index() -> int:
	var values: Array[int] = [30, 45, 60, 90, 120]
	return values.find(Settings.target_fps) if values.has(Settings.target_fps) else 2


func _apply_graphics_settings() -> void:
	if is_instance_valid(player):
		var camera_value: Variant = player.get("camera")

		if camera_value is Camera3D:
			var player_camera: Camera3D = camera_value
			player_camera.far = Settings.view_distance

	var viewport := get_viewport()

	if viewport:
		match Settings.graphics_quality:
			1:
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			2:
				viewport.msaa_3d = Viewport.MSAA_2X
			3:
				viewport.msaa_3d = Viewport.MSAA_4X
			_:
				viewport.msaa_3d = Viewport.MSAA_DISABLED

	for node in get_tree().get_nodes_in_group("vehicles"):
		if node.has_method("apply_settings"):
			node.call("apply_settings")


func _save_settings() -> void:
	Settings.save_settings()
	Settings.apply_settings()
	_close_settings()


func _close_settings() -> void:
	if is_instance_valid(settings_layer):
		settings_layer.queue_free()
		settings_layer = null


func _clear_layer(layer: CanvasLayer) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
