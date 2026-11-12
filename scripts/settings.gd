extends Node

const SAVE_PATH := "user://settings.cfg"

var graphics_quality := 4
var texture_quality := 4
var shadow_quality := 4
var view_distance := 1000.0
var npc_amount := 2
var physics_quality := 3
var target_fps := 60
var language := "ru"

func _ready() -> void:
	load_settings()
	apply_settings()

func apply_settings() -> void:
	Engine.max_fps = target_fps

	var viewport := get_viewport()
	if viewport:
		viewport.msaa_3d = [
			Viewport.MSAA_DISABLED,
			Viewport.MSAA_2X,
			Viewport.MSAA_4X,
			Viewport.MSAA_8X
		][clampi(graphics_quality - 1, 0, 3)]

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
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	graphics_quality = cfg.get_value("graphics", "quality", 4)
	texture_quality = cfg.get_value("graphics", "textures", 4)
	shadow_quality = cfg.get_value("graphics", "shadows", 4)
	view_distance = cfg.get_value("graphics", "view_distance", 1000.0)
	npc_amount = cfg.get_value("gameplay", "npcs", 2)
	physics_quality = cfg.get_value("gameplay", "physics", 3)
	target_fps = cfg.get_value("display", "fps", 60)
	language = cfg.get_value("display", "language", "ru")
