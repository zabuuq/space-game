extends Node2D

const DEFAULT_PORT := 56419
const FONT_SIZE_INCREASE := 3
const QUIT_BUTTON_SIZE := 32.0
const SHIP_OUTLINE_WIDTH := 3.0
const SHIP_NAVIGATION_SCRIPT := preload("res://scripts/ship_navigation.gd")

var status_label: Label
var local_ip_label: Label
var external_ip_label: Label
var peer_list_label: RichTextLabel
var button_row: HBoxContainer
var host_button: Button
var join_button: Button
var disconnect_button: Button
var join_popup: Window
var join_ip_input: LineEdit
var right_section: ColorRect
var external_ip_request: HTTPRequest

var local_internal_ip := "127.0.0.1"
var local_external_ip := "Loading..."
var peer_order: Array[int] = []
var peer_info_by_id: Dictionary = {}
var ship_navigation: ShipNavigation = SHIP_NAVIGATION_SCRIPT.new()

@rpc("authority", "call_local", "unreliable")
func sync_ship_state(new_position: Vector2, new_rotation: float, new_speed: float) -> void:
	ship_navigation.apply_network_state(new_position, new_rotation, new_speed)
	queue_redraw()

@rpc("any_peer", "reliable")
func submit_peer_info(internal_ip: String, external_ip: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	_set_peer_info(sender_id, internal_ip, external_ip)
	_broadcast_peer_roster()

@rpc("authority", "call_local", "reliable")
func sync_peer_roster(peer_ids: Array[int], internal_ips: Array[String], external_ips: Array[String]) -> void:
	peer_order.clear()
	peer_info_by_id.clear()

	var total: int = mini(peer_ids.size(), mini(internal_ips.size(), external_ips.size()))
	for index in range(total):
		var peer_id := peer_ids[index]
		peer_order.append(peer_id)
		peer_info_by_id[peer_id] = {
			"internal": internal_ips[index],
			"external": external_ips[index]
		}

	_refresh_peer_list()

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	local_internal_ip = _get_preferred_local_ip()
	build_ui()

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
	_request_external_ip()
	queue_redraw()

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)

	var root_row := HBoxContainer.new()
	root_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_row)

	var quit_button := Button.new()
	quit_button.text = "X"
	_bump_font_size(quit_button)
	_apply_button_padding(quit_button, 6.0, 4.0)
	quit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	quit_button.offset_left = 8
	quit_button.offset_top = 8
	quit_button.offset_right = 8 + QUIT_BUTTON_SIZE
	quit_button.offset_bottom = 8 + QUIT_BUTTON_SIZE
	quit_button.pressed.connect(_on_quit_pressed)
	layer.add_child(quit_button)

	var left_section := ColorRect.new()
	left_section.color = Color(0.18, 0.18, 0.18, 1.0)
	left_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_section.size_flags_stretch_ratio = 0.6
	root_row.add_child(left_section)

	right_section = ColorRect.new()
	right_section.color = Color.BLACK
	right_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_section.size_flags_stretch_ratio = 3.4
	right_section.resized.connect(queue_redraw)
	root_row.add_child(right_section)

	var left_margin := MarginContainer.new()
	left_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_margin.add_theme_constant_override("margin_left", 16)
	left_margin.add_theme_constant_override("margin_right", 16)
	left_margin.add_theme_constant_override("margin_top", 52)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	left_section.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_vbox)

	local_ip_label = Label.new()
	_bump_font_size(local_ip_label)
	left_vbox.add_child(local_ip_label)

	external_ip_label = Label.new()
	_bump_font_size(external_ip_label)
	left_vbox.add_child(external_ip_label)

	var port_label := Label.new()
	port_label.text = "Port: %d" % DEFAULT_PORT
	_bump_font_size(port_label)
	left_vbox.add_child(port_label)

	button_row = HBoxContainer.new()
	left_vbox.add_child(button_row)

	host_button = Button.new()
	host_button.text = "Host"
	_bump_font_size(host_button)
	_apply_button_padding(host_button, 14.0, 8.0)
	host_button.pressed.connect(_on_host_pressed)
	button_row.add_child(host_button)

	join_button = Button.new()
	join_button.text = "Join"
	_bump_font_size(join_button)
	_apply_button_padding(join_button, 14.0, 8.0)
	join_button.pressed.connect(_on_join_pressed)
	button_row.add_child(join_button)

	disconnect_button = Button.new()
	disconnect_button.text = "Disconnect"
	_bump_font_size(disconnect_button)
	_apply_button_padding(disconnect_button, 14.0, 8.0)
	disconnect_button.visible = false
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	button_row.add_child(disconnect_button)

	status_label = Label.new()
	_bump_font_size(status_label)
	left_vbox.add_child(status_label)

	var instructions := Label.new()
	instructions.text = "Host can press W/A/S/D keys to display directional arrow."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bump_font_size(instructions)
	left_vbox.add_child(instructions)

	peer_list_label = RichTextLabel.new()
	peer_list_label.bbcode_enabled = true
	peer_list_label.fit_content = true
	peer_list_label.scroll_active = false
	peer_list_label.selection_enabled = false
	peer_list_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	peer_list_label.add_theme_font_size_override("normal_font_size", peer_list_label.get_theme_font_size("normal_font_size") + FONT_SIZE_INCREASE)
	left_vbox.add_child(peer_list_label)

	_build_join_popup()
	_refresh_peer_list()

func _build_join_popup() -> void:
	join_popup = Window.new()
	join_popup.title = "Connect to Host"
	join_popup.size = Vector2i(340, 120)
	join_popup.unresizable = true
	join_popup.visible = false
	add_child(join_popup)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_vbox.add_theme_constant_override("separation", 8)
	join_popup.add_child(popup_vbox)

	join_ip_input = LineEdit.new()
	join_ip_input.placeholder_text = "Host IP"
	join_ip_input.text = "127.0.0.1"
	_bump_font_size(join_ip_input)
	popup_vbox.add_child(join_ip_input)

	var connect_button := Button.new()
	connect_button.text = "Connect"
	_bump_font_size(connect_button)
	connect_button.pressed.connect(_on_connect_pressed)
	popup_vbox.add_child(connect_button)

func _bump_font_size(control: Control) -> void:
	var current_size: int = control.get_theme_font_size("font_size")
	control.add_theme_font_size_override("font_size", current_size + FONT_SIZE_INCREASE)

func _apply_button_padding(button: Button, horizontal: float, vertical: float) -> void:
	var states: PackedStringArray = ["normal", "hover", "pressed", "disabled", "focus"]
	for state in states:
		var stylebox: StyleBox = button.get_theme_stylebox(state)
		if stylebox == null:
			continue
		var style_copy: StyleBox = stylebox.duplicate() as StyleBox
		style_copy.set_content_margin(SIDE_LEFT, horizontal)
		style_copy.set_content_margin(SIDE_RIGHT, horizontal)
		style_copy.set_content_margin(SIDE_TOP, vertical)
		style_copy.set_content_margin(SIDE_BOTTOM, vertical)
		button.add_theme_stylebox_override(state, style_copy)

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(DEFAULT_PORT)
	if result != OK:
		_set_status("Failed to host (error %d)" % result)
		return

	multiplayer.multiplayer_peer = peer
	_set_status("Hosting on port %d" % DEFAULT_PORT)
	_set_connected_controls(true)
	_initialize_host_roster()
	_reset_ship()
	sync_ship_state.rpc(
		ship_navigation.position,
		ship_navigation.rotation_radians,
		ship_navigation.speed
	)

func _on_join_pressed() -> void:
	join_popup.popup_centered()

func _on_connect_pressed() -> void:
	join_popup.hide()
	var peer := ENetMultiplayerPeer.new()
	var ip := join_ip_input.text.strip_edges()
	if ip.is_empty():
		_set_status("Invalid IP")
		return

	var result := peer.create_client(ip, DEFAULT_PORT)
	if result != OK:
		_set_status("Failed to connect (error %d)" % result)
		return

	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to %s:%d" % [ip, DEFAULT_PORT])
	_set_connected_controls(true)

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

	if not peer_order.has(peer_id):
		peer_order.append(peer_id)
	_broadcast_peer_roster()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	peer_order.erase(peer_id)
	peer_info_by_id.erase(peer_id)
	_broadcast_peer_roster()

func _on_disconnect_pressed() -> void:
	_disconnect_local_peer(true)

func _disconnect_local_peer(update_status: bool) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if update_status:
		_set_status("Not connected")
	_set_connected_controls(false)
	peer_order.clear()
	peer_info_by_id.clear()
	_refresh_peer_list()
	_reset_ship()

func _set_connected_controls(is_connected: bool) -> void:
	host_button.visible = not is_connected
	join_button.visible = not is_connected
	disconnect_button.visible = is_connected

func _on_quit_pressed() -> void:
	get_tree().quit()

func _set_status(value: String) -> void:
	status_label.text = "Connection Status: %s" % value

func _initialize_host_roster() -> void:
	var host_id := multiplayer.get_unique_id()
	peer_order.clear()
	peer_order.append(host_id)
	peer_info_by_id.clear()
	_set_peer_info(host_id, local_internal_ip, local_external_ip)
	_broadcast_peer_roster()

func _set_peer_info(peer_id: int, internal_ip: String, external_ip: String) -> void:
	peer_info_by_id[peer_id] = {
		"internal": internal_ip,
		"external": external_ip
	}

func _get_peer_info(peer_id: int) -> Dictionary:
	if peer_info_by_id.has(peer_id):
		return peer_info_by_id[peer_id]
	return {
		"internal": "Unknown",
		"external": "Unknown"
	}

func _broadcast_peer_roster() -> void:
	if not multiplayer.is_server():
		return

	var internal_ips: Array[String] = []
	var external_ips: Array[String] = []
	for peer_id in peer_order:
		var info: Dictionary = _get_peer_info(peer_id)
		internal_ips.append(str(info["internal"]))
		external_ips.append(str(info["external"]))

	sync_peer_roster.rpc(peer_order, internal_ips, external_ips)

func _refresh_peer_list() -> void:
	if peer_order.is_empty():
		peer_list_label.text = ""
		return

	var lines: PackedStringArray = []
	for index in range(peer_order.size()):
		var peer_id := peer_order[index]
		var info: Dictionary = _get_peer_info(peer_id)
		var line := "%s/%s" % [str(info["internal"]), str(info["external"])]
		if index == 0:
			lines.append("[b]%s[/b]" % line)
		else:
			lines.append(line)

	peer_list_label.text = "\n".join(lines)

func _submit_local_identity() -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		var host_id := multiplayer.get_unique_id()
		_set_peer_info(host_id, local_internal_ip, local_external_ip)
		if not peer_order.has(host_id):
			peer_order.insert(0, host_id)
		_broadcast_peer_roster()
	else:
		submit_peer_info.rpc_id(1, local_internal_ip, local_external_ip)

func _update_local_ip_labels() -> void:
	local_ip_label.text = "Local IP: %s" % local_internal_ip
	external_ip_label.text = "External IP: %s" % local_external_ip

func _get_preferred_local_ip() -> String:
	for address in IP.get_local_addresses():
		if address.contains(":"):
			continue
		if address.begins_with("127."):
			continue
		return address
	return "127.0.0.1"

func _request_external_ip() -> void:
	external_ip_request = HTTPRequest.new()
	add_child(external_ip_request)
	external_ip_request.request_completed.connect(_on_external_ip_request_completed)
	var request_error := external_ip_request.request("https://api.ipify.org")
	if request_error != OK:
		local_external_ip = "Unavailable"
		_update_local_ip_labels()
		_submit_local_identity()

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

	_update_local_ip_labels()
	_submit_local_identity()

func _reset_ship() -> void:
	ship_navigation.reset(_get_right_section_center())
	queue_redraw()

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

	sync_ship_state.rpc(
		ship_navigation.position,
		ship_navigation.rotation_radians,
		ship_navigation.speed
	)
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
		sync_ship_state.rpc(
			ship_navigation.position,
			ship_navigation.rotation_radians,
			ship_navigation.speed
		)
		queue_redraw()

func _get_right_section_center() -> Vector2:
	if right_section == null:
		return get_viewport_rect().size * 0.5
	var right_rect := right_section.get_global_rect()
	return right_rect.position + (right_rect.size * 0.5)

func _get_right_section_rect() -> Rect2:
	if right_section == null:
		return get_viewport_rect()
	return right_section.get_global_rect()

func _draw() -> void:
	if not ship_navigation.initialized:
		return

	draw_polyline(ship_navigation.get_transformed_points(), Color.ORANGE, SHIP_OUTLINE_WIDTH, true)
