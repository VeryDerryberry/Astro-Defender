extends Node2D

const GameLogic := preload("res://scripts/game_logic.gd")

const CAMERA_ZOOM_IDLE := 2.2
const CAMERA_ZOOM_LERP_SPEED := 4.0
const CAMERA_POSITION_LERP_SPEED := 10.0
const CAMERA_MOVE_SPEED_THRESHOLD := 15.0

@onready var arena_border: Line2D = $ArenaBorder
@onready var arena_walls: StaticBody2D = $ArenaWalls
@onready var camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $Spawner
@onready var entities: Node2D = $Entities

@onready var start_menu: Control = $UI/StartMenu
@onready var hud: Control = $UI/HUD
@onready var game_over_panel: Control = $UI/GameOverPanel

@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var health_label: Label = $UI/HUD/HealthLabel
@onready var wave_label: Label = $UI/HUD/WaveLabel
@onready var touch_to_start_button: Button = $UI/StartMenu/VBox/TouchToStartButton
@onready var menu_high_score_label: Label = $UI/StartMenu/VBox/MenuHighScoreLabel
@onready var final_score_label: Label = $UI/GameOverPanel/VBox/FinalScoreLabel
@onready var high_score_label: Label = $UI/GameOverPanel/VBox/HighScoreLabel

var _option_labels: Dictionary = {}


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	arena_border.points = GameLogic.arena_border_points(viewport_size)
	GameLogic.configure_wall_shapes(arena_walls, viewport_size)
	_setup_camera(viewport_size)
	ArenaContext.register(player, entities)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	GameOptions.options_changed.connect(_refresh_options_labels)
	touch_to_start_button.pressed.connect(_start_play)
	_setup_options_ui()
	_on_state_changed(GameManager.state)
	_update_hud()
	_refresh_menu_high_score()

	if _verify_mode_enabled():
		var verifier := preload("res://scripts/headless_verify.gd").new()
		add_child(verifier)
		verifier.setup(self)
		verifier.run()


func _process(delta: float) -> void:
	_update_camera(delta)


func _setup_camera(viewport_size: Vector2) -> void:
	var center := GameLogic.playable_rect(viewport_size).get_center()
	var menu_zoom := GameLogic.fit_zoom_for_playable(viewport_size)
	camera.position = center
	camera.zoom = Vector2.ONE * menu_zoom


func _snap_camera_to_player() -> void:
	var viewport_size := get_viewport_rect().size
	camera.position = GameLogic.clamp_camera_position(
		player.global_position, viewport_size, CAMERA_ZOOM_IDLE
	)
	camera.zoom = Vector2.ONE * CAMERA_ZOOM_IDLE


func _update_camera(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var target_zoom := GameLogic.fit_zoom_for_playable(viewport_size)
	var follow_target := GameLogic.playable_rect(viewport_size).get_center()

	if GameManager.state == GameManager.State.PLAYING:
		follow_target = player.global_position
		if player.velocity.length() > CAMERA_MOVE_SPEED_THRESHOLD:
			target_zoom = GameLogic.fit_zoom_for_playable(viewport_size)
		else:
			target_zoom = GameLogic.idle_zoom_for_position(
				player.global_position, viewport_size, CAMERA_ZOOM_IDLE
			)

	var zoom_lerp_speed := CAMERA_ZOOM_LERP_SPEED
	var is_moving := (
		GameManager.state == GameManager.State.PLAYING
		and player.velocity.length() > CAMERA_MOVE_SPEED_THRESHOLD
	)
	if is_moving:
		zoom_lerp_speed = 8.0

	var current_zoom := camera.zoom.x
	var new_zoom := lerpf(current_zoom, target_zoom, zoom_lerp_speed * delta)
	camera.zoom = Vector2(new_zoom, new_zoom)

	var clamped_pos := GameLogic.clamp_camera_position(follow_target, viewport_size, new_zoom)
	if is_moving:
		camera.position = clamped_pos
	else:
		camera.position = camera.position.lerp(clamped_pos, CAMERA_POSITION_LERP_SPEED * delta)


func _verify_mode_enabled() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--verify":
			return true
	return false


func _input(event: InputEvent) -> void:
	if GameManager.state == GameManager.State.PLAYING:
		TouchInput.handle_event(event, get_viewport())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if GameManager.state == GameManager.State.MENU:
			_start_play()
		elif GameManager.state == GameManager.State.GAME_OVER:
			_restart()
		return

	if GameManager.state == GameManager.State.MENU:
		if event is InputEventKey or event is InputEventMouseButton:
			if event.is_pressed():
				_start_play()
	elif GameManager.state == GameManager.State.GAME_OVER:
		if event is InputEventKey or event is InputEventMouseButton:
			if event.is_pressed():
				_restart()


func _start_play() -> void:
	_clear_entities()
	TouchInput.reset_state()
	player._apply_fire_rate()
	GameManager.start_game()
	player.global_position = _arena_center()
	player.velocity = Vector2.ZERO
	_snap_camera_to_player()
	print("RUNTIME options_applied=%s" % GameOptions.summary())
	print("RUNTIME game_start_from_menu=true")


func _restart() -> void:
	_clear_entities()
	TouchInput.reset_state()
	player._apply_fire_rate()
	GameManager.start_game()
	player.global_position = _arena_center()
	player.velocity = Vector2.ZERO
	_snap_camera_to_player()


func _arena_center() -> Vector2:
	return GameLogic.playable_rect(get_viewport_rect().size).get_center()


func _clear_entities() -> void:
	for child in entities.get_children():
		entities.remove_child(child)
		child.free()


func _on_state_changed(new_state: GameManager.State) -> void:
	start_menu.visible = new_state == GameManager.State.MENU
	hud.visible = new_state == GameManager.State.PLAYING
	game_over_panel.visible = new_state == GameManager.State.GAME_OVER
	player.visible = new_state != GameManager.State.MENU
	spawner.process_mode = Node.PROCESS_MODE_INHERIT if new_state == GameManager.State.PLAYING else Node.PROCESS_MODE_DISABLED

	if new_state == GameManager.State.MENU:
		_clear_entities()
		_refresh_menu_high_score()
		print("RUNTIME returned_to_menu=true")

	if new_state == GameManager.State.GAME_OVER:
		final_score_label.text = "Score: %d" % GameManager.score
		high_score_label.text = "High Score: %d" % GameManager.high_score


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score


func _on_health_changed(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health


func _on_wave_changed(new_wave: int) -> void:
	wave_label.text = "Wave: %d" % new_wave


func _update_hud() -> void:
	_on_score_changed(GameManager.score)
	_on_health_changed(GameManager.health)
	_on_wave_changed(GameManager.wave)


func _refresh_menu_high_score() -> void:
	menu_high_score_label.text = "High Score: %d" % GameManager.high_score


func _setup_options_ui() -> void:
	var options_box: VBoxContainer = start_menu.get_node("OptionsBox")
	_add_option_row(options_box, "Fire Rate", "fire_rate", -0.02, 0.02)
	_add_option_row(options_box, "Health", "health", -1, 1)
	_add_option_row(options_box, "Enemies / Wave", "enemies", -1, 1)
	_add_option_row(options_box, "Enemy Speed", "enemy_speed", -0.1, 0.1)
	_add_option_row(options_box, "Player Speed", "player_speed", -0.1, 0.1)
	_add_option_row(options_box, "Spawn Interval", "spawn_interval", -0.1, 0.1)
	_refresh_options_labels()


func _add_option_row(parent: VBoxContainer, title: String, key: String, dec: float, inc: float) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(36, 28)
	minus.pressed.connect(func() -> void: _adjust_option(key, dec))
	row.add_child(minus)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(280, 28)
	label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.85))
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
	_option_labels[key] = label

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(36, 28)
	plus.pressed.connect(func() -> void: _adjust_option(key, inc))
	row.add_child(plus)


func _adjust_option(key: String, delta: float) -> void:
	match key:
		"fire_rate":
			GameOptions.adjust_fire_rate(delta)
		"health":
			GameOptions.adjust_health(int(delta))
		"enemies":
			GameOptions.adjust_enemies(int(delta))
		"enemy_speed":
			GameOptions.adjust_enemy_speed(delta)
		"player_speed":
			GameOptions.adjust_player_speed(delta)
		"spawn_interval":
			GameOptions.adjust_spawn_interval(delta)


func _refresh_options_labels() -> void:
	_option_labels["fire_rate"].text = "Fire Rate: %.2fs" % GameOptions.fire_rate
	_option_labels["health"].text = "Health: %d" % GameOptions.starting_health
	_option_labels["enemies"].text = "Enemies / Wave: %d" % GameOptions.enemies_per_wave
	_option_labels["enemy_speed"].text = "Enemy Speed: x%.1f" % GameOptions.enemy_speed_multiplier
	_option_labels["player_speed"].text = "Player Speed: x%.1f" % GameOptions.player_speed_multiplier
	_option_labels["spawn_interval"].text = "Spawn Interval: %.1fs" % GameOptions.spawn_interval