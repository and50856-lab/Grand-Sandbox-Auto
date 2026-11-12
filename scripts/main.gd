extends Node3D

const VirtualJoystickScript = preload("res://scripts/virtual_joystick.gd")

var player: CharacterBody3D
var menu_layer: CanvasLayer
var hud_layer: CanvasLayer
var ui_root: Control

var world_started := false
var current_mode := "sandbox"


func _ready() -> void:
	_setup_input()
	_setup_world()
	_show_main_menu()


# ==================================================
# INPUT
# ==================================================

func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)


func _add_key_action(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


# ==================================================
# WORLD
# ==================================================

func _setup_world() -> void:
	# Яркий фон вместо тёмного неба.
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()

	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.35, 0.62, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.85, 1.0)
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	world_environment.environment = environment
	add_child(world_environment)

	# Солнце без теней — пока проверяем сам рендер.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = false
	add_child(sun)

	_create_ground()
	_create_test_location()


func _create_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(500, 500)
	ground.mesh = mesh
	ground.position.y = -0.02

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.48, 0.22)
	material.roughness = 1.0
	ground.material_override = material

	add_child(ground)

	var body := StaticBody3D.new()
	body.name = "GroundCollision"

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 0.2, 500)

	collision.shape = shape
	collision.position.y = -0.12

	body.add_child(collision)
	add_child(body)


func _create_test_location() -> void:
	# ДОРОГА

	_add_box(
		"Road",
		Vector3(14, 0.08, 120),
		Vector3(0, 0.02, -25),
		Color(0.12, 0.13, 0.15),
		false
	)

	# РАЗМЕТКА

	for i in range(12):
		_add_box(
			"RoadLine",
			Vector3(0.22, 0.04, 3.0),
			Vector3(0, 0.09, 24 - i * 9),
			Color(1.0, 0.88, 0.45),
			false
		)

	# ЗДАНИЯ

	_add_box(
		"BuildingLeft",
		Vector3(13, 9, 15),
		Vector3(-19, 4.5, -24),
		Color(0.55, 0.58, 0.62)
	)

	_add_box(
		"BuildingRight",
		Vector3(13, 12, 15),
		Vector3(19, 6, -30),
		Color(0.65, 0.43, 0.30)
	)

	_add_box(
		"SmallBuilding",
		Vector3(10, 6, 10),
		Vector3(-25, 3, 7),
		Color(0.40, 0.52, 0.65)
	)

	# ПРЕПЯТСТВИЯ

	_add_box(
		"Crate1",
		Vector3(1.5, 1.5, 1.5),
		Vector3(-4, 0.75, -5),
		Color(0.65, 0.36, 0.16)
	)

	_add_box(
		"Crate2",
		Vector3(1.5, 1.5, 1.5),
		Vector3(4, 0.75, -8),
		Color(0.75, 0.48, 0.20)
	)

	_add_box(
		"Barrier",
		Vector3(5, 1, 0.8),
		Vector3(0, 0.5, -15),
		Color(0.95, 0.48, 0.10)
	)

	_add_box(
		"Platform",
		Vector3(5, 0.6, 5),
		Vector3(9, 0.3, 3),
		Color(0.40, 0.46, 0.55)
	)

	# ДЕРЕВЬЯ

	_add_tree(Vector3(-12, 0, -5))
	_add_tree(Vector3(-15, 0, -15))
	_add_tree(Vector3(14, 0, -5))
	_add_tree(Vector3(25, 0, 5))
	_add_tree(Vector3(-28, 0, -12))


func _add_box(
	object_name: String,
	box_size: Vector3,
	world_position: Vector3,
	color: Color,
	with_collision: bool = true
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = object_name

	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = world_position

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material

	add_child(mesh_instance)

	if with_collision:
		var body := StaticBody3D.new()
		body.name = object_name + "Collision"
		body.position = world_position

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size

		collision.shape = shape
		body.add_child(collision)
		add_child(body)


func _add_tree(world_position: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()

	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 2.5
	trunk.mesh = trunk_mesh
	trunk.position = world_position + Vector3(0, 1.25, 0)

	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.32, 0.19, 0.10)
	trunk.material_override = trunk_material
	add_child(trunk)

	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()

	leaves_mesh.radius = 1.5
	leaves_mesh.height = 3.0
	leaves.mesh = leaves_mesh
	leaves.position = world_position + Vector3(0, 3.0, 0)

	var leaves_material := StandardMaterial3D.new()
	leaves_material.albedo_color = Color(0.12, 0.40, 0.15)
	leaves.material_override = leaves_material
	add_child(leaves)


# ==================================================
# MAIN MENU
# ==================================================

func _show_main_menu() -> void:
	_create_menu_layer()

	var column := _build_menu_page(
		"GRAND SANDBOX AUTO",
		"OPEN WORLD  •  PHYSICS  •  FREEDOM"
	)

	_add_menu_button(column, "ИГРАТЬ", _show_mode_menu)
	_add_menu_button(column, "НАСТРОЙКИ", _show_settings)
	_add_menu_button(column, "ВЫХОД", _exit_game)

	var info := Label.new()
	info.text = "ANDROID EDITION  •  PROTOTYPE 0.2"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override(
		"font_color",
		Color(0.60, 0.68, 0.78)
	)
	column.add_child(info)


func _create_menu_layer() -> void:
	if is_instance_valid(menu_layer):
		return

	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(ui_root)


func _build_menu_page(
	title_text: String,
	subtitle_text: String
) -> VBoxContainer:
	_clear_ui()

	var background := ColorRect.new()
	background.color = Color(0.025, 0.045, 0.075, 0.97)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.15, 1)
	panel_style.border_color = Color(0.20, 0.40, 0.62, 1)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)

	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	margin.add_child(column)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override(
		"font_color",
		Color(0.94, 0.97, 1.0)
	)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override(
		"font_color",
		Color(0.40, 0.72, 1.0)
	)
	column.add_child(subtitle)

	var separator := HSeparator.new()
	column.add_child(separator)

	return column


func _add_menu_button(
	parent: VBoxContainer,
	button_text: String,
	callback: Callable
) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(callback)
	parent.add_child(button)


func _show_mode_menu() -> void:
	var column := _build_menu_page(
		"ВЫБЕРИ РЕЖИМ",
		"КАК ТЫ ХОЧЕШЬ ИГРАТЬ?"
	)

	_add_menu_button(
		column,
		"SANDBOX — СВОБОДНЫЙ МИР",
		func(): _start_game("sandbox")
	)

	_add_menu_button(
		column,
		"CHALLENGES — ИСПЫТАНИЯ",
		func(): _start_game("challenges")
	)

	_add_menu_button(column, "НАЗАД", _show_main_menu)


func _show_settings() -> void:
	var column := _build_menu_page(
		"НАСТРОЙКИ",
		"ПАРАМЕТРЫ ИГРЫ"
	)

	_add_setting_option(
		column,
		"Графика",
		["Очень низкая", "Низкая", "Средняя", "Высокая", "Ультра"],
		Settings.graphics_quality - 1,
		func(v): Settings.graphics_quality = v + 1
	)

	_add_setting_option(
		column,
		"Текстуры",
		["Очень низкие", "Низкие", "Средние", "Высокие", "Ультра"],
		Settings.texture_quality - 1,
		func(v): Settings.texture_quality = v + 1
	)

	_add_setting_option(
		column,
		"Тени",
		["Выкл.", "Очень низкие", "Низкие", "Средние", "Высокие", "Ультра"],
		Settings.shadow_quality,
		func(v): Settings.shadow_quality = v
	)

	_add_setting_option(
		column,
		"NPC",
		["Мало", "Средне", "Реалистично"],
		Settings.npc_amount,
		func(v): Settings.npc_amount = v
	)

	var fps_values := [15, 30, 60, 120, 144, 165, 185, 240, 0]
	var fps_row := HBoxContainer.new()

	var fps_label := Label.new()
	fps_label.text = "Ограничение FPS"
	fps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_row.add_child(fps_label)

	var fps := OptionButton.new()

	for value in fps_values:
		fps.add_item("Без ограничений" if value == 0 else str(value))

	var selected := fps_values.find(Settings.target_fps)
	fps.select(selected if selected >= 0 else 2)

	fps.item_selected.connect(func(index):
		Settings.target_fps = fps_values[index]
	)

	fps_row.add_child(fps)
	column.add_child(fps_row)

	_add_menu_button(
		column,
		"СОХРАНИТЬ",
		func():
			Settings.save_settings()
			Settings.apply_settings()
			_show_main_menu()
	)

	_add_menu_button(column, "НАЗАД", _show_main_menu)


func _add_setting_option(
	parent: VBoxContainer,
	label_text: String,
	choices: Array,
	selected: int,
	callback: Callable
) -> void:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var option := OptionButton.new()

	for choice in choices:
		option.add_item(choice)

	option.select(clampi(selected, 0, choices.size() - 1))
	option.item_selected.connect(callback)

	row.add_child(option)
	parent.add_child(row)


func _clear_ui() -> void:
	for child in ui_root.get_children():
		child.queue_free()


# ==================================================
# GAME START
# ==================================================

func _start_game(mode: String) -> void:
	current_mode = mode
	world_started = true

	if is_instance_valid(menu_layer):
		menu_layer.queue_free()
		menu_layer = null

	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0, 0, 8)
	add_child(player)

	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	_create_touch_hud()


# ==================================================
# TOUCH HUD
# ==================================================

func _create_touch_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(root)

	# ЛЕВЫЙ ДЖОЙСТИК

	var joystick = VirtualJoystickScript.new()
	joystick.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT
	)
	joystick.position = Vector2(35, -220)
	joystick.size = Vector2(190, 190)

	joystick.vector_changed.connect(func(value: Vector2):
		if is_instance_valid(player):
			player.touch_move = value
	)

	root.add_child(joystick)

	# ПРЫЖОК

	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT
	)
	jump.position = Vector2(-180, -120)
	jump.size = Vector2(150, 76)
	jump.add_theme_font_size_override("font_size", 18)

	jump.button_down.connect(func():
		Input.action_press("jump")
	)

	jump.button_up.connect(func():
		Input.action_release("jump")
	)

	root.add_child(jump)

	# ВОЗВРАТ В МЕНЮ

	var exit_button := Button.new()
	exit_button.text = "МЕНЮ"
	exit_button.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT
	)
	exit_button.position = Vector2(24, 24)
	exit_button.size = Vector2(120, 54)

	exit_button.pressed.connect(func():
		get_tree().reload_current_scene()
	)

	root.add_child(exit_button)


func _exit_game() -> void:
	get_tree().quit()
