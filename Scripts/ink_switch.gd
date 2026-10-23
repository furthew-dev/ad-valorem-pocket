class_name InkSwitch
extends Button
## A big on/off switch (Settings > Sounds): a rounded track with a sliding knob.
## Use it like a CheckButton: button_pressed, and the toggled(on) signal.

const ON_COLOR := Color("5d6558")    # palette sage (follows the colour theme)
const OFF_COLOR := Color("b3a999")
const KNOB_COLOR := Color("ddcf99")

var _knob := 0.0   # 0 = off (left) .. 1 = on (right)


func _init() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(124, 64)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	toggled.connect(_on_toggled)

func _ready() -> void:
	_knob = 1.0 if button_pressed else 0.0
	ColorTheme.theme_changed.connect(func(_k): queue_redraw())

func _on_toggled(on: bool) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_knob, _knob, 1.0 if on else 0.0, 0.22)

func _set_knob(value: float) -> void:
	_knob = value
	queue_redraw()

func _draw() -> void:
	var h := size.y
	var track := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.map_color(OFF_COLOR).lerp(ColorTheme.map_color(ON_COLOR), clampf(_knob, 0.0, 1.0))
	style.set_corner_radius_all(int(h / 2))
	style.border_color = Color(0, 0, 0, 0.25)
	style.set_border_width_all(2)
	draw_style_box(style, track)
	var radius := h / 2 - 6
	var x := lerpf(h / 2, size.x - h / 2, _knob)
	draw_circle(Vector2(x, h / 2 + 2), radius, Color(0, 0, 0, 0.18))   # soft shadow
	draw_circle(Vector2(x, h / 2), radius, ColorTheme.map_color(KNOB_COLOR))
