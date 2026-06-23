extends Node2D

const GameLogic := preload("res://scripts/game_logic.gd")

@onready var arena_border: Line2D = $ArenaBorder
@onready var arena_walls: StaticBody2D = $ArenaWalls
@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $Spawner
@onready var entities: Node2D = $Entities

@onready var start_menu: Control = $UI/StartMenu
@onready var hud: Control = $UI/HUD
@onready var game_over_panel: Control = $UI/GameOverPanel

@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var lives_label: Label = $UI/HUD/LivesLabel
@onready var wave_label: Label = $UI/HUD/WaveLabel
@onready var final_score_label: Label = $UI/GameOverPanel/VBox/FinalScoreLabel
@onready var high_score_label: Label = $UI/GameOverPanel/VBox/HighScoreLabel

var _option_labels: Dictionary = {}


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	arena_border.points = GameLogic.arena_border_points(viewport_size)
	GameLogic.configure_wall_shapes(arena_walls, viewport_size)
	ArenaContext.register(player, entities)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	GameOptions.options_changed.connect(_refresh_options_labels)
	_setup_options_ui()
	_on_state_changed(GameManager.state)
	_update_hud()

	if _verify_mode_enabled():
		var verifier := preload("res://scripts/headless_verify.gd").new()
		add_child(verifier)
		verifier.setup(self)
		verifier.run()


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
	print("RUNTIME options_applied=%s" % GameOptions.summary())


func _restart() -> void:
	_clear_entities()
	TouchInput.reset_state()
	player._apply_fire_rate()
	GameManager.start_game()
	player.global_position = _arena_center()
	player.velocity = Vector2.ZERO


func _arena_center() -> Vector2:
	return GameLogic.playable_rect(get_viewport_rect().size).get_center()


func _clear_entities() -> void:
	for child in entities.get_children():
		child.queue_free()


func _on_state_changed(new_state: GameManager.State) -> void:
	start_menu.visible = new_state == GameManager.State.MENU
	hud.visible = new_state == GameManager.State.PLAYING
	game_over_panel.visible = new_state == GameManager.State.GAME_OVER
	player.visible = new_state != GameManager.State.MENU
	spawner.process_mode = Node.PROCESS_MODE_INHERIT if new_state == GameManager.State.PLAYING else Node.PROCESS_MODE_DISABLED

	if new_state == GameManager.State.GAME_OVER:
		final_score_label.text = "Score: %d" % GameManager.score
		high_score_label.text = "High Score: %d" % GameManager.high_score


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score


func _on_lives_changed(new_lives: int) -> void:
	lives_label.text = "Lives: %d" % new_lives


func _on_wave_changed(new_wave: int) -> void:
	wave_label.text = "Wave: %d" % new_wave


func _update_hud() -> void:
	_on_score_changed(GameManager.score)
	_on_lives_changed(GameManager.lives)
	_on_wave_changed(GameManager.wave)


func _setup_options_ui() -> void:
	var options_box: VBoxContainer = start_menu.get_node("OptionsBox")
	_add_option_row(options_box, "Fire Rate", "fire_rate", -0.02, 0.02)
	_add_option_row(options_box, "Lives", "lives", -1, 1)
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
		"lives":
			GameOptions.adjust_lives(int(delta))
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
	_option_labels["lives"].text = "Lives: %d" % GameOptions.starting_lives
	_option_labels["enemies"].text = "Enemies / Wave: %d" % GameOptions.enemies_per_wave
	_option_labels["enemy_speed"].text = "Enemy Speed: x%.1f" % GameOptions.enemy_speed_multiplier
	_option_labels["player_speed"].text = "Player Speed: x%.1f" % GameOptions.player_speed_multiplier
	_option_labels["spawn_interval"].text = "Spawn Interval: %.1fs" % GameOptions.spawn_interval