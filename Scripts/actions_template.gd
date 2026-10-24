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
	title.text = str(action_data.get("name", "Unknown action"))
	cost.text = "$%d" % action_data.get("cost", 0)
	_set_shown_stock(action_data.get("stock", 0))
	button.button_group = group
	_make_row_button()

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
	var normal := StyleBoxEmpty.new()
	var hover := _row_style(Color(Color("ddcf99"), 0.16), Color(0, 0, 0, 0))
	var picked := _row_style(Color(Color("533c44"), 0.45), Color(Color("ddcf99"), 0.9))
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
	style.set_border_width_all(3 if border.a > 0 else 0)
	style.set_corner_radius_all(22)
	return style

func _let_taps_through(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_let_taps_through(child)

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
