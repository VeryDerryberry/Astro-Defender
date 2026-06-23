extends Node

var thrust_dir := Vector2.ZERO
var aim_world_pos: Variant = null
var shoot_pressed := false
var touch_events_processed := 0

const JOY_RADIUS := 80.0
const LEFT_ZONE_FRACTION := 0.45

var _finger_positions: Dictionary = {}
var _finger_zones: Dictionary = {}
var _finger_origins: Dictionary = {}


func reset_state() -> void:
	thrust_dir = Vector2.ZERO
	aim_world_pos = null
	shoot_pressed = false
	_finger_positions.clear()
	_finger_zones.clear()
	_finger_origins.clear()


func handle_event(event: InputEvent, viewport: Viewport) -> void:
	if event is InputEventScreenTouch:
		touch_events_processed += 1
		_handle_screen_touch(event as InputEventScreenTouch, viewport)
	elif event is InputEventScreenDrag:
		touch_events_processed += 1
		_finger_positions[event.index] = event.position
		_recompute_state(viewport)


func get_thrust_vector() -> Vector2:
	return thrust_dir


func get_aim_world_position() -> Variant:
	return aim_world_pos


func is_shoot_pressed() -> bool:
	return shoot_pressed


func has_active_aim() -> bool:
	return aim_world_pos is Vector2 and shoot_pressed


func screen_to_world(screen_pos: Vector2, viewport: Viewport) -> Vector2:
	return viewport.get_canvas_transform().affine_inverse() * screen_pos


func _zone_for(pos: Vector2, viewport: Viewport) -> String:
	var size := viewport.get_visible_rect().size
	return "left" if pos.x < size.x * LEFT_ZONE_FRACTION else "right"


func _handle_screen_touch(event: InputEventScreenTouch, viewport: Viewport) -> void:
	if event.pressed:
		_finger_positions[event.index] = event.position
		_finger_zones[event.index] = _zone_for(event.position, viewport)
		if _finger_zones[event.index] == "left":
			_finger_origins[event.index] = event.position
	else:
		_finger_positions.erase(event.index)
		_finger_zones.erase(event.index)
		_finger_origins.erase(event.index)
	_recompute_state(viewport)


func _recompute_state(viewport: Viewport) -> void:
	thrust_dir = Vector2.ZERO
	aim_world_pos = null
	shoot_pressed = false

	var best_strength := 0.0
	for index in _finger_zones:
		if _finger_zones[index] != "left":
			continue
		if not _finger_origins.has(index) or not _finger_positions.has(index):
			continue
		var offset: Vector2 = _finger_positions[index] - _finger_origins[index]
		if offset.length() < 8.0:
			continue
		var strength := clampf(offset.length() / JOY_RADIUS, 0.0, 1.0)
		if strength > best_strength:
			best_strength = strength
			thrust_dir = offset.normalized() * strength

	for index in _finger_zones:
		if _finger_zones[index] != "right" or not _finger_positions.has(index):
			continue
		aim_world_pos = screen_to_world(_finger_positions[index], viewport)
		shoot_pressed = true
		break