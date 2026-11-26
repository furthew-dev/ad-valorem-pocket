extends Control
## One row in the Market's action list (Scenes/actions_template.tscn).

const FLASH_COLOR := Color("c94040")

@onready var item_icon: TextureRect = $Panel/HBoxContainer/VBoxContainer/item/item_icon
@onready var title: Label = $Panel/HBoxContainer/VBoxContainer/item/title
@onready var cost: Label = $Panel/HBoxContainer/VBoxContainer/item/cost
@onready var stock: Label = $Panel/HBoxContainer/VBoxContainer/stock
@onready var button: Button = $Panel/HBoxContainer/VBoxContainer/item/item_icon/Button

var selected_card_data: Dictionary = {}
var _shown_stock: int = 0   # tweened, so the label counts down
var _stock_tween: Tween


func setup_card(action_data: Dictionary, group: ButtonGroup) -> void:
	selected_card_data = action_data
	var art_path: String = action_data.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		item_icon.texture = load(art_path)
	else:   # never show the scene's placeholder token (it made LLC look like another token)
		item_icon.texture = null
		push_warning("No picture for action '%s' at %s" % [action_data.get("name", "?"), art_path])
	title.text = str(action_data.get("name", "Unknown action"))
	cost.text = "$%d" % Actions.price_of(action_data)
	_set_shown_stock(action_data.get("stock", 0))
	button.button_group = group
	_make_row_button()
	_add_details(Actions.details_of(action_data))

# My Actions' "Mine" page: a token you own, in the Shop's look. The price becomes how many
# you have ("×2"), the stock line a hint ("Tap to use").
func setup_owned(data: Dictionary, count: int, hint: String) -> void:
	selected_card_data = data
	var art_path: String = data.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		item_icon.texture = load(art_path)
		ColorTheme.ink_icon(item_icon)   # Fortuna card art matches the black token icons
	else:
		item_icon.texture = null
	title.text = str(data.get("name", "Unknown"))
	cost.text = "×%d" % count
	stock.text = hint
	_make_row_button()
	button.toggle_mode = false
	_add_details(Actions.details_of(data))

# Taps decided by the row itself (My Actions): a drag scrolls the list or slides the
# page instead, and the press reaches the list. `on_tap(row)` runs for a real tap only,
# when `is_tap()` agrees (the finger didn't move, the list didn't scroll).
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

# The select button covers the whole row (behind the icon and text), and its hover and
# selected looks use the palette instead of the engine's greys, so they follow the theme.
func _make_row_button() -> void:
	button.set_meta("row", self)
	button.reparent(self, false)
	move_child(button, 0)   # drawn behind the row's content
	button.custom_minimum_size = Vector2.ZERO
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.offset_top = 4
	button.offset_bottom = -4
	button.offset_left = 12   # the card stops short of the screen's edges
	button.offset_right = -12
	# Each row sits on a soft plum card (the shared card look); picked = a gold edge.
	var normal := _row_style(Color(Color("533c44"), 0.5), Color(Color("ddcf99"), 0.25))
	var hover := _row_style(Color(Color("533c44"), 0.62), Color(Color("ddcf99"), 0.45))
	var picked := _row_style(Color(Color("533c44"), 0.8), Color(Color("ddcf99"), 0.95))
	_cozy_details()
	for state in ["normal", "normal_mirrored", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	for state in ["hover", "hover_mirrored"]:
		button.add_theme_stylebox_override(state, hover)
	for state in ["pressed", "pressed_mirrored", "hover_pressed", "hover_pressed_mirrored"]:
		button.add_theme_stylebox_override(state, picked)
	_let_taps_through($Panel)   # taps anywhere on the row reach the button

func _row_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3 if border.a > 0.5 else (2 if border.a > 0 else 0))
	style.set_corner_radius_all(26)
	style.anti_aliasing = true
	return style

# On the plum cards: the icon in cream (black was hard to see), a soft dotted-looking
# cream line instead of the black one, and the writing kept cream in every theme.
const ICON_TINT := """
shader_type canvas_item;
void fragment() { COLOR = vec4(vec3(0.965, 0.949, 0.882), texture(TEXTURE, UV).a * COLOR.a); }
"""
static var _icon_material: ShaderMaterial
func _cozy_details() -> void:
	if _icon_material == null:
		var shader := Shader.new()
		shader.code = ICON_TINT
		_icon_material = ShaderMaterial.new()
		_icon_material.shader = shader
	if item_icon.texture and ColorTheme._mono_color(item_icon.texture) != "":   # one-colour icons only
		item_icon.material = _icon_material
		ColorTheme.keep(item_icon)
	var line := StyleBoxLine.new()
	line.color = Color(Color("ddcf99"), 0.35)
	line.thickness = 2
	var separator := title.get_parent().get_node_or_null("HSeparator")
	if separator:
		separator.add_theme_stylebox_override("separator", line)
	for l in [title, cost, stock]:
		l.add_theme_color_override("font_color", Color("f6f2e1") if l != stock else Color(Color("f6f2e1"), 0.75))
		ColorTheme.keep(l)

func _let_taps_through(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_let_taps_through(child)

## ---- DETAILS (tap "Details" to read what it does before buying) ----
const ROW_HEIGHT := 145.0
var _details: Label
var _details_btn: Button

func _add_details(text: String) -> void:
	if text == "":
		return
	var column := stock.get_parent() as VBoxContainer
	var line := HBoxContainer.new()   # "12 in Stock ............ Details v"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	column.move_child(line, stock.get_index())
	stock.reparent(line, false)
	stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_btn = Button.new()
	_details_btn.text = "Details  v"
	_details_btn.flat = true
	_details_btn.focus_mode = Control.FOCUS_NONE
	_details_btn.add_theme_font_size_override("font_size", 20)
	_details_btn.add_theme_color_override("font_color", Color(Color("ddcf99"), 0.85))
	_details_btn.add_theme_color_override("font_hover_color", Color("ddcf99"))
	_details_btn.add_theme_color_override("font_pressed_color", Color("ddcf99"))
	_details_btn.mouse_filter = Control.MOUSE_FILTER_STOP   # its own tap, not the row's
	_details_btn.pressed.connect(_toggle_details)
	line.add_child(_details_btn)
	_details = Label.new()
	_details.text = text
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 21)
	_details.add_theme_color_override("font_color", Color(Color("ddcf99"), 0.9))
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.visible = false
	column.add_child(_details)

func _toggle_details() -> void:
	Sound.play("switch")
	_details.visible = not _details.visible
	_details_btn.text = "Details  ^" if _details.visible else "Details  v"
	var column := _details.get_parent() as Control
	_details.custom_minimum_size.x = maxf(column.size.x, 300.0)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var extra := (_details.get_combined_minimum_size().y + 30.0) if _details.visible else 0.0   # room below the last line
	custom_minimum_size.y = ROW_HEIGHT + extra
	$Panel.custom_minimum_size.y = ROW_HEIGHT + extra
	$Panel.size.y = ROW_HEIGHT + extra
	column.custom_minimum_size.y = 135.0 + extra

# Animates the stock label to the card's current stock: counts down, flashes and pops.
func update_stock() -> void:
	var target: int = selected_card_data.get("stock", 0)
	if _stock_tween and _stock_tween.is_valid():
		_stock_tween.kill()
	stock.pivot_offset = stock.size / 2
	_stock_tween = create_tween()
	_stock_tween.tween_method(_set_shown_stock, _shown_stock, target, 0.4)
	_stock_tween.parallel().tween_property(stock, "modulate", FLASH_COLOR, 0.15)
	_stock_tween.parallel().tween_property(stock, "scale", Vector2(1.3, 1.3), 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stock_tween.tween_property(stock, "modulate", Color.WHITE, 0.35)
	_stock_tween.parallel().tween_property(stock, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_shown_stock(value: int) -> void:
	_shown_stock = value
	stock.text = "Out of Stock" if value <= 0 else "%d in Stock" % value
