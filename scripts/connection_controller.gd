extends RefCounted
class_name ConnectionController

var multiplayer: MultiplayerAPI
var host_button: Button
var join_button: Button
var disconnect_button: Button
var host_join_row: HBoxContainer
var set_status: Callable

func configure(
	multiplayer_api: MultiplayerAPI,
	host: Button,
	join: Button,
	disconnect: Button,
	host_join: HBoxContainer,
	set_status_callback: Callable
) -> void:
	multiplayer = multiplayer_api
	host_button = host
	join_button = join
	disconnect_button = disconnect
	host_join_row = host_join
	set_status = set_status_callback

func host(port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port)
	if result != OK:
		set_status.call("Not connected")
		return false

	multiplayer.multiplayer_peer = peer
	set_status.call("Hosting")
	set_connected_controls(true)
	return true

func join(ip: String, port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(ip, port)
	if result != OK:
		return false

	multiplayer.multiplayer_peer = peer
	return true

func disconnect_session(update_status: bool) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	if update_status:
		set_status.call("Not connected")

	set_connected_controls(false)

func set_connected_controls(is_connected: bool) -> void:
	host_join_row.visible = not is_connected
	disconnect_button.visible = is_connected
