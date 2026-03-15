extends Area2D
class_name Ship

## Constants for ship movement and appearance
const MAX_SPEED := 200.0
const SPEED_STEP := 28.0
const ROTATION_SPEED := 2.8
const TURRET_ROTATION_SPEED := 1.4
const SHIP_OUTLINE_WIDTH := 2.0
const TURRET_OUTLINE_WIDTH := 2.0
const TURRET_FIRE_INTERVAL := 0.32

## Ship model points (Asteroids-style)
const SHIP_POINTS: PackedVector2Array = [
	Vector2(0, -12),   # Forward "nose" point
	Vector2(9, 12),    # Back right "wing" point
	Vector2(0, 9),     # Back middle "engine" point
	Vector2(-9, 12),   # Left back "wing" point
	Vector2(0, -12)    # Connect back to nose
]

## Turret state
var turret_rotation := 0.0
var turret_operator_id := 0
var turret_visible := false :
	set(value):
		if turret_visible != value:
			turret_visible = value
			queue_redraw()

var turret_color := Color.WHITE :
	set(value):
		if turret_color != value:
			turret_color = value
			queue_redraw()

var ship_color := Color.WHITE :
	set(value):
		if ship_color != value:
			ship_color = value
			queue_redraw()

var turret_fire_cooldown := 0.0
var _turret_input_left := false
var _turret_input_right := false

const TURRET_RADIUS := 4.5
const TURRET_BARREL_LENGTH := 14.0
const TURRET_PROJECTILE_SPAWN_OFFSET := 18.0

## Game world bounds for wrapping logic
var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
var edge_wrapping := true

## Movement state
var velocity := Vector2.ZERO
var current_speed := 0.0
var acceleration_multiplier := 1.0
var is_immune := false :
	set(value):
		if is_immune != value:
			is_immune = value
			queue_redraw()

var _input_left := false
var _input_right := false
var _input_accelerate := false
var _input_decelerate := false

const IMMUNITY_RING_WIDTH := 2.0
const IMMUNITY_RING_RENDER_SIDES := 48
const SHIP_HIT_RADIUS := 8.0
const IMMUNITY_RING_EXTRA_PIXELS := 13.0

const PROJECTILE_SCENE := preload("res://entities/projectile/projectile.tscn")
const PROJECTILE_SPEED := 260.0
const PROJECTILE_SPAWN_OFFSET := 20.0

func _ready() -> void:
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
		
	var main_node = get_tree().current_scene
	if main_node != null and "world_bounds" in main_node:
		world_bounds = main_node.world_bounds
		edge_wrapping = main_node.current_edge_wrapping

func _physics_process(_delta: float) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		# Update movement based on input on server
		update_movement(
			_delta,
			_input_left,
			_input_right,
			_input_accelerate,
			_input_decelerate,
			acceleration_multiplier
		)
		
		# Handle turret movement on server
		var turret_rotate_input := 0.0
		if _turret_input_left:
			turret_rotate_input -= 1.0
		if _turret_input_right:
			turret_rotate_input += 1.0
		turret_rotation += turret_rotate_input * TURRET_ROTATION_SPEED * _delta
		
		# Handle turret fire cooldown
		if turret_fire_cooldown > 0.0:
			turret_fire_cooldown = maxf(0.0, turret_fire_cooldown - _delta)

	# Wrap around logic (all clients should probably do this or rely on sync)
	_wrap_to_bounds()

func _process(_delta: float) -> void:
	queue_redraw()

@rpc("any_peer", "call_local", "unreliable")
func submit_input(
	turn_left: bool,
	turn_right: bool,
	accelerate: bool,
	decelerate: bool
) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return

	_input_left = turn_left
	_input_right = turn_right
	_input_accelerate = accelerate
	_input_decelerate = decelerate

@rpc("any_peer", "call_local", "reliable")
func request_full_stop() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return

	full_stop()

@rpc("any_peer", "call_local", "unreliable")
func request_fire() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	
	_spawn_projectile()

func _spawn_projectile() -> void:
	var forward := Vector2.UP.rotated(rotation)
	var proj = PROJECTILE_SCENE.instantiate()
	# Wrap spawn position too
	var spawn_pos = position + (forward * PROJECTILE_SPAWN_OFFSET)
	
	# Projectile class handles its own wrapping, so we just pass the initial wrapped pos
	proj.position = _wrap_pos(spawn_pos)
	proj.velocity = forward * PROJECTILE_SPEED
	proj.shooter_peer_id = get_multiplayer_authority()
	proj.modulate = ship_color
	proj.world_bounds = world_bounds
	proj.edge_wrapping = edge_wrapping

	get_parent().add_child(proj, true)
@rpc("any_peer", "call_local", "unreliable")
func submit_turret_input(
	turn_left: bool,
	turn_right: bool
) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != turret_operator_id:
		return

	_turret_input_left = turn_left
	_turret_input_right = turn_right

@rpc("any_peer", "call_local", "unreliable")
func request_turret_fire() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != turret_operator_id:
		return
	
	if turret_fire_cooldown <= 0.0:
		turret_fire_cooldown = TURRET_FIRE_INTERVAL
		_spawn_turret_projectile()

func _spawn_turret_projectile() -> void:
	var forward := Vector2.UP.rotated(turret_rotation)
	var proj = PROJECTILE_SCENE.instantiate()
	var spawn_pos = position + (forward * TURRET_PROJECTILE_SPAWN_OFFSET)
	
	proj.position = _wrap_pos(spawn_pos)
	proj.velocity = forward * PROJECTILE_SPEED
	# Use operator ID if present, otherwise default to ship authority for testing
	proj.shooter_peer_id = turret_operator_id if turret_operator_id != 0 else get_multiplayer_authority()
	proj.modulate = turret_color
	proj.world_bounds = world_bounds
	proj.edge_wrapping = edge_wrapping

	get_parent().add_child(proj, true)
func _wrap_pos(pos: Vector2) -> Vector2:
	if not edge_wrapping:
		return pos
	var wrapped := pos
	if wrapped.x < world_bounds.position.x: wrapped.x = world_bounds.end.x
	elif wrapped.x > world_bounds.end.x: wrapped.x = world_bounds.position.x
	if wrapped.y < world_bounds.position.y: wrapped.y = world_bounds.end.y
	elif wrapped.y > world_bounds.end.y: wrapped.y = world_bounds.position.y
	return wrapped

func update_movement(
	delta: float,
	turn_left: bool,
	turn_right: bool,
	accelerate: bool,
	decelerate: bool,
	multiplier: float = 1.0
) -> void:
	acceleration_multiplier = multiplier
	
	var active_accel_multiplier := acceleration_multiplier
	var active_rot_speed := ROTATION_SPEED
	
	if turret_operator_id != 0:
		active_accel_multiplier *= 0.25
		active_rot_speed *= 0.5
	
	# Handle rotation
	var rotate_input := 0.0
	if turn_left:
		rotate_input -= 1.0
	if turn_right:
		rotate_input += 1.0
	rotation += rotate_input * active_rot_speed * delta
	
	# Handle speed
	if accelerate:
		current_speed = clampf(current_speed + (SPEED_STEP * active_accel_multiplier * delta), 0.0, MAX_SPEED)
	if decelerate:
		current_speed = clampf(current_speed - (SPEED_STEP * delta), 0.0, MAX_SPEED)
	
	# Apply velocity
	if current_speed > 0.0:
		velocity = Vector2.UP.rotated(rotation) * current_speed
		position += velocity * delta
	else:
		velocity = Vector2.ZERO

func reset(center: Vector2) -> void:
	position = center
	rotation = 0.0 # Facing UP
	current_speed = 0.0
	velocity = Vector2.ZERO
	show()
	queue_redraw()

func full_stop() -> void:
	current_speed = 0.0
	velocity = Vector2.ZERO

func _wrap_to_bounds() -> void:
	var pos := position
	var wrap_triggered := false

	if pos.x < world_bounds.position.x:
		if edge_wrapping:
			pos.x += world_bounds.size.x
			wrap_triggered = true
		else:
			pos.x = world_bounds.position.x
			full_stop()
			wrap_triggered = true
	elif pos.x > world_bounds.end.x:
		if edge_wrapping:
			pos.x -= world_bounds.size.x
			wrap_triggered = true
		else:
			pos.x = world_bounds.end.x
			full_stop()
			wrap_triggered = true

	if pos.y < world_bounds.position.y:
		if edge_wrapping:
			pos.y += world_bounds.size.y
			wrap_triggered = true
		else:
			pos.y = world_bounds.position.y
			full_stop()
			wrap_triggered = true
	elif pos.y > world_bounds.end.y:
		if edge_wrapping:
			pos.y -= world_bounds.size.y
			wrap_triggered = true
		else:
			pos.y = world_bounds.end.y
			full_stop()
			wrap_triggered = true

	if wrap_triggered:
		position = pos
func _draw() -> void:
	# Draw the ship using manual polyline for the 8-bit feel
	# To support "wrapping" visuals, we draw multiple copies if near an edge.
	# The points are in local space, so (0,0) is our center.
	
	var offsets := [Vector2.ZERO]
	if edge_wrapping:
		offsets.append_array([
			Vector2(world_bounds.size.x, 0),
			Vector2(-world_bounds.size.x, 0),
			Vector2(0, world_bounds.size.y),
			Vector2(0, -world_bounds.size.y),
			Vector2(world_bounds.size.x, world_bounds.size.y),
			Vector2(-world_bounds.size.x, world_bounds.size.y),
			Vector2(world_bounds.size.x, -world_bounds.size.y),
			Vector2(-world_bounds.size.x, -world_bounds.size.y)
		])
	
	for offset in offsets:
		# Check if this offset drawing would even be visible
		# Actually, since it's local space, it's easier to just draw.
		# If the node is at (5,5), drawing at (0,0) + (1600,0) will draw at (1605,5).
		draw_set_transform(offset.rotated(-rotation), 0, Vector2.ONE)
		draw_polyline(SHIP_POINTS, ship_color, SHIP_OUTLINE_WIDTH, true)
		
		# Draw the turret if it is visible
		if turret_visible:
			# Turret rotation is absolute (screen-relative).
			# Since draw() is already rotated by the ship's rotation, 
			# we subtract the ship's rotation to get back to screen-relative 0,
			# then add the turret's rotation.
			var draw_turret_rot := turret_rotation - rotation
			
			var barrel_end := Vector2.UP.rotated(draw_turret_rot) * TURRET_BARREL_LENGTH
			
			# Draw black outlines first (slightly thicker or offset to show)
			# For 1px outline on a line, we can draw a slightly thicker black line behind it
			draw_line(Vector2.ZERO, barrel_end, Color.BLACK, TURRET_OUTLINE_WIDTH + 2.0, true)
			draw_circle(Vector2.ZERO, TURRET_RADIUS + 1.0, Color.BLACK)

			# Draw turret base (filled circle)
			draw_circle(Vector2.ZERO, TURRET_RADIUS, turret_color)
			# Draw turret barrel (line)
			draw_line(Vector2.ZERO, barrel_end, turret_color, TURRET_OUTLINE_WIDTH, true)
		
		if is_immune:
			var ring_color := ship_color
			ring_color.a = 0.95
			draw_arc(Vector2.ZERO, SHIP_HIT_RADIUS + IMMUNITY_RING_EXTRA_PIXELS, 0.0, TAU, IMMUNITY_RING_RENDER_SIDES, ring_color, IMMUNITY_RING_WIDTH, true)
	
	# Reset transform for any subsequent draws
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
