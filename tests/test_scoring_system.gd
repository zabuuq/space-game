extends GutTest

var ScoringManager = load("res://scripts/scoring_manager.gd")
var PeerRosterService = load("res://scripts/peer_roster_service.gd")
var scoring_manager
var peer_roster

func before_each():
	scoring_manager = ScoringManager.new()
	peer_roster = PeerRosterService.new()

func after_each():
	pass

func test_award_point_unregistered_peer():
	var result = scoring_manager.award_point(999, peer_roster.get_peer_identity_key(999))
	assert_false(result, "Should fail to award point if peer is unregistered and has no identity")

func test_award_point_registered_peer():
	peer_roster.upsert_peer(100, "192.168.1.1", "10.0.0.1", "Player", 0)
	peer_roster.ensure_peer_in_order(100)
	
	# Manually bind because we aren't running the full _submit_local_identity loop
	scoring_manager.bind_peer_score(100, peer_roster.get_peer_identity_key(100))
	
	var result = scoring_manager.award_point(100, peer_roster.get_peer_identity_key(100))
	assert_true(result, "Should successfully award point")
	assert_eq(scoring_manager.get_peer_score(100), 1, "Peer score should be 1")
	
	scoring_manager.award_point(100, peer_roster.get_peer_identity_key(100))
	assert_eq(scoring_manager.get_peer_score(100), 2, "Peer score should be 2")

func test_score_persistence_across_reconnect():
	# Player connects as peer 100
	peer_roster.upsert_peer(100, "192.168.1.1", "10.0.0.1", "Player", 0)
	peer_roster.ensure_peer_in_order(100)
	scoring_manager.bind_peer_score(100, peer_roster.get_peer_identity_key(100))
	
	scoring_manager.award_point(100, peer_roster.get_peer_identity_key(100))
	scoring_manager.award_point(100, peer_roster.get_peer_identity_key(100))
	assert_eq(scoring_manager.get_peer_score(100), 2, "Score should be 2")
	
	# Player disconnects (simulated by clearing peer ID from roster but NOT clearing scores)
	peer_roster.remove_peer(100)
	scoring_manager.remove_peer(100)
	
	# Player reconnects as peer 200 with the SAME IP
	peer_roster.upsert_peer(200, "192.168.1.1", "10.0.0.1", "Player", 0)
	peer_roster.ensure_peer_in_order(200)
	scoring_manager.bind_peer_score(200, peer_roster.get_peer_identity_key(200))
	
	assert_eq(scoring_manager.get_peer_score(200), 2, "Score should persist across reconnect")
