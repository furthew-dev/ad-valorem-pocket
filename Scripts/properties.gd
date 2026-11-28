extends Control
## One row in My Properties (Scenes/properties.tscn). Tapping it opens property_info,
## or, while My Properties is assigning a Golden Lock, asks to lock this property.
##
## The row is a card in the game's cosy look (rebuilt 11-28):
##   ( picture )  Renovated Farm House            VALUE   RENT
##                [Excellent] (region) (tokens)     $15     $15
## The scene only supplies the root and "Panel" (the card); the rest is built here.

signal assign_requested

const Cozy = preload("res://Scripts/cozy.gd")
const GOLD := Color("d4af37")
const PICTURE := 104.0
const CARD_HEIGHT := 136.0
const MAX_WIDTH := 696.0
# The condition chip's colour (the same as on Property Details).
const CONDITION_COLOURS := {"excellent": Color("4f7d43"), "good": Color("6f7a4d"), "fair": Color("b0743f"),
		"poor": Color("9a4a44"), "lot": Color("7b7e63"), "fixed": Color("6c5f72")}
const TOKEN_ICONS := {"has_skybnb": "res://Assets/icons/skybnb_icon.png", "has_double": "res://Assets/icons/double_icon.png",
		"has_insurance": "res://Assets/icons/insurance_icon.png", "has_golden_lock": "res://Assets/icons/tokens/lock_icon.png"}

@onready var panel: Panel = $Panel

var property_name: Label
var current_value: Label
var current_rent: Label
var condition: Label        # the condition chip's writing (the tutorial points at it)
var texture_rect: TextureRect
var property_button: Button

var current_scene := "res://Scenes/my_properties.tscn"
var this_card_id := 0


func setup_card(property_data: Dictionary) -> void:
	this_card_id = property_data.get("id", 0)
	_build(property_data)
	property_name.text = str(property_data.get("name", "Unknown Property"))
	_fit_name()
	current_value.text = "$%d" % property_data.get("value", 0)
	current_rent.text = "$%d" % property_data.get("rent", 0)
	var art_path: String = property_data.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		texture_rect.texture = Cards.round_icon(art_path)


## ---- THE CARD ----
func _build(p: Dictionary) -> void:
	for child in panel.get_children():   # the old scene layout
		child.queue_free()
	var width := minf(MAX_WIDTH, get_viewport().get_visible_rect().size.x - 24.0)
	custom_minimum_size.y = CARD_HEIGHT + 16.0
	panel.custom_minimum_size = Vector2.ZERO
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	panel.offset_top = 8.0
	panel.offset_bottom = 8.0 + CARD_HEIGHT
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var locked: bool = p.get("has_golden_lock", false)
	var face := Cozy.style(Cozy.CARD, 30, GOLD if locked else Color(Cozy.EDGE, 0.3), 4 if locked else 2)
	face.shadow_color = Color(0, 0, 0, 0.22)
	face.shadow_size = 8
	face.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", face)
	ColorTheme.keep(panel)

	# The whole card is the button (pressed = a little darker).
	property_button = Button.new()
	property_button.flat = true
	property_button.focus_mode = Control.FOCUS_NONE
	property_button.mouse_filter = Control.MOUSE_FILTER_PASS   # drags still scroll the list
	property_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pressed := Cozy.style(Color(0, 0, 0, 0.18), 30)
	for state in ["normal", "hover", "focus", "disabled"]:
		property_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	property_button.add_theme_stylebox_override("pressed", pressed)
	property_button.pressed.connect(_on_property_button_pressed)
	panel.add_child(property_button)

	var line := HBoxContainer.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 14
	line.offset_right = -20
	line.add_theme_constant_override("separation", 16)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)

	# The picture in a round frame with a soft gold rim.
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(PICTURE, PICTURE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", Cozy.style(Cozy.INSET, int(PICTURE / 2.0), Color(GOLD if locked else Cozy.EDGE, 0.8), 3))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(frame)
	texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		texture_rect.set_offset(side, 4)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		texture_rect.set_offset(side, -4)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(texture_rect)

	# Name, then the condition chip, region and tokens.
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 10)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(words)
	property_name = _label("", Cozy.BOLD, 30, Cozy.CREAM)
	property_name.custom_minimum_size.x = 1
	words.add_child(property_name)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(tags)
	tags.add_child(_condition_chip(p))
	var region := str(p.get("region", ""))
	if Network.expansion_on() and region != "":
		tags.add_child(_mini_badge(Expansion.region_icon(region), false))
	for key in TOKEN_ICONS:
		if p.get(key, false) and ResourceLoader.exists(TOKEN_ICONS[key]):
			tags.add_child(_mini_badge(load(TOKEN_ICONS[key]), true, key == "has_golden_lock"))

	# Value and rent, big, with small gold captions.
	var figures := HBoxContainer.new()
	figures.add_theme_constant_override("separation", 18)
	figures.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(figures)
	current_value = _figure(figures, "VALUE")
	current_rent = _figure(figures, "RENT")
	for node in panel.find_children("*", "", true, false):
		ColorTheme.keep(node)   # the same cosy card in every theme

func _figure(parent: HBoxContainer, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var small := _label(caption, Cozy.BOLD, 24, Color(Cozy.EDGE, 0.85))
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(small)
	var number := _label("$0", Cozy.BOLD, 36, Cozy.CREAM)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.custom_minimum_size.x = 76
	box.add_child(number)
	return number

func _condition_chip(p: Dictionary) -> Control:
	var kind := "fixed"
	var text := "Fixed value"
	if Cards.is_lot(p):
		kind = "lot"
		text = "Empty lot"
	elif p.get("has_condition", false):
		kind = str(p.get("condition", "excellent")).to_lower()
		text = kind.capitalize()
	var chip := PanelContainer.new()
	var style := Cozy.style(CONDITION_COLOURS.get(kind, CONDITION_COLOURS["fixed"]), 18)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	condition = _label(text, Cozy.BOLD, 24, Cozy.CREAM)
	chip.add_child(condition)
	return chip

# A small round badge: a region picture, or a token icon (drawn cream; gold for a Golden Lock).
func _mini_badge(texture: Texture2D, icon: bool, gold := false) -> Control:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(38, 38)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", Cozy.style(Cozy.INSET, 19, Color(GOLD if gold else Cozy.EDGE, 0.6), 2))
	badge.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon:
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		for side in [SIDE_LEFT, SIDE_TOP]:
			picture.set_offset(side, 7)
		for side in [SIDE_RIGHT, SIDE_BOTTOM]:
			picture.set_offset(side, -7)
		picture.material = Cozy.tint_material()
		if gold:
			picture.modulate = GOLD
	else:
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	badge.add_child(picture)
	return badge

func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# Every card is the same width, so a long name gets a smaller font (down to the text floor),
# then "..." rather than a wider card.
func _fit_name() -> void:
	property_name.clip_text = true
	property_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var width := panel.offset_right - panel.offset_left - 14.0 - 20.0 - PICTURE - 16.0 * 2.0 - (76.0 * 2.0 + 18.0)
	var font: Font = property_name.get_theme_font("font")
	var size := 30
	while size > 24 and font.get_string_size(property_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	property_name.add_theme_font_size_override("font_size", size)

func _on_property_button_pressed() -> void:
	Sound.play("click")
	if Global.assigning_token != "":
		assign_requested.emit()
		return
	Global.save_scene(current_scene)
	Cards.selected_id = this_card_id
	get_tree().change_scene_to_file("res://Scenes/property_info.tscn")
