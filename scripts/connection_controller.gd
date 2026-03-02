extends RefCounted
class_name ConnectionController

var multiplayer: MultiplayerAPI
var host_button: Button
var join_button: Button
var disconnect_button: Button
var set_status: Callable

func configure(
	multiplayer_api: MultiplayerAPI,
	host: Button,
	join: Button,
	disconnect: Button,
	set_status_callback: Callable
) -> void:
	multiplayer = multiplayer_api
	host_button = host
	join_button = join
	disconnect_button = disconnect
	set_status = set_status_callback

func host(port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port)
	if result != OK:
		set_status.call("Failed to host (error %d)" % result)
		return false

	multiplayer.multiplayer_peer = peer
	set_status.call("Hosting on port %d" % port)
	set_connected_controls(true)
	return true

func join(ip: String, port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(ip, port)
	if result != OK:
		set_status.call("Failed to connect (error %d)" % result)
		return false

	multiplayer.multiplayer_peer = peer
	set_status.call("Connecting to %s:%d" % [ip, port])
	set_connected_controls(true)
	return true

func disconnect(update_status: bool) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	if update_status:
		set_status.call("Not connected")

	set_connected_controls(false)

func set_connected_controls(is_connected: bool) -> void:
	host_button.visible = not is_connected
	join_button.visible = not is_connected
	disconnect_button.visible = is_connected
