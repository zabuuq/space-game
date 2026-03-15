extends Area2D
class_name Projectile

const PROJECTILE_MAX_TRAVEL := 400.0 # WORLD_BOUNDS.size.x * 0.25 (1600 * 0.25)
const PROJECTILE_RADIUS := 1.5
const PROJECTILE_RENDER_SIDES := 12
const WRAP_UTILS_SCRIPT := preload("res://scripts/wrap_utils.gd")

var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
var edge_wrapping := true
var velocity := Vector2.ZERO
var distance_traveled := 0.0

@export var shooter_peer_id := -1

func _ready() -> void:
	if not multiplayer.is_server():
		set_physics_process(false)
		
	var main_node = get_tree().current_scene
	if main_node != null and "world_bounds" in main_node:
		world_bounds = main_node.world_bounds
		edge_wrapping = main_node.current_edge_wrapping

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	position += velocity * delta
	distance_traveled += velocity.length() * delta

	if distance_traveled >= PROJECTILE_MAX_TRAVEL:
		queue_free()
		return

	_wrap_to_bounds()

func _wrap_to_bounds() -> void:
	if edge_wrapping:
		var new_pos := WRAP_UTILS_SCRIPT.wrap_pos(position, world_bounds, true)
		if new_pos != position:
			position = new_pos
	else:
		# Delete if hit edge
		if not world_bounds.has_point(position):
			queue_free()

func _draw() -> void:
	var offsets := WRAP_UTILS_SCRIPT.get_wrap_offsets(world_bounds, edge_wrapping)
	
	var points := PackedVector2Array()
	var angle_step: float = (PI * 2.0) / PROJECTILE_RENDER_SIDES
	for i in range(PROJECTILE_RENDER_SIDES):
		var angle: float = i * angle_step
		points.append(Vector2(cos(angle), sin(angle)) * PROJECTILE_RADIUS)
		
	for offset in offsets:
		draw_set_transform(offset.rotated(-rotation), 0, Vector2.ONE)
		draw_colored_polygon(points, modulate)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
