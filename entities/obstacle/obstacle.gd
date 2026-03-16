extends Area2D
class_name Obstacle

const OUTLINE_WIDTH := 2.0
const WRAP_UTILS_SCRIPT := preload("res://scripts/wrap_utils.gd")

var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
var edge_wrapping := true

var shape_index := 0 :
	set(value):
		shape_index = value
		_update_shape()
var shape_scale := 1.0 :
	set(value):
		shape_scale = value
		_update_shape()

var PRESET_SHAPES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(-20, -20), Vector2(0, -30), Vector2(25, -15), Vector2(30, 10), Vector2(10, 25), Vector2(-15, 20), Vector2(-25, 0)]),
	PackedVector2Array([Vector2(-15, -25), Vector2(15, -25), Vector2(30, 0), Vector2(20, 20), Vector2(-10, 30), Vector2(-25, 10)]),
	PackedVector2Array([Vector2(-30, -10), Vector2(-10, -30), Vector2(20, -20), Vector2(30, 10), Vector2(10, 30), Vector2(-20, 20)]),
	PackedVector2Array([Vector2(-10, -25), Vector2(15, -20), Vector2(25, 5), Vector2(10, 25), Vector2(-15, 25), Vector2(-30, 5)])
]

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

func _ready() -> void:
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(1)
		
	var main_node = get_tree().current_scene
	if main_node != null and "world_bounds" in main_node:
		world_bounds = main_node.world_bounds
		edge_wrapping = main_node.current_edge_wrapping
	
	_update_shape()

func _update_shape() -> void:
	if shape_index < 0 or shape_index >= PRESET_SHAPES.size():
		return
		
	var base_points = PRESET_SHAPES[shape_index]
	var scaled_points := PackedVector2Array()
	for p in base_points:
		scaled_points.append(p * shape_scale)
		
	if collision_polygon != null:
		collision_polygon.polygon = scaled_points
		print("Obstacle %s shape updated with %d points" % [name, scaled_points.size()])
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var offsets := WRAP_UTILS_SCRIPT.get_wrap_offsets(world_bounds, edge_wrapping)
	var points := collision_polygon.polygon if collision_polygon != null else PackedVector2Array()
	if points.is_empty():
		return
		
	# Close the polygon for drawing
	var draw_points = points.duplicate()
	draw_points.append(points[0])
		
	for offset in offsets:
		draw_set_transform(offset.rotated(-rotation), 0, Vector2.ONE)
		draw_polyline(draw_points, Color.WHITE, OUTLINE_WIDTH, true)
		
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
