extends CharacterBody2D

const GameLogic := preload("res://scripts/game_logic.gd")
const THRUST_FORCE := 280.0
const MAX_SPEED := 320.0
const FRICTION := 4.5
const SHOOT_COOLDOWN := 0.18

var projectile_scene: PackedScene
var can_shoot := true
var invincible := false

@onready var ship_body: Polygon2D = $ShipBody
@onready var ship_outline: Line2D = $ShipOutline
@onready var hit_area: Area2D = $HitArea
@onready var shoot_timer: Timer = $ShootTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer


func _ready() -> void:
	projectile_scene = preload("res://scenes/projectile.tscn")
	shoot_timer.wait_time = SHOOT_COOLDOWN
	hit_area.area_entered.connect(_on_hit_area_entered)


func apply_movement(input_dir: Vector2, delta: float) -> void:
	velocity = GameLogic.apply_thrust(velocity, input_dir, delta, THRUST_FORCE, MAX_SPEED, FRICTION)


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	apply_movement(input_dir, delta)

	var mouse_pos := get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle() + PI / 2.0

	move_and_slide()
	var viewport_size := get_viewport_rect().size
	velocity = GameLogic.zero_velocity_into_wall(
		velocity,
		global_position,
		GameLogic.SHIP_HULL_RADIUS,
		viewport_size
	)

	if Input.is_action_pressed("shoot") and can_shoot:
		_shoot()


func _shoot() -> void:
	can_shoot = false
	shoot_timer.start()

	var projectile: Area2D = projectile_scene.instantiate()
	projectile.global_position = global_position + Vector2.UP.rotated(rotation) * 14.0
	projectile.rotation = rotation
	var container := ArenaContext.get_entities()
	if container == null:
		push_error("ArenaContext has no entities container")
		projectile.queue_free()
		return
	container.add_child(projectile)


func take_hit() -> void:
	if invincible or GameManager.state != GameManager.State.PLAYING:
		return

	invincible = true
	invincibility_timer.start()
	GameManager.lose_life()

	if GameManager.lives > 0:
		velocity = Vector2.ZERO
		global_position = GameLogic.playable_rect(get_viewport_rect().size).get_center()


func _on_hit_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if area.has_method("destroy"):
			area.destroy(false)
		else:
			area.queue_free()
		take_hit()


func _on_shoot_timer_timeout() -> void:
	can_shoot = true


func _on_invincibility_timer_timeout() -> void:
	invincible = false


func _process(_delta: float) -> void:
	var visible := not invincible or int(Time.get_ticks_msec() / 100) % 2 == 0
	ship_body.visible = visible
	ship_outline.visible = visible