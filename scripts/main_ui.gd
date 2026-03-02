extends RefCounted
class_name MainUi

var status_label: Label
var local_ip_label: Label
var external_ip_label: Label
var player_name_input: LineEdit
var peer_list_label: RichTextLabel
var host_button: Button
var join_button: Button
var disconnect_button: Button
var host_join_row: HBoxContainer
var join_popup: Window
var join_ip_input: LineEdit
var right_section: ColorRect

func build(
	owner: Node,
	default_port: int,
	font_size_increase: int,
	quit_button_size: float,
	on_quit_pressed: Callable,
	on_host_pressed: Callable,
	on_join_pressed: Callable,
	on_disconnect_pressed: Callable,
	on_connect_pressed: Callable,
	on_name_changed: Callable,
	on_right_section_resized: Callable
) -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	owner.add_child(layer)

	var root_row := HBoxContainer.new()
	root_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_row)

	var quit_button := Button.new()
	quit_button.text = "X"
	_bump_font_size(quit_button, font_size_increase)
	_apply_button_padding(quit_button, 6.0, 4.0)
	quit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	quit_button.offset_left = 8
	quit_button.offset_top = 8
	quit_button.offset_right = 8 + quit_button_size
	quit_button.offset_bottom = 8 + quit_button_size
	quit_button.pressed.connect(on_quit_pressed)
	layer.add_child(quit_button)

	var left_section := ColorRect.new()
	left_section.color = Color(0.18, 0.18, 0.18, 1.0)
	left_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_section.size_flags_stretch_ratio = 1.0
	root_row.add_child(left_section)

	right_section = ColorRect.new()
	right_section.color = Color.BLACK
	right_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_section.size_flags_stretch_ratio = 4.0
	right_section.resized.connect(on_right_section_resized)
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

	var button_margin := MarginContainer.new()
	button_margin.add_theme_constant_override("margin_left", 6)
	button_margin.add_theme_constant_override("margin_right", 6)
	button_margin.add_theme_constant_override("margin_top", 6)
	button_margin.add_theme_constant_override("margin_bottom", 6)
	left_vbox.add_child(button_margin)

	var button_vbox := VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 8)
	button_margin.add_child(button_vbox)

	host_join_row = HBoxContainer.new()
	host_join_row.add_theme_constant_override("separation", 8)
	host_join_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_vbox.add_child(host_join_row)

	host_button = Button.new()
	host_button.text = "Host"
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bump_font_size(host_button, font_size_increase)
	_apply_button_padding(host_button, 8.0, 6.0)
	host_button.pressed.connect(on_host_pressed)
	host_join_row.add_child(host_button)

	join_button = Button.new()
	join_button.text = "Join"
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bump_font_size(join_button, font_size_increase)
	_apply_button_padding(join_button, 8.0, 6.0)
	join_button.pressed.connect(on_join_pressed)
	host_join_row.add_child(join_button)

	disconnect_button = Button.new()
	disconnect_button.text = "Disconnect"
	disconnect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bump_font_size(disconnect_button, font_size_increase)
	_apply_button_padding(disconnect_button, 8.0, 6.0)
	disconnect_button.visible = false
	disconnect_button.pressed.connect(on_disconnect_pressed)
	button_vbox.add_child(disconnect_button)

	status_label = Label.new()
	_bump_font_size(status_label, font_size_increase)
	left_vbox.add_child(status_label)

	var address_grid := GridContainer.new()
	address_grid.columns = 2
	address_grid.add_theme_constant_override("h_separation", 8)
	address_grid.add_theme_constant_override("v_separation", 6)
	left_vbox.add_child(address_grid)

	var local_ip_title := Label.new()
	local_ip_title.text = "Local IP:"
	_bump_font_size(local_ip_title, font_size_increase)
	address_grid.add_child(local_ip_title)

	local_ip_label = Label.new()
	_bump_font_size(local_ip_label, font_size_increase)
	address_grid.add_child(local_ip_label)

	var external_ip_title := Label.new()
	external_ip_title.text = "External IP:"
	_bump_font_size(external_ip_title, font_size_increase)
	address_grid.add_child(external_ip_title)

	external_ip_label = Label.new()
	_bump_font_size(external_ip_label, font_size_increase)
	address_grid.add_child(external_ip_label)

	var port_title := Label.new()
	port_title.text = "Port:"
	_bump_font_size(port_title, font_size_increase)
	address_grid.add_child(port_title)

	var port_value := Label.new()
	port_value.text = str(default_port)
	_bump_font_size(port_value, font_size_increase)
	address_grid.add_child(port_value)

	var name_title := Label.new()
	name_title.text = "Name:"
	_bump_font_size(name_title, font_size_increase)
	left_vbox.add_child(name_title)

	player_name_input = LineEdit.new()
	player_name_input.placeholder_text = "Enter name"
	player_name_input.max_length = 24
	player_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bump_font_size(player_name_input, font_size_increase)
	player_name_input.text_changed.connect(on_name_changed)
	left_vbox.add_child(player_name_input)

	var instructions_top_separator := HSeparator.new()
	left_vbox.add_child(instructions_top_separator)

	var instructions_heading_spacer := Control.new()
	instructions_heading_spacer.custom_minimum_size = Vector2(0, 10)
	left_vbox.add_child(instructions_heading_spacer)

	var instructions_heading := RichTextLabel.new()
	instructions_heading.bbcode_enabled = true
	instructions_heading.fit_content = true
	instructions_heading.scroll_active = false
	instructions_heading.selection_enabled = false
	instructions_heading.text = "[b]Instructions[/b]"
	instructions_heading.add_theme_font_size_override(
		"normal_font_size",
		instructions_heading.get_theme_font_size("normal_font_size") + font_size_increase
	)
	left_vbox.add_child(instructions_heading)

	var instructions := Label.new()
	instructions.text = "W - Increase Speed\nS - Decrease Speed\nA - Turn Counter-Clockwise\nD - Turn Clockwise\nX - Full Stop\nSpace - Fire Projectile"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bump_font_size(instructions, font_size_increase)
	left_vbox.add_child(instructions)

	var instructions_bottom_separator_spacer := Control.new()
	instructions_bottom_separator_spacer.custom_minimum_size = Vector2(0, 10)
	left_vbox.add_child(instructions_bottom_separator_spacer)

	var instructions_bottom_separator := HSeparator.new()
	left_vbox.add_child(instructions_bottom_separator)

	var players_heading_spacer := Control.new()
	players_heading_spacer.custom_minimum_size = Vector2(0, 10)
	left_vbox.add_child(players_heading_spacer)

	var players_heading := RichTextLabel.new()
	players_heading.bbcode_enabled = true
	players_heading.fit_content = true
	players_heading.scroll_active = false
	players_heading.selection_enabled = false
	players_heading.text = "[b]Players[/b]"
	players_heading.add_theme_font_size_override(
		"normal_font_size",
		players_heading.get_theme_font_size("normal_font_size") + font_size_increase
	)
	left_vbox.add_child(players_heading)

	peer_list_label = RichTextLabel.new()
	peer_list_label.bbcode_enabled = true
	peer_list_label.fit_content = true
	peer_list_label.scroll_active = false
	peer_list_label.selection_enabled = false
	peer_list_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	peer_list_label.add_theme_font_size_override(
		"normal_font_size",
		peer_list_label.get_theme_font_size("normal_font_size") + font_size_increase
	)
	left_vbox.add_child(peer_list_label)

	_build_join_popup(owner, on_connect_pressed, font_size_increase)

func _build_join_popup(owner: Node, on_connect_pressed: Callable, font_size_increase: int) -> void:
	join_popup = Window.new()
	join_popup.title = "Connect to Host"
	join_popup.size = Vector2i(340, 120)
	join_popup.unresizable = true
	join_popup.visible = false
	owner.add_child(join_popup)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_vbox.add_theme_constant_override("separation", 8)
	join_popup.add_child(popup_vbox)

	join_ip_input = LineEdit.new()
	join_ip_input.placeholder_text = "Host IP"
	join_ip_input.text = "127.0.0.1"
	_bump_font_size(join_ip_input, font_size_increase)
	popup_vbox.add_child(join_ip_input)

	var connect_button := Button.new()
	connect_button.text = "Connect"
	_bump_font_size(connect_button, font_size_increase)
	connect_button.pressed.connect(on_connect_pressed)
	popup_vbox.add_child(connect_button)

func _bump_font_size(control: Control, increase: int) -> void:
	var current_size: int = control.get_theme_font_size("font_size")
	control.add_theme_font_size_override("font_size", current_size + increase)

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
