extends Panel
## One property card on the reveal screen (Scenes/listed_property_template.tscn).

@onready var image: TextureRect = $image
@onready var property_name: Label = $image/property_name
@onready var property_condition: Label = $image/property_condition
@onready var property_cost: Label = $image/property_cost
@onready var property_rent: Label = $image/property_rent
@onready var toggle_on_off: Button = $toggle_on_off

var card_data: Dictionary = {}


func setup_property(data: Dictionary, button_group: ButtonGroup) -> void:
	card_data = data
	var art_path: String = card_data.get("sale_art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		image.texture = load(art_path)   # the "for sale" listing poster
	# Build mode passes ready-made text (e.g. "from $4") instead of a single condition.
	property_name.text = str(card_data["name"])
	property_condition.text = card_data.get("condition_text", str(card_data["condition"]))
	# Say what each number is: new players couldn't tell the price from the rent.
	property_cost.text = "Cost " + card_data.get("price_text", "$%d" % card_data["value"])
	property_rent.text = "Rent " + card_data.get("rent_text", "$%d" % card_data["rent"])
	for label in [property_name, property_condition, property_cost, property_rent]:
		ColorTheme.keep(label)   # written on the listing poster, which no theme changes
	_fit.call_deferred(property_cost)
	_fit.call_deferred(property_rent)
	toggle_on_off.toggle_mode = true
	toggle_on_off.button_group = button_group
	_selection_look()
	_add_region_badge()
	_add_details()


# Picked: a glowing green edge around the poster (like the chosen Realtor / Buy Solo card);
# a faint light edge while a finger hovers.
func _selection_look() -> void:
	var picked := StyleBoxFlat.new()
	picked.bg_color = Color(0, 0, 0, 0)
	picked.draw_center = false
	picked.border_color = Color("6fe07c")
	picked.set_border_width_all(6)
	picked.set_corner_radius_all(26)
	picked.shadow_color = Color(Color("6fe07c"), 0.5)
	picked.shadow_size = 18
	picked.set_expand_margin_all(4)
	var hover := picked.duplicate()
	hover.border_color = Color(Color("ddcf99"), 0.6)
	hover.set_border_width_all(3)
	hover.shadow_size = 0
	for state in ["pressed", "hover_pressed", "pressed_mirrored", "hover_pressed_mirrored"]:
		toggle_on_off.add_theme_stylebox_override(state, picked)
	for state in ["hover", "hover_mirrored"]:
		toggle_on_off.add_theme_stylebox_override(state, hover)
	toggle_on_off.flat = false
	for state in ["normal", "focus", "disabled", "normal_mirrored"]:
		toggle_on_off.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	ColorTheme.keep(toggle_on_off)
	toggle_on_off.toggled.connect(func(on: bool):
		if on:
			pivot_offset = size / 2.0
			var tween := create_tween()
			tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "scale", Vector2.ONE, 0.16))

# A long price ("Cost $4-18" in build mode) gets a smaller font instead of running off
# the poster's corner.
func _fit(label: Label) -> void:
	if not is_instance_valid(label) or label.size.x <= 0:
		return
	var font: Font = label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	while size > 16 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > label.size.x:
		size -= 1
	label.add_theme_font_size_override("font_size", size)


## ---- EXPANSION: REGION SYMBOL (top-left corner of the poster) ----
const BADGE_SIZE := 74.0

func _add_region_badge() -> void:
	var region := str(card_data.get("region", ""))
	if not Network.expansion_on() or region == "":
		return
	var badge := TextureRect.new()
	badge.texture = Expansion.region_icon(region)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.position = Vector2(22, 22)
	badge.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.tooltip_text = region
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(badge)
	add_child(badge)


## ---- DETAILS DROP-DOWN (value and rent in every condition, plus the card's own rules) ----
const CREAM := Color("f6f2e1")
var _details_btn: Button
var _details_panel: PanelContainer

# What's worth knowing before buying: the card's own rule, and what it can't take.
func details_text() -> String:
	var lines := []
	var rule := str(card_data.get("p_details", card_data.get("description", ""))).strip_edges()
	if rule != "":
		lines.append(rule)
	var not_allowed := []
	if not card_data.get("allow_skybnb", true):
		not_allowed.append("SkyBnB")
	if not card_data.get("allow_double", true):
		not_allowed.append("Double")
	if not not_allowed.is_empty():
		lines.append("Can't take a %s." % " or ".join(not_allowed))
	if Network.expansion_on() and str(card_data.get("region", "")) != "":
		var region := str(card_data["region"])
		var mine := region.to_lower() == Expansion.my_region.to_lower()
		lines.append("Region: %s%s" % [region, " (yours: earns an Environment token)" if mine else ""])
	if lines.is_empty() or (lines.size() == 1 and lines[0].begins_with("Region:")):
		return ""   # nothing beyond the region: no drop-down
	return "\n\n".join(lines)

func _has_table() -> bool:
	return bool(card_data.get("has_condition", false)) and card_data.has("e_value")

func _add_details() -> void:
	var text := details_text()
	if text == "" and not _has_table():
		return
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.16, 0.12, 0.14, 0.82)
	pill.set_corner_radius_all(20)
	pill.content_margin_left = 16
	pill.content_margin_right = 16
	pill.content_margin_top = 4
	pill.content_margin_bottom = 6
	_details_btn = Button.new()
	_details_btn.text = "Details  v"
	_details_btn.focus_mode = Control.FOCUS_NONE
	_details_btn.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		_details_btn.add_theme_stylebox_override(state, pill)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_details_btn.add_theme_color_override(state, CREAM)
	_details_btn.position = Vector2(22 + (BADGE_SIZE + 10 if Network.expansion_on() else 0), 36)
	_details_btn.mouse_filter = Control.MOUSE_FILTER_STOP   # its own tap, not "select this"
	_details_btn.pressed.connect(_toggle_details)
	ColorTheme.keep(_details_btn)
	add_child(_details_btn)

	_details_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.12, 0.14, 0.9)
	box.set_corner_radius_all(22)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 16
	box.content_margin_bottom = 22
	_details_panel.add_theme_stylebox_override("panel", box)
	_details_panel.position = Vector2(16, 112)
	_details_panel.custom_minimum_size = Vector2(size.x - 32 if size.x > 100 else 468, 0)
	_details_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_details_panel.gui_input.connect(func(event: InputEvent):   # tap the panel to fold it away
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_details())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_panel.add_child(column)
	if _has_table():
		column.add_child(_conditions_table())
	if text != "":
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", CREAM)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
	_details_panel.visible = false
	add_child(_details_panel)
	for node in [_details_panel] + _details_panel.find_children("*", "", true, false):
		ColorTheme.keep(node)

# Value and rent in every condition (Matt, 11-28: compare before buying). The one for
# sale is lit with a gold band.
const GOLD := Color("ddcf99")
const TIERS := [["e", "excellent", "Excellent"], ["g", "good", "Good"], ["f", "fair", "Fair"], ["p", "poor", "Poor"]]

func _conditions_table() -> Control:
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	table.add_child(_table_row(["Condition", "Value", "Rent"], GOLD, false))
	var two: bool = card_data.get("two_conditions", false)   # Excellent / Poor only
	for tier in TIERS:
		if two and tier[0] in ["g", "f"]:
			continue
		var for_sale: bool = str(card_data.get("condition", "")).to_lower() == tier[1]
		table.add_child(_table_row([tier[2], "$%s" % card_data.get(tier[0] + "_value", 0),
				"$%s" % card_data.get(tier[0] + "_rent", 0)], CREAM, for_sale))
	return table

func _table_row(cells: Array, colour: Color, lit: bool) -> Control:
	var row := PanelContainer.new()
	var band := StyleBoxFlat.new()
	band.bg_color = Color(GOLD, 0.22) if lit else Color(0, 0, 0, 0)
	band.border_color = Color(GOLD, 0.8)
	band.set_border_width_all(2 if lit else 0)
	band.set_corner_radius_all(12)
	band.content_margin_left = 10
	band.content_margin_right = 10
	band.content_margin_top = 2
	band.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", band)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	for i in cells.size():
		var label := Label.new()
		label.text = cells[i]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = 1.5 if i == 0 else 1.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Bold.ttf") if lit or colour == GOLD else preload("res://Assets/fonts/Comfortaa-Regular.ttf"))
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", colour)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(label)
	return row

func _toggle_details() -> void:
	Sound.play("switch")
	var opening := not _details_panel.visible
	_details_btn.text = "Details  ^" if opening else "Details  v"
	if not opening:
		_details_panel.visible = false
		return
	_details_panel.custom_minimum_size.x = size.x - 32
	_details_panel.visible = true
	_details_panel.pivot_offset = Vector2(_details_panel.size.x / 2.0, 0)
	_details_panel.scale = Vector2(1, 0.2)   # drops down from under the button
	_details_panel.modulate.a = 0.0
	var tween := _details_panel.create_tween().set_parallel(true)
	tween.tween_property(_details_panel, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(_details_panel, "modulate:a", 1.0, 0.12)
