extends Node2D
## Title screen: host a room, join one with a key, or resume.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const LOBBY_SCENE := "res://Scenes/lobby.tscn"

@onready var resume_game: Button = $"CanvasLayer/Options Panel/resume_game"
@onready var join_game: Button = $"CanvasLayer/Options Panel/join_game"
@onready var host_game: Button = $"CanvasLayer/Options Panel/host_game"
@onready var ui_menu_frame: Control = $"CanvasLayer/UI Menu Frame"

var _waiting_popup: Node = null


func _ready() -> void:
	ui_menu_frame.clear_ui()
	ui_menu_frame.show_title("Ad Valorem Pocket Edition", "Main Menu")
	Network.room_ready.connect(_on_room_ready)
	Network.connection_failed.connect(_on_connection_failed)
	Network.resumed.connect(_on_resumed)


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
	_waiting_popup.left_sound = "back"
	_waiting_popup.left_pressed.connect(func():
		_waiting_popup = null
		Network.leave())

func _close_waiting() -> void:
	if is_instance_valid(_waiting_popup):
		_waiting_popup.queue_free()
	_waiting_popup = null
