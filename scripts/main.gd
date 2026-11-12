extends Node3D

const VirtualJoystickScript = preload("res://scripts/virtual_joystick.gd")

var player: CharacterBody3D
var menu_layer: CanvasLayer
var world_started := false
var current_mode := "sandbox"
var ui_root: Control

func _ready() -> void:
	_setup_input()
	_setup_world()
	_show_main_menu()

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

func _setup_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()

	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.62, 0.78)
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(500, 500)
	ground.mesh = ground_mesh

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.19, 0.28, 0.17)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	ground.position.y = -0.08
	add_child(ground)

	var ground_body := StaticBody3D.new()
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()

	ground_shape.size = Vector3(500, 0.2, 500)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.1

	ground_body.add_child(ground_collision)
	add_child(ground_body)

func _show_main_menu() -> void:
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(ui_root)

	var background := ColorRect.new()
	background.color = Color(0.035, 0.055, 0.085, 0.96)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)

	var title := Label.new()
	title.text = "GRAND SANDBOX AUTO"
	title.position = Vector2(70, 65)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	ui_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "OPEN WORLD • PHYSICS • FREEDOM"
	subtitle.position = Vector2(75, 125)
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	ui_root.add_child(subtitle)

	_add_menu_button("ИГРАТЬ", Vector2(80, 260), Vector2(360, 72), _show_mode_menu)
	_add_menu_button("НАСТРОЙКИ", Vector2(80, 350), Vector2(360, 64), _show_settings)
	_add_menu_button("ВЫХОД", Vector2(80, 432), Vector2(360, 56), _exit_game)

	var info := Label.new()
	info.text = "GODOT 4 • ANDROID EDITION"
	info.position = Vector2(80, 550)
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	ui_root.add_child(info)

func _add_menu_button(
	label_text: String,
	pos: Vector2,
	button_size: Vector2,
	callback: Callable
) -> void:
	var button := Button.new()
	button.text = label_text
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 23)
	button.pressed.connect(callback)
	ui_root.add_child(button)

func _show_mode_menu() -> void:
	_clear_ui()

	var title := Label.new()
	title.text = "ВЫБЕРИ РЕЖИМ"
	title.position = Vector2(80, 70)
	title.add_theme_font_size_override("font_size", 38)
	ui_root.add_child(title)

	_add_menu_button(
		"SANDBOX\nСвободный мир",
		Vector2(80, 220),
		Vector2(390, 190),
		func(): _start_game("sandbox")
	)

	_add_menu_button(
		"CHALLENGES\nИспытания физики",
		Vector2(510, 220),
		Vector2(390, 190),
		func(): _start_game("challenges")
	)

	_add_menu_button(
		"НАЗАД",
		Vector2(80, 460),
		Vector2(240, 60),
		_show_main_menu
	)

func _show_settings() -> void:
	_clear_ui()

	var title := Label.new()
	title.text = "НАСТРОЙКИ"
	title.position = Vector2(70, 35)
	title.add_theme_font_size_override("font_size", 38)
	ui_root.add_child(title)

	var panel := VBoxContainer.new()
	panel.position = Vector2(80, 115)
	panel.size = Vector2(850, 440)
	panel.add_theme_constant_override("separation", 13)
	ui_root.add_child(panel)

	_add_option(
		panel,
		"Графика",
		["Очень низкая", "Низкая", "Средняя", "Высокая", "Ультра"],
		Settings.graphics_quality - 1,
		func(v): Settings.graphics_quality = v + 1
	)

	_add_option(
		panel,
		"Текстуры",
		["Очень низкие", "Низкие", "Средние", "Высокие", "Ультра"],
		Settings.texture_quality - 1,
		func(v): Settings.texture_quality = v + 1
	)

	_add_option(
		panel,
		"Тени",
		["Выкл.", "Очень низкие", "Низкие", "Средние", "Высокие", "Ультра"],
		Settings.shadow_quality,
		func(v): Settings.shadow_quality = v
	)

	_add_option(
		panel,
		"NPC",
		["Мало", "Средне", "Реалистично"],
		Settings.npc_amount,
		func(v): Settings.npc_amount = v
	)

	_add_option(
		panel,
		"Физика",
		["Лёгкая", "Средняя", "Высокая", "Максимальная"],
		Settings.physics_quality,
		func(v): Settings.physics_quality = v
	)

	var fps_row := HBoxContainer.new()
	panel.add_child(fps_row)

	var fps_label := Label.new()
	fps_label.text = "Ограничение FPS"
	fps_label.custom_minimum_size.x = 250
	fps_row.add_child(fps_label)

	var fps := OptionButton.new()
	var fps_values := [15, 30, 60, 120, 144, 165, 185, 240, 0]

	for value in fps_values:
		fps.add_item("Без ограничений" if value == 0 else str(value))

	var selected_fps := fps_values.find(Settings.target_fps)
	fps.select(selected_fps if selected_fps >= 0 else 2)

	fps.item_selected.connect(func(index):
		Settings.target_fps = fps_values[index]
	)

	fps_row.add_child(fps)

	var distance_label := Label.new()
	distance_label.text = "Дальность прорисовки: " + str(int(Settings.view_distance)) + " м"
	panel.add_child(distance_label)

	var distance := HSlider.new()
	distance.min_value = 100
	distance.max_value = 5000
	distance.step = 100
	distance.value = Settings.view_distance
	distance.custom_minimum_size.x = 650

	distance.value_changed.connect(func(v):
		Settings.view_distance = v
		distance_label.text = "Дальность прорисовки: " + str(int(v)) + " м"
	)

	panel.add_child(distance)

	_add_menu_button(
		"СОХРАНИТЬ И НАЗАД",
		Vector2(80, 600),
		Vector2(380, 65),
		func():
			Settings.save_settings()
			Settings.apply_settings()
			_show_main_menu()
	)

func _add_option(
	parent: VBoxContainer,
	label_text: String,
	choices: Array,
	selected: int,
	callback: Callable
) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 250
	row.add_child(label)

	var option := OptionButton.new()

	for choice in choices:
		option.add_item(choice)

	option.select(clampi(selected, 0, choices.size() - 1))
	option.item_selected.connect(callback)
	row.add_child(option)

func _clear_ui() -> void:
	for child in ui_root.get_children():
		child.queue_free()

func _start_game(mode: String) -> void:
	current_mode = mode
	world_started = true

	menu_layer.queue_free()

	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0, 1, 0)
	add_child(player)

	var hud := CanvasLayer.new()
	add_child(hud)

	_create_touch_hud(hud)

func _create_touch_hud(hud: CanvasLayer) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)

	# ЛЕВЫЙ АНАЛОГОВЫЙ ДЖОЙСТИК
	# Создаём непосредственно экземпляр собственного скрипта.

	var joystick = VirtualJoystickScript.new()
	joystick.position = Vector2(65, 760)
	joystick.size = Vector2(220, 220)

	joystick.vector_changed.connect(func(value: Vector2):
		if is_instance_valid(player):
			player.touch_move = value
	)

	root.add_child(joystick)

	# ПРЫЖОК

	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.position = Vector2(1640, 820)
	jump.size = Vector2(190, 100)
	jump.add_theme_font_size_override("font_size", 22)

	jump.button_down.connect(func():
		Input.action_press("jump")
	)

	jump.button_up.connect(func():
		Input.action_release("jump")
	)

	root.add_child(jump)

	# МЕНЮ

	var exit_button := Button.new()
	exit_button.text = "МЕНЮ"
	exit_button.position = Vector2(30, 25)
	exit_button.size = Vector2(130, 55)

	exit_button.pressed.connect(func():
		get_tree().reload_current_scene()
	)

	root.add_child(exit_button)

func _exit_game() -> void:
	get_tree().quit()
