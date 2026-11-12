extends Node

var ambient_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer

var ambient_playback: AudioStreamGeneratorPlayback
var engine_playback: AudioStreamGeneratorPlayback

var ambient_phase := 0.0
var engine_phase := 0.0
var engine_frequency := 45.0
var engine_volume := 0.0

const SAMPLE_RATE := 22050.0


func _ready() -> void:
	add_to_group("audio_manager")

	ambient_player = _create_player(0.2)
	engine_player = _create_player(0.18)

	ambient_playback = ambient_player.get_stream_playback()
	engine_playback = engine_player.get_stream_playback()


func _create_player(volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.25

	player.stream = generator
	player.volume_db = linear_to_db(volume)
	add_child(player)
	player.play()

	return player


func set_engine_speed(speed: float) -> void:
	engine_frequency = 42.0 + clampf(speed, 0.0, 35.0) * 4.0
	engine_volume = clampf(absf(speed) / 30.0, 0.08, 0.7)


func stop_engine() -> void:
	engine_volume = 0.0


func _process(delta: float) -> void:
	if ambient_playback:
		_fill_ambient()

	if engine_playback:
		_fill_engine()


func _fill_ambient() -> void:
	var frames := ambient_playback.get_frames_available()

	for i in range(frames):
		ambient_phase += TAU * 58.0 / SAMPLE_RATE
		if ambient_phase > TAU:
			ambient_phase -= TAU

		var sample := sin(ambient_phase) * 0.012
		ambient_playback.push_frame(Vector2(sample, sample))


func _fill_engine() -> void:
	var frames := engine_playback.get_frames_available()

	for i in range(frames):
		engine_phase += TAU * engine_frequency / SAMPLE_RATE
		if engine_phase > TAU:
			engine_phase -= TAU

		var fundamental := sin(engine_phase)
		var harmonic := sin(engine_phase * 2.0) * 0.35
		var sample := (fundamental + harmonic) * engine_volume * 0.12

		engine_playback.push_frame(Vector2(sample, sample))
