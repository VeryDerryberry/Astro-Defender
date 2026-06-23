extends Area2D

const GameLogic := preload("res://scripts/game_logic.gd")
const BASE_SPEED := 90.0

var velocity := Vector2.ZERO
var speed_multiplier := 1.0
var target: Node2D

@onready var body: Polygon2D = $Body
@onready var outline: Line2D = $Outline


func setup(spawn_pos: Vector2, target_node: Node2D, multiplier: float = 1.0) -> void:
	global_position = spawn_pos
	target = target_node
	speed_multiplier = multiplier
	_update_pursuit()


func _update_pursuit() -> void:
	var target_pos := target.global_position if is_instance_valid(target) else global_position + Vector2.RIGHT
	var direction: Vector2 = GameLogic.direction_toward(global_position, target_pos)
	velocity = direction * BASE_SPEED * speed_multiplier
	rotation = direction.angle() + PI / 2.0


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	_update_pursuit()
	global_position += velocity * delta

	if GameLogic.is_outside_play_area(global_position, get_viewport_rect().size, 60.0):
		queue_free()