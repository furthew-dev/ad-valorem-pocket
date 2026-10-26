extends CanvasLayer
## Host-only "Game Settings" pop-up in the lobby: starting cash, starting properties,
## end goal. Starting cash must be less than the end goal.

const PAPER = preload("res://Assets/icons/pop_up.png")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const INK := Color(0.1, 0.1, 0.1)
const ERROR_INK := Color("b03030")

# key, label
const ROWS := [
	["start_cash", "Starting Cash $:"],
	["start_properties", "Starting Properties:"],
	["end_goal", "End Goal $:"],
]
const ROW_FONT := 34

var _boxes: Dictionary = {}   # key -> LineEdit
var _timer_switch: InkSwitch
var _base_switch: InkSwitch
var _expansion_switch: InkSwitch
var _buttons: Array = []
var _error: Label


func _ready() -> void:
	layer = 60
	Sound.play("open")
	_build()

func _build() -> void:
	var dim := ColorRect.new()
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

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -175   # centred on the paper, with a margin each side
	box.offset_right = 175
	box.offset_top = -230
	box.offset_bottom = 290
	box.add_theme_constant_override("separation", 8)
	paper.add_child(box)

	box.add_child(_label("Game Settings", 64))
	box.add_child(_spacer(16))
	# One line per setting: "Starting Cash $: ____"
	for row in ROWS:
		var key: String = row[0]
		var limits: Array = Network.SETTING_LIMITS[key]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var name_label := _label(row[1], ROW_FONT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.custom_minimum_size.x = 236   # same width on every line, so the blanks line up
		line.add_child(name_label)
		var field := LineEdit.new()
		field.text = str(Network.game_settings.get(key, Network.DEFAULT_SETTINGS[key]))
		field.placeholder_text = "%d to %d" % [limits[0], limits[1]]   # also the phone prompt's title
		field.max_length = 3
		field.alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.custom_minimum_size = Vector2(84, 0)
		field.add_theme_font_override("font", FONT)
		field.add_theme_font_size_override("font_size", ROW_FONT)
		field.add_theme_color_override("font_color", INK)
		field.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
		field.add_theme_color_override("caret_color", INK)
		for style in ["normal", "focus", "read_only"]:
			field.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		field.draw.connect(func(): field.draw_line(   # the pencil line to write on
				Vector2(4, field.size.y - 4), Vector2(field.size.x - 4, field.size.y - 4), Color(INK, 0.6), 3))
		field.text_changed.connect(_digits_only.bind(field))
		field.text_submitted.connect(func(_t): _save())
		line.add_child(field)
		box.add_child(line)
		_boxes[key] = field

	# Last-player timer: when everyone else has ended their turn, the last player gets
	# 30 seconds before their turn is ended for them.
	var timer_line := HBoxContainer.new()
	var timer_label := _label("Last-Turn Timer (30s):", ROW_FONT)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	timer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # wraps instead of pushing the switch off the paper
	timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_line.add_child(timer_label)
	_timer_switch = InkSwitch.new()
	_timer_switch.button_pressed = Network.game_settings.get("turn_timer", true)
	timer_line.add_child(_timer_switch)
	box.add_child(timer_line)
	# Editions: which properties are in the deck (Expansion also adds regions and its Fortunas).
	_base_switch = _switch_line(box, "Base Edition:", Network.game_settings.get("base", true))
	_expansion_switch = _switch_line(box, "Expansion:", Network.game_settings.get("expansion", false))

	_error = _label("", 30)
	_error.add_theme_color_override("font_color", ERROR_INK)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_error)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	buttons.add_child(_button("Save", _save))
	buttons.add_child(_button("Cancel", _close))
	box.add_child(buttons)
	_fit_buttons.call_deferred()

func _switch_line(box: VBoxContainer, text: String, on: bool) -> InkSwitch:
	var line := HBoxContainer.new()
	var label := _label(text, ROW_FONT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var toggle := InkSwitch.new()
	toggle.button_pressed = on
	line.add_child(toggle)
	box.add_child(line)
	return toggle

func _fit_buttons() -> void:
	await get_tree().process_frame
	InkBox.fit_text(_buttons)

func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _digits_only(new_text: String, field: LineEdit) -> void:
	var digits := ""
	for c in new_text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != new_text:
		var caret := field.caret_column
		field.text = digits
		field.caret_column = mini(caret, digits.length())

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 52)
	InkBox.apply(button, INK)
	button.pressed.connect(action)
	_buttons.append(button)
	return button

func current_values() -> Dictionary:
	var values := {}
	for key in _boxes:
		var text: String = _boxes[key].text.strip_edges()
		values[key] = int(text) if text.is_valid_int() else -1   # -1 fails the range check
	values["turn_timer"] = _timer_switch.button_pressed
	values["base"] = _base_switch.button_pressed
	values["expansion"] = _expansion_switch.button_pressed
	return values

func _save() -> void:
	var problem := Network.set_game_settings(current_values())
	if problem != "":
		Sound.play("error")
		_error.text = problem
		return
	Sound.play("saved")
	queue_free()

func _close() -> void:
	Sound.play("back")
	queue_free()
