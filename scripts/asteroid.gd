extends Area2D

const GameLogic := preload("res://scripts/game_logic.gd")
const DRIFT_SPEED := 45.0
const ENTITY_GROUP := "asteroids"

var velocity := Vector2.ZERO

@onready var body: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func setup(spawn_pos: Vector2, drift_dir: Vector2) -> void:
	global_position = spawn_pos
	velocity = drift_dir.normalized() * DRIFT_SPEED
	rotation = randf() * TAU


func destroy() -> void:
	AudioManager.play_destroy()
	queue_free()


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	global_position += velocity * delta
	var viewport_size := get_viewport_rect().size
	if GameLogic.is_outside_play_area(global_position, viewport_size, 50.0):
		queue_free()