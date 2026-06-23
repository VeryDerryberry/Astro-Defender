extends Node

const GameLogic := preload("res://scripts/game_logic.gd")

const CUSTOM_ENEMIES := 6
const CUSTOM_LIVES := 5
const CUSTOM_FIRE_RATE := 0.10

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

	await _apply_custom_options()
	await _start_via_input()
	if GameManager.state != GameManager.State.PLAYING:
		_fail("start input did not enter PLAYING state")
		return

	print("RUNTIME game_started=true")
	print("RUNTIME options_custom=true")
	print("RUNTIME spawner_active=%s" % str(_spawner.process_mode == Node.PROCESS_MODE_INHERIT).to_lower())
	print("RUNTIME music_looping=%s" % str(AudioManager.music_looping).to_lower())
	print("RUNTIME fire_rate_applied=%f" % _player.get_node("ShootTimer").wait_time)

	if GameOptions.enemies_per_wave != CUSTOM_ENEMIES:
		_fail("options enemies not applied")
	if GameOptions.starting_lives != CUSTOM_LIVES:
		_fail("options lives not applied")
	if not is_equal_approx(GameOptions.fire_rate, CUSTOM_FIRE_RATE):
		_fail("options fire_rate not applied")

	_halt_spawner()
	await _wait_physics(2)
	await _probe_spawner_wave(viewport_size, CUSTOM_ENEMIES)
	_clear_enemies()
	TouchInput.reset_state()
	await _probe_touch_thrust(playable)

	await _probe_wall_thrust(viewport_size, playable, "right", "move_right")
	await _probe_wall_thrust(viewport_size, playable, "left", "move_left")

	await _probe_player_collision(CUSTOM_LIVES)
	await _probe_touch_shoot()

	if failures > 0:
		print("RUNTIME verify_exit=1 failures=%d" % failures)
		get_tree().quit(1)
	else:
		print("RUNTIME verify_exit=0")
		get_tree().quit(0)


func _fail(msg: String) -> void:
	failures += 1
	push_error("VERIFY_FAIL: %s" % msg)


func _apply_custom_options() -> void:
	GameOptions.reset_defaults()
	GameOptions.adjust_enemies(CUSTOM_ENEMIES - GameOptions.DEFAULT_ENEMIES)
	GameOptions.adjust_lives(CUSTOM_LIVES - GameOptions.DEFAULT_LIVES)
	GameOptions.adjust_fire_rate(CUSTOM_FIRE_RATE - GameOptions.DEFAULT_FIRE_RATE)
	print("RUNTIME options_preset=%s" % GameOptions.summary())


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


func _push_touch(event: InputEvent) -> void:
	_main._input(event)


func _halt_spawner() -> void:
	for child in _spawner.get_children():
		if child is Timer:
			child.stop()


func _clear_enemies() -> void:
	for child in _entities.get_children():
		child.queue_free()
	await get_tree().physics_frame


func _probe_touch_thrust(playable: Rect2) -> void:
	TouchInput.reset_state()
	_player.velocity = Vector2.ZERO
	_player.global_position = playable.get_center()
	await get_tree().physics_frame

	var size := _main.get_viewport_rect().size
	var joy_origin := Vector2(size.x * 0.2, size.y * 0.75)
	var joy_current := Vector2(size.x * 0.2, size.y * 0.55)

	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = joy_origin
	press.pressed = true
	_push_touch(press)
	await get_tree().physics_frame

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = joy_current
	drag.relative = joy_current - joy_origin
	_push_touch(drag)

	var aim_screen := Vector2(size.x * 0.78, size.y * 0.5)
	var right_press := InputEventScreenTouch.new()
	right_press.index = 1
	right_press.position = aim_screen
	right_press.pressed = true
	_push_touch(right_press)
	await get_tree().physics_frame

	var thrust_during := TouchInput.get_thrust_vector().length()
	var aim_during := TouchInput.has_active_aim()
	if thrust_during < 0.2 or not aim_during:
		_fail("simultaneous touch thrust and aim not active")

	var peak_speed := 0.0
	for _i in 30:
		await get_tree().physics_frame
		peak_speed = maxf(peak_speed, _player.velocity.length())

	print("RUNTIME touch_thrust_dir=%f" % thrust_during)

	var right_release := InputEventScreenTouch.new()
	right_release.index = 1
	right_release.position = aim_screen
	right_release.pressed = false
	_push_touch(right_release)

	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = joy_current
	release.pressed = false
	_push_touch(release)
	await get_tree().physics_frame

	print("RUNTIME touch_events_processed=%d" % TouchInput.touch_events_processed)
	print("RUNTIME touch_thrust_peak=%f" % peak_speed)

	if thrust_during < 0.2:
		_fail("touch thrust direction not set")
	if peak_speed < 20.0:
		_fail("touch thrust did not accelerate player")


func _probe_wall_thrust(
	viewport_size: Vector2,
	playable: Rect2,
	label: String,
	action: String
) -> void:
	TouchInput.reset_state()
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


func _probe_spawner_wave(viewport_size: Vector2, expected_count: int) -> void:
	var count := _entities.get_child_count()
	print("RUNTIME spawner_enemy_count=%d" % count)

	if count != expected_count:
		_fail("spawner enemy count %d != options %d" % [count, expected_count])

	var edges := {}
	for child in _entities.get_children():
		if child.is_in_group("enemies"):
			edges[GameLogic.edge_index(child.global_position, viewport_size)] = true
	print("RUNTIME spawn_edge_count=%d" % edges.size())
	if edges.size() < 2:
		_fail("spawner enemies not distributed across edges")


func _probe_player_collision(expected_start_lives: int) -> void:
	if GameManager.lives != expected_start_lives:
		_fail("lives not at expected %d before collision (got %d)" % [expected_start_lives, GameManager.lives])
	if GameManager.score != 0:
		_fail("score not zero before collision test")

	var lives_before := GameManager.lives
	_player.invincible = false
	_player.velocity = Vector2.ZERO
	_player.global_position = GameLogic.playable_rect(_main.get_viewport_rect().size).get_center()
	TouchInput.reset_state()

	var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
	var enemy: Area2D = enemy_scene.instantiate()
	_entities.add_child(enemy)
	enemy.global_position = _player.global_position
	enemy.setup(enemy.global_position, _player, 1.0)
	await _wait_physics(30)

	print("RUNTIME lives_after_hit=%d" % GameManager.lives)
	print("RUNTIME score_after_hit=%d" % GameManager.score)
	if lives_before != expected_start_lives:
		_fail("unexpected starting lives %d" % lives_before)
	if GameManager.lives != lives_before - 1:
		_fail("player collision did not decrement lives")
	if GameManager.score != 0:
		_fail("player collision awarded score")


func _probe_touch_shoot() -> void:
	var score_before := GameManager.score
	var sfx_before := AudioManager.sfx_played_count
	_player.invincible = false
	_player.can_shoot = true
	_player.velocity = Vector2.ZERO
	_player.global_position = GameLogic.playable_rect(_main.get_viewport_rect().size).get_center()

	for child in _entities.get_children():
		child.queue_free()
	await get_tree().physics_frame
	TouchInput.reset_state()

	var size := _main.get_viewport_rect().size
	var aim_screen := Vector2(size.x * 0.78, size.y * 0.5)

	var shoot_touch := InputEventScreenTouch.new()
	shoot_touch.index = 1
	shoot_touch.position = aim_screen
	shoot_touch.pressed = true
	_push_touch(shoot_touch)
	await get_tree().physics_frame

	var aim_world: Vector2 = TouchInput.get_aim_world_position()
	if aim_world == null:
		aim_world = TouchInput.screen_to_world(aim_screen, _main.get_viewport())
	var aim_dir := (aim_world - _player.global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
	var enemy: Area2D = enemy_scene.instantiate()
	_entities.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = _player.global_position + aim_dir * 160.0
	enemy.setup(enemy.global_position, _player, 1.0)
	await get_tree().physics_frame

	for _i in 80:
		await get_tree().physics_frame
		if GameManager.score > score_before:
			break

	var shoot_release := InputEventScreenTouch.new()
	shoot_release.index = 1
	shoot_release.position = aim_screen
	shoot_release.pressed = false
	_push_touch(shoot_release)

	print("RUNTIME touch_shoot_pressed=%s" % str(TouchInput.is_shoot_pressed() or AudioManager.sfx_played_count > sfx_before).to_lower())
	print("RUNTIME score_after_shot=%d" % GameManager.score)
	print("RUNTIME touch_shoot_score=%d" % (GameManager.score - score_before))
	print("RUNTIME sfx_played=%d" % AudioManager.sfx_played_count)

	if GameManager.score != score_before + 100:
		_fail("touch shoot did not award score")
	if AudioManager.sfx_played_count <= sfx_before:
		_fail("touch shoot did not play sfx")
	if GameManager.score - score_before != 100:
		_fail("touch shoot score mismatch")