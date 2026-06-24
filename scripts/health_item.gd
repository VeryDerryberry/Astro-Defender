extends Area2D

const GameLogic := preload("res://scripts/game_logic.gd")
const DRIFT_SPEED := 25.0
const ENTITY_GROUP := "health_items"
const PULSE_SPEED := 3.0

var velocity := Vector2.ZERO
var _pulse_time := 0.0

@onready var body: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func setup(spawn_pos: Vector2, drift_dir: Vector2) -> void:
	global_position = spawn_pos
	velocity = drift_dir.normalized() * DRIFT_SPEED


func collect() -> void:
	AudioManager.play_destroy()
	GameManager.restore_health()
	queue_free()


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	global_position += velocity * delta
	_pulse_time += delta
	var pulse := 0.85 + 0.15 * sin(_pulse_time * PULSE_SPEED)
	body.modulate = Color(0.4 * pulse, 1.0 * pulse, 0.6 * pulse, 1.0)

	var viewport_size := get_viewport_rect().size
	if GameLogic.is_outside_play_area(global_position, viewport_size, 40.0):
		queue_free()