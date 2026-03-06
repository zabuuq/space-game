extends GutTest

var Ship = load("res://entities/ship/ship.gd")
var ship

func before_each():
	ship = Ship.new()
	ship.world_bounds = Rect2(0, 0, 1000, 1000)
	add_child_autofree(ship)

func test_wrap_to_bounds_right():
	ship.position = Vector2(1050, 500)
	ship._wrap_to_bounds()
	assert_eq(ship.position.x, 0.0, "Should wrap to left edge")

func test_wrap_to_bounds_left():
	ship.position = Vector2(-50, 500)
	ship._wrap_to_bounds()
	assert_eq(ship.position.x, 1000.0, "Should wrap to right edge")

func test_wrap_to_bounds_bottom():
	ship.position = Vector2(500, 1050)
	ship._wrap_to_bounds()
	assert_eq(ship.position.y, 0.0, "Should wrap to top edge")

func test_wrap_to_bounds_top():
	ship.position = Vector2(500, -50)
	ship._wrap_to_bounds()
	assert_eq(ship.position.y, 1000.0, "Should wrap to bottom edge")

func test_update_movement_acceleration():
	ship.current_speed = 0.0
	ship.update_movement(1.0, false, false, true, false)
	assert_gt(ship.current_speed, 0.0, "Speed should increase when accelerating")

func test_update_movement_deceleration():
	ship.current_speed = 50.0
	ship.update_movement(1.0, false, false, false, true)
	assert_lt(ship.current_speed, 50.0, "Speed should decrease when decelerating")

func test_update_movement_max_speed():
	ship.current_speed = ship.MAX_SPEED
	ship.update_movement(1.0, false, false, true, false)
	assert_eq(ship.current_speed, ship.MAX_SPEED, "Speed should not exceed MAX_SPEED")

func test_update_movement_rotation():
	var initial_rotation = ship.rotation
	ship.update_movement(1.0, true, false, false, false) # turn left
	assert_lt(ship.rotation, initial_rotation, "Should rotate counter-clockwise")
	
	initial_rotation = ship.rotation
	ship.update_movement(1.0, false, true, false, false) # turn right
	assert_gt(ship.rotation, initial_rotation, "Should rotate clockwise")
