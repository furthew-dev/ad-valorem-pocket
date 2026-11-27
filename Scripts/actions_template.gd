extends Control
## One row in the Market (tokens for sale) or in My Actions (tokens you own).
## Scenes/actions_template.tscn only supplies this root (and its "Panel", which follows the
## card so the red-dot pulse can outline it); the card itself is built here:
##
##   ( icon )  Double                  [ $25 ]
##             12 in Stock          [ Details v ]
##   ┌──────────────────────────────────────────┐   (opens when Details is tapped)
##   │ Put it on a property to double its value │
##   └──────────────────────────────────────────┘
##
## Tap the card to pick it (Market) or use it (My Actions); Details has its own tap.

const FLASH_COLOR := Color("c94040")
const Cozy = preload("res://Scripts/cozy.gd")
const BADGE := 84.0
const SIDE := 12        # the card stops short of the screen's edges
const PAD := 18         # inside the card

var item_icon: TextureRect
var title: Label
var cost: Label
var stock: Label
var button: Button      # the card's own select button (drawn as the card)

var selected_card_data: Dictionary = {}
var _shown_stock: int = 0   # tweened, so the label counts down
var _stock_tween: Tween
var _card: PanelContainer
var _built := false


func setup_card(action_data: Dictionary, group: ButtonGroup) -> void:
	_build()
	selected_card_data = action_data
	_set_icon(str(action_data.get("art", "")), false)
	title.text = str(action_data.get("name", "Unknown action"))
	cost.text = "$%d" % Actions.price_of(action_data)
	_set_shown_stock(action_data.get("stock", 0))
	button.toggle_mode = true
	button.button_group = group
	_add_details(Actions.details_of(action_data))

# My Actions: a token you own. The price becomes how many you have ("×2"), the stock
# line a hint ("Tap to use").
func setup_owned(data: Dictionary, count: int, hint: String) -> void:
	_build()
	selected_card_data = data
	_set_icon(str(data.get("art", "")), true)
	title.text = str(data.get("name", "Unknown"))
	cost.text = "×%d" % count
	stock.text = hint
	button.toggle_mode = false
	_add_details(Actions.details_of(data))

# Taps decided by the row itself: a drag scrolls the list instead, and the press reaches
# the list. `on_tap(row)` runs for a real tap only, when `is_tap()` agrees.
func use_taps(on_tap: Callable, is_tap: Callable) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE   # only shows hover / picked now
	mouse_filter = Control.MOUSE_FILTER_PASS
	var down := [false]
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				down[0] = true
			elif down[0]:
				down[0] = false
				if is_tap.call():
					on_tap.call(self))


## ---- THE CARD ----
func _build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	for child in $Panel.get_children():   # the old scene layout
		child.queue_free()
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var wrap := MarginContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right"]:
		wrap.add_theme_constant_override("margin_" + side, SIDE)
	wrap.add_theme_constant_override("margin_top", 5)
	wrap.add_theme_constant_override("margin_bottom", 5)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_card)

	# The select button is the card's face: plum, a soft gold edge; picked = bright gold edge.
	button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("row", self)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var normal := _card_style(Color(Cozy.CARD, 0.72), Color(Cozy.EDGE, 0.28), 2)
	var hover := _card_style(Color(Cozy.CARD, 0.82), Color(Cozy.EDGE, 0.5), 2)
	var picked := _card_style(Color(Cozy.CARD, 0.95), Cozy.EDGE, 4)
	for state in ["normal", "normal_mirrored", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	for state in ["hover", "hover_mirrored"]:
		button.add_theme_stylebox_override(state, hover)
	for state in ["pressed", "pressed_mirrored", "hover_pressed", "hover_pressed_mirrored"]:
		button.add_theme_stylebox_override(state, picked)
	_card.add_child(button)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, PAD if side in ["left", "right"] else 14)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(pad)
	var column := VBoxContainer.new()
	column.name = "column"
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	top.add_child(_badge())

	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(words)
	title = _label("", Cozy.BOLD, 30, Cozy.CREAM)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 1
	words.add_child(title)
	stock = _label("", Cozy.FONT, 24, Color(Cozy.CREAM, 0.72))
	stock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stock.custom_minimum_size.x = 1
	words.add_child(stock)

	var side_box := VBoxContainer.new()   # the price, and Details under it
	side_box.alignment = BoxContainer.ALIGNMENT_CENTER
	side_box.add_theme_constant_override("separation", 10)
	side_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(side_box)
	var price := PanelContainer.new()
	var price_style := Cozy.style(Cozy.INSET, 22, Color(Cozy.EDGE, 0.55), 2)
	price_style.content_margin_left = 18
	price_style.content_margin_right = 18
	price_style.content_margin_top = 4
	price_style.content_margin_bottom = 6
	price.add_theme_stylebox_override("panel", price_style)
	price.size_flags_horizontal = Control.SIZE_SHRINK_END
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_box.add_child(price)
	cost = _label("", Cozy.BOLD, 30, Cozy.EDGE)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_child(cost)
	_details_slot = side_box

	_card.resized.connect(_fit)
	_card.minimum_size_changed.connect(_fit)
	_fit.call_deferred()
	for node in [_card] + _card.find_children("*", "", true, false):
		ColorTheme.keep(node)   # the same cosy card in every theme
	_glass_soften()

func _card_style(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var style := Cozy.style(fill, 26, edge, width)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style

# In Glass the cards are frosted like the other panels (they keep their shape and writing).
func _glass_soften() -> void:
	if ColorTheme.is_glass():
		ColorTheme.frost(button)

# The round icon badge: a dark well with a light rim; one-colour icons drawn in cream.
func _badge() -> Control:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(BADGE, BADGE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", Cozy.style(Cozy.INSET, int(BADGE / 2.0), Color(Cozy.EDGE, 0.45), 2))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon = TextureRect.new()
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		item_icon.set_offset(side, 14)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		item_icon.set_offset(side, -14)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(item_icon)
	return badge

const ICON_TINT := """
shader_type canvas_item;
void fragment() { COLOR = vec4(vec3(0.965, 0.949, 0.882), texture(TEXTURE, UV).a * COLOR.a); }
"""
static var _icon_material: ShaderMaterial

func _set_icon(path: String, owned: bool) -> void:
	if path == "" or not ResourceLoader.exists(path):
		item_icon.texture = null   # never a stand-in picture (it made LLC look like another token)
		return
	item_icon.texture = load(path)
	if ColorTheme._mono_color(item_icon.texture) != "":   # one-colour icons: cream on the dark well
		if _icon_material == null:
			var shader := Shader.new()
			shader.code = ICON_TINT
			_icon_material = ShaderMaterial.new()
			_icon_material.shader = shader
		item_icon.material = _icon_material
	elif owned:
		ColorTheme.ink_icon(item_icon)   # Fortuna card art kept in hand

# The row is as tall as its card; "Panel" follows the card (the red-dot pulse outlines it).
func _fit() -> void:
	if not is_instance_valid(_card):
		return
	var wrap := _card.get_parent() as Control
	custom_minimum_size.y = wrap.get_combined_minimum_size().y
	wrap.size.y = custom_minimum_size.y
	$Panel.position = Vector2(SIDE, 5)
	$Panel.size = _card.size
	$Panel.custom_minimum_size = Vector2.ZERO

func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## ---- DETAILS (a clear "Details" pill; the text opens in a roomy well under the row) ----
var _details_slot: VBoxContainer
var _details: Label
var _details_box: PanelContainer
var _details_btn: Button
var _chevron: Control

func _add_details(text: String) -> void:
	if text == "" or _details_btn:
		return
	_details_btn = Button.new()
	_details_btn.focus_mode = Control.FOCUS_NONE
	_details_btn.text = "Details"
	_details_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_details_btn.custom_minimum_size = Vector2(150, 48)
	_details_btn.add_theme_font_override("font", Cozy.BOLD)
	_details_btn.add_theme_font_size_override("font_size", 24)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_details_btn.add_theme_color_override(c, Cozy.CREAM)
	for state in ["normal", "focus"]:
		_details_btn.add_theme_stylebox_override(state, _pill(Color(Cozy.PURPLE, 0.55)))
	for state in ["hover", "pressed"]:
		_details_btn.add_theme_stylebox_override(state, _pill(Color(Cozy.PURPLE, 0.85)))
	_details_btn.mouse_filter = Control.MOUSE_FILTER_STOP   # its own tap, not the row's
	_details_btn.pressed.connect(_toggle_details)
	_chevron = Control.new()   # drawn (the fonts have no arrow glyphs)
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chevron.custom_minimum_size = Vector2(18, 12)
	_chevron.size = Vector2(18, 12)
	_chevron.draw.connect(func():
		var open := _details_box != null and _details_box.visible
		var w := _chevron.size.x
		var h := _chevron.size.y
		var points := PackedVector2Array([Vector2(0, h), Vector2(w / 2.0, 0), Vector2(w, h)]) if open \
				else PackedVector2Array([Vector2(0, 0), Vector2(w / 2.0, h), Vector2(w, 0)])
		_chevron.draw_polyline(points, Cozy.CREAM, 3.0, true))
	_details_btn.add_child(_chevron)
	_details_btn.resized.connect(func():
		_chevron.position = Vector2(_details_btn.size.x - 18 - 16, (_details_btn.size.y - 12) / 2.0))
	_details_slot.add_child(_details_btn)

	_details_box = PanelContainer.new()
	var well := Cozy.style(Cozy.INSET, 18, Color(Cozy.EDGE, 0.3), 1)
	well.content_margin_left = 20
	well.content_margin_right = 20
	well.content_margin_top = 16
	well.content_margin_bottom = 18
	_details_box.add_theme_stylebox_override("panel", well)
	_details_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_box.visible = false
	_details = _label(text, Cozy.FONT, 24, Color(Cozy.CREAM, 0.92))
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.x = 1
	_details_box.add_child(_details)
	(_card.find_child("column", true, false) as VBoxContainer).add_child(_details_box)
	for node in [_details_btn, _chevron, _details_box, _details]:
		ColorTheme.keep(node)
	ColorTheme.keep_text(_details_btn)

func _pill(fill: Color) -> StyleBoxFlat:
	var style := Cozy.style(fill, 24, Color(Cozy.EDGE, 0.8), 2)
	style.content_margin_left = 20
	style.content_margin_right = 46   # room for the drawn arrow
	return style

func _toggle_details() -> void:
	Sound.play("switch")
	_details_box.visible = not _details_box.visible
	_chevron.queue_redraw()
	if _details_box.visible:
		_details_box.modulate.a = 0.0
		_details_box.create_tween().tween_property(_details_box, "modulate:a", 1.0, 0.18)
	_fit.call_deferred()


## ---- STOCK ----
# Animates the stock label to the card's current stock: counts down, flashes and pops.
func update_stock() -> void:
	var target: int = selected_card_data.get("stock", 0)
	if _stock_tween and _stock_tween.is_valid():
		_stock_tween.kill()
	stock.pivot_offset = stock.size / 2
	_stock_tween = create_tween()
	_stock_tween.tween_method(_set_shown_stock, _shown_stock, target, 0.4)
	_stock_tween.parallel().tween_property(stock, "modulate", FLASH_COLOR, 0.15)
	_stock_tween.parallel().tween_property(stock, "scale", Vector2(1.15, 1.15), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stock_tween.tween_property(stock, "modulate", Color.WHITE, 0.35)
	_stock_tween.parallel().tween_property(stock, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_shown_stock(value: int) -> void:
	_shown_stock = value
	stock.text = "Out of Stock" if value <= 0 else "%d in Stock" % value
