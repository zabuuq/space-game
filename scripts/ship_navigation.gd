extends RefCounted
class_name ShipNavigation

const WORLD_BOUNDS := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
const MAX_SPEED := 200.0
const SPEED_STEP := 28.0
const ROTATION_SPEED := 2.8
const START_ROTATION_RADIANS := PI
const SHIP_RENDER_SCALE := 0.010
const SHIP_MODEL_POINTS := [
	Vector2(0, 1),
	Vector2(0.75, -1),
	Vector2(0, -0.75),
	Vector2(-0.75, -1)
]

var position: Vector2 = Vector2.ZERO
var rotation_radians := 0.0
var speed := 0.0
var initialized := false

func reset(center: Vector2) -> void:
	position = center
	rotation_radians = START_ROTATION_RADIANS
	speed = 0.0
	initialized = true

func hide() -> void:
	position = Vector2.ZERO
	rotation_radians = START_ROTATION_RADIANS
	speed = 0.0
	initialized = false

func apply_network_state(new_position: Vector2, new_rotation: float, new_speed: float) -> void:
	position = new_position
	rotation_radians = new_rotation
	speed = clampf(new_speed, 0.0, MAX_SPEED)
	initialized = true

func update_host(
	delta: float,
	turn_left: bool,
	turn_right: bool,
	accelerate: bool,
	decelerate: bool,
	bounds: Rect2 = WORLD_BOUNDS
) -> void:
	if not initialized:
		return

	var rotate_input := 0.0
	if turn_left:
		rotate_input -= 1.0
	if turn_right:
		rotate_input += 1.0
	rotation_radians += rotate_input * ROTATION_SPEED * delta

	if accelerate:
		speed = clampf(speed + (SPEED_STEP * delta), 0.0, MAX_SPEED)
	if decelerate:
		speed = clampf(speed - (SPEED_STEP * delta), 0.0, MAX_SPEED)

	if speed <= 0.0:
		return

	var forward := Vector2(0, 1).rotated(rotation_radians)
	position += forward * speed * delta
	position = _wrap_to_bounds(position, bounds)

func full_stop() -> void:
	speed = 0.0

func get_screen_points(play_rect: Rect2, world_bounds: Rect2 = WORLD_BOUNDS) -> PackedVector2Array:
	if play_rect.size.x <= 0.0 or play_rect.size.y <= 0.0:
		return PackedVector2Array()

	var normalized_position := Vector2.ZERO
	if world_bounds.size.x > 0.0:
		normalized_position.x = (position.x - world_bounds.position.x) / world_bounds.size.x
	if world_bounds.size.y > 0.0:
		normalized_position.y = (position.y - world_bounds.position.y) / world_bounds.size.y
	var center := play_rect.position + (normalized_position * play_rect.size)
	var ship_scale := minf(play_rect.size.x, play_rect.size.y) * SHIP_RENDER_SCALE

	var transformed := PackedVector2Array()
	for point in SHIP_MODEL_POINTS:
		transformed.append(center + (point * ship_scale).rotated(rotation_radians))
	# Close the shape by connecting back to the nose.
	transformed.append(center + (SHIP_MODEL_POINTS[0] * ship_scale).rotated(rotation_radians))
	return transformed

func _wrap_to_bounds(current: Vector2, bounds: Rect2) -> Vector2:
	var min_x := bounds.position.x
	var min_y := bounds.position.y
	var max_x := bounds.position.x + bounds.size.x
	var max_y := bounds.position.y + bounds.size.y

	var wrapped := current
	if wrapped.x < min_x:
		wrapped.x = max_x
	elif wrapped.x > max_x:
		wrapped.x = min_x

	if wrapped.y < min_y:
		wrapped.y = max_y
	elif wrapped.y > max_y:
		wrapped.y = min_y

	return wrapped
