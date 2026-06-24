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
	spawn_timer.timeout.connect(_spawn_enemy_batch)
	add_child(spawn_timer)

	wave_timer = Timer.new()
	wave_timer.one_shot = false
	wave_timer.wait_time = WAVE_WAIT_TIME
	wave_timer.timeout.connect(_on_wave_timer)
	add_child(wave_timer)

	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_reset_difficulty()
		_begin_wave()
		wave_timer.start()
	elif new_state == GameManager.State.MENU:
		spawn_timer.stop()
		wave_timer.stop()


func _reset_difficulty() -> void:
	enemies_per_wave = GameOptions.enemies_per_wave
	spawn_interval = GameOptions.spawn_interval
	speed_multiplier = GameOptions.enemy_speed_multiplier


func _on_wave_timer() -> void:
	_advance_wave()
	_begin_wave()


func _advance_wave() -> void:
	GameManager.advance_wave()
	enemies_per_wave = mini(enemies_per_wave + 1, 16)
	spawn_interval = maxf(spawn_interval - 0.04, 0.45)
	speed_multiplier += 0.06


func _begin_wave() -> void:
	_spawn_enemy_batch()
	_spawn_wave_obstacles()
	spawn_timer.start(spawn_interval)


func _spawn_enemy_batch() -> void:
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


func _spawn_wave_obstacles() -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	var entities := ArenaContext.get_entities()
	if entities == null:
		return

	var viewport_size := get_viewport_rect().size
	_spawn_asteroids(entities, viewport_size)

	if GameManager.wave % 2 == 0:
		_spawn_health_item(entities, viewport_size)

	print(
		"RUNTIME wave_obstacles wave=%d asteroids=%d"
		% [GameManager.wave, ASTEROIDS_PER_WAVE]
	)


func _spawn_asteroids(entities: Node2D, viewport_size: Vector2) -> void:
	var playable := GameLogic.playable_rect(viewport_size)
	for i in ASTEROIDS_PER_WAVE:
		var asteroid: Area2D = ASTEROID_SCENE.instantiate()
		var pos := Vector2(
			playable.position.x + 80 + (i * 90),
			playable.position.y + 120 + (i * 70)
		)
		var drift := Vector2(cos(i * 1.2), sin(i * 0.9))
		asteroid.setup(pos, drift)
		entities.add_child(asteroid)


func _spawn_health_item(entities: Node2D, viewport_size: Vector2) -> void:
	var playable := GameLogic.playable_rect(viewport_size)
	var item: Area2D = HEALTH_ITEM_SCENE.instantiate()
	var pos := playable.get_center() + Vector2(0, -80)
	var drift := Vector2(0.3, -0.7)
	item.setup(pos, drift)
	entities.add_child(item)
	print("RUNTIME health_item_spawned=true")