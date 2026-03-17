extends GutTest

var PeerRosterService = load("res://scripts/peer_roster_service.gd")
var roster: PeerRosterService

func before_each():
	roster = PeerRosterService.new()

func test_register_host_adds_first_peer():
	roster.register_host(1, "192.168.1.5", "10.0.0.1", "HostName", 0)
	
	assert_eq(roster.peer_order.size(), 1, "Should have one peer registered")
	assert_eq(roster.peer_order[0], 1, "The host should be the first peer")
	
	var sync_names = roster.get_sync_names()
	assert_eq(sync_names[0], "HostName", "Name should be recorded correctly")

func test_upsert_peer_adds_new_peer():
	roster.upsert_peer(2, "192.168.1.6", "10.0.0.2", "ClientName", 1)
	roster.ensure_peer_in_order(2)
	
	assert_eq(roster.peer_order.size(), 1, "Should have one peer in order list")
	assert_eq(roster.get_sync_names()[0], "ClientName")

func test_remove_peer():
	roster.register_host(1, "192.168.1.5", "10.0.0.1", "HostName", 0)
	roster.upsert_peer(2, "192.168.1.6", "10.0.0.2", "ClientName", 1)
	roster.ensure_peer_in_order(2)
	
	assert_eq(roster.peer_order.size(), 2)
	
	roster.remove_peer(1)
	
	assert_eq(roster.peer_order.size(), 1, "Host should be removed")
	assert_eq(roster.peer_order[0], 2, "Client should be the only remaining peer")

func test_is_color_taken():
	roster.upsert_peer(1, "192.168.1.5", "10.0.0.1", "Host", 0)
	roster.ensure_peer_in_order(1)
	
	roster.upsert_peer(2, "192.168.1.6", "10.0.0.2", "Client", 2)
	roster.ensure_peer_in_order(2)
	
	assert_true(roster.is_color_taken(0), "Color index 0 should be taken by peer 1")
	assert_false(roster.is_color_taken(1), "Color index 1 should be free")
	assert_true(roster.is_color_taken(2), "Color index 2 should be taken by peer 2")
	
	# Ignoring a peer should make their color appear available
	assert_false(roster.is_color_taken(0, 1), "Color index 0 should not be taken if we ignore peer 1")

func test_resolve_color_index():
	# Assume max colors is 5 for this test
	roster.upsert_peer(1, "IP", "IP", "Host", 0)
	roster.ensure_peer_in_order(1)
	
	# Asking for a preferred color that is free
	var resolved = roster.resolve_color_index(2, 5)
	assert_eq(resolved, 2, "Should get preferred color if free")
	
	# Asking for a preferred color that is taken
	resolved = roster.resolve_color_index(0, 5)
	assert_eq(resolved, 1, "Should fall back to first available color (1) since 0 is taken")
	
	# Asking for a preferred color while updating self
	resolved = roster.resolve_color_index(0, 5, 1)
	assert_eq(resolved, 0, "Should be allowed to keep own color if ignoring self")

func test_get_peer_identity_key():
	roster.upsert_peer(1, "192.168.1.5", "8.8.8.8", "Player", 0)
	roster.ensure_peer_in_order(1)

	var key = roster.get_peer_identity_key(1)
	assert_eq(key, "192.168.1.5|8.8.8.8|Player", "Key should include name when present")

	roster.upsert_peer(2, "192.168.1.5", "8.8.8.8", "", 1)
	roster.ensure_peer_in_order(2)

	var key2 = roster.get_peer_identity_key(2)
	assert_eq(key2, "192.168.1.5|8.8.8.8|peer_2", "Key should fallback to peer_id if name is empty")
