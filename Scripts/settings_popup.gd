extends CanvasLayer
## Settings pop-up, opened from the settings button in the UI frame.
## Change your name, turn sounds on/off, and leave the lobby / game.

const PAPER = preload("res://Assets/icons/pop_up.png")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const TITLE_SCENE := "res://Scenes/main.tscn"
const INK := Color(0.1, 0.1, 0.1)

var _name_field: LineEdit
var _sound_toggle: InkSwitch
var _theme_button: Button
var _timer_toggle: InkSwitch


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
	box.offset_left = -175   # centred on the paper, with a margin each side
	box.offset_right = 175
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

	# --- Sound: a label and a big switch on one line ---
	var sound_row := HBoxContainer.new()
	var sound_label := _label("Sounds", 48)
	sound_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sound_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_row.add_child(sound_label)
	_sound_toggle = InkSwitch.new()
	_sound_toggle.button_pressed = Sound.enabled
	_sound_toggle.toggled.connect(_on_sound_toggled)
	sound_row.add_child(_sound_toggle)
	box.add_child(sound_row)

	# --- Last-player timer (in a game; only the host can change it) ---
	if Network.in_game and Network.is_online():
		var timer_row := HBoxContainer.new()
		var timer_label := _label("Last-Turn Timer", 40)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		timer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		timer_row.add_child(timer_label)
		_timer_toggle = InkSwitch.new()
		_timer_toggle.button_pressed = Network.game_settings.get("turn_timer", true)
		if Network.is_host():
			_timer_toggle.toggled.connect(_on_timer_toggled)
		else:
			_timer_toggle.disabled = true
			_timer_toggle.modulate.a = 0.5
		timer_row.add_child(_timer_toggle)
		box.add_child(timer_row)
		var note := _label("30 seconds for the last player each round." if Network.is_host() else "Only the host can change this.", 26)
		note.modulate.a = 0.7
		box.add_child(note)
		box.offset_top -= 80   # two more lines: start higher so Close stays on the paper

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
	var report := _button("Report a Bug", _report_bug, false)
	report.add_theme_font_size_override("font_size", 34)
	box.add_child(report)
	box.offset_top -= 50   # room for the extra line
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

# Host: switch the last-player countdown on or off for everyone, right now.
func _on_timer_toggled(on: bool) -> void:
	Sound.play("switch")
	var settings: Dictionary = Network.game_settings.duplicate()
	settings["turn_timer"] = on
	Network.set_game_settings(settings)
	Turns.timer_setting_changed()
	Global.banner("Last-turn timer %s." % ("on" if on else "off"))

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

## ---- BUG REPORT ----
# Opens the bug report form in a new browser tab. The game version and the screen the
# player was on are filled in for them.
const BUG_REPORT_URL := "https://furthew.com/bug-report/"

func _report_bug() -> void:
	Sound.play("click")
	var screen := "title"
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		screen = scene.scene_file_path.get_file().get_basename()
	var url := "%s?v=%s&screen=%s" % [BUG_REPORT_URL, Network.APP_VERSION.uri_encode(), screen.uri_encode()]
	if Network.in_game:
		url += "&round=%d&expansion=%s" % [Global.ROUND, "1" if Network.expansion_on() else "0"]
	if OS.has_feature("web"):
		# A new tab, so the game keeps running here. If the browser blocks it, show the link.
		var window := JavaScriptBridge.get_interface("window")
		var tab = window.open(url, "_blank") if window else null
		if tab == null:
			Global.show_notice("Your browser blocked the new tab. To report a bug, visit:\n\nfurthew.com/bug-report")
	else:
		OS.shell_open(url)

func _close() -> void:
	Sound.play("back")
	queue_free()
