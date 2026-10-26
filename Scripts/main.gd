extends Node2D
## Title screen: host a room, join one with a key, or resume.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const MenuArtTheme = preload("res://Scripts/menu_art_theme.gd")
const HowToPlay = preload("res://Scripts/how_to_play.gd")
const LOBBY_SCENE := "res://Scenes/lobby.tscn"

@onready var resume_game: Button = $"CanvasLayer/Options Panel/resume_game"
@onready var join_game: Button = $"CanvasLayer/Options Panel/join_game"
@onready var host_game: Button = $"CanvasLayer/Options Panel/host_game"
@onready var ui_menu_frame: Control = $"CanvasLayer/UI Menu Frame"

var _waiting_popup: Node = null

# The coffee steam redraws the whole screen 20 times a second. Left on the title screen,
# that keeps the phone working for nothing, so it rests after a while and wakes on a tap.
const STEAM_REST_AFTER := 20.0
@onready var _steam: AnimatedSprite2D = $"CanvasLayer/Options Panel/coffee_mug/AnimatedSprite2D"
var _idle_time := 0.0


func _ready() -> void:
	ui_menu_frame.clear_ui()
	ui_menu_frame.show_title("Ad Valorem Pocket Edition", "Main Menu")
	_theme_art()
	ColorTheme.theme_changed.connect(func(_key): _theme_art())
	_add_how_to_play()
	Network.room_ready.connect(_on_room_ready)
	Network.connection_failed.connect(_on_connection_failed)
	Network.resumed.connect(_on_resumed)


func _process(delta: float) -> void:
	if _steam.is_playing():
		_idle_time += delta
		if _idle_time >= STEAM_REST_AFTER:
			_steam.pause()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_idle_time = 0.0
		if not _steam.is_playing():
			_steam.play()


## ---- THE DESK ----
# The wall, desk, cork board, notes, pencil cup and mug follow the colour theme. (The
# writing on the notes follows it too: dark themes get dark notes and light writing.)
func _theme_art() -> void:
	var options := $"CanvasLayer/Options Panel"
	MenuArtTheme.apply($CanvasLayer/NinePatchRect, "background")
	MenuArtTheme.apply(options.get_node("TextureRect"), "pin_board")
	MenuArtTheme.apply(options.get_node("TextureRect2"), "paper")
	MenuArtTheme.apply(options.get_node("TextureRect3"), "pencil_holder")
	MenuArtTheme.apply(_steam, "coffee_mug")

# The "How to Play" notepad: an invisible button over the pad (where it sits in paper.png).
var _how_to_play: Node = null
const PAD_AREA := Rect2(12.0 / 1080.0, 783.0 / 1920.0, 1040.0 / 1080.0, 628.0 / 1920.0)
func _add_how_to_play() -> void:
	var paper: Control = $"CanvasLayer/Options Panel/TextureRect2"
	var pad := Button.new()
	pad.flat = true
	pad.focus_mode = Control.FOCUS_NONE
	pad.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pad.anchor_left = PAD_AREA.position.x
	pad.anchor_top = PAD_AREA.position.y
	pad.anchor_right = PAD_AREA.end.x
	pad.anchor_bottom = PAD_AREA.end.y
	pad.offset_left = 0
	pad.offset_top = 0
	pad.offset_right = 0
	pad.offset_bottom = 0
	for style in ["normal", "hover", "pressed", "focus"]:
		pad.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	pad.pressed.connect(func():
		if is_instance_valid(_how_to_play):
			return
		var bounce := paper.create_tween()   # the pad hops as it's picked up
		bounce.tween_property(paper, "position:y", paper.position.y - 12, 0.08)
		bounce.tween_property(paper, "position:y", paper.position.y, 0.12)
		_how_to_play = HowToPlay.open(get_tree(), pad))
	paper.add_child(pad)


## ---- HOST ----
func _on_host_game_pressed() -> void:
	Sound.play("click")
	var popup = _new_popup("Start a server for a new game?", "Start Server", "Back")
	var name_field: LineEdit = popup.add_field("Your name", Network.MAX_NAME_LENGTH)
	name_field.text = Network.my_name
	popup.validate_left = func(): return _name_problem(name_field.text)
	popup.left_pressed.connect(func():
		_show_waiting("Starting server...")
		Network.host_game(name_field.text))


## ---- JOIN ----
func _on_join_game_pressed() -> void:
	Sound.play("click")
	var popup = _new_popup("Join a game", "Join", "Back")
	var name_field: LineEdit = popup.add_field("Your name", Network.MAX_NAME_LENGTH)
	var key_field: LineEdit = popup.add_field("Room key  e.g. SJ4-GT7", 7, true)
	name_field.text = Network.my_name
	popup.validate_left = func():
		var problem := _name_problem(name_field.text)
		if problem == "" and not Network.is_valid_key(key_field.text):
			problem = "Room keys look like SJ4-GT7."
		return problem
	popup.left_pressed.connect(func():
		_show_waiting("Joining room...")
		Network.join_game(name_field.text, key_field.text))

## ---- RESUME ----
# Rejoin the game this phone was in (after a refresh or lost connection).
func _on_resume_game_pressed() -> void:
	Sound.play("click")
	var snapshot := SaveGame.load_snapshot()
	if snapshot.is_empty():
		Sound.play("error")
		_new_popup("There's no game to resume.", "OK", "")
		return
	var popup = _new_popup("Resume your game in room %s as %s?" % [snapshot["room_key"], snapshot["name"]], "Resume", "Back")
	popup.left_pressed.connect(func():
		_show_waiting("Rejoining game...")
		Network.resume_game())

func _on_resumed() -> void:
	_close_waiting()


## ---- CONNECTION RESULTS ----
func _on_room_ready(_key: String) -> void:
	_close_waiting()
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_connection_failed(message: String) -> void:
	_close_waiting()
	Sound.play("error")
	var popup = _new_popup(message, "OK", "")
	popup.left_pressed.connect(func(): pass)


## ---- HELPERS ----
func _new_popup(text: String, left: String, right: String) -> Node:
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout(text, left, right)
	return popup

func _name_problem(raw: String) -> String:
	return "Please enter your name." if raw.strip_edges() == "" else ""

# "Connecting" pop-up whose button cancels the attempt.
func _show_waiting(text: String) -> void:
	_waiting_popup = _new_popup(text, "Cancel", "")
	_waiting_popup.add_note("The server may take a moment to wake up.")
	_waiting_popup.animate_dots()
	_waiting_popup.left_sound = "back"
	_waiting_popup.left_pressed.connect(func():
		_waiting_popup = null
		Network.leave())

func _close_waiting() -> void:
	if is_instance_valid(_waiting_popup):
		_waiting_popup.queue_free()
	_waiting_popup = null
