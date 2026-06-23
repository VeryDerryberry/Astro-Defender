extends Node

const ProceduralAudio := preload("res://scripts/procedural_audio.gd")

const MELODY_HZ: Array[float] = [262.0, 330.0, 392.0, 523.0, 392.0, 330.0, 294.0, 262.0]
const NOTE_BEATS := 0.28

var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sfx_played_count := 0
var music_looping := false

var _note_index := 0
var _note_elapsed := 0.0
var _phase := 0.0


func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)

	music_player = AudioStreamPlayer.new()
	music_player.stream = ProceduralAudio.make_generator_stream(0.25)
	music_player.bus = "Master"
	add_child(music_player)

	GameManager.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	if not music_looping or not music_player.playing:
		return
	var playback := music_player.get_stream_playback()
	if playback == null:
		return
	var frames_available: int = playback.get_frames_available()
	if frames_available <= 0:
		return

	_note_elapsed += delta
	if _note_elapsed >= NOTE_BEATS:
		_note_elapsed = 0.0
		_note_index = (_note_index + 1) % MELODY_HZ.size()

	var freq := MELODY_HZ[_note_index]
	var increment := freq * TAU / float(ProceduralAudio.MIX_RATE)
	for _i in frames_available:
		_phase = fmod(_phase + increment, TAU)
		var sample := sin(_phase) * 0.12
		playback.push_frame(Vector2(sample, sample))


func play_shoot() -> void:
	_play_sfx(880.0, 0.07)


func play_hit() -> void:
	_play_sfx(180.0, 0.18)


func play_destroy() -> void:
	_play_sfx(660.0, 0.1)


func _play_sfx(freq: float, duration: float) -> void:
	sfx_player.stream = ProceduralAudio.make_tone_wav(freq, duration)
	sfx_player.play()
	sfx_played_count += 1


func start_music() -> void:
	if music_looping:
		return
	music_looping = true
	_note_index = 0
	_note_elapsed = 0.0
	_phase = 0.0
	music_player.play()


func stop_music() -> void:
	music_looping = false
	music_player.stop()


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		start_music()
	else:
		stop_music()