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
