extends CanvasLayer
class_name MainUi

@onready var status_label: Label = %StatusLabel
@onready var local_ip_label: Label = %LocalIpLabel
@onready var external_ip_label: Label = %ExternalIpLabel
@onready var player_name_input: LineEdit = %PlayerNameInput
@onready var player_color_dropdown: OptionButton = %PlayerColorDropdown
@onready var peer_list_container: VBoxContainer = %PeerListContainer
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var host_join_row: HBoxContainer = %HostJoinRow
@onready var join_popup: Window = %JoinPopup
@onready var host_popup: ConfirmationDialog = %HostPopup
@onready var play_area_size_option: OptionButton = %PlayAreaSizeOption
@onready var edge_wrap_check: CheckButton = %EdgeWrapCheck
@onready var join_ip_input: LineEdit = %JoinIpInput
@onready var right_section: ColorRect = %RightSection
@onready var quit_button: Button = %QuitButton
@onready var connect_button: Button = %ConnectButton
@onready var team_confirm_dialog: ConfirmationDialog = %TeamConfirmDialog

var peer_list_font_size := 16
var _color_option_icons: Array = []

func _ready() -> void:
	# Initial UI state setup if needed
	_color_option_icons.clear()
	# The actual color setup will be handled by main.gd or via an initialization method
	
	# Initial signal connections for UI-internal logic if any
	join_popup.close_requested.connect(join_popup.hide)
	host_popup.close_requested.connect(host_popup.hide)

func setup_ui(
	on_quit_pressed: Callable,
	on_host_pressed: Callable,
	on_join_pressed: Callable,
	on_disconnect_pressed: Callable,
	on_connect_pressed: Callable,
	on_name_changed: Callable,
	on_color_selected: Callable,
	on_right_section_resized: Callable,
	on_host_confirmed: Callable,
	on_name_submitted: Callable
) -> void:
	quit_button.pressed.connect(on_quit_pressed)
	host_button.pressed.connect(on_host_pressed)
	join_button.pressed.connect(on_join_pressed)
	disconnect_button.pressed.connect(on_disconnect_pressed)
	connect_button.pressed.connect(on_connect_pressed)
	host_popup.confirmed.connect(on_host_confirmed)
	player_name_input.text_changed.connect(on_name_changed)
	player_name_input.text_submitted.connect(on_name_submitted)
	player_name_input.focus_exited.connect(func(): on_name_submitted.call(player_name_input.text))
	player_color_dropdown.item_selected.connect(on_color_selected)
	right_section.resized.connect(on_right_section_resized)

func get_host_settings() -> Dictionary:
	return {
		"play_area_size": play_area_size_option.selected,
		"edge_wrapping": edge_wrap_check.button_pressed
	}

func initialize_color_dropdown(ship_colors: Array) -> void:
	player_color_dropdown.clear()
	_color_option_icons.clear()
	for color in ship_colors:
		var swatch_icon := _build_color_swatch_icon(color, 80, 18)
		_color_option_icons.append(swatch_icon)
		player_color_dropdown.add_icon_item(swatch_icon, " ")
	
	var popup := player_color_dropdown.get_popup()
	for item_index in range(popup.get_item_count()):
		popup.set_item_as_checkable(item_index, false)
	player_color_dropdown.select(-1)

func set_selected_color_index(color_index: int) -> void:
	if player_color_dropdown == null:
		return
	if color_index >= 0 and color_index < player_color_dropdown.get_item_count():
		player_color_dropdown.select(color_index)
		return
	player_color_dropdown.select(-1)

func _build_color_swatch_icon(color: Color, width: int, height: int) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
