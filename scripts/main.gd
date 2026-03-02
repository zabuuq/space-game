extends Node2D

const DEFAULT_PORT := 56419
const FONT_SIZE_INCREASE := 3
const QUIT_BUTTON_SIZE := 32.0
const SHIP_OUTLINE_WIDTH := 3.0
const WORLD_BOUNDS := Rect2(Vector2.ZERO, Vector2(1600.0, 900.0))
const MAX_SHIPS := 6
const PROJECTILE_SPEED := 260.0
const PROJECTILE_MAX_TRAVEL := WORLD_BOUNDS.size.x * 0.25
const PROJECTILE_RADIUS := 3.0
const PROJECTILE_SPAWN_OFFSET := 20.0
const PROJECTILE_RENDER_SIDES := 12

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

const SHIP_START_NORMALIZED_POSITIONS: Array[Vector2] = [
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
var local_player_name: String = ""
var projectiles: Array[Dictionary] = []

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

@rpc("any_peer", "reliable")
func request_fire_projectile() -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	var slot_index: int = _get_slot_index_for_peer(sender_id)
	if slot_index == -1:
		return

	_spawn_projectile_from_slot(slot_index)
	_sync_projectiles_to_clients()
	queue_redraw()

@rpc("authority", "call_remote", "unreliable")
func sync_projectiles(positions: Array[Vector2], slot_indices: Array[int]) -> void:
	if multiplayer.is_server():
		return

	projectiles.clear()
	var total: int = mini(positions.size(), slot_indices.size())
	var index: int = 0
	while index < total:
		projectiles.append({
			"position": positions[index],
			"slot_index": slot_indices[index]
		})
		index += 1
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
		Callable(self, "_on_player_name_changed"),
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
	if ui.player_name_input != null:
		ui.player_name_input.text_submitted.connect(_on_player_name_submitted)
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
	projectiles.clear()
	_hide_all_ships()

func _set_status(value: String) -> void:
	ui.status_label.text = "Connection Status: %s" % value

func _initialize_host_roster() -> void:
	var host_id: int = multiplayer.get_unique_id()
	peer_roster.register_host(
		host_id,
		ip_info.local_internal_ip,
		ip_info.local_external_ip,
		local_player_name
	)
	_broadcast_peer_roster()

func _broadcast_peer_roster() -> void:
	if not multiplayer.is_server():
		return

	sync_peer_roster.rpc(
		peer_roster.get_sync_peer_ids(),
		peer_roster.get_sync_internal_ips(),
		peer_roster.get_sync_external_ips(),
		peer_roster.get_sync_names()
	)

@rpc("authority", "call_local", "reliable")
func sync_peer_roster(
	peer_ids: Array[int],
	internal_ips: Array[String],
	external_ips: Array[String],
	names: Array[String]
) -> void:
	peer_roster.apply_synced_roster(peer_ids, internal_ips, external_ips, names)
	_refresh_peer_list()

func _refresh_peer_list() -> void:
	var peer_ids: Array[int] = peer_roster.get_sync_peer_ids()
	var internal_ips: Array[String] = peer_roster.get_sync_internal_ips()
	var external_ips: Array[String] = peer_roster.get_sync_external_ips()
	var names: Array[String] = peer_roster.get_sync_names()
	var total: int = mini(
		peer_ids.size(),
		mini(internal_ips.size(), mini(external_ips.size(), names.size()))
	)
	if total <= 0:
		ui.peer_list_label.text = ""
		return

	var local_id: int = multiplayer.get_unique_id()
	var list_font_size: int = ui.peer_list_label.get_theme_font_size("normal_font_size")
	var lines: PackedStringArray = []
	var index: int = 0
	while index < total:
		var peer_id: int = peer_ids[index]
		var display_value: String = names[index].strip_edges()
		if display_value.is_empty():
			display_value = "%s/%s" % [internal_ips[index], external_ips[index]]
		var line := display_value
		var slot_index: int = _get_slot_index_for_peer(peer_id)
		var color_code: String = DEFAULT_PEER_TEXT_COLOR
		if slot_index >= 0 and slot_index < SHIP_COLORS.size():
			color_code = SHIP_COLORS[slot_index].to_html(false)

		line = "[color=#%s]%s[/color]" % [color_code, line]
		line = "[font_size=%d]%s[/font_size]" % [list_font_size, line]
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
		peer_roster.upsert_peer(
			host_id,
			ip_info.local_internal_ip,
			ip_info.local_external_ip,
			local_player_name
		)
		peer_roster.ensure_peer_in_order(host_id)
		_broadcast_peer_roster()
	else:
		submit_peer_info.rpc_id(
			1,
			ip_info.local_internal_ip,
			ip_info.local_external_ip,
			local_player_name
		)

@rpc("any_peer", "reliable")
func submit_peer_info(internal_ip: String, external_ip: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	peer_roster.upsert_peer(sender_id, internal_ip, external_ip, player_name)
	_broadcast_peer_roster()

func _update_local_ip_labels() -> void:
	ui.local_ip_label.text = ip_info.local_internal_ip
	ui.external_ip_label.text = ip_info.local_external_ip

func _on_ip_info_updated() -> void:
	_update_local_ip_labels()
	_submit_local_identity()

func _on_player_name_changed(value: String) -> void:
	local_player_name = value.strip_edges()
	_submit_local_identity()
	_refresh_peer_list()

func _on_player_name_submitted(_value: String) -> void:
	if ui.player_name_input == null:
		return
	ui.player_name_input.release_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		_update_server_ships(delta)
		_update_projectiles(delta)
		_sync_ships_to_clients()
		_sync_projectiles_to_clients()
		queue_redraw()
		return

	_send_client_input_to_server()

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.pressed:
			_release_name_focus_if_clicked_outside(mouse_event.position)
	if _is_typing_name():
		return
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return

	if key_event.physical_keycode == KEY_X and multiplayer.is_server():
		var host_id: int = multiplayer.get_unique_id()
		var host_slot: int = _get_slot_index_for_peer(host_id)
		if host_slot == -1:
			return
		ship_slots[host_slot].full_stop()
		_sync_ships_to_clients()
		queue_redraw()
		return

	var local_id: int = multiplayer.get_unique_id()
	var local_slot_index: int = _get_slot_index_for_peer(local_id)
	if local_slot_index == -1:
		return

	if key_event.physical_keycode == KEY_X:
		if multiplayer.is_server():
			return
		request_full_stop.rpc_id(1)
		return

	if key_event.physical_keycode != KEY_SPACE:
		return

	if multiplayer.is_server():
		_spawn_projectile_from_slot(local_slot_index)
		_sync_projectiles_to_clients()
		queue_redraw()
		return

	request_fire_projectile.rpc_id(1)

func _draw() -> void:
	var play_rect: Rect2 = _get_play_render_rect()
	draw_rect(play_rect, Color.BLACK, true)

	if multiplayer.multiplayer_peer != null:
		var index: int = 0
		for ship in ship_slots:
			if not ship.initialized:
				index += 1
				continue

			var point_sets := ship.get_wrapped_screen_point_sets(play_rect, WORLD_BOUNDS)
			for ship_points in point_sets:
				_draw_clipped_polyline(ship_points, SHIP_COLORS[index], SHIP_OUTLINE_WIDTH, play_rect)

			index += 1

		for projectile in projectiles:
			var world_position: Vector2 = projectile.get("position", Vector2.ZERO)
			var slot_index: int = int(projectile.get("slot_index", -1))
			var color: Color = Color.WHITE
			if slot_index >= 0 and slot_index < SHIP_COLORS.size():
				color = SHIP_COLORS[slot_index]
			_draw_wrapped_projectile(world_position, play_rect, color)

func _draw_wrapped_projectile(world_position: Vector2, play_rect: Rect2, color: Color) -> void:
	var base_center := _world_to_screen_position(world_position, play_rect)
	var wrapped_centers := _get_wrapped_centers(base_center, play_rect, PROJECTILE_RADIUS)
	for center in wrapped_centers:
		var projectile_poly := _build_circle_polygon(center, PROJECTILE_RADIUS, PROJECTILE_RENDER_SIDES)
		var clipped_poly := _clip_polygon_to_rect(projectile_poly, play_rect)
		if clipped_poly.size() >= 3:
			draw_colored_polygon(clipped_poly, color)

func _get_wrapped_centers(base_center: Vector2, play_rect: Rect2, radius: float) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var x_offset: int = -1
	while x_offset <= 1:
		var y_offset: int = -1
		while y_offset <= 1:
			var center := base_center + Vector2(
				float(x_offset) * play_rect.size.x,
				float(y_offset) * play_rect.size.y
			)
			if _circle_may_be_visible(center, radius, play_rect):
				centers.append(center)
			y_offset += 1
		x_offset += 1
	return centers

func _circle_may_be_visible(center: Vector2, radius: float, rect: Rect2) -> bool:
	var min_x: float = rect.position.x - radius
	var max_x: float = rect.position.x + rect.size.x + radius
	var min_y: float = rect.position.y - radius
	var max_y: float = rect.position.y + rect.size.y + radius
	return center.x >= min_x and center.x <= max_x and center.y >= min_y and center.y <= max_y

func _build_circle_polygon(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if sides < 3:
		return polygon

	var step := TAU / float(sides)
	var index: int = 0
	while index < sides:
		var angle := float(index) * step
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
		index += 1
	return polygon

func _draw_clipped_polyline(points: PackedVector2Array, color: Color, width: float, clip_rect: Rect2) -> void:
	if points.size() < 2:
		return

	var index: int = 0
	while index < points.size() - 1:
		var clipped := _clip_segment_to_rect(points[index], points[index + 1], clip_rect)
		if clipped.get("visible", false):
			var from_point: Vector2 = clipped.get("from", Vector2.ZERO)
			var to_point: Vector2 = clipped.get("to", Vector2.ZERO)
			draw_line(from_point, to_point, color, width, true)
		index += 1

func _clip_segment_to_rect(from_point: Vector2, to_point: Vector2, rect: Rect2) -> Dictionary:
	var x_min: float = rect.position.x
	var x_max: float = rect.position.x + rect.size.x
	var y_min: float = rect.position.y
	var y_max: float = rect.position.y + rect.size.y
	var dx: float = to_point.x - from_point.x
	var dy: float = to_point.y - from_point.y
	var t0 := 0.0
	var t1 := 1.0
	var p: Array[float] = [-dx, dx, -dy, dy]
	var q: Array[float] = [
		from_point.x - x_min,
		x_max - from_point.x,
		from_point.y - y_min,
		y_max - from_point.y
	]

	var index: int = 0
	while index < 4:
		var p_value: float = p[index]
		var q_value: float = q[index]
		if is_zero_approx(p_value):
			if q_value < 0.0:
				return {"visible": false}
			index += 1
			continue

		var ratio: float = q_value / p_value
		if p_value < 0.0:
			if ratio > t1:
				return {"visible": false}
			t0 = maxf(t0, ratio)
		else:
			if ratio < t0:
				return {"visible": false}
			t1 = minf(t1, ratio)
		index += 1

	var clipped_from := from_point + (Vector2(dx, dy) * t0)
	var clipped_to := from_point + (Vector2(dx, dy) * t1)
	return {
		"visible": true,
		"from": clipped_from,
		"to": clipped_to
	}

func _clip_polygon_to_rect(polygon: PackedVector2Array, rect: Rect2) -> PackedVector2Array:
	var clipped := polygon
	clipped = _clip_polygon_against_vertical(clipped, rect.position.x, true)
	clipped = _clip_polygon_against_vertical(clipped, rect.position.x + rect.size.x, false)
	clipped = _clip_polygon_against_horizontal(clipped, rect.position.y, true)
	clipped = _clip_polygon_against_horizontal(clipped, rect.position.y + rect.size.y, false)
	return clipped

func _clip_polygon_against_vertical(
	polygon: PackedVector2Array,
	x_edge: float,
	keep_greater: bool
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty():
		return result

	var previous: Vector2 = polygon[polygon.size() - 1]
	var previous_inside: bool = previous.x >= x_edge if keep_greater else previous.x <= x_edge
	for current in polygon:
		var current_inside: bool = current.x >= x_edge if keep_greater else current.x <= x_edge
		if current_inside != previous_inside:
			var delta_x: float = current.x - previous.x
			if not is_zero_approx(delta_x):
				var t: float = (x_edge - previous.x) / delta_x
				result.append(previous + ((current - previous) * t))
		if current_inside:
			result.append(current)
		previous = current
		previous_inside = current_inside

	return result

func _clip_polygon_against_horizontal(
	polygon: PackedVector2Array,
	y_edge: float,
	keep_greater: bool
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if polygon.is_empty():
		return result

	var previous: Vector2 = polygon[polygon.size() - 1]
	var previous_inside: bool = previous.y >= y_edge if keep_greater else previous.y <= y_edge
	for current in polygon:
		var current_inside: bool = current.y >= y_edge if keep_greater else current.y <= y_edge
		if current_inside != previous_inside:
			var delta_y: float = current.y - previous.y
			if not is_zero_approx(delta_y):
				var t: float = (y_edge - previous.y) / delta_y
				result.append(previous + ((current - previous) * t))
		if current_inside:
			result.append(current)
		previous = current
		previous_inside = current_inside

	return result

func _get_right_section_rect() -> Rect2:
	if ui.right_section == null:
		return get_viewport_rect()
	return ui.right_section.get_global_rect()

func _get_play_render_rect() -> Rect2:
	var container: Rect2 = _get_right_section_rect()
	if container.size.x <= 0.0 or container.size.y <= 0.0:
		return container

	var world_aspect: float = WORLD_BOUNDS.size.x / WORLD_BOUNDS.size.y
	var container_aspect: float = container.size.x / container.size.y
	var fitted_size := container.size
	if container_aspect > world_aspect:
		fitted_size.x = container.size.y * world_aspect
	else:
		fitted_size.y = container.size.x / world_aspect

	var fitted_position := container.position + ((container.size - fitted_size) * 0.5)
	return Rect2(fitted_position, fitted_size)

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
	ship_slots[slot_index].reset(_to_world_position(SHIP_START_NORMALIZED_POSITIONS[slot_index]))

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
			if _is_typing_name():
				turn_left = false
				turn_right = false
				accelerate = false
				decelerate = false
			else:
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

	var turn_left := false
	var turn_right := false
	var accelerate := false
	var decelerate := false
	if not _is_typing_name():
		turn_left = Input.is_physical_key_pressed(KEY_A)
		turn_right = Input.is_physical_key_pressed(KEY_D)
		accelerate = Input.is_physical_key_pressed(KEY_W)
		decelerate = Input.is_physical_key_pressed(KEY_S)

	submit_ship_input.rpc_id(
		1,
		turn_left,
		turn_right,
		accelerate,
		decelerate
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

func _is_typing_name() -> bool:
	if ui.player_name_input == null:
		return false
	return ui.player_name_input.has_focus()

func _release_name_focus_if_clicked_outside(click_position: Vector2) -> void:
	if ui.player_name_input == null:
		return
	if not ui.player_name_input.has_focus():
		return

	var name_rect: Rect2 = ui.player_name_input.get_global_rect()
	if name_rect.has_point(click_position):
		return
	ui.player_name_input.release_focus()

func _to_world_position(normalized_position: Vector2) -> Vector2:
	return WORLD_BOUNDS.position + Vector2(
		normalized_position.x * WORLD_BOUNDS.size.x,
		normalized_position.y * WORLD_BOUNDS.size.y
	)

func _world_to_screen_position(world_position: Vector2, play_rect: Rect2) -> Vector2:
	var normalized_position := Vector2.ZERO
	if WORLD_BOUNDS.size.x > 0.0:
		normalized_position.x = (world_position.x - WORLD_BOUNDS.position.x) / WORLD_BOUNDS.size.x
	if WORLD_BOUNDS.size.y > 0.0:
		normalized_position.y = (world_position.y - WORLD_BOUNDS.position.y) / WORLD_BOUNDS.size.y
	return play_rect.position + (normalized_position * play_rect.size)

func _spawn_projectile_from_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= ship_slots.size():
		return
	var ship: ShipNavigation = ship_slots[slot_index]
	if not ship.initialized:
		return

	var forward := Vector2(0, 1).rotated(ship.rotation_radians)
	projectiles.append({
		"position": _wrap_world_position(ship.position + (forward * PROJECTILE_SPAWN_OFFSET)),
		"velocity": forward * PROJECTILE_SPEED,
		"distance": 0.0,
		"slot_index": slot_index
	})

func _update_projectiles(delta: float) -> void:
	if projectiles.is_empty():
		return

	var next_projectiles: Array[Dictionary] = []
	for projectile in projectiles:
		var velocity: Vector2 = projectile.get("velocity", Vector2.ZERO)
		var position: Vector2 = projectile.get("position", Vector2.ZERO)
		var distance: float = float(projectile.get("distance", 0.0))
		var slot_index: int = int(projectile.get("slot_index", -1))

		position = _wrap_world_position(position + (velocity * delta))
		distance += velocity.length() * delta
		if distance >= PROJECTILE_MAX_TRAVEL:
			continue

		next_projectiles.append({
			"position": position,
			"velocity": velocity,
			"distance": distance,
			"slot_index": slot_index
		})

	projectiles = next_projectiles

func _wrap_world_position(current: Vector2) -> Vector2:
	var min_x: float = WORLD_BOUNDS.position.x
	var min_y: float = WORLD_BOUNDS.position.y
	var max_x: float = WORLD_BOUNDS.position.x + WORLD_BOUNDS.size.x
	var max_y: float = WORLD_BOUNDS.position.y + WORLD_BOUNDS.size.y

	var wrapped: Vector2 = current
	if wrapped.x < min_x:
		wrapped.x = max_x
	elif wrapped.x > max_x:
		wrapped.x = min_x

	if wrapped.y < min_y:
		wrapped.y = max_y
	elif wrapped.y > max_y:
		wrapped.y = min_y

	return wrapped

func _sync_projectiles_to_clients() -> void:
	if not multiplayer.is_server():
		return

	var positions: Array[Vector2] = []
	var slot_indices: Array[int] = []
	for projectile in projectiles:
		positions.append(projectile.get("position", Vector2.ZERO))
		slot_indices.append(int(projectile.get("slot_index", -1)))

	sync_projectiles.rpc(positions, slot_indices)
