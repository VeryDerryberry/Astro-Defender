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


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	arena_border.points = GameLogic.arena_border_points(viewport_size)
	GameLogic.configure_wall_shapes(arena_walls, viewport_size)
	ArenaContext.register(player, entities)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	_on_state_changed(GameManager.state)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
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
	GameManager.start_game()
	player.global_position = _arena_center()
	player.velocity = Vector2.ZERO


func _restart() -> void:
	_clear_entities()
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