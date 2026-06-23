extends Area2D

const GameLogic := preload("res://scripts/game_logic.gd")
const SPEED := 520.0
const LIFETIME := 1.8

@onready var line: Line2D = $Line2D
@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	lifetime_timer.wait_time = LIFETIME
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	lifetime_timer.start()
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	global_position += Vector2.UP.rotated(rotation) * SPEED * delta

	if GameLogic.is_outside_play_area(global_position, get_viewport_rect().size, 40.0):
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if area.has_method("destroy"):
			area.destroy()
		queue_free()


func _on_lifetime_expired() -> void:
	queue_free()