extends Node2D
class_name Starfield

const STAR_COUNT_PER_SCREEN = 150
var world_bounds := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
var stars: Array[Vector2] = []

func _ready() -> void:
	z_index = -10

func generate_stars(bounds: Rect2) -> void:
	world_bounds = bounds
	stars.clear()
	var area_ratio = (bounds.size.x * bounds.size.y) / (1600.0 * 900.0)
	var num_stars = int(STAR_COUNT_PER_SCREEN * area_ratio)
	
	# Use a consistent seed based on bounds so all clients see the same stars
	seed(int(bounds.size.x * bounds.size.y))
	
	for i in range(num_stars):
		var x = randf_range(bounds.position.x, bounds.end.x)
		var y = randf_range(bounds.position.y, bounds.end.y)
		stars.append(Vector2(x, y))
	
	queue_redraw()

func _draw() -> void:
	for star in stars:
		draw_rect(Rect2(star, Vector2(2, 2)), Color(0.5, 0.5, 0.5))
