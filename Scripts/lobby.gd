extends CanvasLayer
## Lobby: shows the room key and who has joined (up to 8). The host starts the game.
## Home / Back ask before leaving the room.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const TRANSITION_SCENE = preload("res://Scenes/transition.tscn")
const TITLE_SCENE := "res://Scenes/main.tscn"
const ROW_HEIGHT := 56
const SETTINGS_POPUP = preload("res://Scripts/lobby_settings_popup.gd")

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
	for entry in list:
		var row := Label.new()
		row.custom_minimum_size.y = ROW_HEIGHT
		row.add_theme_color_override("font_color", Color.BLACK)
		row.add_theme_font_size_override("font_size", 24)
		var text: String = entry["name"]
		if entry["is_host"]:
			text += "  (host)"
		if entry["is_me"]:
			text += "  - you"
		row.text = text
		player_list.add_child(row)

	if Network.is_host():
		var enough := list.size() >= Network.MIN_PLAYERS_TO_START
		start_btn.disabled = not enough
		status.text = "Press Start Game when everyone is in." if enough else "Waiting for players..."
	elif list.is_empty():
		status.text = "Connecting to the host..."
	else:
		status.text = "Waiting for the host to start the game..."

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
