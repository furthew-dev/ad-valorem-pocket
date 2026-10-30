extends Node2D
## My Properties: one card per owned property.
## Assign mode (Global.assigning_token = "golden_lock"): tapping a property locks it
## instead of opening it.

const PROPERTY_CARD_SCENE = preload("res://Scenes/properties.tscn")
const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
# Sort button: tap to switch between A-Z and highest value first.
# "" = the order you got them in (until you first sort).

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

## ---- CAPACITY ("Capacity 3 / 5 Properties") ----
# 4 to start; each Land Expansion and Inheritance adds one. Empty lots count, as they do
# when buying. Shown in the header band so players know if they can keep buying.
var capacity_pill: PanelContainer   # (the tutorial points at it)

func capacity_text() -> String:
	return "Capacity  %d / %d Properties" % [Cards.properties_owned.size(), Global.PROPERTY_CAPACITY]

func _add_capacity_label() -> void:
	var full := Cards.properties_owned.size() >= Global.PROPERTY_CAPACITY
	capacity_pill = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e2328") if not full else Color("793c44")
	style.border_color = Color("ddcf99")
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	capacity_pill.add_theme_stylebox_override("panel", style)
	capacity_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	capacity_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = capacity_text() + ("  ·  Full" if full else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("f6f2e1"))
	capacity_pill.add_child(label)
	var centre := CenterContainer.new()   # top of the list (the header band sits under the frame)
	centre.custom_minimum_size = Vector2(0, 76)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(capacity_pill)
	list_of_properties.add_child(centre)

## ---- SORTING ----
func _add_sort_button() -> void:
	# Sits in the empty space to the right of the (centred) property cards, under the header.
	_sort_button = Button.new()
	_sort_button.custom_minimum_size = Vector2(92, 92)
	_sort_button.size = Vector2(92, 92)
	_sort_button.add_theme_font_override("font", FONT)
	_sort_button.add_theme_font_size_override("font_size", 30)
	InkBox.apply(_sort_button, Color("ddcf99"))
	_sort_button.pressed.connect(_on_sort_pressed)
	$CanvasLayer/Panel.add_child(_sort_button)
	_sort_button.text = _sort_text()
	_place_sort_button.call_deferred()

func _place_sort_button() -> void:
	var scroll: Control = list_of_properties.get_parent()
	var area := scroll.get_global_rect()
	var panel: Control = $CanvasLayer/Panel
	var top_left := panel.get_global_transform().affine_inverse() * Vector2(area.end.x - 100, area.position.y + 12)
	_sort_button.position = top_left

func _sort_text() -> String:
	return {"": "Sort", "name": "Sort\nA-Z", "value": "Sort\nValue"}[_sort_mode]

func _on_sort_pressed() -> void:
	Sound.play("switch")
	_sort_mode = "value" if _sort_mode == "name" else "name"
	Network.save_setting("my_properties", "sort", _sort_mode)
	_sort_button.text = _sort_text()
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
	_add_capacity_label()
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
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions. End your turn for more.", "home")
		return
	if not Actions.consume("golden_lock"):
		Global.error("You need a Golden Lock token.", "market")
		return
	property["has_golden_lock"] = true
	Global.action_used()
	Global.assigning_token = ""
	Global.banner("%s is locked: it can't be harmed or sold." % property["name"])
	_build_list()
