extends Node2D
class_name Projectile

const PROJECTILE_MAX_TRAVEL := 400.0 # WORLD_BOUNDS.size.x * 0.25 (1600 * 0.25)
const PROJECTILE_RADIUS := 1.5
const PROJECTILE_RENDER_SIDES := 12

var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
var velocity := Vector2.ZERO
var distance_traveled := 0.0

@export var shooter_peer_id := -1

func _ready() -> void:
	if not multiplayer.is_server():
		set_physics_process(false)

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
	var pos := position
	var wrap_triggered := false
	
	if pos.x < world_bounds.position.x:
		pos.x += world_bounds.size.x
		wrap_triggered = true
	elif pos.x > world_bounds.end.x:
		pos.x -= world_bounds.size.x
		wrap_triggered = true
		
	if pos.y < world_bounds.position.y:
		pos.y += world_bounds.size.y
		wrap_triggered = true
	elif pos.y > world_bounds.end.y:
		pos.y -= world_bounds.size.y
		wrap_triggered = true
		
	if wrap_triggered:
		position = pos

func _draw() -> void:
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
	
	var points := PackedVector2Array()
	var angle_step: float = (PI * 2.0) / PROJECTILE_RENDER_SIDES
	for i in range(PROJECTILE_RENDER_SIDES):
		var angle: float = i * angle_step
		points.append(Vector2(cos(angle), sin(angle)) * PROJECTILE_RADIUS)
		
	for offset in offsets:
		draw_set_transform(offset.rotated(-rotation), 0, Vector2.ONE)
		draw_colored_polygon(points, modulate)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
