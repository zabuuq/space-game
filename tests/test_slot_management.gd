extends GutTest

var Main = load("res://scripts/main.gd")
var main_node

func before_each():
	main_node = Main.new()
	main_node.world_node = ColorRect.new()
	
	main_node.ship_owner_by_slot.resize(main_node.MAX_SHIPS)
	main_node.ship_owner_by_slot.fill(-1)

func after_each():
	main_node.world_node.queue_free()
	main_node.queue_free()

func test_get_first_free_slot_empty():
	var slot = main_node._get_first_free_slot()
	assert_eq(slot, 0, "Should return 0 when empty")

func test_get_first_free_slot_partial():
	main_node.ship_owner_by_slot[0] = 100
	main_node.ship_owner_by_slot[1] = 200
	var slot = main_node._get_first_free_slot()
	assert_eq(slot, 2, "Should return first free index")

func test_get_first_free_slot_full():
	main_node.ship_owner_by_slot.fill(100)
	var slot = main_node._get_first_free_slot()
	assert_eq(slot, -1, "Should return -1 when full")

func test_get_slot_index_for_peer():
	main_node.ship_owner_by_slot[3] = 999
	var slot = main_node._get_slot_index_for_peer(999)
	assert_eq(slot, 3, "Should return the slot the peer is in")
	
	var missing = main_node._get_slot_index_for_peer(888)
	assert_eq(missing, -1, "Should return -1 if peer is not in any slot")
