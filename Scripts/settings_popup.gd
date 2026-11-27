extends CanvasLayer
## Settings pop-up, opened from the settings button in the UI frame.
## Change your name, turn sounds and alerts on/off, pick a theme, report a bug, and leave
## the lobby / game. Laid out like Game Settings: sections of row cards, buttons at the bottom.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const TITLE_SCENE := "res://Scenes/main.tscn"
const INK := Color("2e2328")

var _name_field: LineEdit
var _sound_toggle: InkSwitch
var _theme_button: Button
var _timer_toggle: InkSwitch


func _ready() -> void:
	layer = 60   # above screens and transitions, below the Fortuna card (100)
	Sound.play("open")
	_build()

func _build() -> void:
	var dim := ColorRect.new()   # blocks taps on the screen behind; tap outside to close
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close())
	add_child(dim)
	var screen := get_viewport().get_visible_rect().size
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(centre)

	# The same framed card as Game Settings: olive frame, a row card for each setting.
	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(minf(660.0, screen.x - 40.0), 0)
	var style := _style(FRAME_BG, 30, FRAME_EDGE, 4)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 22
	_frame.add_theme_stylebox_override("panel", style)
	centre.add_child(_frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_frame.add_child(outer)

	var title := _text("Settings", TITLE_FONT, 60, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	# Everything between the title and Close scrolls if the screen is short.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	# --- You ---
	box.add_child(_heading("YOU"))
	if Network.is_online():
		var key_row := _row("Room key: %s" % Network.room_key, "Friends type this under Join Game")
		key_row[1].add_child(_small_button("Copy", ROW_DARK, _copy_room_key))
		box.add_child(key_row[0])
	var name_card := _card()
	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 12)
	name_card.add_child(name_line)
	_name_field = LineEdit.new()
	_name_field.text = Global.PLAYER if Network.in_game else Network.my_name
	_name_field.placeholder_text = "Your name"
	_name_field.max_length = Network.MAX_NAME_LENGTH
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.custom_minimum_size.y = 60
	_name_field.add_theme_font_override("font", BOLD)
	_name_field.add_theme_font_size_override("font_size", 30)
	_name_field.add_theme_color_override("font_color", CREAM)
	_name_field.add_theme_color_override("caret_color", CREAM)
	_name_field.add_theme_color_override("font_placeholder_color", Color(CREAM, 0.45))
	var field_style := _style(ROW_DARK, 16)
	field_style.content_margin_left = 16
	field_style.content_margin_right = 12
	for state in ["normal", "focus"]:
		_name_field.add_theme_stylebox_override(state, field_style)
	_name_field.text_submitted.connect(func(_t): _save_name())
	name_line.add_child(_name_field)
	name_line.add_child(_small_button("Save", GREEN, _save_name))
	box.add_child(name_card)

	# --- Sound & alerts ---
	box.add_child(_heading("SOUND & ALERTS"))
	_sound_toggle = _switch_row(box, "Sounds", "Taps, cards, cash and dice", Sound.enabled)
	_sound_toggle.toggled.connect(_on_sound_toggled)
	var dots := _switch_row(box, "Red Dot Alerts", "A dot on an app when something changed", Notices.enabled)
	dots.toggled.connect(_on_dots_toggled)
	var recap := _switch_row(box, "Round Recap", "Highlights and standings between rounds", Network.load_setting("ui", "round_recap", true))
	recap.toggled.connect(func(on: bool):
		Sound.play("switch")
		Network.save_setting("ui", "round_recap", on))
	if Network.in_game and Network.is_online():   # (only the host can change it)
		_timer_toggle = _switch_row(box, "Last-Turn Timer",
				"The last player gets 30 seconds" if Network.is_host() else "Only the host can change this",
				Network.game_settings.get("turn_timer", true))
		if Network.is_host():
			_timer_toggle.toggled.connect(_on_timer_toggled)
		else:
			_timer_toggle.disabled = true
			_timer_toggle.modulate.a = 0.5

	# --- Look ---
	box.add_child(_heading("LOOK"))
	var theme_row := _row("Colour Theme", "Tap to try the next one")
	_theme_button = _small_button(ColorTheme.theme_name(), ROW_DARK, _next_theme)
	_theme_button.custom_minimum_size.x = 190
	theme_row[1].add_child(_theme_button)
	box.add_child(theme_row[0])

	# --- Help ---
	box.add_child(_heading("HELP"))
	box.add_child(_wide_button("Report a Bug", ROW_DARK, _report_bug))

	# --- Leave / Close ---
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var leave_text := _leave_text()
	if leave_text != "":
		var leave := _wide_button(leave_text, RED, _confirm_leave)
		leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(leave)
	var close := _wide_button("Close", GREEN, _close)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(close)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	outer.add_child(gap)
	outer.add_child(buttons)

	# Fit: as tall as its content, but never off the screen (then the middle scrolls).
	await get_tree().process_frame
	var room := screen.y - 120.0 - (_frame.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y)
	scroll.custom_minimum_size = Vector2(0, minf(box.get_combined_minimum_size().y, room))
	_pop_in()

## ---- LOOK (the same as Game Settings, lobby_settings_popup.gd) ----
const TITLE_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")
const FRAME_BG := Color("99966d")
const FRAME_EDGE := Color("f6f2e1")
const ROW_BG := Color("7b7e63")
const ROW_DARK := Color("5f6150")
const CREAM := Color("f6f2e1")
const GREEN := Color("5d6558")
const RED := Color("b76051")
var _frame: PanelContainer

func _pop_in() -> void:
	_frame.pivot_offset = _frame.size / 2.0
	_frame.scale = Vector2(0.92, 0.92)
	_frame.modulate.a = 0.0
	var t := _frame.create_tween().set_parallel(true)
	t.tween_property(_frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_frame, "modulate:a", 1.0, 0.12)

func _heading(text: String) -> Label:
	var label := _text(text, BOLD, 24, Color(INK, 0.75))
	return label

func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := _style(ROW_BG, 22)
	style.content_margin_left = 18
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	return card

# A row card: title and a small line on the left, room on the right ([card, right box]).
func _row(title: String, hint: String) -> Array:
	var card := _card()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	card.add_child(line)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.add_child(_text(title, BOLD, 27, CREAM))
	var small := _text(hint, BODY, 24, Color(CREAM, 0.78))
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	small.custom_minimum_size.x = 1
	words.add_child(small)
	line.add_child(words)
	var right := HBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(right)
	return [card, right]

func _switch_row(box: VBoxContainer, title: String, hint: String, on: bool) -> InkSwitch:
	var row := _row(title, hint)
	var toggle := InkSwitch.new()
	toggle.button_pressed = on
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row[1].add_child(toggle)
	box.add_child(row[0])
	return toggle

func _wide_button(text: String, colour: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 76
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", 30)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := _style(colour.darkened(0.15) if state == "pressed" else (colour.lightened(0.06) if state == "hover" else colour), 38, CREAM, 3)
		st.shadow_color = Color(0, 0, 0, 0.25)
		st.shadow_size = 5
		st.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(state, st)
	b.pressed.connect(action)
	return b

func _small_button(text: String, colour: Color, action: Callable) -> Button:
	var b := _wide_button(text, colour, action)
	b.custom_minimum_size = Vector2(120, 60)
	b.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st: StyleBoxFlat = b.get_theme_stylebox(state)
		st.set_corner_radius_all(30)
		st.set_border_width_all(2)
		st.content_margin_left = 18
		st.content_margin_right = 18
	return b

func _text(words: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(bg: Color, radius: int, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(radius)
	st.anti_aliasing = true
	if width > 0:
		st.border_color = border
		st.set_border_width_all(width)
	return st


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

func _next_theme() -> void:
	Sound.play("switch")
	ColorTheme.set_theme(ColorTheme.next_theme())
	_theme_button.text = ColorTheme.theme_name()

# Host: switch the last-player countdown on or off for everyone, right now.
func _on_timer_toggled(on: bool) -> void:
	Sound.play("switch")
	var settings: Dictionary = Network.game_settings.duplicate()
	settings["turn_timer"] = on
	Network.set_game_settings(settings)
	Turns.timer_setting_changed()
	Global.banner("Last-turn timer %s." % ("on" if on else "off"))

func _on_dots_toggled(on: bool) -> void:
	Sound.play("switch")
	if on:
		Notices.baseline()   # start fresh: no dots for what changed while they were off
	Notices.enabled = on

func _on_sound_toggled(on: bool) -> void:
	Sound.set_enabled(on)
	Sound.play("switch")   # silent when turning off

# What "leaving" means depends on where you are.
func _leave_text() -> String:
	if Network.in_game:
		return "Leave Game" if Network.is_online() else "Quit to Title"
	if Network.is_online():
		return "Leave Lobby"
	return ""   # the title screen: nothing to leave (and a browser tab can't quit itself)

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
	var screen := "title"
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		screen = scene.scene_file_path.get_file().get_basename()
	var url := "%s?v=%s&screen=%s" % [BUG_REPORT_URL, Network.APP_VERSION.uri_encode(), screen.uri_encode()]
	if Network.in_game:
		url += "&round=%d&expansion=%s" % [Global.ROUND, "1" if Network.expansion_on() else "0"]
	Global.open_web(url, "furthew.com/bug-report")

func _close() -> void:
	Sound.play("back")
	queue_free()
