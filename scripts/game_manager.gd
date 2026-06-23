extends Node

enum State { MENU, PLAYING, GAME_OVER }

var state: State = State.MENU
var score: int = 0
var lives: int = 3
var wave: int = 1
var high_score: int = 0

const HIGH_SCORE_PATH := "user://highscore.save"
const STARTING_LIVES := 3

signal state_changed(new_state: State)
signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal wave_changed(new_wave: int)


func _ready() -> void:
	_load_high_score()


func start_game() -> void:
	score = 0
	lives = STARTING_LIVES
	wave = 1
	_set_state(State.PLAYING)
	score_changed.emit(score)
	lives_changed.emit(lives)
	wave_changed.emit(wave)


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		end_game()


func advance_wave() -> void:
	wave += 1
	wave_changed.emit(wave)


func end_game() -> void:
	if score > high_score:
		high_score = score
		_save_high_score()
	_set_state(State.GAME_OVER)


func return_to_menu() -> void:
	_set_state(State.MENU)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)


func _load_high_score() -> void:
	if FileAccess.file_exists(HIGH_SCORE_PATH):
		var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
		if file:
			high_score = int(file.get_as_text())
			file.close()


func _save_high_score() -> void:
	var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(str(high_score))
		file.close()