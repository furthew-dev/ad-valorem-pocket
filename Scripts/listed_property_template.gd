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
