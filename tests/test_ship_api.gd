extends GutTest

var Ship = load("res://entities/ship/ship.gd")

func test_ship_has_required_rpc_methods():
	var ship = Ship.new()
	assert_true(ship.has_method("submit_input"), "Ship must have submit_input to receive player controls.")
	assert_true(ship.has_method("request_fire"), "Ship must have request_fire to shoot.")
	assert_true(ship.has_method("request_full_stop"), "Ship must have request_full_stop.")
	ship.free()

func test_ship_initial_input_state():
	var ship = Ship.new()
	# These are the variables that the server uses for movement logic
	assert_false(ship.get("_input_left") == null, "Ship must have _input_left variable.")
	assert_false(ship.get("_input_right") == null, "Ship must have _input_right variable.")
	assert_false(ship.get("_input_accelerate") == null, "Ship must have _input_accelerate variable.")
	assert_false(ship.get("_input_decelerate") == null, "Ship must have _input_decelerate variable.")
	ship.free()

func test_ship_has_required_properties():
	var ship = Ship.new()
	assert_false(ship.get("current_speed") == null, "Ship must have current_speed property.")
	assert_false(ship.get("world_bounds") == null, "Ship must have world_bounds property.")
	assert_false(ship.get("is_immune") == null, "Ship must have is_immune property.")
	ship.free()
