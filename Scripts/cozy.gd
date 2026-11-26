extends RefCounted
## The shared "card" look (Property Details, Real Estate, Sell, Bank, My Loans...):
## dark plum cards with a thin warm edge and a soft shadow, cream writing, small gold
## captions, big friendly numbers, rounded buttons with a cream rim.
##     const Cozy = preload("res://Scripts/cozy.gd")
##     var card := Cozy.card()
##     card.add_child(Cozy.label("Hello", Cozy.HAND, 48))
## Cards keep their dark colour in every theme's own palette (ColorTheme maps them), and
## the writing on them stays cream (Retro and Rosey would otherwise turn it dark).

const HAND = preload("res://Assets/fonts/Handwriting-Regular.otf")
const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")

const CARD := Color("533c44")
const INSET := Color("49343d")      # a darker well inside a card
const EDGE := Color("ddcf99")
const CREAM := Color("f6f2e1")
const GOLD := Color("d4af37")
const GREEN := Color("5d6558")
const RED := Color("b76051")
const PURPLE := Color("7a6d79")
const UP := Color("7fd17f")
const DOWN := Color("ff8a7e")

const TINT_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * COLOR.a); }
"""
static var _tint: ShaderMaterial


static func style(bg: Color, radius: int = 32, border := Color(0, 0, 0, 0), width := 0, shadow := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if width > 0:
		s.border_color = border
		s.set_border_width_all(width)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 5)
	return s

# A card: PanelContainer with the plum look, padded.
static func card(pad: int = 24, bg: Color = CARD) -> PanelContainer:
	var c := PanelContainer.new()
	var s := style(bg, 34, Color(EDGE, 0.45), 2, true)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad - 6
	s.content_margin_bottom = pad - 4
	c.add_theme_stylebox_override("panel", s)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c

# on_card: cream that stays cream in every theme (the cards are dark in all of them).
# Writing straight on a screen's background passes false: then each theme recolours it
# (Retro and Rosey have light backgrounds, so their writing turns dark there).
static func label(text: String, font: Font = FONT, size: int = 26, colour: Color = CREAM, on_card: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if on_card:
		ColorTheme.keep(l)   # cream on the dark cards in every theme
	return l

# "NET WORTH": a small gold heading.
static func caption(text: String) -> Label:
	return label(text.to_upper(), BOLD, 19, EDGE)

static func gap(height: int) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = height
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

# A thin line across a card.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(EDGE, 0.3)
	r.custom_minimum_size.y = 2
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(r)
	return r

# A big rounded button with a cream rim (green by default, red for selling).
static func button(text: String, colour: Color = GREEN, height: int = 88, size: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, CREAM)
	ColorTheme.keep_text(b)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := style(colour.darkened(0.12) if state == "pressed" else colour, height / 2, CREAM, 3)
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 5)
		s.content_margin_left = 20
		s.content_margin_right = 20
		b.add_theme_stylebox_override(state, s)
	return b

# Dimmed while it can't be used.
static func set_enabled(b: Button, on: bool) -> void:
	b.disabled = not on
	b.modulate.a = 1.0 if on else 0.5

# A round badge with an icon. mode: "tint" (one-colour icon drawn cream), "plain" (an icon
# already in its colours, e.g. cream_copy()), "picture" (a round picture filling it).
static func badge(texture: Texture2D, size: float = 64.0, bg: Color = INSET, mode: String = "tint") -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(func():
		holder.draw_circle(Vector2(size, size) / 2.0, size / 2.0, bg, true, -1.0, true)
		holder.draw_circle(Vector2(size, size) / 2.0, size / 2.0 - 1.5, Color(EDGE, 0.5), false, 2.0, true))
	if texture:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var inner := 0.94 if mode == "picture" else 0.58
		icon.position = Vector2(size, size) * (1.0 - inner) / 2.0
		icon.size = Vector2(size, size) * inner
		if mode == "tint":
			icon.material = tint_material()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ColorTheme.keep(icon)
		holder.add_child(icon)
	ColorTheme.keep(holder)
	return holder

static func tint_material() -> ShaderMaterial:
	if _tint == null:
		var shader := Shader.new()
		shader.code = TINT_SHADER
		_tint = ShaderMaterial.new()
		_tint.shader = shader
		_tint.set_shader_parameter("tint", CREAM)
	return _tint

# A rounded progress bar (0..1), gold on a dark track.
static func bar(height: float = 14.0, colour: Color = GOLD) -> Control:
	var b := Control.new()
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("value", 0.0)
	b.draw.connect(func():
		var r := height / 2.0
		_pill(b, Rect2(Vector2.ZERO, b.size), Color(0, 0, 0, 0.28), r)
		var v: float = clampf(b.get_meta("value"), 0.0, 1.0)
		if v > 0.0:
			_pill(b, Rect2(Vector2.ZERO, Vector2(maxf(b.size.x * v, height), b.size.y)), b.get_meta("colour", colour), r))
	ColorTheme.keep(b)
	return b

static func set_bar(b: Control, value: float, colour = null) -> void:
	b.set_meta("value", value)
	if colour != null:
		b.set_meta("colour", colour)
	b.queue_redraw()

static func _pill(canvas: CanvasItem, rect: Rect2, colour: Color, r: float) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(maxf(rect.size.x - 2 * r, 0), rect.size.y)), colour)
	canvas.draw_circle(rect.position + Vector2(r, r), r, colour, true, -1.0, true)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, colour, true, -1.0, true)

# A quick pop (scale up and back) for something that just changed.
static func pop(c: Control, amount: float = 1.08) -> void:
	c.pivot_offset = c.size / 2.0
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE * amount, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.18)

# Counts a label's "$N" from one number to another.
static func count(l: Label, from: int, to: int, fmt: String = "$%d", time: float = 0.8) -> void:
	var t := l.create_tween()
	t.tween_method(func(v: int): l.text = fmt % v, from, to, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# A page area between the header and the bottom bar, above the screen's UI frame (or the
# frame would catch every tap), that scrolls. Returns the VBox to fill.
static func page(screen_panel: Control, frame: Control, top: float = 184.0, bottom: float = 176.0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "CozyPage"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = top
	scroll.offset_bottom = -bottom
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	screen_panel.add_child(scroll)
	if frame:
		screen_panel.move_child(scroll, frame.get_index() + 1)
	var centre := MarginContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		centre.add_theme_constant_override("margin_" + side, 26)
	centre.add_theme_constant_override("margin_bottom", 16)
	centre.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(centre)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	centre.add_child(column)
	return column

# A row "label ........ value" for a card (with an optional icon badge on the left).
static func line(text: String, value: String, icon: Texture2D = null, value_colour: Color = CREAM) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	if icon:
		row.add_child(badge(icon, 52))
	var name_label := label(text, FONT, 26)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	var value_label := label(value, BOLD, 30, value_colour)
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.name = "value"
	row.add_child(value_label)
	return row

# The win: more than the End Goal in cash with no loans. 0..1 of the way there.
static func win_progress() -> float:
	return clampf(float(Global.CASH - Global.all_loans()) / maxf(Global.END_GOAL, 1.0), 0.0, 1.0)

static func can_win() -> bool:
	return Global.CASH > Global.END_GOAL and Global.all_loans() == 0

# How much more (in cash, after paying off every loan) until this player would end the game.
static func cash_to_end() -> int:
	return maxi(Global.END_GOAL + 1 - (Global.CASH - Global.all_loans()), 0)

# The game ends after a round where someone has more than the End Goal in cash and no loans;
# then the highest net worth wins (so the most cash doesn't always win).
static func end_rule() -> String:
	return "The game ends after a round where someone has more than $%d cash and no loans. Highest net worth wins." % Global.END_GOAL


## ---- CHOICE CARDS (Real Estate: Realtor / Buy Solo; Sell: Listing Agent / On Your Own) ----
# Turns a scene's choice Panel (with its full-size toggle Button and a "Select" Label) into a
# card: round emblem, title, a short line, an optional extra row (e.g. the die's faces) and a
# status pill made from that Label. The toggle stays on top, so taps work as before.
static func choice_card(panel: Panel, toggle: Button, note: Label, icon: Texture2D, title: String,
		hint: String, extra: Control = null) -> Dictionary:
	var s := style(CARD, 36, Color(EDGE, 0.55), 2, true)
	panel.add_theme_stylebox_override("panel", s)
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	toggle.offset_left = 0
	toggle.offset_top = 0
	toggle.offset_right = 0
	toggle.offset_bottom = 0
	toggle.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed",
			"normal_mirrored", "pressed_mirrored", "disabled_mirrored", "hover_mirrored", "hover_pressed_mirrored"]:
		toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_right = -14
	content.offset_top = 16
	content.offset_bottom = -14
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	panel.move_child(content, 0)   # under the toggle, so taps still land on it
	var emblem := badge(cream_copy(icon), 72, INSET, "plain")
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(emblem)
	var t := label(title, BOLD, 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(t)
	var h := label(hint, FONT, 19, Color(CREAM, 0.75))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(h)
	if extra:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(extra)
	note.get_parent().remove_child(note)
	note.set_anchors_preset(Control.PRESET_TOP_LEFT)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate.a = 1.0
	note.add_theme_font_override("font", BOLD)
	note.add_theme_font_size_override("font_size", 20)
	note.add_theme_color_override("font_color", CREAM)
	var pill := style(Color(0, 0, 0, 0.25), 16)
	pill.content_margin_left = 16
	pill.content_margin_right = 16
	pill.content_margin_top = 5
	pill.content_margin_bottom = 5
	note.add_theme_stylebox_override("normal", pill)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(note)
	content.add_child(gap(2))
	content.add_child(note)
	return {"panel": panel, "style": s, "note": note, "pill": pill}

# state: "off" (Tap to choose), "chosen" (green glow), "locked" (Not owned, faded).
static func paint_choice(c: Dictionary, state: String, locked_text: String = "Not owned") -> void:
	var s: StyleBoxFlat = c["style"]
	var chosen := state == "chosen"
	c["note"].text = locked_text if state == "locked" else ("Chosen" if chosen else "Tap to choose")
	c["panel"].modulate = Color(1, 1, 1, 0.5 if state == "locked" else 1.0)
	s.border_color = UP.lerp(Color("6fe07c"), 0.5) if chosen else Color(EDGE, 0.55)
	s.set_border_width_all(5 if chosen else 2)
	s.shadow_color = Color(Color("6fe07c"), 0.45) if chosen else Color(0, 0, 0, 0.3)
	s.shadow_size = 16 if chosen else 10
	s.shadow_offset = Vector2.ZERO if chosen else Vector2(0, 5)
	c["pill"].bg_color = Color(Color("6fe07c"), 0.35) if chosen else Color(0, 0, 0, 0.25)

# A scene's Panel + Label + flat Button made into one big rounded button.
static func panel_button(panel: Panel, text_label: Label, colour: Color, height: int = 96) -> StyleBoxFlat:
	panel.custom_minimum_size.y = height
	panel.size_flags_vertical = Control.SIZE_FILL
	var s := style(colour, height / 2, CREAM, 3)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", s)
	text_label.add_theme_font_override("font", BOLD)
	text_label.add_theme_font_size_override("font_size", 34)
	text_label.add_theme_color_override("font_color", CREAM)
	ColorTheme.keep(text_label)
	text_label.resized.connect(func(): text_label.pivot_offset = text_label.size / 2.0)
	for b in panel.get_children():
		if b is Button:
			for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
				b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			b.focus_mode = Control.FOCUS_NONE
	return s

# A cream copy of a black line icon: dark lines turn cream, light fill turns clear.
static var _cream := {}
static func cream_copy(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if _cream.has(texture):
		return _cream[texture]
	var image := texture.get_image()
	if image == null:
		return texture
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var px := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(CREAM, px.a * clampf(1.0 - px.get_luminance() * 1.2, 0.0, 1.0)))
	var copy := ImageTexture.create_from_image(image)
	_cream[texture] = copy
	return copy
