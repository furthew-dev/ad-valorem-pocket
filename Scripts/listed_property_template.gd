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
	property_cost.text = card_data.get("price_text", "$%d" % card_data["value"])
	property_rent.text = card_data.get("rent_text", "$%d" % card_data["rent"])
	for label in [property_name, property_condition, property_cost, property_rent]:
		ColorTheme.keep(label)   # written on the listing poster, which no theme changes
	toggle_on_off.toggle_mode = true
	toggle_on_off.button_group = button_group
	_add_region_badge()
	_add_details()


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


## ---- DETAILS DROP-DOWN (only for properties with something extra to say) ----
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

func _add_details() -> void:
	var text := details_text()
	if text == "":
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
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_panel.add_child(label)
	_details_panel.visible = false
	ColorTheme.keep(_details_panel)
	ColorTheme.keep(label)
	add_child(_details_panel)

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
