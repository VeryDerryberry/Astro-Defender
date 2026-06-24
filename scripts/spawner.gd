extends Node2D

const GameLogic := preload("res://scripts/game_logic.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ASTEROID_SCENE := preload("res://scenes/asteroid.tscn")
const HEALTH_ITEM_SCENE := preload("res://scenes/health_item.tscn")

const ASTEROIDS_PER_WAVE := 3
const WAVE_WAIT_TIME := 20.0

var spawn_timer: Timer
var wave_timer: Timer
var enemies_per_wave := 6
var spawn_interval := 1.2
var speed_multiplier := 1.0


func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_spawn_wave)
	add_child(spawn_timer)

	wave_timer = Timer.new()
	wave_timer.one_shot = false
	wave_timer.wait_time = WAVE_WAIT_TIME
	wave_timer.timeout.connect(_advance_wave)
	add_child(wave_timer)

	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_reset_difficulty()
		_spawn_wave()
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
	enemies_per_wave = mini(enemies_per_wave + 1, 16)
	spawn_interval = maxf(spawn_interval - 0.04, 0.45)
	speed_multiplier += 0.06


func _spawn_wave() -> void:
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

	_spawn_asteroids(entities, viewport.size)

	if GameManager.wave % 2 == 0:
		_spawn_health_item(entities, viewport.size)

	print("RUNTIME wave_spawn enemies=%d asteroids=%d" % [enemies_per_wave, ASTEROIDS_PER_WAVE])
	spawn_timer.start(spawn_interval)


func _spawn_asteroids(entities: Node2D, viewport_size: Vector2) -> void:
	var playable := GameLogic.playable_rect(viewport_size)
	for _i in ASTEROIDS_PER_WAVE:
		var asteroid: Area2D = ASTEROID_SCENE.instantiate()
		var pos := Vector2(
			randf_range(playable.position.x + 40, playable.end.x - 40),
			randf_range(playable.position.y + 40, playable.end.y - 40)
		)
		var drift := Vector2(randf_range(-1, 1), randf_range(-1, 1))
		asteroid.setup(pos, drift)
		entities.add_child(asteroid)


func _spawn_health_item(entities: Node2D, viewport_size: Vector2) -> void:
	var playable := GameLogic.playable_rect(viewport_size)
	var item: Area2D = HEALTH_ITEM_SCENE.instantiate()
	var pos := Vector2(
		randf_range(playable.position.x + 60, playable.end.x - 60),
		randf_range(playable.position.y + 60, playable.end.y - 60)
	)
	var drift := Vector2(randf_range(-1, 1), randf_range(-1, 1))
	item.setup(pos, drift)
	entities.add_child(item)
	print("RUNTIME health_item_spawned=true")