extends CanvasLayer
## Host-only "Game Settings" pop-up in the lobby: starting cash, starting properties,
## end goal. Starting cash must be less than the end goal.

const PAPER = preload("res://Assets/icons/pop_up.png")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const INK := Color(0.1, 0.1, 0.1)
const ERROR_INK := Color("b03030")

# key, label, arrow step
const ROWS := [
	["start_cash", "Starting cash ($)", 5],
	["start_properties", "Starting properties", 1],
	["end_goal", "End goal ($)", 10],
]

var _boxes: Dictionary = {}   # key -> SpinBox
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
	box.offset_left = -179
	box.offset_right = 221
	box.offset_top = -230
	box.offset_bottom = 290
	box.add_theme_constant_override("separation", 8)
	paper.add_child(box)

	box.add_child(_label("Game Settings", 64))
	for row in ROWS:
		var key: String = row[0]
		var limits: Array = Network.SETTING_LIMITS[key]
		box.add_child(_label(row[1], 38))
		var spin := SpinBox.new()
		spin.min_value = limits[0]
		spin.max_value = limits[1]
		spin.step = 1
		spin.custom_arrow_step = row[2]
		spin.rounded = true
		spin.value = Network.game_settings.get(key, Network.DEFAULT_SETTINGS[key])
		spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var field := spin.get_line_edit()
		field.add_theme_font_override("font", FONT)
		field.add_theme_font_size_override("font_size", 40)
		field.add_theme_color_override("font_color", INK)
		field.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		field.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		box.add_child(spin)
		_boxes[key] = spin

	_error = _label("", 30)
	_error.add_theme_color_override("font_color", ERROR_INK)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_error)

	var buttons := HBoxContainer.new()
	buttons.add_child(_button("Save", _save))
	buttons.add_child(_button("Cancel", _close))
	box.add_child(buttons)

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
	button.flat = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 52)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.pressed.connect(action)
	return button

func current_values() -> Dictionary:
	var values := {}
	for key in _boxes:
		_boxes[key].apply()   # include anything still being typed
		values[key] = int(_boxes[key].value)
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
