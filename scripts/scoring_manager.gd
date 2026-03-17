extends RefCounted
class_name ScoringManager

var score_by_identity: Dictionary = {}
var peer_identity_by_id: Dictionary = {}
var peer_score_by_id: Dictionary = {}

func clear() -> void:
	score_by_identity.clear()
	peer_identity_by_id.clear()
	peer_score_by_id.clear()

func remove_peer(peer_id: int) -> void:
	peer_identity_by_id.erase(peer_id)
	peer_score_by_id.erase(peer_id)

func clear_peer_scores() -> void:
	peer_score_by_id.clear()

func bind_peer_score(peer_id: int, identity_key: String) -> void:
	if identity_key.is_empty():
		return
	peer_identity_by_id[peer_id] = identity_key
	if not score_by_identity.has(identity_key):
		score_by_identity[identity_key] = 0
	peer_score_by_id[peer_id] = int(score_by_identity[identity_key])

func award_point(peer_id: int, identity_key: String, points: int = 1) -> bool:
	if peer_id == -1:
		return false
	var key: String = str(peer_identity_by_id.get(peer_id, ""))
	if key.is_empty():
		bind_peer_score(peer_id, identity_key)
		key = str(peer_identity_by_id.get(peer_id, ""))
	if key.is_empty():
		return false
	var next_score: int = int(score_by_identity.get(key, 0)) + points
	score_by_identity[key] = next_score
	for p_id in peer_identity_by_id:
		if peer_identity_by_id[p_id] == key:
			peer_score_by_id[p_id] = next_score
	return true

func get_sync_scores(peer_ids: Array[int]) -> Array[int]:
	var scores: Array[int] = []
	for peer_id in peer_ids:
		scores.append(int(peer_score_by_id.get(peer_id, 0)))
	return scores

func get_peer_score(peer_id: int) -> int:
	return int(peer_score_by_id.get(peer_id, 0))

func set_peer_score(peer_id: int, score: int) -> void:
	peer_score_by_id[peer_id] = score
