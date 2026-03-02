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
	names: Array[String]
) -> void:
	clear()
	var total: int = mini(
		peer_ids.size(),
		mini(internal_ips.size(), mini(external_ips.size(), names.size()))
	)
	for index in range(total):
		var peer_id := peer_ids[index]
		peer_order.append(peer_id)
		peer_info_by_id[peer_id] = {
			"internal": internal_ips[index],
			"external": external_ips[index],
			"name": names[index]
		}

func register_host(host_id: int, internal_ip: String, external_ip: String, name: String) -> void:
	clear()
	peer_order.append(host_id)
	upsert_peer(host_id, internal_ip, external_ip, name)

func ensure_peer_in_order(peer_id: int) -> void:
	if not peer_order.has(peer_id):
		peer_order.append(peer_id)

func upsert_peer(peer_id: int, internal_ip: String, external_ip: String, name: String) -> void:
	peer_info_by_id[peer_id] = {
		"internal": internal_ip,
		"external": external_ip,
		"name": name
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

func format_bbcode() -> String:
	if peer_order.is_empty():
		return ""

	var lines: PackedStringArray = []
	for index in range(peer_order.size()):
		var peer_id := peer_order[index]
		var info: Dictionary = _get_peer_info(peer_id)
		var line := "%s/%s" % [str(info["internal"]), str(info["external"])]
		if index == 0:
			lines.append("[b]%s[/b]" % line)
		else:
			lines.append(line)

	return "\n".join(lines)

func _get_peer_info(peer_id: int) -> Dictionary:
	if peer_info_by_id.has(peer_id):
		return peer_info_by_id[peer_id]
	return {
		"internal": "Unknown",
		"external": "Unknown",
		"name": ""
	}
