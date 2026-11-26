extends Node2D
## Sell the selected property (Cards.selected_id) by rolling the die (dice_roll.gd):
## SOLD on 2 of its 6 faces on your own, 5 of 6 with a Listing Agent (used up either way).
## Laid out like Real Estate: the property on a card at the top (picture, name, condition,
## what it sells for), two choice cards (Listing Agent / On Your Own, each with its die
## faces), and a big Sell button that says what will happen. The scene keeps its node names
## (the tour points at select/Realtor, select/Private Sale and the sell button).

const SELECT := "CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/"
const DiceRoll = preload("res://Scripts/dice_roll.gd")
const Cozy = preload("res://Scripts/cozy.gd")
const AGENT_ICON := preload("res://Assets/icons/tokens/listing_agent_icon.png")
const PERSON_ICON := preload("res://Assets/icons/person.png")
const CONDITION_COLORS := {"excellent": Color("749c5c"), "good": Color("7b7e63"),
		"fair": Color("c2855f"), "poor": Color("96514b")}

@onready var property_icon: TextureRect = $CanvasLayer/Panel/VBoxContainer/list_of_properties/property_icon
@onready var realtor_emblem: Panel = $CanvasLayer/Panel/realtor_emblem
@onready var personal_emblem: Panel = $CanvasLayer/Panel/personal_emblem
@onready var listing_agent_toggle: Button = get_node(SELECT + "select/Realtor/realtor_toggle")
@onready var ps_toggle: Button = get_node(SELECT + "select/Private Sale/ps_toggle")
@onready var sell_btn: Button = get_node(SELECT + "sell/sell_btn")
@onready var sell_label: Label = get_node(SELECT + "sell/sell_for")

var using_agent := false
var _chosen := false
var _has_agent := false
var _cards := {}   # true (Listing Agent) / false (on your own) -> Cozy choice card


func _ready() -> void:
	sell_btn.disabled = true
	realtor_emblem.visible = false   # the old corner emblems: now on the cards
	personal_emblem.visible = false
	_has_agent = Actions.actions_owned.has("listing_agent")
	_lay_out()
	if not _has_agent:
		listing_agent_toggle.toggle_mode = false
		listing_agent_toggle.pressed.connect(func():
			Global.error("You don't have a Listing Agent. Buy one in the Shop (in Actions).", "market"))
	_paint()

func _selected_property() -> Dictionary:
	for property in Cards.properties_owned:
		if property["id"] == Cards.selected_id:
			return property
	return {}


## ---- LOOK ----
func _lay_out() -> void:
	var column: VBoxContainer = $CanvasLayer/Panel/VBoxContainer
	column.get_node("Title").visible = false
	column.get_node("Control4").custom_minimum_size = Vector2(0, 22)
	property_icon.visible = false
	var list: VBoxContainer = column.get_node("list_of_properties")
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	var summary := _property_card(_selected_property())
	list.add_child(summary)
	list.move_child(summary, 0)

	var margin: MarginContainer = list.get_node("MarginContainer2")
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 0)
	var box: Panel = margin.get_node("Panel")
	box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	ColorTheme.keep(box)
	var inner: MarginContainer = box.get_node("MarginContainer")
	inner.offset_top = 0
	inner.offset_bottom = 0
	for side in ["left", "top", "right", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 0)
	var stack: VBoxContainer = inner.get_node("VBoxContainer")
	stack.add_theme_constant_override("separation", 0)
	for old in ["details", "success_rate", "Control2"]:   # their words are on the cards now
		stack.get_node(old).visible = false
	var row: HBoxContainer = stack.get_node("select")
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size.y = 290
	row.size_flags_vertical = Control.SIZE_FILL
	for spacer in ["Control", "Control2"]:
		row.get_node(spacer).custom_minimum_size.x = 0
	row.get_node("Control3").custom_minimum_size.x = 20
	stack.get_node("spacer").custom_minimum_size.y = 22
	_cards[true] = Cozy.choice_card(row.get_node("Realtor"), listing_agent_toggle,
			row.get_node("Realtor/realtor_select"), AGENT_ICON, "Listing Agent", "SOLD on 5 of 6 sides", _die_faces(5))
	_cards[false] = Cozy.choice_card(row.get_node("Private Sale"), ps_toggle,
			row.get_node("Private Sale/Select"), PERSON_ICON, "On Your Own", "SOLD on 2 of 6 sides", _die_faces(2))
	Cozy.panel_button(stack.get_node("sell"), sell_label, Cozy.RED)
	box.custom_minimum_size.y = 290 + 22 + 96

# The property at the top: its picture, name, condition and what a sale pays.
func _property_card(p: Dictionary) -> Control:
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_left", 22)
	holder.add_theme_constant_override("margin_right", 22)
	var card := Cozy.card(20)
	holder.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	if p.is_empty():
		row.add_child(Cozy.label("This property is no longer yours.", Cozy.FONT, 26))
		return holder
	var art := Cozy.badge(Cards.round_icon(p["art"]), 170, Cozy.INSET, "picture")
	row.add_child(art)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 6)
	row.add_child(words)
	var title := Cozy.label(str(p["name"]), Cozy.HAND, 46)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	var condition := str(p.get("condition", ""))
	if p.get("has_condition", false) and CONDITION_COLORS.has(condition):
		words.add_child(_chip(condition.capitalize(), CONDITION_COLORS[condition]))
	words.add_child(Cozy.gap(4))
	words.add_child(Cozy.caption("Sells for"))
	words.add_child(Cozy.label("$%d" % int(p.get("value", 0)), Cozy.BOLD, 54))
	var keep := Cozy.label("If it doesn't sell, you keep it.", Cozy.FONT, 18, Color(Cozy.CREAM, 0.7))
	words.add_child(keep)
	return holder

func _chip(text: String, colour: Color) -> Control:
	var chip := Cozy.label(text, Cozy.BOLD, 20)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var s := Cozy.style(colour, 14)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	chip.add_theme_stylebox_override("normal", s)
	return chip

# Six little die faces: green ones SOLD, the rest FAIL.
func _die_faces(sold: int) -> Control:
	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", 5)
	faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 6:
		var face := Panel.new()
		face.custom_minimum_size = Vector2(20, 20)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_theme_stylebox_override("panel", Cozy.style(Color("6fae5f") if i < sold else Color("a14a44"), 5))
		ColorTheme.keep(face)
		faces.add_child(face)
	return faces

func _paint() -> void:
	Cozy.paint_choice(_cards[true], "locked" if not _has_agent else ("chosen" if _chosen and using_agent else "off"), "None owned")
	Cozy.paint_choice(_cards[false], "chosen" if _chosen and not using_agent else "off")
	var price := int(_selected_property().get("value", 0))
	if not _chosen:
		sell_label.text = "Choose how to sell"
		sell_label.get_parent().modulate = Color(1, 1, 1, 0.55)
	else:
		sell_label.text = ("Sell for $%d" if using_agent else "Try to sell for $%d") % price
		sell_label.get_parent().modulate = Color.WHITE


## ---- CHOOSING AND SELLING ----
func _on_realtor_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(true)

func _on_ps_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(false)

func _choose(agent: bool) -> void:
	Sound.play("switch")
	using_agent = agent
	_chosen = true
	(ps_toggle if agent else listing_agent_toggle).set_deferred("button_pressed", false)
	sell_btn.disabled = false
	_paint()
	Cozy.pop(_cards[agent]["panel"], 1.04)
	Cozy.pop(sell_label, 1.08)

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
	var article := "an" if sale_name.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a"
	Messages.share_moment("sell", "sold %s %s for $%d" % [article, sale_name, price], price)
	return {"message": "SOLD! %s sold for $%d." % [sale_name, price], "cash": price}
