extends CanvasLayer
## Reusable pop-up. layout("Question?", "Yes", "No"): left_pressed fires for the first
## button, right_pressed for the second. Pass "" as the second label for a single OK button.
## The pop-up frees itself after either button, so callers can `await popup.tree_exited`.
##
## Text fields: call add_field() after layout(). Set `validate_left` to a Callable that
## returns an error message ("" = fine) to keep the pop-up open until the input is valid.

signal left_pressed
signal right_pressed

const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const INK := Color(0.1, 0.1, 0.1)
const ERROR_INK := Color("b03030")

@onready var panel: Panel = $CanvasLayer/Panel
@onready var vbox: VBoxContainer = $CanvasLayer/Panel/TextureRect/VBoxContainer
@onready var question: Label = $CanvasLayer/Panel/TextureRect/VBoxContainer/question
@onready var buttons: HBoxContainer = $CanvasLayer/Panel/TextureRect/VBoxContainer/HBoxContainer
@onready var no: Button = $CanvasLayer/Panel/TextureRect/VBoxContainer/HBoxContainer/no     # left button
@onready var yes: Button = $CanvasLayer/Panel/TextureRect/VBoxContainer/HBoxContainer/yes   # right button

var fields: Array[LineEdit] = []
var validate_left: Callable
var left_sound := "continue"   # Sound.play() names for each button
var right_sound := "back"
var _error_label: Label


func _ready() -> void:
	Sound.play("open")
	_style_buttons()

# Each button gets its own pencil-drawn box, so "Start Server" and "Back" read as two
# buttons rather than one sentence.
func _style_buttons() -> void:
	buttons.add_theme_constant_override("separation", 24)
	for button in [no, yes]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(INK, 0.06)
		box.border_color = Color(INK, 0.55)
		box.set_border_width_all(3)
		box.set_corner_radius_all(18)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		var pressed := box.duplicate()
		pressed.bg_color = Color(INK, 0.16)
		button.add_theme_stylebox_override("normal", box)
		button.add_theme_stylebox_override("hover", box)
		button.add_theme_stylebox_override("focus", box)
		button.add_theme_stylebox_override("pressed", pressed)
		button.flat = false
		button.clip_text = true   # let the box take its share of the row; the text then shrinks to fit

# Shrinks the button text until it fits inside its box. Both buttons use the same size
# so they look like a matching pair.
func _fit_button_text() -> void:
	await get_tree().process_frame
	var shown := [no, yes].filter(func(b): return b.visible and b.size.x > 0)
	if shown.is_empty():
		return
	var size: int = no.get_theme_font_size("font_size")
	for button in shown:
		var font: Font = button.get_theme_font("font")
		while size > 24 and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > button.size.x - 28:
			size -= 2
	for button in shown:
		button.add_theme_font_size_override("font_size", size)

# Draws this pop-up above other overlays (e.g. when opened from the settings pop-up).
func bring_to_front(index: int = 80) -> void:
	layer = index
	$CanvasLayer.layer = index

func layout(body: String, first_btn: String, second_btn: String) -> void:
	question.text = body
	no.text = first_btn
	yes.text = second_btn
	yes.visible = second_btn != ""
	_fit_button_text()

# Adds a text box above the buttons and returns it.
func add_field(placeholder: String, max_length: int = 0, uppercase: bool = false) -> LineEdit:
	question.custom_minimum_size.y = 0   # make room on the paper
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.max_length = max_length
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.custom_minimum_size = Vector2(0, 80)
	field.add_theme_font_override("font", FONT)
	field.add_theme_font_size_override("font_size", 36)
	field.add_theme_color_override("font_color", INK)
	field.add_theme_color_override("font_placeholder_color", Color(INK, 0.4))
	field.add_theme_color_override("caret_color", INK)
	for style in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	field.draw.connect(func(): field.draw_line(   # a pencil line to write on
			Vector2(20, field.size.y - 6), Vector2(field.size.x - 20, field.size.y - 6), Color(INK, 0.6), 3))
	if uppercase:
		field.text_changed.connect(func(new_text: String):
			var caret := field.caret_column
			field.text = new_text.to_upper()
			field.caret_column = caret)
	field.text_submitted.connect(func(_t): _on_no_pressed())
	vbox.add_child(field)
	vbox.move_child(field, buttons.get_index())
	fields.append(field)
	return field

func show_error(message: String) -> void:
	if _error_label == null:
		_error_label = Label.new()
		_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_error_label.add_theme_font_override("font", FONT)
		_error_label.add_theme_font_size_override("font_size", 24)
		_error_label.add_theme_color_override("font_color", ERROR_INK)
		vbox.add_child(_error_label)
		vbox.move_child(_error_label, buttons.get_index())
	_error_label.text = message

func _on_no_pressed() -> void:
	if validate_left.is_valid():
		var problem: String = validate_left.call()
		if problem != "":
			Sound.play("error")
			show_error(problem)
			return
	Sound.play(left_sound)
	left_pressed.emit()
	queue_free()

func _on_yes_pressed() -> void:
	Sound.play(right_sound)
	right_pressed.emit()
	queue_free()
