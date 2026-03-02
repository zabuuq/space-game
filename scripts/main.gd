extends Node2D

const DEFAULT_PORT := 56419
const FONT_SIZE_INCREASE := 3
const QUIT_BUTTON_SIZE := 32.0
const SHIP_OUTLINE_WIDTH := 3.0

const SHIP_NAVIGATION_SCRIPT := preload("res://scripts/ship_navigation.gd")
const MAIN_UI_SCRIPT := preload("res://scripts/main_ui.gd")
const CONNECTION_CONTROLLER_SCRIPT := preload("res://scripts/connection_controller.gd")
const IP_INFO_SERVICE_SCRIPT := preload("res://scripts/ip_info_service.gd")
const PEER_ROSTER_SERVICE_SCRIPT := preload("res://scripts/peer_roster_service.gd")

var ship_navigation: ShipNavigation = SHIP_NAVIGATION_SCRIPT.new()
var ui: MainUi = MAIN_UI_SCRIPT.new()
var connection_controller: ConnectionController = CONNECTION_CONTROLLER_SCRIPT.new()
var ip_info: IpInfoService = IP_INFO_SERVICE_SCRIPT.new()
var peer_roster: PeerRosterService = PEER_ROSTER_SERVICE_SCRIPT.new()

@rpc("authority", "call_local", "unreliable")
func sync_ship_state(new_position: Vector2, new_rotation: float, new_speed: float) -> void:
	ship_navigation.apply_network_state(new_position, new_rotation, new_speed)
	queue_redraw()

@rpc("any_peer", "reliable")
func submit_peer_info(internal_ip: String, external_ip: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	peer_roster.upsert_peer(sender_id, internal_ip, external_ip)
	_broadcast_peer_roster()

@rpc("authority", "call_local", "reliable")
func sync_peer_roster(peer_ids: Array[int], internal_ips: Array[String], external_ips: Array[String]) -> void:
	peer_roster.apply_synced_roster(peer_ids, internal_ips, external_ips)
	_refresh_peer_list()

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	ui.build(
		self,
		DEFAULT_PORT,
		FONT_SIZE_INCREASE,
		QUIT_BUTTON_SIZE,
		Callable(self, "_on_quit_pressed"),
		Callable(self, "_on_host_pressed"),
		Callable(self, "_on_join_pressed"),
		Callable(self, "_on_disconnect_pressed"),
		Callable(self, "_on_connect_pressed"),
		Callable(self, "queue_redraw")
	)

	connection_controller.configure(
		multiplayer,
		ui.host_button,
		ui.join_button,
		ui.disconnect_button,
		Callable(self, "_set_status")
	)

	ip_info.configure(self, Callable(self, "_on_ip_info_updated"))
	ip_info.detect_local_ip()

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	get_viewport().size_changed.connect(queue_redraw)

	set_process_unhandled_input(true)
	set_process(true)
	_set_status("Not connected")
	_update_local_ip_labels()
	ip_info.request_external_ip()
	_refresh_peer_list()
	queue_redraw()

func _on_host_pressed() -> void:
	if not connection_controller.host(DEFAULT_PORT):
		return

	_initialize_host_roster()
	_reset_ship()
	_sync_ship_state_to_clients()

func _on_join_pressed() -> void:
	ui.join_popup.popup_centered()

func _on_connect_pressed() -> void:
	ui.join_popup.hide()
	var ip := ui.join_ip_input.text.strip_edges()
	if ip.is_empty():
		_set_status("Invalid IP")
		return

	connection_controller.join(ip, DEFAULT_PORT)

func _on_connected_to_server() -> void:
	_set_status("Connected as client")
	_submit_local_identity()

func _on_connection_failed() -> void:
	_set_status("Connection failed")
	_disconnect_local_peer(false)

func _on_server_disconnected() -> void:
	_set_status("Server disconnected")
	_disconnect_local_peer(false)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	peer_roster.ensure_peer_in_order(peer_id)
	_broadcast_peer_roster()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	peer_roster.remove_peer(peer_id)
	_broadcast_peer_roster()

func _on_disconnect_pressed() -> void:
	_disconnect_local_peer(true)

func _disconnect_local_peer(update_status: bool) -> void:
	connection_controller.disconnect(update_status)
	peer_roster.clear()
	_refresh_peer_list()
	_reset_ship()

func _set_status(value: String) -> void:
	ui.status_label.text = "Connection Status: %s" % value

func _initialize_host_roster() -> void:
	var host_id := multiplayer.get_unique_id()
	peer_roster.register_host(host_id, ip_info.local_internal_ip, ip_info.local_external_ip)
	_broadcast_peer_roster()

func _broadcast_peer_roster() -> void:
	if not multiplayer.is_server():
		return

	sync_peer_roster.rpc(
		peer_roster.get_sync_peer_ids(),
		peer_roster.get_sync_internal_ips(),
		peer_roster.get_sync_external_ips()
	)

func _refresh_peer_list() -> void:
	ui.peer_list_label.text = peer_roster.format_bbcode()

func _submit_local_identity() -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		var host_id := multiplayer.get_unique_id()
		peer_roster.upsert_peer(host_id, ip_info.local_internal_ip, ip_info.local_external_ip)
		peer_roster.ensure_peer_in_order(host_id)
		_broadcast_peer_roster()
	else:
		submit_peer_info.rpc_id(1, ip_info.local_internal_ip, ip_info.local_external_ip)

func _update_local_ip_labels() -> void:
	ui.local_ip_label.text = "Local IP: %s" % ip_info.local_internal_ip
	ui.external_ip_label.text = "External IP: %s" % ip_info.local_external_ip

func _on_ip_info_updated() -> void:
	_update_local_ip_labels()
	_submit_local_identity()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _reset_ship() -> void:
	ship_navigation.reset(_get_right_section_center())
	queue_redraw()

func _sync_ship_state_to_clients() -> void:
	sync_ship_state.rpc(
		ship_navigation.position,
		ship_navigation.rotation_radians,
		ship_navigation.speed
	)

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return

	if not ship_navigation.initialized:
		_reset_ship()

	ship_navigation.update_host(
		delta,
		Input.is_physical_key_pressed(KEY_A),
		Input.is_physical_key_pressed(KEY_D),
		Input.is_physical_key_pressed(KEY_W),
		_get_right_section_rect()
	)

	_sync_ship_state_to_clients()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return
	if event is InputEventKey and not event.echo:
		match event.physical_keycode:
			KEY_S:
				ship_navigation.decrease_speed_once()
			_:
				return
		_sync_ship_state_to_clients()
		queue_redraw()

func _get_right_section_center() -> Vector2:
	if ui.right_section == null:
		return get_viewport_rect().size * 0.5
	var right_rect := ui.right_section.get_global_rect()
	return right_rect.position + (right_rect.size * 0.5)

func _get_right_section_rect() -> Rect2:
	if ui.right_section == null:
		return get_viewport_rect()
	return ui.right_section.get_global_rect()

func _draw() -> void:
	if not ship_navigation.initialized:
		return

	draw_polyline(ship_navigation.get_transformed_points(), Color.ORANGE, SHIP_OUTLINE_WIDTH, true)
