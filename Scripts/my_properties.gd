extends Node2D
## My Properties: one card per owned property.
## Assign mode (Global.assigning_token = "golden_lock"): tapping a property locks it
## instead of opening it.

const PROPERTY_CARD_SCENE = preload("res://Scenes/properties.tscn")
const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")

@onready var list_of_properties: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/ScrollContainer/list_of_properties
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"


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
	_build_list()

func _exit_tree() -> void:
	Global.assigning_token = ""   # leaving the page cancels assign mode

func _build_list() -> void:
	for child in list_of_properties.get_children():
		child.queue_free()
	for property_data in Cards.properties_owned:
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
