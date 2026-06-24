extends Node

enum State { MENU, PLAYING }

var state: State = State.MENU
var score: int = 0
var health: int = 0
var wave: int = 1
var high_score: int = 0

const HIGH_SCORE_PATH := "user://highscore.save"
const HEALTH_RESTORE_AMOUNT := 5

signal state_changed(new_state: State)
signal score_changed(new_score: int)
signal health_changed(new_health: int)
signal wave_changed(new_wave: int)


func _ready() -> void:
	health = GameOptions.DEFAULT_HEALTH
	_load_high_score()


func start_game() -> void:
	score = 0
	health = GameOptions.starting_health
	wave = 1
	_set_state(State.PLAYING)
	score_changed.emit(score)
	health_changed.emit(health)
	wave_changed.emit(wave)
	print("RUNTIME start_health=%d" % health)


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


func lose_health(amount: int = 1) -> void:
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		_on_player_death()


func restore_health(amount: int = HEALTH_RESTORE_AMOUNT) -> void:
	health = mini(health + amount, GameOptions.starting_health)
	health_changed.emit(health)


func advance_wave() -> void:
	wave += 1
	wave_changed.emit(wave)


func _on_player_death() -> void:
	if score > high_score:
		high_score = score
		_save_high_score()
	return_to_menu()


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