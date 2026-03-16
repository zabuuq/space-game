extends Area2D

const MAX_SPEED := 200.0 / 3.0
const SPEED_STEP := 28.0 / 3.0
const ROTATION_SPEED := 2.8 / 3.0
const FIRE_INTERVAL := 0.96
const NPC_OUTLINE_WIDTH := 2.0
const NPC_HIT_RADIUS := 10.0

const PROJECTILE_SCENE := preload("res://entities/projectile/projectile.tscn")
const PROJECTILE_SPEED := 260.0
const PROJECTILE_MAX_TRAVEL := 400.0 * 1.3333
const WRAP_UTILS_SCRIPT := preload("res://scripts/wrap_utils.gd")

var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
var edge_wrapping := true
var velocity := Vector2.ZERO
var current_speed := 0.0
var fire_cooldown := 0.0

var target_player: Ship = null

func _ready() -> void:
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
	
	var main_node = get_tree().current_scene
	if main_node != null and "world_bounds" in main_node:
		world_bounds = main_node.world_bounds
		edge_wrapping = main_node.current_edge_wrapping

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		_wrap_to_bounds()
		return
		
	_update_targeting()
	_update_movement(delta)
	_update_firing(delta)
	_wrap_to_bounds()

func _update_targeting() -> void:
	var closest_ship: Ship = null
	var min_dist := INF
	
	var main_node = get_tree().current_scene
	if main_node == null or not main_node.has_method("_get_all_ships"):
		return
		
	for ship in main_node._get_all_ships():
		if ship.is_immune: # Maybe don't target immune players? Prompt doesn't say.
			# continue
			pass
			
		var dist: float
		if edge_wrapping:
			# Wrapped distance
			dist = WRAP_UTILS_SCRIPT.get_wrapped_distance(global_position, ship.global_position, world_bounds)
		else:
			# Absolute distance
			dist = global_position.distance_to(ship.global_position)
			
		if dist < min_dist:
			min_dist = dist
			closest_ship = ship
			
	target_player = closest_ship

func _update_movement(delta: float) -> void:
	if target_player == null:
		# If no players, maybe just drift or slow down
		current_speed = maxf(0.0, current_speed - SPEED_STEP * delta)
		position += velocity * delta
		return

	# Move toward closest player
	var target_pos = target_player.global_position
	var diff: Vector2
	
	if edge_wrapping:
		# Find the shortest vector considering wrapping
		diff = WRAP_UTILS_SCRIPT.get_wrapped_vector(global_position, target_pos, world_bounds)
	else:
		diff = target_pos - global_position
		
	var target_dir = diff.normalized()
	
	# Flying saucers can move in any direction. Prompt says: "Should always move toward the closest player ship."
	# "Accelaration, turn speed, maximum speed... one-third what a standard player ship is."
	# Does "turn speed" apply if it moves like a saucer (omni-directional)?
	# Prompt says "move in any direction", but also gives "turn speed".
	# If it always moves toward the player, maybe it turns its VELOCITY vector.
	
	var desired_velocity = target_dir * MAX_SPEED
	velocity = velocity.move_toward(desired_velocity, SPEED_STEP * delta)
	position += velocity * delta
	current_speed = velocity.length()

func _update_firing(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
		
	if target_player == null or fire_cooldown > 0.0:
		return
		
	var diff: Vector2
	if edge_wrapping:
		diff = WRAP_UTILS_SCRIPT.get_wrapped_vector(global_position, target_player.global_position, world_bounds)
	else:
		diff = target_player.global_position - global_position
		
	var dist = diff.length()
	if dist <= PROJECTILE_MAX_TRAVEL:
		_spawn_projectile(diff.normalized())
		fire_cooldown = FIRE_INTERVAL

func _spawn_projectile(dir: Vector2) -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	proj.position = WRAP_UTILS_SCRIPT.wrap_pos(position, world_bounds, edge_wrapping)
	proj.velocity = dir * PROJECTILE_SPEED
	proj.shooter_peer_id = -1 # NPC shooter
	proj.modulate = Color.WHITE
	proj.world_bounds = world_bounds
	proj.edge_wrapping = edge_wrapping
	# Override distance traveled limit for NPC
	# We'll need to set this after add_child or via a property if Projectile supports it.
	# Let's check if we can modify PROJECTILE_MAX_TRAVEL on the instance.
	# Actually PROJECTILE_MAX_TRAVEL is a constant in projectile.gd.
	# I should probably update projectile.gd to use a variable.
	
	get_parent().add_child(proj, true)
	if "max_travel_distance" in proj: # I will add this to projectile.gd
		proj.max_travel_distance = PROJECTILE_MAX_TRAVEL

func _wrap_to_bounds() -> void:
	if edge_wrapping:
		var new_pos := WRAP_UTILS_SCRIPT.wrap_pos(position, world_bounds, true)
		if new_pos != position:
			position = new_pos
	else:
		var clamped_x := clampf(position.x, world_bounds.position.x, world_bounds.end.x)
		var clamped_y := clampf(position.y, world_bounds.position.y, world_bounds.end.y)
		if clamped_x != position.x or clamped_y != position.y:
			position = Vector2(clamped_x, clamped_y)
			velocity = Vector2.ZERO # Stop if hit edge

func full_stop() -> void:
	current_speed = 0.0
	velocity = Vector2.ZERO

func _draw() -> void:
	var offsets := WRAP_UTILS_SCRIPT.get_wrap_offsets(world_bounds, edge_wrapping)
	
	for offset in offsets:
		draw_set_transform(offset, 0, Vector2.ONE)
		
		# Saucer shape: white thin oval outline with half circle on top
		# Oval (thin): same size as player ship from point to back (21 units)
		# Let's use Rect2 for the oval drawing area or a series of points
		
		# Draw Oval outline
		var oval_width := 24.0
		var oval_height := 8.0
		_draw_oval_outline(Vector2.ZERO, oval_width, oval_height, Color.WHITE, NPC_OUTLINE_WIDTH)
		
		# Draw Half Circle on top
		var dome_radius := 6.0
		_draw_half_circle_outline(Vector2(0, -2), dome_radius, Color.WHITE, NPC_OUTLINE_WIDTH)
		
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_oval_outline(center: Vector2, width: float, height: float, color: Color, thickness: float) -> void:
	var points := PackedVector2Array()
	var steps := 32
	for i in range(steps + 1):
		var angle := i * TAU / steps
		points.append(center + Vector2(cos(angle) * width / 2.0, sin(angle) * height / 2.0))
	draw_polyline(points, color, thickness, true)

func _draw_half_circle_outline(center: Vector2, radius: float, color: Color, thickness: float) -> void:
	var points := PackedVector2Array()
	var steps := 16
	for i in range(steps + 1):
		var angle := -PI + (i * PI / steps) # From -PI to 0 (top half)
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	draw_polyline(points, color, thickness, false)
