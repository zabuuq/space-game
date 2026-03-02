extends RefCounted
class_name IpInfoService

var owner: Node
var external_ip_request: HTTPRequest
var on_updated: Callable

var local_internal_ip := "127.0.0.1"
var local_external_ip := "Loading..."

func configure(owner_node: Node, updated_callback: Callable) -> void:
	owner = owner_node
	on_updated = updated_callback

func detect_local_ip() -> void:
	for address in IP.get_local_addresses():
		if address.contains(":"):
			continue
		if address.begins_with("127."):
			continue
		local_internal_ip = address
		return

	local_internal_ip = "127.0.0.1"

func request_external_ip() -> void:
	external_ip_request = HTTPRequest.new()
	owner.add_child(external_ip_request)
	external_ip_request.request_completed.connect(_on_external_ip_request_completed)
	var request_error := external_ip_request.request("https://api.ipify.org")
	if request_error != OK:
		local_external_ip = "Unavailable"
		on_updated.call()

func _on_external_ip_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		local_external_ip = body.get_string_from_utf8().strip_edges()
		if local_external_ip.is_empty():
			local_external_ip = "Unavailable"
	else:
		local_external_ip = "Unavailable"

	on_updated.call()
