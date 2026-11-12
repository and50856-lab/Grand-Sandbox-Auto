extends Node

const SAMPLE_RATE := 22050.0

var ambient_player: AudioStreamPlayer
var engine_player: AudioStreamPlayer

var ambient_playback: AudioStreamGeneratorPlayback
var engine_playback: AudioStreamGeneratorPlayback

var ambient_phase := 0.0
var engine_phase := 0.0

var engine_frequency := 45.0
var engine_volume := 0.0
var master_volume := 1.0


func _ready() -> void:
	add_to_group("audio_manager")

	ambient_player = _create_player(0.16)
	engine_player = _create_player(0.22)

	ambient_playback = ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback
	engine_playback = engine_player.get_stream_playback() as AudioStreamGeneratorPlayback


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
	var normalized_speed := clampf(speed / 35.0, 0.0, 1.0)

	engine_frequency = 42.0 + normalized_speed * 145.0
	engine_volume = 0.08 + normalized_speed * 0.62


func stop_engine() -> void:
	engine_volume = move_toward(engine_volume, 0.0, 0.08)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)

	if is_instance_valid(ambient_player):
		ambient_player.volume_db = linear_to_db(maxf(0.001, 0.16 * master_volume))

	if is_instance_valid(engine_player):
		engine_player.volume_db = linear_to_db(maxf(0.001, 0.22 * master_volume))


func _process(_delta: float) -> void:
	if is_instance_valid(ambient_playback):
		_fill_ambient()

	if is_instance_valid(engine_playback):
		_fill_engine()


func _fill_ambient() -> void:
	var frames := ambient_playback.get_frames_available()

	for i in range(frames):
		ambient_phase += TAU * 58.0 / SAMPLE_RATE

		if ambient_phase >= TAU:
			ambient_phase -= TAU

		var sample := sin(ambient_phase) * 0.012
		ambient_playback.push_frame(Vector2(sample, sample))


func _fill_engine() -> void:
	var frames := engine_playback.get_frames_available()

	for i in range(frames):
		engine_phase += TAU * engine_frequency / SAMPLE_RATE

		if engine_phase >= TAU:
			engine_phase -= TAU

		var fundamental := sin(engine_phase)
		var harmonic := sin(engine_phase * 2.0) * 0.35
		var sample := (fundamental + harmonic) * engine_volume * 0.12

		engine_playback.push_frame(Vector2(sample, sample))
