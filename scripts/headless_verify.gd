extends Node

const GameLogic := preload("res://scripts/game_logic.gd")

var _main: Node2D
var _player: CharacterBody2D
var _entities: Node2D
var _spawner: Node2D
var failures := 0


func setup(main: Node2D) -> void:
	_main = main
	_player = main.get_node("Player")
	_entities = main.get_node("Entities")
	_spawner = main.get_node("Spawner")


func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_size := _main.get_viewport_rect().size
	var playable := GameLogic.playable_rect(viewport_size)

	print("RUNTIME arena_walls_present=%s" % str(_main.get_node_or_null("ArenaWalls") != null).to_lower())
	print("RUNTIME arena_context_ok=%s" % str(
		ArenaContext.get_player() == _player and ArenaContext.get_entities() == _entities
	).to_lower())

	await _start_via_input()
	if GameManager.state != GameManager.State.PLAYING:
		_fail("start input did not enter PLAYING state")
		return

	print("RUNTIME game_started=true")
	print("RUNTIME spawner_active=%s" % str(_spawner.process_mode == Node.PROCESS_MODE_INHERIT).to_lower())

	await _wait_physics(6)
	await _probe_spawner_wave(viewport_size)
	_halt_spawner()
	_freeze_enemies()

	await _probe_wall_thrust(viewport_size, playable, "right", "move_right")
	await _probe_wall_thrust(viewport_size, playable, "left", "move_left")

	_unfreeze_enemies()
	await _probe_player_collision()
	await _probe_projectile_shoot()

	if failures > 0:
		print("RUNTIME verify_exit=1 failures=%d" % failures)
		get_tree().quit(1)
	else:
		print("RUNTIME verify_exit=0")
		get_tree().quit(0)


func _fail(msg: String) -> void:
	failures += 1
	push_error("VERIFY_FAIL: %s" % msg)


func _start_via_input() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	_main.get_viewport().push_input(key)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _halt_spawner() -> void:
	for child in _spawner.get_children():
		if child is Timer:
			child.stop()


func _freeze_enemies() -> void:
	for child in _entities.get_children():
		if child.is_in_group("enemies"):
			child.set_physics_process(false)


func _unfreeze_enemies() -> void:
	for child in _entities.get_children():
		if child.is_in_group("enemies"):
			child.set_physics_process(true)


func _probe_wall_thrust(
	viewport_size: Vector2,
	playable: Rect2,
	label: String,
	action: String
) -> void:
	_player.velocity = Vector2.ZERO
	_player.global_position = playable.get_center()
	await get_tree().physics_frame

	Input.action_press(action)
	var peak_speed := 0.0
	for _i in 160:
		await get_tree().physics_frame
		peak_speed = maxf(peak_speed, _player.velocity.length())
	Input.action_release(action)
	await _wait_physics(12)

	var pos_end := _player.global_position
	var inside := GameLogic.is_inside_playable(pos_end, viewport_size)
	print("RUNTIME wall_%s_inside=%s" % [label, str(inside).to_lower()])
	print("RUNTIME wall_%s_pos=%f" % [label, pos_end.x if label in ["right", "left"] else pos_end.y])
	print("RUNTIME wall_%s_velocity=%f" % [label, _player.velocity.length()])
	print("RUNTIME wall_%s_peak_speed=%f" % [label, peak_speed])

	if peak_speed < 20.0:
		_fail("thrust %s did not accelerate player" % label)
	if not inside:
		_fail("player escaped playable rect thrusting %s (pos=%s)" % [label, pos_end])


func _probe_spawner_wave(viewport_size: Vector2) -> void:
	var count := _entities.get_child_count()
	print("RUNTIME spawner_enemy_count=%d" % count)

	if count < 1:
		_fail("spawner did not create enemies in Entities")

	var edges := {}
	for child in _entities.get_children():
		if child.is_in_group("enemies"):
			edges[GameLogic.edge_index(child.global_position, viewport_size)] = true
	print("RUNTIME spawn_edge_count=%d" % edges.size())
	if edges.size() < 2:
		_fail("spawner enemies not distributed across edges")


func _probe_player_collision() -> void:
	var lives_before := GameManager.lives
	_player.invincible = false
	_player.velocity = Vector2.ZERO
	_player.global_position = GameLogic.playable_rect(_main.get_viewport_rect().size).get_center()

	var enemies: Array[Node] = []
	for child in _entities.get_children():
		if child.is_in_group("enemies"):
			enemies.append(child)
	for i in range(enemies.size()):
		if i > 0:
			enemies[i].queue_free()
	if enemies.is_empty():
		_fail("no enemies available for collision test")
		return

	var enemy: Node2D = enemies[0]
	enemy.global_position = _player.global_position
	enemy.set_physics_process(false)
	await _wait_physics(30)

	print("RUNTIME lives_after_hit=%d" % GameManager.lives)
	print("RUNTIME score_after_hit=%d" % GameManager.score)
	if GameManager.lives != lives_before - 1:
		_fail("player collision did not decrement lives")
	if GameManager.score != 0:
		_fail("player collision awarded score")


func _probe_projectile_shoot() -> void:
	var score_before := GameManager.score
	_player.invincible = false
	_player.can_shoot = true
	_player.velocity = Vector2.ZERO
	_player.global_position = GameLogic.playable_rect(_main.get_viewport_rect().size).get_center()

	for child in _entities.get_children():
		child.queue_free()
	await get_tree().physics_frame

	await get_tree().physics_frame
	var aim_dir := (_player.get_global_mouse_position() - _player.global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
	var enemy: Area2D = enemy_scene.instantiate()
	_entities.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = _player.global_position + aim_dir * 160.0
	enemy.setup(enemy.global_position, _player, 1.0)
	await get_tree().physics_frame

	Input.action_press("shoot")
	for _i in 80:
		await get_tree().physics_frame
		if GameManager.score > score_before:
			break
	Input.action_release("shoot")

	print("RUNTIME score_after_shot=%d" % GameManager.score)
	if GameManager.score != score_before + 100:
		_fail("projectile collision did not award score via shoot input")