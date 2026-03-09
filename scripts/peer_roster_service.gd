extends RefCounted
class_name PeerRosterService

var peer_order: Array[int] = []
var peer_info_by_id: Dictionary = {}

func clear() -> void:
	peer_order.clear()
	peer_info_by_id.clear()

func apply_synced_roster(
	peer_ids: Array[int],
	internal_ips: Array[String],
	external_ips: Array[String],
	names: Array[String],
	color_indices: Array[int]
) -> void:
	clear()
	var total: int = mini(
		peer_ids.size(),
		mini(internal_ips.size(), mini(external_ips.size(), mini(names.size(), color_indices.size())))
	)
	for index in range(total):
		var peer_id := peer_ids[index]
		peer_order.append(peer_id)
		peer_info_by_id[peer_id] = {
			"internal": internal_ips[index],
			"external": external_ips[index],
			"name": names[index],
			"color_index": color_indices[index]
		}

func register_host(
	host_id: int,
	internal_ip: String,
	external_ip: String,
	name: String,
	color_index: int
) -> void:
	clear()
	peer_order.append(host_id)
	upsert_peer(host_id, internal_ip, external_ip, name, color_index)

func ensure_peer_in_order(peer_id: int) -> void:
	if not peer_order.has(peer_id):
		peer_order.append(peer_id)

func upsert_peer(
	peer_id: int,
	internal_ip: String,
	external_ip: String,
	name: String,
	color_index: int = -1
) -> void:
	peer_info_by_id[peer_id] = {
		"internal": internal_ip,
		"external": external_ip,
		"name": name,
		"color_index": color_index
	}

func remove_peer(peer_id: int) -> void:
	peer_order.erase(peer_id)
	peer_info_by_id.erase(peer_id)

func get_sync_peer_ids() -> Array[int]:
	return peer_order.duplicate()

func get_sync_internal_ips() -> Array[String]:
	var internal_ips: Array[String] = []
	for peer_id in peer_order:
		var info: Dictionary = _get_peer_info(peer_id)
		internal_ips.append(str(info["internal"]))
	return internal_ips

func get_sync_external_ips() -> Array[String]:
	var external_ips: Array[String] = []
	for peer_id in peer_order:
		var info: Dictionary = _get_peer_info(peer_id)
		external_ips.append(str(info["external"]))
	return external_ips

func get_sync_names() -> Array[String]:
	var names: Array[String] = []
	for peer_id in peer_order:
		var info: Dictionary = _get_peer_info(peer_id)
		names.append(str(info["name"]))
	return names

func get_sync_color_indices() -> Array[int]:
	var color_indices: Array[int] = []
	for peer_id in peer_order:
		var info: Dictionary = _get_peer_info(peer_id)
		color_indices.append(int(info["color_index"]))
	return color_indices

func get_peer_color_index(peer_id: int) -> int:
	var info: Dictionary = _get_peer_info(peer_id)
	return int(info["color_index"])

func get_peer_identity_key(peer_id: int) -> String:
	var info: Dictionary = _get_peer_info(peer_id)
	var internal_ip: String = str(info["internal"])
	var external_ip: String = str(info["external"])
	if internal_ip == "Unknown" or external_ip == "Unknown":
		return ""
	return "%s|%s" % [internal_ip, external_ip]

func is_color_taken(color_index: int, ignore_peer_id: int = -1) -> bool:
	if color_index < 0:
		return false
	for peer_id in peer_order:
		if peer_id == ignore_peer_id:
			continue
		if get_peer_color_index(peer_id) == color_index:
			return true
	return false

func find_first_available_color(max_colors: int, ignore_peer_id: int = -1) -> int:
	var index: int = 0
	while index < max_colors:
		if not is_color_taken(index, ignore_peer_id):
			return index
		index += 1
	return -1

func resolve_color_index(preferred_color_index: int, max_colors: int, ignore_peer_id: int = -1) -> int:
	if preferred_color_index >= 0 and preferred_color_index < max_colors:
		if not is_color_taken(preferred_color_index, ignore_peer_id):
			return preferred_color_index
	return find_first_available_color(max_colors, ignore_peer_id)

func _get_peer_info(peer_id: int) -> Dictionary:
	if peer_info_by_id.has(peer_id):
		return peer_info_by_id[peer_id]
	return {
		"internal": "Unknown",
		"external": "Unknown",
		"name": "",
		"color_index": -1
	}
