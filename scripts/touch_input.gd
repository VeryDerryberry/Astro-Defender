extends Node

var thrust_dir := Vector2.ZERO
var aim_world_pos: Variant = null
var shoot_pressed := false
var touch_events_processed := 0

const JOY_RADIUS := 80.0


func reset_state() -> void:
	thrust_dir = Vector2.ZERO
	aim_world_pos = null
	shoot_pressed = false


func handle_event(event: InputEvent, viewport: Viewport) -> void:
	if event is InputEventScreenTouch:
		touch_events_processed += 1
		_handle_screen_touch(event as InputEventScreenTouch, viewport)
	elif event is InputEventScreenDrag:
		touch_events_processed += 1
		_handle_screen_drag(event as InputEventScreenDrag, viewport)


func get_thrust_vector() -> Vector2:
	return thrust_dir


func get_aim_world_position() -> Variant:
	return aim_world_pos


func is_shoot_pressed() -> bool:
	return shoot_pressed


func screen_to_world(screen_pos: Vector2, viewport: Viewport) -> Vector2:
	return viewport.get_canvas_transform().affine_inverse() * screen_pos


func _handle_screen_touch(event: InputEventScreenTouch, viewport: Viewport) -> void:
	var size := viewport.get_visible_rect().size
	var pos := event.position

	if event.pressed:
		if pos.x < size.x * 0.45:
			_update_joystick(pos, pos, size)
		else:
			aim_world_pos = screen_to_world(pos, viewport)
			shoot_pressed = true
	else:
		if pos.x < size.x * 0.45:
			thrust_dir = Vector2.ZERO
		else:
			shoot_pressed = false
			if pos.x >= size.x * 0.45:
				aim_world_pos = null


func _handle_screen_drag(event: InputEventScreenDrag, viewport: Viewport) -> void:
	var size := viewport.get_visible_rect().size
	var pos := event.position

	if pos.x < size.x * 0.45:
		_update_joystick(event.position - event.relative, pos, size)
	else:
		aim_world_pos = screen_to_world(pos, viewport)
		shoot_pressed = true


func _update_joystick(origin: Vector2, current: Vector2, viewport_size: Vector2) -> void:
	var offset := current - origin
	if offset.length() < 8.0:
		thrust_dir = Vector2.ZERO
		return
	var dir := offset.normalized()
	var strength := clampf(offset.length() / JOY_RADIUS, 0.0, 1.0)
	thrust_dir = dir * strength
	aim_world_pos = screen_to_world(
		Vector2(viewport_size.x * 0.75, viewport_size.y * 0.5),
		get_tree().root.get_viewport()
	)