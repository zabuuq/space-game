extends GutTest

const OBSTACLE_SCRIPT = preload("res://entities/obstacle/obstacle.gd")

func test_obstacle_initialization():
	var obs = OBSTACLE_SCRIPT.new()
	assert_not_null(obs, "Obstacle should instantiate")
	obs.free()

func test_obstacle_update_shape():
	var obs = OBSTACLE_SCRIPT.new()
	
	# Mock the collision polygon
	var poly = CollisionPolygon2D.new()
	obs.add_child(poly)
	obs.collision_polygon = poly
	
	obs.shape_index = 0
	obs.shape_scale = 2.0
	
	var expected_points = obs.PRESET_SHAPES[0]
	var scaled_points = poly.polygon
	
	assert_eq(scaled_points.size(), expected_points.size(), "Polygon should have same number of points as preset")
	if scaled_points.size() > 0:
		assert_eq(scaled_points[0], expected_points[0] * 2.0, "Polygon points should be scaled correctly")
	
	obs.free()
