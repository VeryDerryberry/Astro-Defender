extends CharacterBody2D

const GameLogic := preload("res://scripts/game_logic.gd")
const BASE_THRUST_FORCE := 280.0
const BASE_MAX_SPEED := 320.0
const FRICTION := 4.5

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
	hit_area.area_entered.connect(_on_hit_area_entered)
	_apply_fire_rate()


func _apply_fire_rate() -> void:
	shoot_timer.wait_time = GameOptions.fire_rate


func apply_movement(input_dir: Vector2, delta: float) -> void:
	var speed_scale := GameOptions.player_speed_multiplier
	var thrust := BASE_THRUST_FORCE * speed_scale
	var max_speed := BASE_MAX_SPEED * speed_scale
	velocity = GameLogic.apply_thrust(velocity, input_dir, delta, thrust, max_speed, FRICTION)


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var touch_thrust := TouchInput.get_thrust_vector()
	if touch_thrust.length_squared() > 0.01:
		input_dir = touch_thrust

	apply_movement(input_dir, delta)

	var aim_pos: Vector2 = get_global_mouse_position()
	if TouchInput.has_active_aim():
		aim_pos = TouchInput.get_aim_world_position()

	rotation = (aim_pos - global_position).angle() + PI / 2.0

	var viewport_size := get_viewport_rect().size
	velocity = GameLogic.zero_velocity_into_wall(
		velocity, global_position, GameLogic.SHIP_HULL_RADIUS, viewport_size
	)
	move_and_slide()

	var wants_shoot := Input.is_action_pressed("shoot") or TouchInput.is_shoot_pressed()
	if wants_shoot and can_shoot:
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
	AudioManager.play_shoot()


func take_hit() -> void:
	if invincible or GameManager.state != GameManager.State.PLAYING:
		return

	invincible = true
	invincibility_timer.start()
	GameManager.lose_health()
	AudioManager.play_hit()

	if GameManager.health > 0:
		velocity = Vector2.ZERO
		global_position = GameLogic.playable_rect(get_viewport_rect().size).get_center()


func _on_hit_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if area.has_method("destroy"):
			area.destroy(false)
		else:
			area.queue_free()
		take_hit()
	elif area.is_in_group("health_items"):
		if area.has_method("collect"):
			area.collect()
	elif area.is_in_group("asteroids"):
		if area.has_method("destroy"):
			area.destroy()


func _on_shoot_timer_timeout() -> void:
	can_shoot = true


func _on_invincibility_timer_timeout() -> void:
	invincible = false


func _process(_delta: float) -> void:
	var visible := not invincible or int(Time.get_ticks_msec() / 100) % 2 == 0
	ship_body.visible = visible
	ship_outline.visible = visible