extends RefCounted

const ARENA_INSET := 8.0
const SHIP_HULL_RADIUS := 12.0

static func apply_thrust(
	velocity: Vector2,
	input_dir: Vector2,
	delta: float,
	thrust_force: float = 280.0,
	max_speed: float = 320.0,
	friction: float = 4.5
) -> Vector2:
	if input_dir.length_squared() > 0.0:
		velocity += input_dir.normalized() * thrust_force * delta
	elif velocity.length_squared() > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, friction * max_speed * delta)

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	return velocity


static func arena_rect(viewport_size: Vector2, inset: float = ARENA_INSET) -> Rect2:
	return Rect2(Vector2(inset, inset), viewport_size - Vector2(inset * 2.0, inset * 2.0))


static func playable_rect(viewport_size: Vector2, hull_radius: float = SHIP_HULL_RADIUS) -> Rect2:
	var border := arena_rect(viewport_size)
	var pad := Vector2(hull_radius, hull_radius)
	return Rect2(border.position + pad, border.size - pad * 2.0)


static func is_inside_playable(
	pos: Vector2,
	viewport_size: Vector2,
	hull_radius: float = SHIP_HULL_RADIUS
) -> bool:
	return playable_rect(viewport_size, hull_radius).has_point(pos)


static func clamp_to_playable_bounds(
	pos: Vector2,
	viewport_size: Vector2,
	hull_radius: float = 0.0
) -> Vector2:
	var inner := playable_rect(viewport_size, hull_radius)
	return Vector2(
		clampf(pos.x, inner.position.x, inner.position.x + inner.size.x),
		clampf(pos.y, inner.position.y, inner.position.y + inner.size.y)
	)


static func arena_border_points(viewport_size: Vector2) -> PackedVector2Array:
	var rect := arena_rect(viewport_size)
	var top_left := rect.position
	var bottom_right := rect.position + rect.size
	return PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y),
		top_left,
	])


static func zero_velocity_into_wall(
	velocity: Vector2,
	pos: Vector2,
	hull_radius: float,
	viewport_size: Vector2
) -> Vector2:
	var inner := playable_rect(viewport_size, hull_radius)
	var min_x := inner.position.x
	var max_x := inner.position.x + inner.size.x
	var min_y := inner.position.y
	var max_y := inner.position.y + inner.size.y

	if pos.x <= min_x + 0.5 and velocity.x < 0.0:
		velocity.x = 0.0
	if pos.x >= max_x - 0.5 and velocity.x > 0.0:
		velocity.x = 0.0
	if pos.y <= min_y + 0.5 and velocity.y < 0.0:
		velocity.y = 0.0
	if pos.y >= max_y - 0.5 and velocity.y > 0.0:
		velocity.y = 0.0
	return velocity


static func is_outside_play_area(
	pos: Vector2,
	viewport_size: Vector2,
	margin: float = 0.0
) -> bool:
	var rect := arena_rect(viewport_size)
	return (
		pos.x < rect.position.x - margin
		or pos.x > rect.position.x + rect.size.x + margin
		or pos.y < rect.position.y - margin
		or pos.y > rect.position.y + rect.size.y + margin
	)


static func direction_toward(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var direction := to_pos - from_pos
	if direction.length_squared() < 0.001:
		return Vector2.RIGHT
	return direction.normalized()


static func edge_position_for_arena(
	arena: Rect2,
	side: int,
	along: float,
	margin: float = 30.0
) -> Vector2:
	match side % 4:
		0:
			return Vector2(arena.position.x + along, arena.position.y - margin)
		1:
			return Vector2(arena.position.x + arena.size.x + margin, arena.position.y + along)
		2:
			return Vector2(arena.position.x + along, arena.position.y + arena.size.y + margin)
		_:
			return Vector2(arena.position.x - margin, arena.position.y + along)


static func wave_spawn_positions(viewport_size: Vector2, count: int, margin: float = 30.0) -> Array[Vector2]:
	var arena := arena_rect(viewport_size)
	var positions: Array[Vector2] = []
	for _i in count:
		var side := randi() % 4
		var along := 0.0
		match side:
			0, 2:
				along = randf_range(0, arena.size.x)
			_:
				along = randf_range(0, arena.size.y)
		positions.append(edge_position_for_arena(arena, side, along, margin))
	return positions


static func configure_wall_shapes(walls: StaticBody2D, viewport_size: Vector2) -> void:
	var playable := playable_rect(viewport_size)
	var center_x := playable.position.x + playable.size.x * 0.5
	var center_y := playable.position.y + playable.size.y * 0.5

	var top: CollisionShape2D = walls.get_node("TopWall")
	var bottom: CollisionShape2D = walls.get_node("BottomWall")
	var left: CollisionShape2D = walls.get_node("LeftWall")
	var right: CollisionShape2D = walls.get_node("RightWall")

	top.position = Vector2(center_x, playable.position.y)
	bottom.position = Vector2(center_x, playable.position.y + playable.size.y)
	left.position = Vector2(playable.position.x, center_y)
	right.position = Vector2(playable.position.x + playable.size.x, center_y)

	var h_shape := RectangleShape2D.new()
	h_shape.size = Vector2(playable.size.x, 4.0)
	top.shape = h_shape
	bottom.shape = h_shape.duplicate()

	var v_shape := RectangleShape2D.new()
	v_shape.size = Vector2(4.0, playable.size.y)
	left.shape = v_shape
	right.shape = v_shape.duplicate()


static func edge_index(pos: Vector2, viewport_size: Vector2, _margin: float = 30.0) -> int:
	var arena := arena_rect(viewport_size)
	if pos.y < arena.position.y:
		return 0
	if pos.x > arena.position.x + arena.size.x:
		return 1
	if pos.y > arena.position.y + arena.size.y:
		return 2
	return 3
