extends CharacterBody2D
class_name Ship

## Constants for ship movement and appearance
const MAX_SPEED := 200.0
const SPEED_STEP := 28.0
const ROTATION_SPEED := 2.8
const SHIP_OUTLINE_WIDTH := 3.0

## Ship model points (Asteroids-style)
const SHIP_POINTS: PackedVector2Array = [
	Vector2(0, -24),   # Forward "nose" point
	Vector2(18, 24),   # Back right "wing" point
	Vector2(0, 18),    # Back middle "engine" point
	Vector2(-18, 24),  # Left back "wing" point
	Vector2(0, -24)    # Connect back to nose
]

## Game world bounds for wrapping logic
var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))

## Movement state
var current_speed := 0.0
var acceleration_multiplier := 1.0
var is_immune := false

const IMMUNITY_RING_WIDTH := 2.0
const IMMUNITY_RING_RENDER_SIDES := 48
const SHIP_HIT_RADIUS := 18.0
const IMMUNITY_RING_EXTRA_PIXELS := 4.0

func _physics_process(_delta: float) -> void:
	# Wrap around logic
	_wrap_to_bounds()
	queue_redraw()

func update_movement(
	delta: float,
	turn_left: bool,
	turn_right: bool,
	accelerate: bool,
	decelerate: bool,
	multiplier: float = 1.0
) -> void:
	acceleration_multiplier = multiplier
	
	# Handle rotation
	var rotate_input := 0.0
	if turn_left:
		rotate_input -= 1.0
	if turn_right:
		rotate_input += 1.0
	rotation += rotate_input * ROTATION_SPEED * delta
	
	# Handle speed
	if accelerate:
		current_speed = clampf(current_speed + (SPEED_STEP * acceleration_multiplier * delta), 0.0, MAX_SPEED)
	if decelerate:
		current_speed = clampf(current_speed - (SPEED_STEP * delta), 0.0, MAX_SPEED)
	
	# Apply velocity
	if current_speed > 0.0:
		velocity = Vector2.UP.rotated(rotation) * current_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func reset(center: Vector2) -> void:
	global_position = center
	rotation = 0.0 # Facing UP
	current_speed = 0.0
	velocity = Vector2.ZERO
	show()
	queue_redraw()

func full_stop() -> void:
	current_speed = 0.0
	velocity = Vector2.ZERO

func _wrap_to_bounds() -> void:
	var pos := global_position
	var wrap_triggered := false
	
	if pos.x < world_bounds.position.x:
		pos.x = world_bounds.end.x
		wrap_triggered = true
	elif pos.x > world_bounds.end.x:
		pos.x = world_bounds.position.x
		wrap_triggered = true
		
	if pos.y < world_bounds.position.y:
		pos.y = world_bounds.end.y
		wrap_triggered = true
	elif pos.y > world_bounds.end.y:
		pos.y = world_bounds.position.y
		wrap_triggered = true
		
	if wrap_triggered:
		global_position = pos

func _draw() -> void:
	# Draw the ship using manual polyline for the 8-bit feel
	# To support "wrapping" visuals, we draw multiple copies if near an edge.
	# The points are in local space, so (0,0) is our center.
	
	var offsets := [
		Vector2.ZERO,
		Vector2(world_bounds.size.x, 0),
		Vector2(-world_bounds.size.x, 0),
		Vector2(0, world_bounds.size.y),
		Vector2(0, -world_bounds.size.y),
		Vector2(world_bounds.size.x, world_bounds.size.y),
		Vector2(-world_bounds.size.x, world_bounds.size.y),
		Vector2(world_bounds.size.x, -world_bounds.size.y),
		Vector2(-world_bounds.size.x, -world_bounds.size.y)
	]
	
	for offset in offsets:
		# Check if this offset drawing would even be visible
		# Actually, since it's local space, it's easier to just draw.
		# If the node is at (5,5), drawing at (0,0) + (1600,0) will draw at (1605,5).
		draw_set_transform(offset, 0, Vector2.ONE)
		draw_polyline(SHIP_POINTS, modulate, SHIP_OUTLINE_WIDTH, true)
		
		if is_immune:
			var ring_color := modulate
			ring_color.a = 0.95
			draw_arc(Vector2.ZERO, SHIP_HIT_RADIUS + IMMUNITY_RING_EXTRA_PIXELS, 0.0, TAU, IMMUNITY_RING_RENDER_SIDES, ring_color, IMMUNITY_RING_WIDTH, true)
	
	# Reset transform for any subsequent draws
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func apply_network_state(new_position: Vector2, new_rotation: float, new_speed: float) -> void:
	global_position = new_position
	rotation = new_rotation
	current_speed = new_speed
	queue_redraw()
