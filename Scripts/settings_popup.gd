extends CanvasLayer
## Settings pop-up, opened from the settings button in the UI frame.
## Change your name, turn sounds on/off, and leave the lobby / game.

const PAPER = preload("res://Assets/icons/pop_up.png")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const TITLE_SCENE := "res://Scenes/main.tscn"
const INK := Color(0.1, 0.1, 0.1)

var _name_field: LineEdit
var _sound_toggle: CheckButton
var _theme_button: Button


func _ready() -> void:
	layer = 60   # above screens and transitions, below the Fortuna card (100)
	Sound.play("open")
	_build()

func _build() -> void:
	var dim := ColorRect.new()   # blocks taps on the screen behind
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var paper := TextureRect.new()
	paper.texture = PAPER
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.offset_left = -280
	paper.offset_right = 270
	paper.offset_top = -576
	paper.offset_bottom = 424
	dim.add_child(paper)

	var box := VBoxContainer.new()   # same writing area as pop_up.tscn
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -179
	box.offset_right = 221
	box.offset_top = -230
	box.offset_bottom = 290
	box.add_theme_constant_override("separation", 10)
	paper.add_child(box)

	box.add_child(_label("Settings", 70))

	# --- Room key (tap to copy) ---
	if Network.is_online():
		var key_button := _button("Room key: %s" % Network.room_key, _copy_room_key, false)
		key_button.add_theme_font_size_override("font_size", 40)
		box.add_child(key_button)

	# --- Player name ---
	box.add_child(_label("Player name", 40))
	var name_row := HBoxContainer.new()
	_name_field = LineEdit.new()
	_name_field.text = Global.PLAYER if Network.in_game else Network.my_name
	_name_field.placeholder_text = "Your name"
	_name_field.max_length = Network.MAX_NAME_LENGTH
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_ink(_name_field, 40)
	for style in ["normal", "focus"]:
		_name_field.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_name_field.draw.connect(func(): _name_field.draw_line(
			Vector2(0, _name_field.size.y - 4), Vector2(_name_field.size.x, _name_field.size.y - 4), Color(INK, 0.6), 3))
	_name_field.text_submitted.connect(func(_t): _save_name())
	name_row.add_theme_constant_override("separation", 16)
	name_row.add_child(_name_field)
	var save := _button("Save", _save_name)
	save.custom_minimum_size.x = 120
	name_row.add_child(save)
	box.add_child(name_row)

	# --- Sound ---
	_sound_toggle = CheckButton.new()
	_sound_toggle.text = "Sounds"
	_sound_toggle.button_pressed = Sound.enabled
	_style_ink(_sound_toggle, 48)
	_sound_toggle.toggled.connect(_on_sound_toggled)
	box.add_child(_sound_toggle)

	# --- Theme (tap to try the next one) ---
	_theme_button = _button(_theme_text(), _next_theme)
	_theme_button.add_theme_font_size_override("font_size", 42)
	box.add_child(_theme_button)

	# --- Leave ---
	var leave_text := _leave_text()
	if leave_text != "":
		box.add_child(_spacer(10))
		box.add_child(_button(leave_text, _confirm_leave))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_button("Close", _close))

func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_ink(label, size)
	return label

# boxed: drawn inside a pencil box like the pop-up buttons (Save, Leave, Close).
func _button(text: String, action: Callable, boxed: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	_style_ink(button, 48)
	if boxed:
		InkBox.apply(button, INK)
	else:
		button.add_theme_color_override("font_hover_color", Color("b76051"))
		button.add_theme_color_override("font_pressed_color", Color("96514b"))
	button.pressed.connect(action)
	return button

func _style_ink(control: Control, size: int) -> void:
	control.add_theme_font_override("font", FONT)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
	control.add_theme_color_override("caret_color", INK)
	control.add_theme_color_override("font_pressed_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.add_theme_color_override("font_hover_pressed_color", INK)
	control.add_theme_color_override("font_focus_color", INK)


## ---- ACTIONS ----
func _save_name() -> void:
	if _name_field.text.strip_edges() == "":
		Global.error("Please enter a name.")
		return
	Network.rename(_name_field.text)
	_name_field.text = Network.my_name
	Sound.play("saved")
	Global.banner("Name saved.")

func _copy_room_key() -> void:
	DisplayServer.clipboard_set(Network.room_key)
	Sound.play("switch")
	Global.banner("Room key %s copied." % Network.room_key)

func _theme_text() -> String:
	return "Theme: %s" % ColorTheme.theme_name()

func _next_theme() -> void:
	Sound.play("switch")
	ColorTheme.set_theme(ColorTheme.next_theme())
	_theme_button.text = _theme_text()

func _on_sound_toggled(on: bool) -> void:
	Sound.set_enabled(on)
	Sound.play("switch")   # silent when turning off

# What "leaving" means depends on where you are.
func _leave_text() -> String:
	if Network.in_game:
		return "Leave Game" if Network.is_online() else "Quit to Title"
	if Network.is_online():
		return "Leave Lobby"
	if OS.has_feature("web"):
		return ""   # a browser tab can't quit itself
	return "Quit Game"

func _confirm_leave() -> void:
	var question := "Are you sure?"
	if Network.is_host():
		question = "Leave? This ends the game for everyone."
	elif Network.is_online():
		question = "Leave this game?"
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.bring_to_front(layer + 10)   # pop-ups normally sit under this one
	popup.layout(question, "Yes", "No")
	popup.left_pressed.connect(_leave)

func _leave() -> void:
	var on_title := not Network.in_game and not Network.is_online()
	Turns.reset()
	Network.leave()
	if on_title:
		get_tree().quit()
		return
	get_tree().change_scene_to_file(TITLE_SCENE)
	queue_free()

func _close() -> void:
	Sound.play("back")
	queue_free()
