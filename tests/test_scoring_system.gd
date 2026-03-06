extends GutTest

var Main = load("res://scripts/main.gd")
var PeerRosterService = load("res://scripts/peer_roster_service.gd")
var main_node

func before_each():
	main_node = Main.new()
	main_node.peer_roster = PeerRosterService.new()
	main_node._reset_session_scores()

func after_each():
	main_node.queue_free()

func test_award_point_unregistered_peer():
	var result = main_node._award_point(999)
	assert_false(result, "Should fail to award point if peer is unregistered and has no identity")

func test_award_point_registered_peer():
	main_node.peer_roster.upsert_peer(100, "192.168.1.1", "10.0.0.1", "Player", 0)
	main_node.peer_roster.ensure_peer_in_order(100)
	
	# Manually bind because we aren't running the full _submit_local_identity loop
	main_node._bind_peer_score(100)
	
	var result = main_node._award_point(100)
	assert_true(result, "Should successfully award point")
	assert_eq(main_node.peer_score_by_id[100], 1, "Peer score should be 1")
	
	main_node._award_point(100)
	assert_eq(main_node.peer_score_by_id[100], 2, "Peer score should be 2")

func test_score_persistence_across_reconnect():
	# Player connects as peer 100
	main_node.peer_roster.upsert_peer(100, "192.168.1.1", "10.0.0.1", "Player", 0)
	main_node.peer_roster.ensure_peer_in_order(100)
	main_node._bind_peer_score(100)
	
	main_node._award_point(100)
	main_node._award_point(100)
	assert_eq(main_node.peer_score_by_id[100], 2, "Score should be 2")
	
	# Player disconnects (simulated by clearing peer ID from roster but NOT clearing scores)
	main_node.peer_roster.remove_peer(100)
	main_node.peer_identity_by_id.erase(100)
	main_node.peer_score_by_id.erase(100)
	
	# Player reconnects as peer 200 with the SAME IP
	main_node.peer_roster.upsert_peer(200, "192.168.1.1", "10.0.0.1", "Player", 0)
	main_node.peer_roster.ensure_peer_in_order(200)
	main_node._bind_peer_score(200)
	
	assert_eq(main_node.peer_score_by_id[200], 2, "Score should persist across reconnect")
