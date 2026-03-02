extends Node2D

const DEFAULT_PORT := 56419
const FONT_SIZE_INCREASE := 3
const QUIT_BUTTON_SIZE := 32.0
const SHIP_OUTLINE_WIDTH := 3.0
const WORLD_BOUNDS := Rect2(Vector2.ZERO, Vector2.ONE)
const MAX_SHIPS := 6

const STATUS_NOT_CONNECTED := "Not connected"
const STATUS_HOSTING := "Hosting"
const STATUS_CONNECTED_TO_HOST := "Connected to host"
const STATUS_OBSERVER := "Observer"
const DEFAULT_PEER_TEXT_COLOR := "ffffff"
const SHIP_COLORS: Array[Color] = [
	Color(0.97, 0.33, 0.33), # red
	Color(0.20, 0.63, 0.98), # blue
	Color(0.30, 0.84, 0.39), # green
	Color(1.00, 0.79, 0.27), # amber
	Color(0.84, 0.44, 0.96), # violet
	Color(0.29, 0.90, 0.88)  # cyan
]

const SHIP_START_POSITIONS: Array[Vector2] = [
	Vector2(1.0 / 6.0, 1.0 / 4.0),
	Vector2(5.0 / 6.0, 1.0 / 4.0),
	Vector2(5.0 / 6.0, 3.0 / 4.0),
	Vector2(1.0 / 6.0, 3.0 / 4.0),
	Vector2(3.0 / 6.0, 1.0 / 4.0),
	Vector2(3.0 / 6.0, 3.0 / 4.0)
]

const SHIP_NAVIGATION_SCRIPT := preload("res://scripts/ship_navigation.gd")
const MAIN_UI_SCRIPT := preload("res://scripts/main_ui.gd")
const CONNECTION_CONTROLLER_SCRIPT := preload("res://scripts/connection_controller.gd")
const IP_INFO_SERVICE_SCRIPT := preload("res://scripts/ip_info_service.gd")
const PEER_ROSTER_SERVICE_SCRIPT := preload("res://scripts/peer_roster_service.gd")

var ui: MainUi = MAIN_UI_SCRIPT.new()
var connection_controller: ConnectionController = CONNECTION_CONTROLLER_SCRIPT.new()
var ip_info: IpInfoService = IP_INFO_SERVICE_SCRIPT.new()
var peer_roster: PeerRosterService = PEER_ROSTER_SERVICE_SCRIPT.new()

var ship_slots: Array[ShipNavigation] = []
var ship_owner_by_slot: Array[int] = []
var observer_queue: Array[int] = []
var input_by_peer: Dictionary = {}

@rpc("authority", "call_remote", "unreliable")
func sync_ship_roster(
	owner_ids: Array[int],
	positions: Array[Vector2],
	rotations: Array[float],
	speeds: Array[float],
	actives: Array[bool],
	observer_ids: Array[int]
) -> void:
	if multiplayer.is_server():
		return

	var total: int = mini(
		owner_ids.size(),
		mini(positions.size(), mini(rotations.size(), mini(speeds.size(), actives.size())))
	)
	var index: int = 0
	while index < MAX_SHIPS:
		var owner_id: int = -1
		var position: Vector2 = Vector2.ZERO
		var rotation_value := 0.0
		var speed_value := 0.0
		var is_active := false

		if index < total:
			owner_id = owner_ids[index]
			position = positions[index]
			rotation_value = rotations[index]
			speed_value = speeds[index]
			is_active = actives[index]

		ship_owner_by_slot[index] = owner_id

		var ship: ShipNavigation = ship_slots[index]
		if is_active and owner_id != -1:
			ship.apply_network_state(position, rotation_value, speed_value)
		else:
			ship.hide()

		index += 1

	observer_queue = observer_ids.duplicate()
	_update_local_connection_status_from_roles()
	_refresh_peer_list()
	queue_redraw()

@rpc("any_peer", "unreliable")
func submit_ship_input(
	turn_left: bool,
	turn_right: bool,
	accelerate: bool,
	decelerate: bool
) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if _get_slot_index_for_peer(sender_id) == -1:
		return

	input_by_peer[sender_id] = {
		"left": turn_left,
		"right": turn_right,
		"accelerate": accelerate,
		"decelerate": decelerate
	}

@rpc("any_peer", "reliable")
func request_full_stop() -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	var slot_index: int = _get_slot_index_for_peer(sender_id)
	if slot_index == -1:
		return

	var ship: ShipNavigation = ship_slots[slot_index]
	ship.full_stop()
	_sync_ships_to_clients()
	queue_redraw()

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_initialize_ship_slots()
	_hide_all_ships()

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
		ui.host_join_row,
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
	_set_status(STATUS_NOT_CONNECTED)
	_update_local_ip_labels()
	ip_info.request_external_ip()
	_refresh_peer_list()
	queue_redraw()

func _on_host_pressed() -> void:
	if not connection_controller.host(DEFAULT_PORT):
		return

	_initialize_host_roster()
	_start_host_ship_session()
	_refresh_peer_list()
	_sync_ships_to_clients()
	queue_redraw()

func _on_join_pressed() -> void:
	ui.join_popup.popup_centered()

func _on_connect_pressed() -> void:
	ui.join_popup.hide()
	var ip := ui.join_ip_input.text.strip_edges()
	if ip.is_empty():
		_set_status(STATUS_NOT_CONNECTED)
		return

	connection_controller.join(ip, DEFAULT_PORT)

func _on_connected_to_server() -> void:
	_set_status(STATUS_CONNECTED_TO_HOST)
	_submit_local_identity()

func _on_connection_failed() -> void:
	_set_status(STATUS_NOT_CONNECTED)
	_disconnect_local_peer(false)

func _on_server_disconnected() -> void:
	_set_status(STATUS_NOT_CONNECTED)
	_disconnect_local_peer(false)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	peer_roster.ensure_peer_in_order(peer_id)
	_assign_peer_role(peer_id)
	_broadcast_peer_roster()
	_sync_ships_to_clients()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	peer_roster.remove_peer(peer_id)
	observer_queue.erase(peer_id)
	input_by_peer.erase(peer_id)

	var slot_index: int = _get_slot_index_for_peer(peer_id)
	if slot_index != -1:
		_release_slot(slot_index)
		_promote_observer_to_slot(slot_index)

	_broadcast_peer_roster()
	_sync_ships_to_clients()

func _on_disconnect_pressed() -> void:
	_disconnect_local_peer(true)

func _disconnect_local_peer(update_status: bool) -> void:
	connection_controller.disconnect_session(update_status)
	peer_roster.clear()
	_refresh_peer_list()
	_clear_ship_roles()
	_hide_all_ships()

func _set_status(value: String) -> void:
	ui.status_label.text = "Connection Status: %s" % value

func _initialize_host_roster() -> void:
	var host_id: int = multiplayer.get_unique_id()
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

@rpc("authority", "call_local", "reliable")
func sync_peer_roster(peer_ids: Array[int], internal_ips: Array[String], external_ips: Array[String]) -> void:
	peer_roster.apply_synced_roster(peer_ids, internal_ips, external_ips)
	_refresh_peer_list()

func _refresh_peer_list() -> void:
	var peer_ids: Array[int] = peer_roster.get_sync_peer_ids()
	var internal_ips: Array[String] = peer_roster.get_sync_internal_ips()
	var external_ips: Array[String] = peer_roster.get_sync_external_ips()
	var total: int = mini(peer_ids.size(), mini(internal_ips.size(), external_ips.size()))
	if total <= 0:
		ui.peer_list_label.text = ""
		return

	var local_id: int = multiplayer.get_unique_id()
	var lines: PackedStringArray = []
	var index: int = 0
	while index < total:
		var peer_id: int = peer_ids[index]
		var line := "%s/%s" % [internal_ips[index], external_ips[index]]
		var slot_index: int = _get_slot_index_for_peer(peer_id)
		var color_code: String = DEFAULT_PEER_TEXT_COLOR
		if slot_index >= 0 and slot_index < SHIP_COLORS.size():
			color_code = SHIP_COLORS[slot_index].to_html(false)

		line = "[color=#%s]%s[/color]" % [color_code, line]
		if peer_id == local_id:
			line = "[b]%s[/b]" % line

		lines.append(line)
		index += 1

	ui.peer_list_label.text = "\n".join(lines)

func _submit_local_identity() -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		var host_id: int = multiplayer.get_unique_id()
		peer_roster.upsert_peer(host_id, ip_info.local_internal_ip, ip_info.local_external_ip)
		peer_roster.ensure_peer_in_order(host_id)
		_broadcast_peer_roster()
	else:
		submit_peer_info.rpc_id(1, ip_info.local_internal_ip, ip_info.local_external_ip)

@rpc("any_peer", "reliable")
func submit_peer_info(internal_ip: String, external_ip: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	peer_roster.upsert_peer(sender_id, internal_ip, external_ip)
	_broadcast_peer_roster()

func _update_local_ip_labels() -> void:
	ui.local_ip_label.text = ip_info.local_internal_ip
	ui.external_ip_label.text = ip_info.local_external_ip

func _on_ip_info_updated() -> void:
	_update_local_ip_labels()
	_submit_local_identity()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		_update_server_ships(delta)
		_sync_ships_to_clients()
		queue_redraw()
		return

	_send_client_input_to_server()

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if key_event == null:
		return
	if key_event.physical_keycode != KEY_X or not key_event.pressed or key_event.echo:
		return

	if multiplayer.is_server():
		var host_id: int = multiplayer.get_unique_id()
		var host_slot: int = _get_slot_index_for_peer(host_id)
		if host_slot == -1:
			return
		ship_slots[host_slot].full_stop()
		_sync_ships_to_clients()
		queue_redraw()
		return

	var local_id: int = multiplayer.get_unique_id()
	if _get_slot_index_for_peer(local_id) == -1:
		return
	request_full_stop.rpc_id(1)

func _draw() -> void:
	if multiplayer.multiplayer_peer == null:
		return

	var play_rect: Rect2 = _get_right_section_rect()
	var index: int = 0
	for ship in ship_slots:
		if not ship.initialized:
			index += 1
			continue

		var ship_points := ship.get_screen_points(play_rect)
		if ship_points.size() < 2:
			index += 1
			continue

		draw_polyline(ship_points, SHIP_COLORS[index], SHIP_OUTLINE_WIDTH, true)
		index += 1

func _get_right_section_rect() -> Rect2:
	if ui.right_section == null:
		return get_viewport_rect()
	return ui.right_section.get_global_rect()

func _initialize_ship_slots() -> void:
	ship_slots.clear()
	ship_owner_by_slot.clear()
	var index: int = 0
	while index < MAX_SHIPS:
		var ship: ShipNavigation = SHIP_NAVIGATION_SCRIPT.new()
		ship.hide()
		ship_slots.append(ship)
		ship_owner_by_slot.append(-1)
		index += 1

func _hide_all_ships() -> void:
	for ship in ship_slots:
		ship.hide()
	queue_redraw()

func _clear_ship_roles() -> void:
	observer_queue.clear()
	input_by_peer.clear()

	var index: int = 0
	while index < MAX_SHIPS:
		ship_owner_by_slot[index] = -1
		ship_slots[index].hide()
		index += 1

func _start_host_ship_session() -> void:
	_clear_ship_roles()
	var host_id: int = multiplayer.get_unique_id()
	_assign_peer_to_slot(host_id, 0)
	_set_status(STATUS_HOSTING)

func _assign_peer_role(peer_id: int) -> void:
	var slot_index: int = _get_first_free_slot()
	if slot_index == -1:
		observer_queue.append(peer_id)
		return

	_assign_peer_to_slot(peer_id, slot_index)

func _assign_peer_to_slot(peer_id: int, slot_index: int) -> void:
	ship_owner_by_slot[slot_index] = peer_id
	input_by_peer.erase(peer_id)
	ship_slots[slot_index].reset(SHIP_START_POSITIONS[slot_index])

func _release_slot(slot_index: int) -> void:
	ship_owner_by_slot[slot_index] = -1
	ship_slots[slot_index].hide()

func _promote_observer_to_slot(slot_index: int) -> void:
	while not observer_queue.is_empty():
		var next_observer: int = observer_queue[0]
		observer_queue.remove_at(0)
		if next_observer == multiplayer.get_unique_id():
			continue
		_assign_peer_to_slot(next_observer, slot_index)
		return

func _get_first_free_slot() -> int:
	var index: int = 0
	while index < MAX_SHIPS:
		if ship_owner_by_slot[index] == -1:
			return index
		index += 1
	return -1

func _get_slot_index_for_peer(peer_id: int) -> int:
	var index: int = 0
	while index < MAX_SHIPS:
		if ship_owner_by_slot[index] == peer_id:
			return index
		index += 1
	return -1

func _update_server_ships(delta: float) -> void:
	var host_id: int = multiplayer.get_unique_id()
	var index: int = 0
	while index < MAX_SHIPS:
		var owner_id: int = ship_owner_by_slot[index]
		if owner_id == -1:
			index += 1
			continue

		var turn_left := false
		var turn_right := false
		var accelerate := false
		var decelerate := false

		if owner_id == host_id:
			turn_left = Input.is_physical_key_pressed(KEY_A)
			turn_right = Input.is_physical_key_pressed(KEY_D)
			accelerate = Input.is_physical_key_pressed(KEY_W)
			decelerate = Input.is_physical_key_pressed(KEY_S)
		else:
			var peer_input: Dictionary = input_by_peer.get(owner_id, {})
			turn_left = bool(peer_input.get("left", false))
			turn_right = bool(peer_input.get("right", false))
			accelerate = bool(peer_input.get("accelerate", false))
			decelerate = bool(peer_input.get("decelerate", false))

		ship_slots[index].update_host(
			delta,
			turn_left,
			turn_right,
			accelerate,
			decelerate,
			WORLD_BOUNDS
		)
		index += 1

func _send_client_input_to_server() -> void:
	var local_id: int = multiplayer.get_unique_id()
	if _get_slot_index_for_peer(local_id) == -1:
		return

	submit_ship_input.rpc_id(
		1,
		Input.is_physical_key_pressed(KEY_A),
		Input.is_physical_key_pressed(KEY_D),
		Input.is_physical_key_pressed(KEY_W),
		Input.is_physical_key_pressed(KEY_S)
	)

func _sync_ships_to_clients() -> void:
	if not multiplayer.is_server():
		return

	var owner_ids: Array[int] = []
	var positions: Array[Vector2] = []
	var rotations: Array[float] = []
	var speeds: Array[float] = []
	var actives: Array[bool] = []

	var index: int = 0
	while index < MAX_SHIPS:
		var ship: ShipNavigation = ship_slots[index]
		owner_ids.append(ship_owner_by_slot[index])
		positions.append(ship.position)
		rotations.append(ship.rotation_radians)
		speeds.append(ship.speed)
		actives.append(ship.initialized and ship_owner_by_slot[index] != -1)
		index += 1

	sync_ship_roster.rpc(owner_ids, positions, rotations, speeds, actives, observer_queue.duplicate())

func _update_local_connection_status_from_roles() -> void:
	if multiplayer.multiplayer_peer == null:
		_set_status(STATUS_NOT_CONNECTED)
		return
	if multiplayer.is_server():
		_set_status(STATUS_HOSTING)
		return

	var local_id: int = multiplayer.get_unique_id()
	if observer_queue.has(local_id):
		_set_status(STATUS_OBSERVER)
		return
	if _get_slot_index_for_peer(local_id) != -1:
		_set_status(STATUS_CONNECTED_TO_HOST)
		return

	_set_status(STATUS_CONNECTED_TO_HOST)
