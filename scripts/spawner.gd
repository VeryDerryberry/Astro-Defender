extends Node2D

const GameLogic := preload("res://scripts/game_logic.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var spawn_timer: Timer
var wave_timer: Timer
var enemies_per_wave := 4
var spawn_interval := 1.2
var speed_multiplier := 1.0


func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)

	wave_timer = Timer.new()
	wave_timer.one_shot = false
	wave_timer.wait_time = 12.0
	wave_timer.timeout.connect(_advance_wave)
	add_child(wave_timer)

	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_reset_difficulty()
		_spawn_enemy()
		wave_timer.start()
	elif new_state == GameManager.State.MENU or new_state == GameManager.State.GAME_OVER:
		spawn_timer.stop()
		wave_timer.stop()


func _reset_difficulty() -> void:
	enemies_per_wave = GameOptions.enemies_per_wave
	spawn_interval = GameOptions.spawn_interval
	speed_multiplier = GameOptions.enemy_speed_multiplier


func _advance_wave() -> void:
	GameManager.advance_wave()
	enemies_per_wave = mini(enemies_per_wave + 2, 16)
	spawn_interval = maxf(spawn_interval - 0.08, 0.35)
	speed_multiplier += 0.12


func _spawn_enemy() -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	var entities := ArenaContext.get_entities()
	if entities == null:
		push_error("ArenaContext has no entities container")
		return

	var viewport := get_viewport_rect()
	var player := ArenaContext.get_player()
	var target := player if is_instance_valid(player) else null
	var spawn_positions := GameLogic.wave_spawn_positions(viewport.size, enemies_per_wave)

	for spawn_pos in spawn_positions:
		var enemy: Area2D = ENEMY_SCENE.instantiate()
		enemy.setup(spawn_pos, target, speed_multiplier)
		entities.add_child(enemy)

	spawn_timer.start(spawn_interval)