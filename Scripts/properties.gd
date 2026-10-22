extends Control
## One row in My Properties (Scenes/properties.tscn). Tapping it opens property_info,
## or, while My Properties is assigning a Golden Lock, asks to lock this property.

signal assign_requested

const GOLD := Color("d4af37")

@onready var property_button: Button = $Panel/property_button
@onready var texture_rect: TextureRect = $Panel/HBoxContainer/TextureRect
@onready var property_name: Label = $Panel/HBoxContainer/VBoxContainer/property_name
@onready var current_value: Label = $Panel/HBoxContainer/VBoxContainer/HBoxContainer/current_value
@onready var current_rent: Label = $Panel/HBoxContainer/VBoxContainer/HBoxContainer/current_rent
@onready var value: Label = $Panel/HBoxContainer/VBoxContainer/HBoxContainer2/value
@onready var condition: Label = $Panel/HBoxContainer/VBoxContainer/HBoxContainer2/condition
@onready var rent: Label = $Panel/HBoxContainer/VBoxContainer/HBoxContainer2/rent
@onready var skybnb: Panel = $Panel/skybnb
@onready var double: Panel = $Panel/Double
@onready var panel: Panel = $Panel
@onready var insurance: Panel = $Panel/insurance

var current_scene := "res://Scenes/my_properties.tscn"
var this_card_id := 0


func setup_card(property_data: Dictionary) -> void:
	this_card_id = property_data.get("id", 0)
	property_name.text = str(property_data.get("name", "Unknown Property"))
	current_value.text = "$%d" % property_data.get("value", 0)
	current_rent.text = "$%d" % property_data.get("rent", 0)

	var shown_condition := "excellent"
	if property_data.get("has_condition", false):
		shown_condition = property_data.get("condition", "excellent")
	condition.text = "Condition: " + shown_condition.capitalize()
	if Cards.is_lot(property_data):
		condition.text = "Empty lot: build here"

	if property_data.get("has_golden_lock", false):
		_add_gold_border()

	insurance.visible = property_data.get("has_insurance", false)
	skybnb.visible = property_data.get("has_skybnb", false)
	double.visible = property_data.get("has_double", false)

	var art_path: String = property_data.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		texture_rect.texture = load(art_path)

# Golden Lock: same panel, with a gold border around it.
func _add_gold_border() -> void:
	var style = panel.get_theme_stylebox("panel").duplicate()
	if not style is StyleBoxFlat:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.set_corner_radius_all(40)
	style.border_color = GOLD
	style.set_border_width_all(6)
	panel.add_theme_stylebox_override("panel", style)

func _on_property_button_pressed() -> void:
	Sound.play("click")
	if Global.assigning_token != "":
		assign_requested.emit()
		return
	Global.save_scene(current_scene)
	Cards.selected_id = this_card_id
	get_tree().change_scene_to_file("res://Scenes/property_info.tscn")
