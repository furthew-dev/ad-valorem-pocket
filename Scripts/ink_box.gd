class_name InkBox
## The pencil-drawn box used around pop-up buttons ("Start Server" | "Back", Save | Cancel...),
## so side-by-side buttons read as separate buttons. Call InkBox.apply(button).

const INK := Color(0.1, 0.1, 0.1)


static func apply(button: Button, ink: Color = INK) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(ink, 0.06)
	box.border_color = Color(ink, 0.55)
	box.set_border_width_all(3)
	box.set_corner_radius_all(18)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	var pressed := box.duplicate()
	pressed.bg_color = Color(ink, 0.16)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("focus", box)
	button.add_theme_stylebox_override("pressed", pressed)
	button.flat = false
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ink)


# Shrinks the text of `buttons` (one shared size) until each fits inside its box.
static func fit_text(buttons: Array, smallest: int = 24) -> void:
	var shown := buttons.filter(func(b): return b.visible and b.size.x > 0)
	if shown.is_empty():
		return
	var size: int = shown[0].get_theme_font_size("font_size")
	for button in shown:
		var font: Font = button.get_theme_font("font")
		while size > smallest and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > button.size.x - 28:
			size -= 2
	for button in shown:
		button.add_theme_font_size_override("font_size", size)
