extends Node2D
## My Properties: one card per owned property.
## Assign mode (Global.assigning_token = "golden_lock"): tapping a property locks it
## instead of opening it.

const PROPERTY_CARD_SCENE = preload("res://Scenes/properties.tscn")
const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
# Sort button: tap to switch. "" = the order you got them in (until you first sort).
const SORT_LABELS := {"": "Sort", "name": "A - Z", "value": "$ High - Low"}

@onready var list_of_properties: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/ScrollContainer/list_of_properties
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"
@onready var header: HBoxContainer = $CanvasLayer/Panel/VBoxContainer/Title/header

var _sort_mode := ""
var _sort_button: Button


func _ready() -> void:
	Cards.reset_id()
	if Global.new_property and not Cards.properties_owned.is_empty():
		var added := Global.new_property_name
		if added == "":
			added = Cards.properties_owned[-1]["name"]
		Global.banner("%s added to inventory." % added)
	Global.new_property = false
	Global.new_property_name = ""
	if Global.assigning_token == "golden_lock":
		Global.banner("Choose a property to protect with the Golden Lock.")
	_sort_mode = Network.load_setting("my_properties", "sort", "")
	_add_sort_button()
	_build_list()

## ---- SORTING ----
func _add_sort_button() -> void:
	_sort_button = Button.new()
	_sort_button.custom_minimum_size = Vector2(230, 70)
	_sort_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sort_button.add_theme_font_override("font", FONT)
	_sort_button.add_theme_font_size_override("font_size", 34)
	InkBox.apply(_sort_button, Color(1, 1, 1))
	_sort_button.pressed.connect(_on_sort_pressed)
	header.add_child(_sort_button)
	header.move_child(_sort_button, header.get_child_count() - 2)   # before the right-hand spacer
	_sort_button.text = SORT_LABELS[_sort_mode]

func _on_sort_pressed() -> void:
	Sound.play("switch")
	_sort_mode = "value" if _sort_mode == "name" else "name"
	Network.save_setting("my_properties", "sort", _sort_mode)
	_sort_button.text = SORT_LABELS[_sort_mode]
	_build_list()

# The properties in display order (the list itself stays in the order you got them).
func _sorted_properties() -> Array:
	var list: Array = Cards.properties_owned.duplicate()
	match _sort_mode:
		"name":
			list.sort_custom(func(a, b): return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
		"value":
			list.sort_custom(func(a, b):
				if a.get("value", 0) != b.get("value", 0):
					return a.get("value", 0) > b.get("value", 0)
				return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return list

func _exit_tree() -> void:
	Global.assigning_token = ""   # leaving the page cancels assign mode

func _build_list() -> void:
	for child in list_of_properties.get_children():
		child.queue_free()
	for property_data in _sorted_properties():
		var card_instance = PROPERTY_CARD_SCENE.instantiate()
		list_of_properties.add_child(card_instance)
		card_instance.setup_card(property_data)
		card_instance.assign_requested.connect(_on_assign_requested.bind(property_data))


## ---- GOLDEN LOCK ----
func _on_assign_requested(property: Dictionary) -> void:
	if property.get("has_golden_lock", false):
		Global.error("%s is already locked." % property["name"])
		return
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout("Lock your %s with the Golden Lock?" % property["name"], "Yes", "No")
	popup.left_pressed.connect(_lock.bind(property))

func _lock(property: Dictionary) -> void:
	if Global.ACTIONS <= 0 or not Actions.consume("golden_lock"):
		Global.error("You can't use a Golden Lock right now.")
		return
	property["has_golden_lock"] = true
	Global.action_used()
	Global.assigning_token = ""
	Global.banner("%s is locked: it can't be harmed or sold." % property["name"])
	_build_list()
