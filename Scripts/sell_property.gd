extends Node2D
## Sell the selected property (Cards.selected_id) by rolling the die (dice_roll.gd):
## SOLD on 2 of its 6 faces on your own, 5 of 6 with a Listing Agent (used up either way).

const SELECT := "CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/"
const DiceRoll = preload("res://Scripts/dice_roll.gd")

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
	for toggle in [listing_agent_toggle, ps_toggle]:
		InkBox.soft_hover(toggle)
		_match_realtor_page(toggle.get_parent() as Panel)
	if not Actions.actions_owned.has("listing_agent"):
		_show_unavailable(listing_agent_toggle)
	var property := _selected_property()
	if not property.is_empty():
		property_icon.texture = Cards.round_icon(property["art"])
		property_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # stay round in any box

# The choice boxes use the same dark sage as the Realtor / Buy Solo page, so the white
# writing reads in every theme (the light olive they had turned pale in some themes).
func _match_realtor_page(box: Panel) -> void:
	if box == null:
		return
	var style := box.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var sage: StyleBoxFlat = style.duplicate()
		sage.bg_color = Color("5d6558")
		box.add_theme_stylebox_override("panel", sage)

# No Listing Agent: the Select button stays tappable but looks faded (the theme's own
# colors, see-through) and tapping it explains how to get one.
func _show_unavailable(toggle: Button) -> void:
	var normal := toggle.get_theme_stylebox("normal")
	var faded: StyleBox = StyleBoxEmpty.new()
	if normal is StyleBoxFlat:
		faded = normal.duplicate()
		faded.bg_color.a *= 0.35
		faded.shadow_size = 0
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		toggle.add_theme_stylebox_override(state, faded)
	for child in toggle.get_parent().get_children():
		if child is Label:   # the "Select" writing sits under the button
			child.text = "None owned"
			child.modulate.a = 0.5
	toggle.toggle_mode = false
	toggle.pressed.connect(func():
		Global.error("You don't have a Listing Agent. Buy one in the Market.", "market"))

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
		Global.error("You are out of Actions. End your turn for more.", "home")
		return
	sell_btn.disabled = true   # no double taps
	Sound.play("continue")
	DiceRoll.open(get_tree(), using_agent, _settle_sale.bind(using_agent))

# The die has landed (dice_roll.gd): apply the sale. Returns the banner's message and any
# cash; the die screen then goes to My Properties and shows them there.
func _settle_sale(sold: bool, agent: bool) -> Dictionary:
	var property := _selected_property()
	var sale_name: String = str(property.get("name", "your property"))
	if agent:
		Actions.consume("listing_agent")
	Global.action_used()
	if property.is_empty():   # lost while the die was rolling (a swap, a disaster...)
		return {"message": "Your property was gone before the sale went through.", "cash": 0}
	Global.SOLD = sold
	if not sold:
		var note := " Your Listing Agent is used up." if agent else ""
		return {"message": "%s didn't sell.%s" % [sale_name, note], "cash": 0}
	var price: int = property["value"]
	Cards.properties_owned.erase(property)
	Stats.add("sales")
	return {"message": "SOLD! %s sold for $%d." % [sale_name, price], "cash": price}
