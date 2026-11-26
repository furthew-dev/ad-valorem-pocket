extends Node2D
## Market > Real Estate (Scenes/realtor_or_random.tscn): choose Realtor (3 reveals)
## or Private Purchase (1 reveal), then go to property_reveal.
##
## The scene keeps its node names (the tutorial points at select/Realtor,
## select/Private Purchase and proceed); the look is set up here: two choice cards
## side by side, each with its emblem, and a Proceed button that says what happens.
## The three property pictures react to the choice: all three for the Realtor, only
## the middle one for Solo.

const SELECT := "CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/"
const ART := "CanvasLayer/Panel/VBoxContainer/list_of_properties/HBoxContainer/"

const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")
const REALTOR_ICON := preload("res://Assets/icons/realtor.png")
const PERSON_ICON := preload("res://Assets/icons/person.png")

const CARD_BG := Color("533c44")
const CARD_EDGE := Color("ddcf99")
const CREAM := Color("f6f2e1")
const BADGE_BG := Color("7a6d79")
const GREEN := Color("5d6558")
const GLOW := Color("6fe07c")
const ART_SIZE := Vector2(200, 454)   # the property pictures (their 720x1280 shape, trimmed)

@onready var realtor_toggle: Button = get_node(SELECT + "select/Realtor/realtor_toggle")
@onready var realtor_select: Label = get_node(SELECT + "select/Realtor/realtor_select")
@onready var ps_toggle: Button = get_node(SELECT + "select/Private Purchase/ps_toggle")
@onready var personal_select: Label = get_node(SELECT + "select/Private Purchase/personal")
@onready var proceed_btn: Button = get_node(SELECT + "proceed/proceed_btn")
@onready var proceed_label: Label = get_node(SELECT + "proceed/proceed_label")
@onready var realtor_emblem: Panel = $"CanvasLayer/Panel/realtor emblem"
@onready var personal_emblem: Panel = $"CanvasLayer/Panel/personal emblem"

var current_scene := "res://Scenes/realtor_or_random.tscn"

var _cards := {}       # true (Realtor) / false (Solo) -> {panel, style, title, note}
var _pictures: Array = []
var _proceed_style: StyleBoxFlat


func _ready() -> void:
	realtor_emblem.visible = false    # the old corner emblems: now inside the cards
	personal_emblem.visible = false
	proceed_btn.disabled = true
	Global.using_realtor = false
	realtor_toggle.disabled = not Actions.actions_owned.has("realtor")
	_lay_out()
	_paint()

func _on_proceed_btn_pressed() -> void:
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions. End your turn for more.", "home")
		return
	if Cards.properties_owned.size() >= Global.PROPERTY_CAPACITY:
		Global.error("Your properties are maxed out! Sell one first.", "my_properties")
		return
	Sound.play("continue")
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/property_reveal.tscn")

func _on_realtor_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(true)

func _on_ps_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(false)

func _choose(use_realtor: bool) -> void:
	Sound.play("switch")
	Global.using_realtor = use_realtor
	# set_deferred avoids fighting the toggle that is being pressed this frame
	(ps_toggle if use_realtor else realtor_toggle).set_deferred("button_pressed", false)
	proceed_btn.disabled = false
	_paint()
	_pop(_cards[use_realtor]["panel"], 1.04)
	_pop(proceed_label, 1.08)
	_show_pictures(use_realtor)


## ---- LOOK ----

func _lay_out() -> void:
	var column: VBoxContainer = $CanvasLayer/Panel/VBoxContainer
	column.get_node("Control4").custom_minimum_size = Vector2(0, 14)
	column.get_node("Control4").size_flags_vertical = Control.SIZE_FILL

	# The three property pictures: a little smaller, so everything fits with room to breathe.
	var art_row: HBoxContainer = get_node(ART.trim_suffix("/"))
	art_row.add_theme_constant_override("separation", 14)
	for picture in art_row.get_children():
		if picture is TextureRect:
			picture.custom_minimum_size = ART_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.pivot_offset = ART_SIZE / 2
			ColorTheme.keep(picture)
			_pictures.append(picture)

	# The old purple box goes: the choices are cards of their own now.
	var margin: MarginContainer = column.get_node("list_of_properties/MarginContainer2")
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 0)
	var box: Panel = margin.get_node("Panel")
	box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ColorTheme.keep(box)
	var inner: MarginContainer = box.get_node("MarginContainer")
	inner.offset_top = 0
	inner.offset_bottom = 0
	for side in ["left", "top", "right", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 0)
	var stack: VBoxContainer = inner.get_node("VBoxContainer")
	stack.add_theme_constant_override("separation", 0)
	for old in ["details", "success_rate", "Control2"]:   # their words are on the cards now
		stack.get_node(old).visible = false
	var row: HBoxContainer = stack.get_node("select")
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size.y = 236
	row.size_flags_vertical = Control.SIZE_FILL
	for spacer in ["Control", "Control2"]:
		row.get_node(spacer).custom_minimum_size.x = 0
	row.get_node("Control3").custom_minimum_size.x = 20
	stack.get_node("spacer").custom_minimum_size.y = 22

	_make_card(true, row.get_node("Realtor"), realtor_toggle, realtor_select,
			REALTOR_ICON, "Realtor", "See three, pick one")
	_make_card(false, row.get_node("Private Purchase"), ps_toggle, personal_select,
			PERSON_ICON, "Buy Solo", "See one, take it or leave it")

	# Proceed: a big button that says what will happen.
	var proceed: Panel = stack.get_node("proceed")
	proceed.custom_minimum_size.y = 96
	proceed.size_flags_vertical = Control.SIZE_FILL
	_proceed_style = _style(GREEN, 48, CREAM, 3)
	_proceed_style.shadow_color = Color(0, 0, 0, 0.35)
	_proceed_style.shadow_size = 8
	_proceed_style.shadow_offset = Vector2(0, 5)
	proceed.add_theme_stylebox_override("panel", _proceed_style)
	proceed_label.add_theme_font_override("font", BOLD)
	proceed_label.add_theme_font_size_override("font_size", 36)
	proceed_label.add_theme_color_override("font_color", CREAM)
	ColorTheme.keep(proceed_label)
	proceed_label.resized.connect(func(): proceed_label.pivot_offset = proceed_label.size / 2)
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		proceed_btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	proceed_btn.focus_mode = Control.FOCUS_NONE

	# The whole bottom block sits a touch lower than the pictures' bottom edge.
	column.get_node("list_of_properties").size_flags_vertical = Control.SIZE_EXPAND_FILL

func _make_card(realtor: bool, panel: Panel, toggle: Button, note: Label, icon: Texture2D,
		title_text: String, hint_text: String) -> void:
	var style := _style(CARD_BG, 36, CARD_EDGE, 2)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	panel.pivot_offset = Vector2.ZERO
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2)

	# The toggle covers the card; the card itself shows the choice.
	toggle.offset_left = 0
	toggle.offset_top = 0
	toggle.offset_right = 0
	toggle.offset_bottom = 0
	toggle.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed",
			"normal_mirrored", "pressed_mirrored", "disabled_mirrored", "hover_mirrored",
			"hover_pressed_mirrored"]:
		toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_right = -14
	content.offset_top = 18
	content.offset_bottom = -16
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	panel.move_child(content, 0)   # under the toggle, so taps still land on it

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(76, 76)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _style(BADGE_BG, 38))
	var picture := TextureRect.new()
	picture.texture = _cream_copy(icon)
	picture.custom_minimum_size = Vector2(48, 48)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(picture)
	badge.add_child(picture)
	content.add_child(badge)

	var title := _label(title_text, BOLD, 34, CREAM)
	content.add_child(title)
	var hint := _label(hint_text, FONT, 19, Color(CREAM, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	# The scene's "Select" label becomes a small status pill at the bottom.
	note.get_parent().remove_child(note)
	note.set_anchors_preset(Control.PRESET_TOP_LEFT)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", BOLD)
	note.add_theme_font_size_override("font_size", 20)
	note.add_theme_color_override("font_color", CREAM)
	var pill := _style(Color(0, 0, 0, 0.25), 16)
	pill.content_margin_left = 16
	pill.content_margin_right = 16
	pill.content_margin_top = 5
	pill.content_margin_bottom = 5
	note.add_theme_stylebox_override("normal", pill)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(note)
	content.add_child(_gap(4))
	content.add_child(note)

	_cards[realtor] = {"panel": panel, "style": style, "note": note, "pill": pill}

# Cards, pills and Proceed to match the current choice.
func _paint() -> void:
	for realtor in _cards:
		var card: Dictionary = _cards[realtor]
		var style: StyleBoxFlat = card["style"]
		var note: Label = card["note"]
		var pill: StyleBoxFlat = card["pill"]
		var toggle: Button = realtor_toggle if realtor else ps_toggle
		var chosen: bool = not proceed_btn.disabled and Global.using_realtor == realtor
		if toggle.disabled:
			note.text = "Not owned"
			card["panel"].modulate = Color(1, 1, 1, 0.5)
		elif chosen:
			note.text = "Chosen"
		else:
			note.text = "Tap to choose"
		style.border_color = GLOW if chosen else Color(CARD_EDGE, 0.55)
		style.set_border_width_all(5 if chosen else 2)
		style.shadow_color = Color(GLOW, 0.45) if chosen else Color(0, 0, 0, 0.3)
		style.shadow_size = 16 if chosen else 8
		style.shadow_offset = Vector2.ZERO if chosen else Vector2(0, 5)
		pill.bg_color = Color(GLOW, 0.35) if chosen else Color(0, 0, 0, 0.25)
	if proceed_btn.disabled:
		proceed_label.text = "Choose how to buy"
		proceed_label.get_parent().modulate = Color(1, 1, 1, 0.55)
	else:
		proceed_label.text = "Reveal 3 Properties" if Global.using_realtor else "Reveal 1 Property"
		proceed_label.get_parent().modulate = Color.WHITE

# Realtor: all three pictures. Solo: only the middle one; the others fade back.
func _show_pictures(use_realtor: bool) -> void:
	for i in _pictures.size():
		var picture: TextureRect = _pictures[i]
		var lit := use_realtor or i == 1
		var tween := picture.create_tween().set_parallel()
		tween.tween_property(picture, "modulate", Color(1, 1, 1, 1.0 if lit else 0.3), 0.25)
		tween.tween_property(picture, "scale", Vector2.ONE * (1.0 if lit else 0.92), 0.25) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if lit:
			_pop(picture, 1.05, i * 0.06)

func _pop(control: Control, size: float, delay := 0.0) -> void:
	var tween := control.create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	tween.tween_property(control, "scale", Vector2.ONE * size, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.18)

func _style(bg: Color, radius: int, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	return style

func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(label)   # the cards stay dark in every theme, so their writing stays cream
	return label

func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap

# A cream copy of a black line icon: dark lines turn cream, light fill turns clear.
static var _cream_icons := {}
func _cream_copy(texture: Texture2D) -> Texture2D:
	if _cream_icons.has(texture):
		return _cream_icons[texture]
	var image := texture.get_image()
	if image == null:
		return texture
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(CREAM, c.a * clampf(1.0 - c.get_luminance() * 1.2, 0.0, 1.0)))
	var copy := ImageTexture.create_from_image(image)
	_cream_icons[texture] = copy
	return copy
