extends Node

var engine_player: AudioStreamPlayer
var engine_playback_speed: float = 1.0


func _ready() -> void:
	engine_player = AudioStreamPlayer.new()
	engine_player.name = "EngineAudio"
	add_child(engine_player)


func set_engine_speed(speed: float) -> void:
	engine_playback_speed = clampf(speed / 18.0, 0.8, 2.2)

	if is_instance_valid(engine_player):
		engine_player.pitch_scale = engine_playback_speed


func stop_engine() -> void:
	if is_instance_valid(engine_player):
		engine_player.stop()
