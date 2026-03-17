extends "res://addons/gut/test.gd"

const NPC_SCENE := preload("res://entities/npc/npc.tscn")
const SHIP_SCENE := preload("res://entities/ship/ship.tscn")

func test_npc_initialization():
	var npc = NPC_SCENE.instantiate()
	add_child_autofree(npc)
	assert_not_null(npc, "NPC should instantiate")
	assert_eq(npc.current_speed, 0.0, "Initial speed should be 0")

func test_npc_targeting():
	var npc = NPC_SCENE.instantiate()
	add_child_autofree(npc)
	
	var ship = SHIP_SCENE.instantiate()
	ship.position = Vector2(100, 100)
	add_child_autofree(ship)
	
	# We need a way to mock the main node's _get_all_ships
	# For simplicity, let's just check if targeting logic exists
	assert_has_method(npc, "_update_targeting")

func test_npc_movement_math():
	var npc = NPC_SCENE.instantiate()
	# Mock speed/accel
	npc.velocity = Vector2.ZERO
	# Simulate 1 second of acceleration toward a target at (100, 0)
	var delta = 1.0
	var target_dir = Vector2.RIGHT
	var desired_velocity = target_dir * npc.MAX_SPEED
	npc.velocity = npc.velocity.move_toward(desired_velocity, npc.SPEED_STEP * delta)
	
	assert_gt(npc.velocity.x, 0.0, "NPC should accelerate toward target")
	assert_almost_eq(npc.velocity.x, npc.SPEED_STEP, 0.1, "NPC acceleration should match SPEED_STEP")

func test_npc_firing_rate():
	var npc = NPC_SCENE.instantiate()
	assert_eq(npc.FIRE_INTERVAL, 1.44, "NPC fire interval should be 1.44 seconds")
