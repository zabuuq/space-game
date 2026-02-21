extends Node2D

const ARROW_LENGTH := 90.0
const ARROW_HEAD := 24.0
const DOT_RADIUS := 20.0

var direction: Vector2 = Vector2.ZERO
var ip_input: LineEdit
var port_input: LineEdit
var status_label: Label

@rpc("any_peer", "call_local", "reliable")
func update_direction(new_direction: Vector2) -> void:
	direction = new_direction
	queue_redraw()

func _ready() -> void:
	build_ui()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
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

	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Server IP"
	ip_input.text = "127.0.0.1"
	vbox.add_child(ip_input)

	port_input = LineEdit.new()
	port_input.placeholder_text = "Port"
	port_input.text = "9000"
	vbox.add_child(port_input)

	var button_row := HBoxContainer.new()
	vbox.add_child(button_row)

	var host_button := Button.new()
	host_button.text = "Host"
	host_button.pressed.connect(_on_host_pressed)
	button_row.add_child(host_button)

	var join_button := Button.new()
	join_button.text = "Join"
	join_button.pressed.connect(_on_join_pressed)
	button_row.add_child(join_button)

	status_label = Label.new()
	status_label.text = "Status: Not connected"
	vbox.add_child(status_label)

	var instructions := Label.new()
	instructions.text = "Host can press W/A/S/D to change the shared arrow direction."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)

func _on_host_pressed() -> void:
	var port := int(port_input.text)
	if port <= 0:
		status_label.text = "Status: Invalid port"
		return

	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port)
	if result != OK:
		status_label.text = "Status: Failed to host (error %d)" % result
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Status: Hosting on port %d" % port

func _on_join_pressed() -> void:
	var port := int(port_input.text)
	if port <= 0:
		status_label.text = "Status: Invalid port"
		return

	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(ip_input.text.strip_edges(), port)
	if result != OK:
		status_label.text = "Status: Failed to connect (error %d)" % result
		return

	multiplayer.multiplayer_peer = peer
	status_label.text = "Status: Connecting to %s:%d" % [ip_input.text.strip_edges(), port]

func _on_connected_to_server() -> void:
	status_label.text = "Status: Connected as client"

func _on_connection_failed() -> void:
	status_label.text = "Status: Connection failed"

func _on_server_disconnected() -> void:
	status_label.text = "Status: Server disconnected"

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
