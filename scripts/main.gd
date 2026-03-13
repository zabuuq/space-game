extends Node2D

const DEFAULT_PORT := 56419
const BASE_RESOLUTION := Vector2(1600.0, 900.0)
const MAX_SHIPS := 6
const FIRE_INTERVAL_SECONDS := 0.16
const SHIP_HIT_RADIUS := 8.0
const DAMAGE_IMMUNITY_SECONDS := 2.0
const IMMUNE_ACCELERATION_MULTIPLIER := 4.0

const STATUS_NOT_CONNECTED := "Not connected"
const STATUS_CONNECTING := "Connecting"
const STATUS_FAILED_TO_CONNECT := "Failed to Connect"
const STATUS_HOSTING := "Hosting"
const STATUS_CONNECTED_TO_HOST := "Connected to host"
const STATUS_OBSERVER := "Observer"
const MAX_CONNECT_ATTEMPTS := 3
const CONNECTING_DOT_STEP_SECONDS := 0.25
const CONNECT_RETRY_DELAY_SECONDS := 0.35
const DEFAULT_PEER_TEXT_COLOR := "ffffff"
const PLAYER_COLORS: Array[Color] = [
	Color(0.93, 0.93, 0.93), # white
	Color(0.97, 0.33, 0.33), # red
	Color(0.20, 0.63, 0.98), # blue
	Color(0.30, 0.84, 0.39), # green
	Color(1.00, 0.79, 0.27), # amber
	Color(0.84, 0.44, 0.96), # violet
	Color(0.29, 0.90, 0.88), # cyan
	Color(1.00, 0.58, 0.24), # orange
	Color(0.98, 0.31, 0.67)  # pink
]

const SHIP_START_NORMALIZED_POSITIONS: Array[Vector2] = [
	Vector2(1.0 / 6.0, 1.0 / 4.0),
	Vector2(5.0 / 6.0, 1.0 / 4.0),
	Vector2(5.0 / 6.0, 3.0 / 4.0),
	Vector2(1.0 / 6.0, 3.0 / 4.0),
	Vector2(3.0 / 6.0, 1.0 / 4.0),
	Vector2(3.0 / 6.0, 3.0 / 4.0)
]

const SHIP_SCENE := preload("res://entities/ship/ship.tscn")
const CONNECTION_CONTROLLER_SCRIPT := preload("res://scripts/connection_controller.gd")
const IP_INFO_SERVICE_SCRIPT := preload("res://scripts/ip_info_service.gd")
const PEER_ROSTER_SERVICE_SCRIPT := preload("res://scripts/peer_roster_service.gd")

@onready var ui: MainUi = %MainUi
@onready var world_node: ColorRect = $World
var world_root: Node2D

var connection_controller: ConnectionController = CONNECTION_CONTROLLER_SCRIPT.new()
var ip_info: IpInfoService = IP_INFO_SERVICE_SCRIPT.new()
var peer_roster: PeerRosterService = PEER_ROSTER_SERVICE_SCRIPT.new()

var ship_owner_by_slot: Array[int] = []
var observer_queue: Array[int] = []
var local_player_name: String = ""
var local_preferred_color_index := -1
var local_fire_cooldown := 0.0
var score_by_identity: Dictionary = {}
var peer_identity_by_id: Dictionary = {}
var peer_score_by_id: Dictionary = {}
var turret_operator_by_pilot_id: Dictionary = {}
var pilot_by_turret_operator_id: Dictionary = {}
var pending_team_join_request_pilot_id := 0
var pending_team_leave_request := false
var damage_immunity_until_by_peer: Dictionary = {}
var is_connecting := false
var connect_target_ip: String = ""
var connect_attempt_count := 0
var connect_retry_pending := false
var connect_retry_timer := 0.0
var connecting_dot_count := 0
var connecting_dot_timer := 0.0

var offering_slot_to_peer: int = 0
var offering_slot_timer: float = 0.0
var observers_who_declined_current_offer: Array[int] = []
var open_join_state: bool = false
var slot_offer_dialog: ConfirmationDialog
var slot_offer_local_timer: float = 0.0

var current_play_area_size: int = 0
var current_edge_wrapping: bool = true
var world_bounds := Rect2(Vector2.ZERO, BASE_RESOLUTION)
var starfield: Node2D
var off_screen_pointers: Control

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	if world_node == null:
		world_node = ColorRect.new()
		world_node.name = "World"
		world_node.color = Color.BLACK
		world_node.clip_contents = true
		add_child(world_node)
		
	if world_root == null:
		world_root = Node2D.new()
		world_root.name = "WorldRoot"
		world_node.add_child(world_root)
		
		# Update spawners to point to the new root
		for child in get_children():
			if child is MultiplayerSpawner:
				child.spawn_path = child.get_path_to(world_root)

	starfield = preload("res://scripts/starfield.gd").new()
	starfield.name = "Starfield"
	world_root.add_child(starfield)
	
	off_screen_pointers = preload("res://scripts/off_screen_pointers.gd").new()
	off_screen_pointers.name = "OffScreenPointers"
	off_screen_pointers.main_node = self
	add_child(off_screen_pointers)

	ship_owner_by_slot.resize(MAX_SHIPS)
	ship_owner_by_slot.fill(-1)

	ui.setup_ui(
		_on_quit_pressed,
		_on_host_pressed,
		_on_join_pressed,
		_on_disconnect_pressed,
		_on_connect_pressed,
		_on_player_name_changed,
		_on_player_color_selected,
		queue_redraw,
		_on_host_confirmed
	)
	ui.player_name_input.text_submitted.connect(_on_player_name_submitted)
	ui.initialize_color_dropdown(PLAYER_COLORS)
	ui.team_confirm_dialog.confirmed.connect(_on_team_confirm_dialog_confirmed)

	slot_offer_dialog = ConfirmationDialog.new()
	slot_offer_dialog.title = "Ship Available"
	slot_offer_dialog.dialog_text = "A ship is available! Do you want to operate it?\nTime remaining: 10"
	slot_offer_dialog.ok_button_text = "Yes"
	slot_offer_dialog.cancel_button_text = "No"
	slot_offer_dialog.confirmed.connect(_on_slot_offer_accepted_locally)
	slot_offer_dialog.canceled.connect(_on_slot_offer_declined_locally)
	slot_offer_dialog.close_requested.connect(_on_slot_offer_declined_locally)
	ui.add_child(slot_offer_dialog)

	connection_controller.configure(
		multiplayer,
		ui.host_button,
		ui.join_button,
		ui.disconnect_button,
		ui.host_join_row,
		_set_status
	)

	ip_info.configure(self, _on_ip_info_updated)
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
	ui.host_popup.popup_centered()

func _on_host_confirmed() -> void:
	var settings = ui.get_host_settings()
	current_play_area_size = settings.play_area_size
	current_edge_wrapping = settings.edge_wrapping
	sync_game_settings(current_play_area_size, current_edge_wrapping)
	
	if not connection_controller.host(DEFAULT_PORT):
		return

	_reset_session_scores()
	_initialize_host_roster()
	_assign_peer_role(multiplayer.get_unique_id())
	_refresh_peer_list()
	queue_redraw()

func _on_join_pressed() -> void:
	ui.join_popup.popup_centered()

func _on_connect_pressed() -> void:
	ui.join_popup.hide()
	var ip: String = ui.join_ip_input.text.strip_edges()
	if ip.is_empty():
		_set_status(STATUS_NOT_CONNECTED)
		return

	_start_connect_sequence(ip)

func _on_connected_to_server() -> void:
	_stop_connect_sequence()
	connection_controller.set_connected_controls(true)
	_set_status(STATUS_CONNECTED_TO_HOST)
	_submit_local_identity()

func _on_connection_failed() -> void:
	if is_connecting:
		_handle_connect_attempt_failure()
		return

	_set_status(STATUS_FAILED_TO_CONNECT)
	_disconnect_local_peer(false)

func _on_server_disconnected() -> void:
	if is_connecting:
		_handle_connect_attempt_failure()
		return

	_set_status(STATUS_NOT_CONNECTED)
	_disconnect_local_peer(false)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	sync_game_settings.rpc_id(peer_id, current_play_area_size, current_edge_wrapping)
	peer_roster.ensure_peer_in_order(peer_id)
	_assign_peer_role(peer_id)
	_broadcast_peer_roster()
	_broadcast_team_roster()

@rpc("authority", "call_local", "reliable")
func sync_game_settings(play_area_size: int, edge_wrapping: bool) -> void:
	current_play_area_size = play_area_size
	current_edge_wrapping = edge_wrapping
	if play_area_size == 1:
		world_bounds = Rect2(Vector2.ZERO, BASE_RESOLUTION * 3.0)
	else:
		world_bounds = Rect2(Vector2.ZERO, BASE_RESOLUTION)
		
	if starfield != null:
		starfield.generate_stars(world_bounds, edge_wrapping)
		
	# Also update existing ships/projectiles bounds
	for ship in _get_all_ships():
		ship.world_bounds = world_bounds
		ship.edge_wrapping = edge_wrapping
	for proj in _get_all_projectiles():
		proj.world_bounds = world_bounds
		proj.edge_wrapping = edge_wrapping

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	peer_roster.remove_peer(peer_id)
	peer_identity_by_id.erase(peer_id)
	peer_score_by_id.erase(peer_id)
	observer_queue.erase(peer_id)
	damage_immunity_until_by_peer.erase(peer_id)

	_server_handle_peer_leave_team(peer_id)

	var slot_index: int = _get_slot_index_for_peer(peer_id)
	if slot_index != -1:
		_remove_ship_node(peer_id)
		ship_owner_by_slot[slot_index] = -1
		_promote_observer_to_slot(slot_index)

	_broadcast_peer_roster()

func _on_disconnect_pressed() -> void:
	_disconnect_local_peer(true)

func _disconnect_local_peer(update_status: bool) -> void:
	_stop_connect_sequence()
	connection_controller.disconnect_session(update_status)
	peer_roster.clear()
	peer_score_by_id.clear()
	turret_operator_by_pilot_id.clear()
	pilot_by_turret_operator_id.clear()
	_refresh_peer_list()
	_clear_session_state()
	local_fire_cooldown = 0.0

func _set_status(value: String) -> void:
	ui.status_label.text = "Connection Status: %s" % value

func _set_local_color_index(color_index: int) -> void:
	local_preferred_color_index = color_index
	ui.set_selected_color_index(color_index)

func _sync_local_color_from_roster() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var local_id: int = multiplayer.get_unique_id()
	var synced_color_index: int = peer_roster.get_peer_color_index(local_id)
	if synced_color_index == -1:
		return
	_set_local_color_index(synced_color_index)

func _resolve_color_for_peer(peer_id: int, preferred_color_index: int) -> int:
	return peer_roster.resolve_color_index(preferred_color_index, PLAYER_COLORS.size(), peer_id)

func _get_ship_color_for_peer(peer_id: int) -> Color:
	var color_index: int = peer_roster.get_peer_color_index(peer_id)
	if color_index < 0 or color_index >= PLAYER_COLORS.size():
		return Color.WHITE
	return PLAYER_COLORS[color_index]

func _initialize_host_roster() -> void:
	var host_id: int = multiplayer.get_unique_id()
	var resolved_color_index := _resolve_color_for_peer(host_id, local_preferred_color_index)
	_set_local_color_index(resolved_color_index)
	peer_roster.register_host(
		host_id,
		ip_info.local_internal_ip,
		ip_info.local_external_ip,
		local_player_name,
		resolved_color_index
	)
	_bind_peer_score(host_id)
	_broadcast_peer_roster()

func _broadcast_peer_roster() -> void:
	if not multiplayer.is_server():
		return

	var peer_ids: Array[int] = peer_roster.get_sync_peer_ids()
	sync_peer_roster.rpc(
		peer_ids,
		peer_roster.get_sync_internal_ips(),
		peer_roster.get_sync_external_ips(),
		peer_roster.get_sync_names(),
		peer_roster.get_sync_color_indices(),
		_get_sync_scores(peer_ids)
	)

@rpc("authority", "call_local", "reliable")
func sync_peer_roster(
	peer_ids: Array[int],
	internal_ips: Array[String],
	external_ips: Array[String],
	names: Array[String],
	color_indices: Array[int],
	scores: Array[int]
) -> void:
	peer_roster.apply_synced_roster(peer_ids, internal_ips, external_ips, names, color_indices)
	peer_score_by_id.clear()
	var score_total: int = mini(peer_ids.size(), scores.size())
	for index in range(score_total):
		peer_score_by_id[peer_ids[index]] = int(scores[index])
	_sync_local_color_from_roster()
	_refresh_peer_list()

func _refresh_peer_list() -> void:
	var peer_ids: Array[int] = peer_roster.get_sync_peer_ids()
	var internal_ips: Array[String] = peer_roster.get_sync_internal_ips()
	var external_ips: Array[String] = peer_roster.get_sync_external_ips()
	var names: Array[String] = peer_roster.get_sync_names()
	
	for child in ui.peer_list_container.get_children():
		child.queue_free()
	
	var total: int = mini(
		peer_ids.size(),
		mini(internal_ips.size(), mini(external_ips.size(), names.size()))
	)
	if total <= 0:
		return

	var local_id: int = multiplayer.get_unique_id()
	var list_font_size: int = ui.peer_list_font_size
	
	var index: int = 0
	while index < total:
		var peer_id: int = peer_ids[index]
		var display_value: String = names[index].strip_edges()
		if display_value.is_empty():
			display_value = "%s/%s" % [internal_ips[index], external_ips[index]]
		
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(80, 0)
		action_btn.add_theme_font_size_override("font_size", list_font_size)
		action_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		if peer_id == local_id:
			action_btn.visible = false
		else:
			if turret_operator_by_pilot_id.has(local_id):
				var my_op: int = turret_operator_by_pilot_id[local_id]
				if peer_id == my_op:
					action_btn.text = "Kick"
					action_btn.pressed.connect(func(): _prompt_team_action(peer_id, "kick"))
				else:
					action_btn.text = "Locked"
					action_btn.disabled = true
			elif pilot_by_turret_operator_id.has(local_id):
				var my_pilot: int = pilot_by_turret_operator_id[local_id]
				if peer_id == my_pilot:
					action_btn.text = "Leave"
					action_btn.pressed.connect(func(): _prompt_team_action(peer_id, "leave"))
				else:
					action_btn.text = "Locked"
					action_btn.disabled = true
			else:
				if turret_operator_by_pilot_id.has(peer_id) or pilot_by_turret_operator_id.has(peer_id):
					action_btn.text = "Locked"
					action_btn.disabled = true
				else:
					action_btn.text = "Join"
					action_btn.pressed.connect(func(): _prompt_team_action(peer_id, "join"))
		row.add_child(action_btn)

		var left_label := Label.new()
		left_label.text = display_value
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_label.size_flags_stretch_ratio = 4.0
		left_label.add_theme_font_size_override("font_size", list_font_size)
		left_label.clip_text = true

		var score_label := Label.new()
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		score_label.size_flags_stretch_ratio = 1.0
		score_label.add_theme_font_size_override("font_size", list_font_size)

		var text_color := Color.html("#%s" % DEFAULT_PEER_TEXT_COLOR)
		var color_index: int = peer_roster.get_peer_color_index(peer_id)
		if color_index >= 0 and color_index < PLAYER_COLORS.size():
			text_color = PLAYER_COLORS[color_index]
		
		var score_value: int = int(peer_score_by_id.get(peer_id, 0))
		score_label.text = str(score_value)

		left_label.add_theme_color_override("font_color", text_color)
		score_label.add_theme_color_override("font_color", text_color)
		if peer_id == local_id:
			left_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
			left_label.add_theme_constant_override("outline_size", 1)
			score_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
			score_label.add_theme_constant_override("outline_size", 1)

		row.add_child(left_label)
		row.add_child(score_label)
		ui.peer_list_container.add_child(row)
		index += 1
		
	if open_join_state and observer_queue.has(local_id):
		var empty_row := HBoxContainer.new()
		empty_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_row.add_theme_constant_override("separation", 8)
		
		var join_btn := Button.new()
		join_btn.custom_minimum_size = Vector2(80, 0)
		join_btn.add_theme_font_size_override("font_size", list_font_size)
		join_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		join_btn.text = "Join"
		join_btn.pressed.connect(_on_empty_slot_join_pressed)
		empty_row.add_child(join_btn)
		
		var empty_label := Label.new()
		empty_label.text = "[Empty Ship]"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.size_flags_stretch_ratio = 5.0
		empty_label.add_theme_font_size_override("font_size", list_font_size)
		empty_row.add_child(empty_label)
		
		ui.peer_list_container.add_child(empty_row)

func _on_empty_slot_join_pressed() -> void:
	request_take_empty_slot.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_take_empty_slot() -> void:
	if not multiplayer.is_server():
		return
	if not open_join_state:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if not observer_queue.has(sender_id):
		return
	
	var slot = _get_first_free_slot()
	if slot != -1:
		observer_queue.erase(sender_id)
		_spawn_ship_for_peer(sender_id, slot)
		
		if _get_first_free_slot() == -1:
			open_join_state = false
			set_open_join_state.rpc(false)

@rpc("authority", "call_local", "reliable")
func set_open_join_state(state: bool) -> void:
	open_join_state = state
	_refresh_peer_list()

func _prompt_team_action(peer_id: int, action: String) -> void:
	if action == "join":
		pending_team_join_request_pilot_id = peer_id
		pending_team_leave_request = false
		ui.team_confirm_dialog.dialog_text = "Are you sure you want to join this player's team?"
	elif action == "leave":
		pending_team_join_request_pilot_id = 0
		pending_team_leave_request = true
		ui.team_confirm_dialog.dialog_text = "Are you sure you want to leave the team?"
	elif action == "kick":
		pending_team_join_request_pilot_id = peer_id
		pending_team_leave_request = false
		ui.team_confirm_dialog.dialog_text = "Are you sure you want to kick this player from your team?"
	ui.team_confirm_dialog.popup_centered()

func _on_team_confirm_dialog_confirmed() -> void:
	if pending_team_leave_request:
		request_leave_team.rpc_id(1)
	elif pending_team_join_request_pilot_id != 0:
		var local_id := multiplayer.get_unique_id()
		if turret_operator_by_pilot_id.has(local_id):
			request_kick_teammate.rpc_id(1)
		else:
			request_join_team.rpc_id(1, pending_team_join_request_pilot_id)

	pending_team_join_request_pilot_id = 0
	pending_team_leave_request = false

@rpc("any_peer", "call_local", "reliable")
func request_join_team(pilot_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	if pilot_id <= 0 or turret_operator_by_pilot_id.has(pilot_id):
		return
	
	if turret_operator_by_pilot_id.has(sender_id) or pilot_by_turret_operator_id.has(sender_id):
		return
		
	turret_operator_by_pilot_id[pilot_id] = sender_id
	pilot_by_turret_operator_id[sender_id] = pilot_id
	
	# Remove operator's old ship and forfeit slot
	var operator_slot_index: int = _get_slot_index_for_peer(sender_id)
	if operator_slot_index != -1:
		_remove_ship_node(sender_id)
		ship_owner_by_slot[operator_slot_index] = -1
		_promote_observer_to_slot(operator_slot_index)
	elif observer_queue.has(sender_id):
		observer_queue.erase(sender_id)
		
	_update_local_status_for_peer(sender_id)
	
	# Update pilot's ship
	var pilot_ship := _get_ship_node(pilot_id)
	if pilot_ship != null:
		pilot_ship.turret_operator_id = sender_id
		pilot_ship.turret_visible = true
		pilot_ship.turret_color = _get_ship_color_for_peer(sender_id)
		_set_damage_immunity_for_peer(pilot_id)
		pilot_ship.is_immune = true
	
	_broadcast_team_roster()

@rpc("any_peer", "call_local", "reliable")
func request_leave_team() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	if pilot_by_turret_operator_id.has(sender_id):
		_server_handle_peer_leave_team(sender_id)
		_broadcast_team_roster()

@rpc("any_peer", "call_local", "reliable")
func request_kick_teammate() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	
	if turret_operator_by_pilot_id.has(sender_id):
		var operator_id: int = turret_operator_by_pilot_id[sender_id]
		_server_handle_peer_leave_team(operator_id)
		_broadcast_team_roster()

func _server_handle_peer_leave_team(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var pilot_id: int = 0
	var operator_id: int = 0
	
	if turret_operator_by_pilot_id.has(peer_id):
		pilot_id = peer_id
		operator_id = turret_operator_by_pilot_id[peer_id]
	elif pilot_by_turret_operator_id.has(peer_id):
		operator_id = peer_id
		pilot_id = pilot_by_turret_operator_id[peer_id]
	
	if pilot_id != 0 and operator_id != 0:
		turret_operator_by_pilot_id.erase(pilot_id)
		pilot_by_turret_operator_id.erase(operator_id)
		
		# Reset pilot's ship
		var pilot_ship := _get_ship_node(pilot_id)
		if pilot_ship != null:
			pilot_ship.turret_operator_id = 0
			pilot_ship.turret_visible = false
			_set_damage_immunity_for_peer(pilot_id)
			pilot_ship.is_immune = true
			
		# Respawn operator or make observer
		_assign_peer_role(operator_id)

func _broadcast_team_roster() -> void:
	if not multiplayer.is_server():
		return
	var pilots: Array[int] = []
	var operators: Array[int] = []
	
	for pilot in turret_operator_by_pilot_id:
		pilots.append(pilot)
		operators.append(turret_operator_by_pilot_id[pilot])
		
	sync_team_roster.rpc(pilots, operators)

@rpc("authority", "call_local", "reliable")
func sync_team_roster(pilots: Array[int], operators: Array[int]) -> void:
	turret_operator_by_pilot_id.clear()
	pilot_by_turret_operator_id.clear()
	
	for i in range(mini(pilots.size(), operators.size())):
		turret_operator_by_pilot_id[pilots[i]] = operators[i]
		pilot_by_turret_operator_id[operators[i]] = pilots[i]
		
	_refresh_peer_list()

func _submit_local_identity() -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		var host_id: int = multiplayer.get_unique_id()
		var resolved_color_index := _resolve_color_for_peer(host_id, local_preferred_color_index)
		_set_local_color_index(resolved_color_index)
		peer_roster.upsert_peer(
			host_id,
			ip_info.local_internal_ip,
			ip_info.local_external_ip,
			local_player_name,
			resolved_color_index
		)
		_bind_peer_score(host_id)
		peer_roster.ensure_peer_in_order(host_id)
		_update_ship_color(host_id)
		_broadcast_peer_roster()
	else:
		submit_peer_info.rpc_id(
			1,
			ip_info.local_internal_ip,
			ip_info.local_external_ip,
			local_player_name,
			local_preferred_color_index
		)

@rpc("any_peer", "reliable")
func submit_peer_info(
	internal_ip: String,
	external_ip: String,
	player_name: String,
	preferred_color_index: int
) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	var resolved_color_index := _resolve_color_for_peer(sender_id, preferred_color_index)
	peer_roster.upsert_peer(
		sender_id,
		internal_ip,
		external_ip,
		player_name,
		resolved_color_index
	)
	_bind_peer_score(sender_id)
	_update_ship_color(sender_id)
	_broadcast_peer_roster()

func _update_ship_color(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var ship := _get_ship_node(peer_id)
	if ship != null:
		ship.ship_color = _get_ship_color_for_peer(peer_id)
		
	if pilot_by_turret_operator_id.has(peer_id):
		var pilot_id: int = pilot_by_turret_operator_id[peer_id]
		var pilot_ship := _get_ship_node(pilot_id)
		if pilot_ship != null:
			pilot_ship.turret_color = _get_ship_color_for_peer(peer_id)

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
	ui.player_name_input.release_focus()

func _on_player_color_selected(selected_index: int) -> void:
	_set_local_color_index(selected_index)
	_submit_local_identity()
	_refresh_peer_list()
	ui.player_color_dropdown.release_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _process(delta: float) -> void:
	_update_connect_sequence(delta)
	
	if slot_offer_dialog != null and slot_offer_dialog.visible:
		slot_offer_local_timer -= delta
		if slot_offer_local_timer > 0.0:
			slot_offer_dialog.dialog_text = "A ship is available! Do you want to operate it?\nTime remaining: %d" % int(ceil(slot_offer_local_timer))
		else:
			slot_offer_dialog.hide()
			_on_slot_offer_declined_locally()

	# Update World transform to fit the play area
	if world_node != null:
		var play_rect := _get_play_render_rect()
		world_node.position = play_rect.position
		var scale_x := play_rect.size.x / BASE_RESOLUTION.x
		var scale_y := play_rect.size.y / BASE_RESOLUTION.y
		world_node.scale = Vector2(scale_x, scale_y)
		
		if current_play_area_size == 1: # Large
			world_node.size = BASE_RESOLUTION
			var target_pos := _get_camera_target_position()
			
			# Wrap the target position
			target_pos.x = wrapf(target_pos.x, 0.0, world_bounds.size.x)
			target_pos.y = wrapf(target_pos.y, 0.0, world_bounds.size.y)
			
			world_root.position = (BASE_RESOLUTION * 0.5) - target_pos
		else:
			world_node.size = world_bounds.size
			world_root.position = Vector2.ZERO

	if multiplayer.multiplayer_peer == null:
		return

	if local_fire_cooldown > 0.0:
		local_fire_cooldown = maxf(0.0, local_fire_cooldown - delta)
	
	_handle_local_input()

	if multiplayer.is_server():
		if offering_slot_to_peer != 0:
			offering_slot_timer -= delta
			if offering_slot_timer <= 0.0:
				var failed_peer = offering_slot_to_peer
				_server_handle_offer_declined(failed_peer)

		_server_rule_checks(delta)
		return

func _server_handle_offer_declined(peer_id: int) -> void:
	if offering_slot_to_peer == peer_id:
		if observer_queue.has(peer_id):
			observer_queue.erase(peer_id)
			observer_queue.append(peer_id)
		observers_who_declined_current_offer.append(peer_id)
		_offer_slot_to_next_observer()

func _handle_local_input() -> void:
	var local_id: int = multiplayer.get_unique_id()
	
	if _is_typing_name():
		return

	# Handle input for any ship we are piloting
	var local_ship := _get_ship_node(local_id)
	if local_ship != null:
		# Handle continuous ship fire
		if local_fire_cooldown <= 0.0 and Input.is_physical_key_pressed(KEY_SPACE):
			var interval := FIRE_INTERVAL_SECONDS
			if local_ship.turret_operator_id != 0:
				interval *= 2.0
			local_fire_cooldown = interval
			local_ship.request_fire.rpc_id(1)

		# Handle ship movement input
		var turn_left := Input.is_physical_key_pressed(KEY_A)
		var turn_right := Input.is_physical_key_pressed(KEY_D)
		var accelerate := Input.is_physical_key_pressed(KEY_W)
		var decelerate := Input.is_physical_key_pressed(KEY_S)
		
		local_ship.submit_input.rpc_id(1, turn_left, turn_right, accelerate, decelerate)

		if Input.is_physical_key_pressed(KEY_X):
			local_ship.request_full_stop.rpc_id(1)

	# Handle input for any ship we are operating a turret on
	var all_ships := _get_all_ships()
	for ship in all_ships:
		if ship.turret_operator_id == local_id:
			var t_left := Input.is_physical_key_pressed(KEY_A)
			var t_right := Input.is_physical_key_pressed(KEY_D)
			ship.submit_turret_input.rpc_id(1, t_left, t_right)
			
			if Input.is_physical_key_pressed(KEY_SPACE):
				ship.request_turret_fire.rpc_id(1)

func _server_rule_checks(_delta: float) -> void:
	var all_ships := _get_all_ships()
	var all_projectiles := _get_all_projectiles()

	# Update ship immunity status
	for ship in all_ships:
		var owner_id = ship.get_multiplayer_authority()
		ship.is_immune = _is_peer_damage_immune(owner_id)
		ship.acceleration_multiplier = IMMUNE_ACCELERATION_MULTIPLIER if ship.is_immune else 1.0

	# Projectile collision detection
	var score_changed := false
	for proj in all_projectiles:
		var hit_ship = _get_hit_ship(proj.position, proj.shooter_peer_id, all_ships)
		if hit_ship != null:
			var hit_peer_id = hit_ship.get_multiplayer_authority()
			var points_to_award = 2 if hit_ship.turret_operator_id != 0 else 1
			_reset_ship(hit_ship, hit_peer_id)
			score_changed = _award_point(proj.shooter_peer_id, points_to_award) or score_changed
			proj.queue_free()

	if score_changed:
		_broadcast_peer_roster()

func _get_hit_ship(projectile_position: Vector2, shooter_peer_id: int, ships: Array[Ship]) -> Ship:
	for ship in ships:
		var owner_id = ship.get_multiplayer_authority()
		if owner_id == -1 or owner_id == shooter_peer_id:
			continue
		if _is_peer_damage_immune(owner_id):
			continue
		
		# Fast broad-phase check (15 is max ship radius + 1.5 projectile radius)
		if ship.position.distance_to(projectile_position) <= 16.5:
			var local_pos = (projectile_position - ship.position).rotated(-ship.rotation)
			
			# Inside the main polygon body
			if Geometry2D.is_point_in_polygon(local_pos, ship.SHIP_POINTS):
				return ship
				
			# Check near edges (accounts for line thickness and projectile radius)
			var point_count = ship.SHIP_POINTS.size()
			for i in range(point_count):
				var p1 = ship.SHIP_POINTS[i]
				var p2 = ship.SHIP_POINTS[(i + 1) % point_count]
				var closest = Geometry2D.get_closest_point_to_segment(local_pos, p1, p2)
				if local_pos.distance_to(closest) <= 3.0:
					return ship
					
	return null

func _reset_ship(ship: Ship, peer_id: int) -> void:
	var slot_index = _get_slot_index_for_peer(peer_id)
	if slot_index != -1:
		_set_damage_immunity_for_peer(peer_id)
		ship.reset(_to_world_position(SHIP_START_NORMALIZED_POSITIONS[slot_index]))

func _get_all_ships() -> Array[Ship]:
	var ships: Array[Ship] = []
	for child in world_root.get_children():
		if child is Ship:
			ships.append(child)
	return ships

func _get_all_projectiles() -> Array[Projectile]:
	var projectiles: Array[Projectile] = []
	for child in world_root.get_children():
		if child is Projectile:
			projectiles.append(child)
	return projectiles

func _get_ship_node(peer_id: int) -> Ship:
	var expected_name := "Ship_%d" % peer_id
	for ship in _get_all_ships():
		if ship.name == expected_name:
			return ship
	return null

func _remove_ship_node(peer_id: int) -> void:
	var ship = _get_ship_node(peer_id)
	if ship != null:
		ship.queue_free()

func _start_connect_sequence(ip: String) -> void:
	_stop_connect_sequence()
	connect_target_ip = ip
	is_connecting = true
	connect_attempt_count = 0
	connect_retry_pending = false
	connect_retry_timer = 0.0
	connecting_dot_count = 0
	connecting_dot_timer = CONNECTING_DOT_STEP_SECONDS
	connection_controller.set_connected_controls(true)
	_set_status(STATUS_CONNECTING)
	_attempt_connect_to_host()

func _stop_connect_sequence() -> void:
	is_connecting = false
	connect_target_ip = ""
	connect_attempt_count = 0
	connect_retry_pending = false
	connect_retry_timer = 0.0
	connecting_dot_count = 0
	connecting_dot_timer = 0.0

func _attempt_connect_to_host() -> void:
	if not is_connecting:
		return
	if connect_target_ip.is_empty():
		_fail_connect_sequence()
		return

	connect_attempt_count += 1
	var connect_started: bool = connection_controller.join(connect_target_ip, DEFAULT_PORT)
	if connect_started:
		return

	_handle_connect_attempt_failure()

func _handle_connect_attempt_failure() -> void:
	if not is_connecting:
		return

	connection_controller.disconnect_session(false)
	if connect_attempt_count >= MAX_CONNECT_ATTEMPTS:
		_fail_connect_sequence()
		return

	connection_controller.set_connected_controls(true)
	connect_retry_pending = true
	connect_retry_timer = CONNECT_RETRY_DELAY_SECONDS

func _fail_connect_sequence() -> void:
	_stop_connect_sequence()
	connection_controller.set_connected_controls(false)
	_set_status(STATUS_FAILED_TO_CONNECT)

func _update_connect_sequence(delta: float) -> void:
	if not is_connecting:
		return

	connecting_dot_timer -= delta
	if connecting_dot_timer <= 0.0:
		connecting_dot_count = (connecting_dot_count % 5) + 1
		_set_status("%s%s" % [STATUS_CONNECTING, ".".repeat(connecting_dot_count)])
		connecting_dot_timer = CONNECTING_DOT_STEP_SECONDS

	if not connect_retry_pending:
		return

	connect_retry_timer -= delta
	if connect_retry_timer > 0.0:
		return

	connect_retry_pending = false
	_attempt_connect_to_host()

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.pressed:
			_release_name_focus_if_clicked_outside(mouse_event.position)

func _get_right_section_rect() -> Rect2:
	if ui.right_section == null:
		return get_viewport_rect()
	return ui.right_section.get_global_rect()

func _get_camera_target_position() -> Vector2:
	if multiplayer.multiplayer_peer == null:
		return world_bounds.size * 0.5
	var local_id := multiplayer.get_unique_id()
	
	# Check if pilot
	var local_ship := _get_ship_node(local_id)
	if local_ship != null:
		return local_ship.position
		
	# Check if operator
	if pilot_by_turret_operator_id.has(local_id):
		var pilot_id: int = pilot_by_turret_operator_id[local_id]
		var pilot_ship := _get_ship_node(pilot_id)
		if pilot_ship != null:
			return pilot_ship.position
			
	# Fallback to center of world
	return world_bounds.size * 0.5

func _get_play_render_rect() -> Rect2:
	var container: Rect2 = _get_right_section_rect()
	if container.size.x <= 0.0 or container.size.y <= 0.0:
		return container

	var world_aspect: float = BASE_RESOLUTION.x / BASE_RESOLUTION.y
	var container_aspect: float = container.size.x / container.size.y
	var fitted_size := container.size
	if container_aspect > world_aspect:
		fitted_size.x = container.size.y * world_aspect
	else:
		fitted_size.y = container.size.x / world_aspect

	var fitted_position := container.position + ((container.size - fitted_size) * 0.5)
	return Rect2(fitted_position, fitted_size)

func _clear_session_state() -> void:
	observer_queue.clear()
	damage_immunity_until_by_peer.clear()
	ship_owner_by_slot.fill(-1)
	for child in world_root.get_children():
		if child != starfield:
			child.queue_free()

func _assign_peer_role(peer_id: int) -> void:
	var slot_index: int = _get_first_free_slot()
	if slot_index == -1:
		observer_queue.append(peer_id)
		_update_local_status_for_peer(peer_id)
		return

	_spawn_ship_for_peer(peer_id, slot_index)

func _spawn_ship_for_peer(peer_id: int, slot_index: int) -> void:
	ship_owner_by_slot[slot_index] = peer_id
	_set_damage_immunity_for_peer(peer_id)
	
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = "Ship_%d" % peer_id
	world_root.add_child(ship, true)
	ship.set_multiplayer_authority(peer_id, false)
	ship.reset(_to_world_position(SHIP_START_NORMALIZED_POSITIONS[slot_index]))
	ship.ship_color = _get_ship_color_for_peer(peer_id)
	ship.world_bounds = world_bounds
	ship.edge_wrapping = current_edge_wrapping
	_update_local_status_for_peer(peer_id)

func _promote_observer_to_slot(_slot_index: int) -> void:
	if not multiplayer.is_server():
		return
	observers_who_declined_current_offer.clear()
	if open_join_state:
		open_join_state = false
		set_open_join_state.rpc(false)
	_offer_slot_to_next_observer()

func _offer_slot_to_next_observer() -> void:
	if not multiplayer.is_server():
		return
		
	if _get_first_free_slot() == -1:
		offering_slot_to_peer = 0
		offering_slot_timer = 0.0
		if open_join_state:
			open_join_state = false
			set_open_join_state.rpc(false)
		return
		
	var next_peer = 0
	for peer in observer_queue:
		if not observers_who_declined_current_offer.has(peer):
			next_peer = peer
			break
			
	if next_peer == 0:
		offering_slot_to_peer = 0
		offering_slot_timer = 0.0
		if not open_join_state:
			open_join_state = true
			set_open_join_state.rpc(true)
		return
		
	offering_slot_to_peer = next_peer
	offering_slot_timer = 10.0
	if open_join_state:
		open_join_state = false
		set_open_join_state.rpc(false)
	offer_slot.rpc_id(next_peer)

@rpc("authority", "call_local", "reliable")
func offer_slot() -> void:
	slot_offer_dialog.dialog_text = "A ship is available! Do you want to operate it?\nTime remaining: 10"
	slot_offer_dialog.popup_centered()
	slot_offer_local_timer = 10.0

func _on_slot_offer_accepted_locally() -> void:
	slot_offer_dialog.hide()
	accept_slot_offer.rpc_id(1)

func _on_slot_offer_declined_locally() -> void:
	slot_offer_dialog.hide()
	decline_slot_offer.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func accept_slot_offer() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if offering_slot_to_peer == sender_id:
		var slot = _get_first_free_slot()
		if slot != -1:
			observer_queue.erase(sender_id)
			_spawn_ship_for_peer(sender_id, slot)
			observers_who_declined_current_offer.clear()
			offering_slot_to_peer = 0
			offering_slot_timer = 0.0
			_offer_slot_to_next_observer()
			_broadcast_peer_roster()

@rpc("any_peer", "call_local", "reliable")
func decline_slot_offer() -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if offering_slot_to_peer == sender_id:
		_server_handle_offer_declined(sender_id)

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

func _update_local_status_for_peer(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_update_local_connection_status_from_roles()

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
	return ui.player_name_input.has_focus()

func _release_name_focus_if_clicked_outside(click_position: Vector2) -> void:
	if not ui.player_name_input.has_focus():
		return

	var name_rect: Rect2 = ui.player_name_input.get_global_rect()
	if name_rect.has_point(click_position):
		return
	ui.player_name_input.release_focus()

func _to_world_position(normalized_position: Vector2) -> Vector2:
	return world_bounds.position + Vector2(
		normalized_position.x * world_bounds.size.x,
		normalized_position.y * world_bounds.size.y
	)

func _set_damage_immunity_for_peer(peer_id: int) -> void:
	if peer_id == -1:
		return
	damage_immunity_until_by_peer[peer_id] = _get_server_time_seconds() + DAMAGE_IMMUNITY_SECONDS

func _is_peer_damage_immune(peer_id: int) -> bool:
	if peer_id == -1:
		return false
	var immunity_until: float = float(damage_immunity_until_by_peer.get(peer_id, 0.0))
	return _get_server_time_seconds() < immunity_until

func _get_server_time_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _reset_session_scores() -> void:
	score_by_identity.clear()
	peer_identity_by_id.clear()
	peer_score_by_id.clear()

func _bind_peer_score(peer_id: int) -> void:
	var identity_key: String = peer_roster.get_peer_identity_key(peer_id)
	if identity_key.is_empty():
		return
	peer_identity_by_id[peer_id] = identity_key
	if not score_by_identity.has(identity_key):
		score_by_identity[identity_key] = 0
	peer_score_by_id[peer_id] = int(score_by_identity[identity_key])

func _award_point(peer_id: int, points: int = 1) -> bool:
	if peer_id == -1:
		return false
	var identity_key: String = str(peer_identity_by_id.get(peer_id, ""))
	if identity_key.is_empty():
		_bind_peer_score(peer_id)
		identity_key = str(peer_identity_by_id.get(peer_id, ""))
	if identity_key.is_empty():
		return false
	var next_score: int = int(score_by_identity.get(identity_key, 0)) + points
	score_by_identity[identity_key] = next_score
	peer_score_by_id[peer_id] = next_score
	return true

func _get_sync_scores(peer_ids: Array[int]) -> Array[int]:
	var scores: Array[int] = []
	for peer_id in peer_ids:
		scores.append(int(peer_score_by_id.get(peer_id, 0)))
	return scores
