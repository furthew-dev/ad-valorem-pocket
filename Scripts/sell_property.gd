extends Node2D
## Sell the selected property (Cards.selected_id). Private sale sells on a 1-2 (of 6);
## a Listing Agent sells on a 1-5 and is used up either way.

const SELECT := "CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/"
const TRANSITION_SCENE = preload("res://Scenes/transition.tscn")
const PRIVATE_SALE_ODDS := 2   # sells on a roll of this or lower
const AGENT_SALE_ODDS := 5

@onready var property_icon: TextureRect = $CanvasLayer/Panel/VBoxContainer/list_of_properties/property_icon
@onready var realtor_emblem: Panel = $CanvasLayer/Panel/realtor_emblem
@onready var personal_emblem: Panel = $CanvasLayer/Panel/personal_emblem
@onready var listing_agent_toggle: Button = get_node(SELECT + "select/Realtor/realtor_toggle")
@onready var ps_toggle: Button = get_node(SELECT + "select/Private Sale/ps_toggle")
@onready var sell_btn: Button = get_node(SELECT + "sell/sell_btn")

var using_agent := false


func _ready() -> void:
	sell_btn.disabled = true
	realtor_emblem.visible = false
	personal_emblem.visible = false
	listing_agent_toggle.disabled = not Actions.actions_owned.has("listing_agent")
	for toggle in [listing_agent_toggle, ps_toggle]:
		InkBox.soft_hover(toggle)
	var property := _selected_property()
	if not property.is_empty():
		property_icon.texture = Cards.round_icon(property["art"])
		property_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # stay round in any box

func _selected_property() -> Dictionary:
	for property in Cards.properties_owned:
		if property["id"] == Cards.selected_id:
			return property
	return {}

func _on_realtor_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(true)

func _on_ps_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(false)

func _choose(agent: bool) -> void:
	Sound.play("switch")
	using_agent = agent
	(ps_toggle if agent else listing_agent_toggle).set_deferred("button_pressed", false)
	realtor_emblem.visible = agent
	personal_emblem.visible = not agent
	sell_btn.disabled = false

func _on_sell_btn_pressed() -> void:
	if _selected_property().is_empty():   # destroyed, swapped or auctioned while this screen was open
		Global.error("You no longer own this property.")
		get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
		return
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions")
		return
	Sound.play("dice")
	var roll := randi_range(1, 6)
	var odds := AGENT_SALE_ODDS if using_agent else PRIVATE_SALE_ODDS
	if using_agent:
		Actions.consume("listing_agent")
	Global.SOLD = roll <= odds
	print("Rolled %d, sold: %s" % [roll, Global.SOLD])
	var price := 0
	if Global.SOLD:
		var property := _selected_property()
		price = property["value"]
		Cards.properties_owned.erase(property)
	sell_btn.disabled = true   # no double taps while the animation plays
	var transition = TRANSITION_SCENE.instantiate()
	add_child(transition)
	transition.run_animation(Global.mystery.app_color, "sold" if Global.SOLD else "failed",
			Global.mystery.app_url, _on_result_revealed.bind(price))

# The "?" lead-in has finished and SOLD / FAILED is showing: the money (with its cash
# register) arrives now, or the crowd groans.
func _on_result_revealed(price: int) -> void:
	if Global.SOLD:
		Global.add_cash(price, "Property Sale")
	else:
		Sound.play("aww")
