extends Node

const SAVE_PATH := "user://settings.cfg"

var graphics_quality: int = 1
var texture_quality: int = 2
var shadow_quality: int = 0
var view_distance: float = 180.0
var npc_amount: int = 2
var physics_quality: int = 2
var target_fps: int = 60
var language: String = "ru"


func _ready() -> void:
	_ensure_input_actions()
	load_settings()
	apply_settings()


func _ensure_input_actions() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("jump", [KEY_SPACE])
	_add_action("run", [KEY_SHIFT])


func _add_action(action_name: String, keys: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for keycode in keys:
		var exists := false

		for existing_event in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey:
				if existing_event.physical_keycode == int(keycode):
					exists = true
					break

		if exists:
			continue

		var event := InputEventKey.new()
		event.physical_keycode = int(keycode)
		InputMap.action_add_event(action_name, event)


func apply_settings() -> void:
	Engine.max_fps = target_fps

	var viewport := get_viewport()

	if viewport == null:
		return

	match graphics_quality:
		1:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
		2:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 0.9
		3:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0

	match texture_quality:
		1:
			viewport.texture_mipmap_bias = 1.5
		2:
			viewport.texture_mipmap_bias = 0.0
		3:
			viewport.texture_mipmap_bias = -0.5

	for sun in get_tree().get_nodes_in_group("world_sun"):
		if not sun is DirectionalLight3D:
			continue

		var light := sun as DirectionalLight3D

		match shadow_quality:
			0:
				light.shadow_enabled = false
			1:
				light.shadow_enabled = true
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				light.directional_shadow_max_distance = 60.0
			2:
				light.shadow_enabled = true
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
				light.directional_shadow_max_distance = 180.0


func save_settings() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.set_value("graphics", "textures", texture_quality)
	cfg.set_value("graphics", "shadows", shadow_quality)
	cfg.set_value("graphics", "view_distance", view_distance)

	cfg.set_value("gameplay", "npcs", npc_amount)
	cfg.set_value("gameplay", "physics", physics_quality)

	cfg.set_value("display", "fps", target_fps)
	cfg.set_value("display", "language", language)

	var result := cfg.save(SAVE_PATH)

	if result != OK:
		push_warning("Не удалось сохранить настройки: %s" % result)


func load_settings() -> void:
	var cfg := ConfigFile.new()

	if cfg.load(SAVE_PATH) != OK:
		return

	graphics_quality = clampi(
		int(cfg.get_value("graphics", "quality", 1)),
		1,
		3
	)

	texture_quality = clampi(
		int(cfg.get_value("graphics", "textures", 2)),
		1,
		3
	)

	shadow_quality = clampi(
		int(cfg.get_value("graphics", "shadows", 0)),
		0,
		2
	)

	view_distance = clampf(
		float(cfg.get_value("graphics", "view_distance", 180.0)),
		80.0,
		500.0
	)

	npc_amount = clampi(
		int(cfg.get_value("gameplay", "npcs", 2)),
		0,
		10
	)

	physics_quality = clampi(
		int(cfg.get_value("gameplay", "physics", 2)),
		1,
		3
	)

	target_fps = int(cfg.get_value("display", "fps", 60))

	if not [30, 45, 60, 90, 120].has(target_fps):
		target_fps = 60

	language = str(cfg.get_value("display", "language", "ru"))
