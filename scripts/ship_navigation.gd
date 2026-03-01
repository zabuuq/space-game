extends RefCounted
class_name ShipNavigation

const MAX_SPEED := 200.0
const SPEED_STEP := 28
const ROTATION_SPEED := 2.8
const SHIP_POINTS := [
	Vector2(0, 24),
	Vector2(18, -24),
	Vector2(0, -18),
	Vector2(-18, -24)
]

var position: Vector2 = Vector2.ZERO
var rotation_radians := 0.0
var speed := 0.0
var initialized := false

func reset(center: Vector2) -> void:
	position = center
	rotation_radians = 0.0
	speed = 0.0
	initialized = true

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
	bounds: Rect2
) -> void:
	if not initialized:
		reset(bounds.position + (bounds.size * 0.5))

	var rotate_input := 0.0
	if turn_left:
		rotate_input -= 1.0
	if turn_right:
		rotate_input += 1.0
	rotation_radians += rotate_input * ROTATION_SPEED * delta

	if accelerate:
		speed = clampf(speed + (SPEED_STEP * delta), 0.0, MAX_SPEED)

	if speed <= 0.0:
		return

	var forward := Vector2(0, 1).rotated(rotation_radians)
	position += forward * speed * delta
	position = _wrap_to_bounds(position, bounds)

func decrease_speed_once() -> void:
	speed = clampf(speed - SPEED_STEP, 0.0, MAX_SPEED)

func get_transformed_points() -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in SHIP_POINTS:
		transformed.append(position + point.rotated(rotation_radians))
	# Close the shape by connecting back to the nose.
	transformed.append(position + SHIP_POINTS[0].rotated(rotation_radians))
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
