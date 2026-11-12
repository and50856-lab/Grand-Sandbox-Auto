extends Node

const SAVE_PATH := "user://settings.cfg"

var graphics_quality := 1
var texture_quality := 2
var shadow_quality := 0
var view_distance := 180.0
var npc_amount := 2
var physics_quality := 2
var target_fps := 60
var language := "ru"


func _ready() -> void:
	load_settings()
	apply_settings()


func apply_settings() -> void:
	Engine.max_fps = target_fps

	var viewport := get_viewport()
	if viewport:
		match graphics_quality:
			1:
				viewport.msaa_3d = Viewport.MSAA_DISABLED
			2:
				viewport.msaa_3d = Viewport.MSAA_2X
			3:
				viewport.msaa_3d = Viewport.MSAA_4X
			_:
				viewport.msaa_3d = Viewport.MSAA_DISABLED


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
		int(cfg.get_value("graphics", "quality", 1)), 1, 3
	)
	texture_quality = clampi(
		int(cfg.get_value("graphics", "textures", 2)), 1, 3
	)
	shadow_quality = clampi(
		int(cfg.get_value("graphics", "shadows", 0)), 0, 2
	)
	view_distance = clampf(
		float(cfg.get_value("graphics", "view_distance", 180.0)),
		80.0, 500.0
	)

	npc_amount = clampi(
		int(cfg.get_value("gameplay", "npcs", 2)), 0, 10
	)
	physics_quality = clampi(
		int(cfg.get_value("gameplay", "physics", 2)), 1, 3
	)

	target_fps = int(cfg.get_value("display", "fps", 60))
	if not [30, 45, 60, 90, 120].has(target_fps):
		target_fps = 60

	language = str(cfg.get_value("display", "language", "ru"))
