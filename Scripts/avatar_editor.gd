extends CanvasLayer
## Lobby: "make your character". Opened by tapping your own character.
##
##          [ big character ]
##            Player Name
##     <      Skin: Honey       >
##     <      Face: Cheerful    >
##     <   Accessory: Aviators  >
##     <   Hair / Hat: Beanie   >
##        [ Back ]    [ Save ]
##
## Save keeps it on this phone (for every game from now on) and shows it to everyone.

const Avatar = preload("res://Scripts/avatar.gd")
const PAPER = preload("res://Assets/icons/pop_up.png")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const INK := Color(0.1, 0.1, 0.1)
const PREVIEW_SIZE := 180.0

signal saved(code: Array)

var _code: Array = []
var _preview: Control
var _values: Array[Label] = []


func _ready() -> void:
	layer = 60
	Sound.play("open")
	_code = Network.my_avatar()
	_build()

func _build() -> void:
	var dim := ColorRect.new()   # blocks taps on the lobby behind
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var paper := TextureRect.new()
	paper.texture = PAPER
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.offset_left = -300
	paper.offset_right = 300
	paper.offset_top = -600
	paper.offset_bottom = 560
	dim.add_child(paper)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -215
	box.offset_right = 215
	box.offset_top = -430
	box.offset_bottom = 470
	box.add_theme_constant_override("separation", 8)
	paper.add_child(box)

	# The character, big, at the top
	var holder := CenterContainer.new()
	_preview = Avatar.make(_code, PREVIEW_SIZE)
	holder.add_child(_preview)
	box.add_child(holder)
	var name_label := _label(Global.PLAYER if Network.in_game else Network.my_name, 46)
	box.add_child(name_label)
	box.add_child(_spacer(4))

	# One line per layer: <  name  >
	for layer in Avatar.COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_arrow("<", _step.bind(layer, -1)))
		var middle := VBoxContainer.new()
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.alignment = BoxContainer.ALIGNMENT_CENTER
		middle.add_theme_constant_override("separation", -4)
		var caption := _label(Avatar.LAYERS[layer], 24)
		caption.modulate.a = 0.6
		middle.add_child(caption)
		var value := _label("", 36)
		value.clip_text = true
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		middle.add_child(value)
		_values.append(value)
		row.add_child(middle)
		row.add_child(_arrow(">", _step.bind(layer, 1)))
		box.add_child(row)

	var shuffle := _button("Surprise me", _shuffle, false)
	shuffle.add_theme_font_size_override("font_size", 34)
	box.add_child(shuffle)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	var back := _button("Back", _close)
	var save := _button("Save", _save)
	for b in [back, save]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 76
		buttons.add_child(b)
	box.add_child(buttons)
	_show()

func _show() -> void:
	for layer in Avatar.COUNT:
		_values[layer].text = Avatar.part_name(layer, _code[layer])
	# Hats keep their own colours: the hair colour line fades out while one is worn.
	_values[4].get_parent().modulate.a = 1.0 if Avatar.is_hair(_code[3]) else 0.4
	Avatar.update(_preview, _code)

func _step(layer: int, direction: int) -> void:
	Sound.play("char_next" if direction > 0 else "char_prev")
	_code[layer] = posmod(_code[layer] + direction, Avatar.options(layer).size())
	_show()
	var pop := _preview.create_tween()   # a little bounce so the change is noticed
	_preview.pivot_offset = _preview.size / 2.0
	pop.tween_property(_preview, "scale", Vector2(1.06, 1.06), 0.07)
	pop.tween_property(_preview, "scale", Vector2.ONE, 0.1)

func _shuffle() -> void:
	Sound.play("dice")
	_code = Avatar.random_code()
	_show()

func _save() -> void:
	Network.set_my_avatar(_code)
	Sound.play("saved")
	saved.emit(_code.duplicate())
	queue_free()

func _close() -> void:
	Sound.play("back")
	queue_free()


## ---- LOOKS (same pencil-on-paper style as the Settings pop-up) ----
func _arrow(text: String, action: Callable) -> Button:
	var button := _button(text, action)
	button.custom_minimum_size = Vector2(72, 72)
	button.add_theme_font_size_override("font_size", 44)
	button.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Regular.ttf"))
	return button

func _button(text: String, action: Callable, boxed: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	_style_ink(button, 46)
	if boxed:
		InkBox.apply(button, INK)
	else:
		button.add_theme_color_override("font_hover_color", Color("b76051"))
		button.add_theme_color_override("font_pressed_color", Color("96514b"))
	button.pressed.connect(action)
	return button

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_ink(label, size)
	return label

func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _style_ink(control: Control, size: int) -> void:
	control.add_theme_font_override("font", FONT)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_pressed_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.add_theme_color_override("font_hover_pressed_color", INK)
	control.add_theme_color_override("font_focus_color", INK)
