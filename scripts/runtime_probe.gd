extends Node

const MAIN_SCENE := preload("res://main.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const GameLogic := preload("res://scripts/game_logic.gd")

var failures := 0


func _ready() -> void:
	var main: Node2D = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await _run_probes(main)
	if failures > 0:
		print("RUNTIME probe_exit=1 failures=%d" % failures)
		get_tree().quit(1)
		return
	print("RUNTIME probe_exit=0")
	get_tree().quit(0)


func _fail(msg: String) -> void:
	failures += 1
	push_error("PROBE_FAIL: %s" % msg)


func _warp_mouse_to(global_pos: Vector2) -> void:
	get_viewport().warp_mouse(global_pos)


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame


func _run_probes(main: Node2D) -> void:
	var player: CharacterBody2D = main.get_node("Player")
	var spawner: Node2D = main.get_node("Spawner")
	var entities: Node2D = main.get_node("Entities")
	var viewport_size := main.get_viewport_rect().size
	var playable := GameLogic.playable_rect(viewport_size)

	main._start_play()
	spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame

	print("RUNTIME arena_walls_present=%s" % str(main.get_node_or_null("ArenaWalls") != null).to_lower())
	print("RUNTIME arena_context_ok=%s" % str(
		ArenaContext.get_player() == player and ArenaContext.get_entities() == entities
	).to_lower())

	await _probe_wall_thrust(player, viewport_size, playable, "right", "move_right")
	await _probe_wall_thrust(player, viewport_size, playable, "left", "move_left")
	await _probe_spawn(viewport_size)
	await _probe_player_collision(player, entities)
	await _probe_projectile_collision(player, entities)


func _probe_wall_thrust(
	player: CharacterBody2D,
	viewport_size: Vector2,
	playable: Rect2,
	label: String,
	action: String
) -> void:
	player.velocity = Vector2.ZERO
	var center_y := playable.position.y + playable.size.y * 0.5
	match label:
		"right":
			player.global_position = Vector2(playable.position.x + playable.size.x - 8.0, center_y)
		"left":
			player.global_position = Vector2(playable.position.x + 8.0, center_y)
		_:
			player.global_position = playable.get_center()

	Input.action_press(action)
	for _i in 80:
		await get_tree().physics_frame
		if player.velocity.length() < 5.0:
			break
	Input.action_release(action)
	await _wait_physics(10)

	var pos_end := player.global_position
	var inside := GameLogic.is_inside_playable(pos_end, viewport_size)
	print("RUNTIME wall_%s_inside=%s" % [label, str(inside).to_lower()])
	print("RUNTIME wall_%s_pos=%f" % [label, pos_end.x if label in ["right", "left"] else pos_end.y])
	print("RUNTIME wall_%s_velocity=%f" % [label, player.velocity.length()])

	if not inside:
		_fail("player escaped playable rect thrusting %s (pos=%s)" % [label, pos_end])


func _probe_spawn(viewport_size: Vector2) -> void:
	var positions := GameLogic.wave_spawn_positions(viewport_size, 16)
	var edges := {}
	for pos in positions:
		edges[GameLogic.edge_index(pos, viewport_size)] = true
	print("RUNTIME spawn_edge_count=%d" % edges.size())
	if edges.size() < 2:
		_fail("wave_spawn_positions not distributed across edges")


func _probe_player_collision(player: CharacterBody2D, entities: Node2D) -> void:
	for child in entities.get_children():
		child.queue_free()
	GameManager.lives = 3
	GameManager.score = 0
	player.invincible = false
	player.velocity = Vector2.ZERO
	player.global_position = GameLogic.playable_rect(player.get_viewport_rect().size).get_center()

	var enemy: Area2D = ENEMY_SCENE.instantiate()
	entities.add_child(enemy)
	enemy.global_position = player.global_position
	enemy.setup(enemy.global_position, player, 1.0)
	await _wait_physics(30)

	print("RUNTIME lives_after_hit=%d" % GameManager.lives)
	print("RUNTIME score_after_hit=%d" % GameManager.score)
	if GameManager.lives != 2:
		_fail("player collision did not decrement lives")
	if GameManager.score != 0:
		_fail("player collision awarded score")


func _probe_projectile_collision(player: CharacterBody2D, entities: Node2D) -> void:
	for child in entities.get_children():
		child.queue_free()
	GameManager.score = 0
	player.velocity = Vector2.ZERO
	player.can_shoot = true
	player.global_position = Vector2(400, 360)

	var enemy: Area2D = ENEMY_SCENE.instantiate()
	entities.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(520, 360)
	enemy.setup(enemy.global_position, player, 1.0)
	await get_tree().physics_frame

	_warp_mouse_to(enemy.global_position)
	player.rotation = (enemy.global_position - player.global_position).angle() + PI / 2.0
	player._shoot()
	await _wait_physics(20)

	print("RUNTIME score_after_shot=%d" % GameManager.score)
	print("RUNTIME projectile_count=%d" % entities.get_child_count())
	if GameManager.score != 100:
		_fail("projectile collision did not award score")