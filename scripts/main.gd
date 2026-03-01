extends Node2D

const ARROW_LENGTH := 90.0
const ARROW_HEAD := 24.0
const DOT_RADIUS := 20.0
const DEFAULT_PORT := 56419

var direction: Vector2 = Vector2.ZERO
var status_label: Label
var button_row: HBoxContainer
var host_button: Button
var join_button: Button
var disconnect_button: Button
var join_popup: Window
var join_ip_input: LineEdit

@rpc("any_peer", "call_local", "reliable")
func update_direction(new_direction: Vector2) -> void:
	direction = new_direction
	queue_redraw()

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	build_ui()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_process_unhandled_input(true)

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Host or Join"
	vbox.add_child(title)

	button_row = HBoxContainer.new()
	vbox.add_child(button_row)

	host_button = Button.new()
	host_button.text = "Host"
	host_button.pressed.connect(_on_host_pressed)
	button_row.add_child(host_button)

	join_button = Button.new()
	join_button.text = "Join"
	join_button.pressed.connect(_on_join_pressed)
	button_row.add_child(join_button)

	disconnect_button = Button.new()
	disconnect_button.text = "Disconnect"
	disconnect_button.visible = false
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	button_row.add_child(disconnect_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)

	status_label = Label.new()
	status_label.text = "Status: Not connected"
	vbox.add_child(status_label)

	var instructions := Label.new()
	instructions.text = "Host can press W/A/S/D to change the shared arrow direction."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)

	_build_join_popup()

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
	popup_vbox.add_child(join_ip_input)

	var connect_button := Button.new()
	connect_button.text = "Connect"
	connect_button.pressed.connect(_on_connect_pressed)
	popup_vbox.add_child(connect_button)

func _on_host_pressed() -> void:
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(DEFAULT_PORT)
	if result != OK:
		status_label.text = "Status: Failed to host (error %d)" % result
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Status: Hosting on port %d" % DEFAULT_PORT
	_set_connected_controls(true)

func _on_join_pressed() -> void:
	join_popup.popup_centered()

func _on_connect_pressed() -> void:
	join_popup.hide()
	var peer := ENetMultiplayerPeer.new()
	var ip := join_ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Status: Invalid IP"
		return

	var result := peer.create_client(ip, DEFAULT_PORT)
	if result != OK:
		status_label.text = "Status: Failed to connect (error %d)" % result
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Status: Connecting to %s:%d" % [ip, DEFAULT_PORT]
	_set_connected_controls(true)

func _on_connected_to_server() -> void:
	status_label.text = "Status: Connected as client"

func _on_connection_failed() -> void:
	status_label.text = "Status: Connection failed"
	_disconnect_local_peer(false)

func _on_server_disconnected() -> void:
	status_label.text = "Status: Server disconnected"
	_disconnect_local_peer(false)

func _on_peer_disconnected(_id: int) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().is_empty():
		status_label.text = "Status: Hosting on port %d" % DEFAULT_PORT

func _on_disconnect_pressed() -> void:
	_disconnect_local_peer(true)

func _disconnect_local_peer(update_status: bool) -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if update_status:
		status_label.text = "Status: Not connected"
	_set_connected_controls(false)

func _set_connected_controls(is_connected: bool) -> void:
	host_button.visible = not is_connected
	join_button.visible = not is_connected
	disconnect_button.visible = is_connected

func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return
	if event is InputEventKey and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_S, KEY_A, KEY_D:
				update_direction.rpc(_get_current_direction())
			_:
				return

func _get_current_direction() -> Vector2:
	if Input.is_physical_key_pressed(KEY_W):
		return Vector2.UP
	if Input.is_physical_key_pressed(KEY_S):
		return Vector2.DOWN
	if Input.is_physical_key_pressed(KEY_A):
		return Vector2.LEFT
	if Input.is_physical_key_pressed(KEY_D):
		return Vector2.RIGHT
	return Vector2.ZERO

func _draw() -> void:
	var center := get_viewport_rect().size * 0.5
	if direction == Vector2.ZERO:
		draw_circle(center, DOT_RADIUS, Color.CYAN)
		return

	var dir := direction.normalized()
	var tip := center + (dir * ARROW_LENGTH)
	var tail := center - (dir * ARROW_LENGTH * 0.45)
	var normal := Vector2(-dir.y, dir.x)
	var left_wing := tip - (dir * ARROW_HEAD) + (normal * ARROW_HEAD * 0.6)
	var right_wing := tip - (dir * ARROW_HEAD) - (normal * ARROW_HEAD * 0.6)

	draw_line(tail, tip, Color.ORANGE, 8.0)
	draw_line(tip, left_wing, Color.ORANGE, 8.0)
	draw_line(tip, right_wing, Color.ORANGE, 8.0)
