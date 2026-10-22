extends Node2D
## Market > Actions: buy action tokens.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const ACTION_CARD_SCENE = preload("res://Scenes/actions_template.tscn")

@onready var list_of_actions: VBoxContainer = $CanvasLayer/Panel/ScrollContainer/VBoxContainer
@onready var buy: Button = $CanvasLayer/Panel2/buy
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"

var button_group := ButtonGroup.new()
var selected_card: Control = null       # the actions_template row
var selected_action: Dictionary = {}    # e.g. Actions.certificate_of_deposit
var _buying_key := ""                   # our own purchase animates after its pop-up closes


func _ready() -> void:
	buy.disabled = true
	button_group.pressed.connect(_on_group_pressed)
	for action_data in Actions.action_types:
		var card_instance = ACTION_CARD_SCENE.instantiate()
		list_of_actions.add_child(card_instance)
		card_instance.setup_card(action_data, button_group)
	Market.stock_changed.connect(_on_stock_changed)   # someone (maybe another player) bought one

func _on_stock_changed(key: String, _stock: int) -> void:
	if key == _buying_key:
		return
	for card in list_of_actions.get_children():
		if _key_of(card.selected_card_data) == key:
			card.update_stock()

func _key_of(action: Dictionary) -> String:
	return str(action.get("name", "")).to_lower().replace(" ", "_")

func _on_group_pressed(button: BaseButton) -> void:
	Sound.play("switch")
	buy.disabled = false
	selected_card = button.owner   # the button belongs to the card scene
	selected_action = selected_card.selected_card_data

func _on_buy_pressed() -> void:
	var problem := _purchase_problem()
	if problem != "":
		Sound.play("error")
		_show_message(problem)
		return
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout("Are you sure you want to buy %s?" % selected_action["name"], "Yes", "No")
	popup.left_pressed.connect(_on_popup_confirm)

# Returns why this purchase can't happen, or "" if it can.
func _purchase_problem() -> String:
	if Global.ACTIONS <= 0:
		return "You are out of Actions."
	if selected_action["stock"] <= 0:
		return "%s is out of stock." % selected_action["name"]
	if not Global.can_afford(selected_action["cost"]):
		return "You don't have enough funds."
	if selected_action["name"] == "Land Expansion" and Cards.owns_land_expansion():
		return "You cannot own more than one Land Expansion."
	if selected_action["name"] == "LLC" and "llc" in Actions.actions_owned:
		return "You already own an LLC."
	return ""

func _on_popup_confirm() -> void:
	# Re-check at the moment of purchase, before any money moves.
	var problem := _purchase_problem()
	if problem != "":
		Sound.play("error")
		_show_message(problem)
		return

	var action_name: String = selected_action["name"]
	var key := _key_of(selected_action)
	var card := selected_card
	_buying_key = key
	buy.disabled = true
	var granted := await Market.buy_action(key)   # the host owns the shared stock
	buy.disabled = false
	if not granted:
		_buying_key = ""
		Sound.play("error")
		_show_message("Sorry, %s just sold out." % action_name)
		if is_instance_valid(card):
			card.update_stock()
		return
	if not Global.spend(selected_action["cost"]):
		_buying_key = ""
		_show_message("You don't have enough funds.")
		return

	var where := "your inventory"
	match key:
		"llc":
			Actions.llc_added()   # must run before the append below
			Actions.actions_owned.append(key)
		"land_expansion":   # an empty lot in My Properties, not a token
			Global.PROPERTY_CAPACITY += 1
			Cards.properties_owned.append(Cards.make_lot("land_expansion"))
			where = "My Properties. Build on it with a Contractor"
		_:
			Actions.actions_owned.append(key)
	Global.action_used()

	await _show_message("%s has been added to %s." % [action_name, where])
	_buying_key = ""
	if is_instance_valid(card):
		card.update_stock()   # animate once the pop-up is out of the way

func _show_message(text: String) -> void:
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout(text, "OK", "")
	await popup.tree_exited
