extends CanvasLayer
## Lobby: shows the room key and who has joined (up to 8). The host starts the game.
## Home / Back ask before leaving the room.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const TRANSITION_SCENE = preload("res://Scenes/transition.tscn")
const TITLE_SCENE := "res://Scenes/main.tscn"
const ROW_HEIGHT := 56
const SETTINGS_POPUP = preload("res://Scripts/lobby_settings_popup.gd")
const Avatar = preload("res://Scripts/avatar.gd")
const AVATAR_EDITOR = preload("res://Scripts/avatar_editor.gd")
const ICON_SIZE := 120
const CARD_WIDTH := 130

@onready var ui_menu_frame: Control = $"UI Menu Frame"
@onready var room_key: Button = $Content/room_key
@onready var players_title: Label = $Content/Players/Margin/VBox/players_title
@onready var player_list: VBoxContainer = $Content/Players/Margin/VBox/player_list
@onready var status: Label = $Content/status
@onready var start_btn: Button = $Content/start_btn

var _leaving := false
var _last_count := 0
var _settings_label: Label


func _ready() -> void:
	ui_menu_frame.clear_ui()
	ui_menu_frame.checking_bal.text = "Lobby"
	ui_menu_frame.custom_navigation = true
	ui_menu_frame.home_pressed.connect(_confirm_leave)
	ui_menu_frame.back_pressed.connect(_confirm_leave)

	Network.players_changed.connect(_refresh)
	Network.session_ended.connect(_on_session_ended)
	Network.game_starting.connect(_on_game_starting)

	room_key.text = Network.room_key
	start_btn.visible = Network.is_host()
	_add_settings_row()
	Network.settings_changed.connect(_show_settings)
	_refresh()

# "Start $20 · 4 properties · Goal $200" for everyone, plus a Game Settings button for the host.
func _add_settings_row() -> void:
	_settings_label = Label.new()
	_settings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settings_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	_settings_label.add_theme_font_size_override("font_size", 26)
	status.add_sibling(_settings_label)
	if Network.is_host():
		var button := Button.new()
		button.text = "Game Settings"
		button.custom_minimum_size.y = 70
		button.add_theme_font_size_override("font_size", 32)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.32549, 0.235294, 0.266667)
		style.set_corner_radius_all(30)
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(func(): get_tree().root.add_child(SETTINGS_POPUP.new()))
		_settings_label.add_sibling(button)
	_show_settings()

func _show_settings() -> void:
	var s: Dictionary = Network.game_settings
	#_settings_label.text = "Starting cash $%d  -  %d starting properties  -  End goal $%d" \
			#% [s["start_cash"], s["start_properties"], s["end_goal"]]

func _refresh() -> void:
	var list := Network.ordered_players()
	if list.size() > _last_count and _last_count > 0:
		Sound.play("notify")   # someone joined
	_last_count = list.size()
	players_title.text = "Players %d/%d" % [list.size(), Network.MAX_PLAYERS]

	for child in player_list.get_children():
		child.queue_free()
	player_list.add_child(_player_grid(list))
	var hint := Label.new()
	hint.text = "Tap your character to change it"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.7))
	hint.add_theme_font_size_override("font_size", 18)
	player_list.add_child(hint)

	if Network.is_host():
		var enough := list.size() >= Network.MIN_PLAYERS_TO_START
		start_btn.disabled = not enough
		status.text = "Press Start Game when everyone is in." if enough else "Waiting for players..."
	elif list.is_empty():
		status.text = "Connecting to the host..."
	else:
		status.text = "Waiting for the host to start the game..."

# Everyone as a card in a centred grid, 4 to a row:
#     [character]
#        Name
#     host · you
const COLUMNS := 4

func _player_grid(list: Array) -> Control:
	var rows := VBoxContainer.new()   # each row centred, so a short last row sits in the middle
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 18)
	var row: HBoxContainer
	for i in list.size():
		if i % COLUMNS == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			rows.add_child(row)
		row.add_child(_player_card(list[i]))
	return rows

func _player_card(entry: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = CARD_WIDTH
	card.add_theme_constant_override("separation", 4)
	var holder := CenterContainer.new()
	holder.add_child(Avatar.for_player(entry["name"], ICON_SIZE))
	card.add_child(holder)
	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.BLACK)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(name_label)
	var tags := []
	if entry["is_host"]:
		tags.append("host")
	if entry["is_me"]:
		tags.append("you")
	var tag_label := Label.new()   # always there, so every card is the same height
	tag_label.text = "  ·  ".join(PackedStringArray(tags))
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 0.75))
	tag_label.add_theme_font_size_override("font_size", 17)
	card.add_child(tag_label)
	if entry["is_me"]:   # your own card: tap it to open the character maker
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_edit_character())
	return card

func _edit_character() -> void:
	if _leaving or get_tree().root.find_children("*", "", false, false).any(func(n): return n.get_script() == AVATAR_EDITOR):
		return
	get_tree().root.add_child(AVATAR_EDITOR.new())

func _on_room_key_pressed() -> void:
	DisplayServer.clipboard_set(Network.room_key)
	Global.banner("Room key %s copied." % Network.room_key)

func _on_start_btn_pressed() -> void:
	Sound.play("continue")
	start_btn.disabled = true
	Network.start_game()

func _on_game_starting() -> void:
	_leaving = true
	var transition = TRANSITION_SCENE.instantiate()
	add_child(transition)
	transition.run_animation(Global.intro.app_color, Global.intro.app_anim, Global.intro.app_url)


## ---- LEAVING ----
func _confirm_leave() -> void:
	if _leaving:
		return
	var question := "Close the room for everyone?" if Network.is_host() else "Leave this lobby?"
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout(question, "Yes", "No")
	popup.left_pressed.connect(_leave)

func _leave() -> void:
	_leaving = true
	Network.leave()
	get_tree().change_scene_to_file(TITLE_SCENE)

func _on_session_ended(message: String) -> void:
	if _leaving:
		return
	_leaving = true
	await Global.show_notice(message)
	get_tree().change_scene_to_file(TITLE_SCENE)
