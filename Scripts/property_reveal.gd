extends Node2D
## Market > Real Estate: reveals 1 property (or 3 with a Realtor) and lets the player buy one.
## Build mode (Global.build_lot_id set): building on an empty lot. Every property type
## still in the deck is listed; after picking one you choose its condition and pay for it.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const LISTING_SCENE = preload("res://Scenes/listed_property_template.tscn")
const LOAN_SCENE = preload("res://Scenes/loan.tscn")
const CHOICE_MENU = preload("res://Scripts/choice_menu.gd")
const CANCEL := "Cancel"
const TRANSITION_SCENE = preload("res://Scenes/transition.tscn")
const REALTOR_FINE := 3

const VBOX := "CanvasLayer/Panel/VBoxContainer/revealed_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/"

@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"
@onready var list_of_properties: HBoxContainer = $CanvasLayer/Panel/VBoxContainer/revealed_properties/ScrollContainer/list_of_properties
@onready var details: Label = get_node(VBOX + "details")
@onready var purchase_btn: Button = get_node(VBOX + "HBoxContainer/Purchase/purchase_btn")
@onready var purchase_panel: Panel = get_node(VBOX + "HBoxContainer/Purchase")

var button_group := ButtonGroup.new()
var selected_card: Dictionary = {}
var build_lot: Dictionary = {}   # the empty lot being built on (build mode only)


func _ready() -> void:
	button_group.pressed.connect(_on_group_pressed)
	ui_menu_frame.disable_buttons()
	Global.erase_scenes()
	_set_purchase_ready(false)
	setup()

func setup() -> void:
	if Global.build_lot_id != 0:
		_setup_build_mode()
		return
	await Cards.return_revealed()   # anything left over from an interrupted visit
	var reveal_count := 3 if Global.using_realtor else 1
	var cards := await Cards.reveal(reveal_count)   # drawn from the shared deck
	if cards.is_empty():
		Global.error("The property deck is empty.")
	for card in cards:
		var listing = LISTING_SCENE.instantiate()
		list_of_properties.add_child(listing)
		listing.setup_property(card, button_group)

# Purchase stays clickable (so it can explain itself) but looks dimmed until a pick is made.
func _set_purchase_ready(is_ready: bool) -> void:
	purchase_panel.modulate.a = 1.0 if is_ready else 0.5

func _on_group_pressed(button: BaseButton) -> void:
	Sound.play("switch")
	selected_card = button.owner.card_data
	_set_purchase_ready(true)


## ---- PURCHASE ----
func _on_purchase_btn_pressed() -> void:
	if selected_card.is_empty():
		Global.error("Select a property first.")
		return
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions")
		return
	if not build_lot.is_empty():
		_build_selected()
		return

	var cost: int = selected_card["value"]
	if not Global.can_afford(cost):
		var popup = POPUP_SCENE.instantiate()
		add_child(popup)
		popup.layout("Insufficient funds. Take loan?", "Yes", "No")
		popup.left_pressed.connect(_yes_take_loan)
		return

	Sound.play("continue")
	purchase_btn.disabled = true
	Global.spend(cost, str(selected_card["name"]))
	Global.action_used()
	Global.new_property = true
	if Global.using_realtor:
		Actions.consume("realtor")

	# Move the bought card into the hand; the rest go back into the shared deck.
	Cards.properties_revealed.erase(selected_card)
	Cards.properties_owned.append(selected_card)
	Cards.return_revealed()

	var transition = TRANSITION_SCENE.instantiate()
	add_child(transition)
	transition.run_animation(Global.purchasing.app_color, Global.purchasing.app_anim, Global.purchasing.app_url)

func _yes_take_loan(amount: int = -1) -> void:
	var loan = LOAN_SCENE.instantiate()
	add_child(loan)
	loan.set_min_value(amount if amount > 0 else selected_card["value"])
	var loans_before := Global.loans.size()
	await loan.tree_exited
	if Global.loans.size() > loans_before:
		Global.banner("New loan of $%d added. You can now purchase." % Global.loans[-1]["loan_balance"])


## ---- BUILD MODE ----
func _setup_build_mode() -> void:
	for p in Cards.properties_owned:
		if p["id"] == Global.build_lot_id:
			build_lot = p
	if build_lot.is_empty():
		Global.build_lot_id = 0
		Global.error("That lot is gone.")
		return
	details.text = "Build on your %s (+$%d value). Pick a property, then its condition." \
			% [build_lot["name"], build_lot["value"]]
	for property_name in Cards.buildable_names():
		var template: Dictionary = Cards.templates_by_name[property_name]
		var card := Cards._make_property(template, "excellent")   # preview only
		if Cards.has_condition(template):
			var values: Dictionary = template["condition"]["value"]
			card["condition_text"] = "any condition"
			card["price_text"] = "$%d-%d" % [values["poor"], values["excellent"]]
			card["rent_text"] = "up to $%d" % template["condition"]["rent"]["excellent"]
		var listing = LISTING_SCENE.instantiate()
		list_of_properties.add_child(listing)
		listing.setup_property(card, button_group)

func _build_selected() -> void:
	var property_name: String = selected_card["name"]
	var condition := "excellent"
	if Cards.has_condition(Cards.templates_by_name[property_name]):
		var options := []
		for level in ["excellent", "good", "fair", "poor"]:
			options.append("%s - $%d" % [level.capitalize(), Cards.price_of(property_name, level)])
		options.append(CANCEL)
		var menu = CHOICE_MENU.new()
		get_tree().root.add_child(menu)
		menu.setup("Build %s in which condition?" % property_name, options)
		var choice: String = await menu.chosen
		if choice == CANCEL:
			return
		condition = choice.get_slice(" ", 0).to_lower()

	var cost := Cards.price_of(property_name, condition)
	if not Global.can_afford(cost):
		var popup = POPUP_SCENE.instantiate()
		add_child(popup)
		popup.layout("Building costs $%d. Take a loan?" % cost, "Yes", "No")
		var wants_loan := [false]
		popup.left_pressed.connect(func(): wants_loan[0] = true)
		await popup.tree_exited
		if not wants_loan[0]:
			return
		await _yes_take_loan(cost)
		if not Global.can_afford(cost):
			return

	purchase_btn.disabled = true
	if not await Market.take_property(property_name):   # the deck is shared: it may be gone
		purchase_btn.disabled = false
		Global.error("Someone just took the last %s." % property_name)
		return
	Sound.play("continue")
	Global.spend(cost, "Build %s" % property_name)
	Actions.consume("contractor")
	Global.action_used()
	var built := Cards.build_on_lot(build_lot, property_name, condition)
	Global.build_lot_id = 0
	Global.new_property = true
	Global.new_property_name = "%s (built on %s)" % [built["name"], build_lot["name"]]
	var transition = TRANSITION_SCENE.instantiate()
	add_child(transition)
	transition.run_animation(Global.purchasing.app_color, Global.purchasing.app_anim, Global.purchasing.app_url)


## ---- CANCEL ----
func _on_cancel_btn_pressed() -> void:
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout("Stop building?" if not build_lot.is_empty() else "Are you sure you want to back out?", "Yes", "No")
	popup.left_pressed.connect(_on_cancel_confirmed)

func _on_cancel_confirmed() -> void:
	if not build_lot.is_empty():
		Global.build_lot_id = 0
		Cards.selected_id = build_lot["id"]
		get_tree().change_scene_to_file("res://Scenes/property_info.tscn")
		return
	if Global.using_realtor:
		Global.remove_cash(REALTOR_FINE, "Realtor Fee")
		Actions.consume("realtor")
		await Global.show_notice("Realtor fined you $%d" % REALTOR_FINE)
	await Cards.return_revealed()   # back into the shared deck
	get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
