extends Node2D
## My Actions: one row per kind of owned token, with a count. Tapping Sabotage
## lets you pick a player to sabotage.

const ACTION_ROW_SCENE = preload("res://Scenes/list_of_actions.tscn")
const CHOICE_MENU = preload("res://Scripts/choice_menu.gd")
const CANCEL := "Cancel"

@onready var list_of_actions: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/ScrollContainer/list_of_actions
@onready var title: Label = $CanvasLayer/Panel/VBoxContainer/Title/header/title


var _news: Array = []   # action keys you have more of since this app was last open

func _ready() -> void:
	Cards.reset_id()
	_news = Notices.new_actions()
	Notices.mark_app("my_actions")
	_build_list()
	_news = []   # pulse once, not again after using a token

func _exit_tree() -> void:
	Notices.mark_app("my_actions")

func _build_list() -> void:
	for child in list_of_actions.get_children():
		child.queue_free()

	var counts := {}
	for action in Actions.actions_owned:
		counts[action] = counts.get(action, 0) + 1

	for action in counts:
		if not Actions.all_actions.has(action):
			push_warning("Unknown action: %s" % action)
			continue
		var row = ACTION_ROW_SCENE.instantiate()
		list_of_actions.add_child(row)
		row.setup_card(Actions.all_actions[action], counts[action])
		row.use_requested.connect(_on_use_requested.bind(action))
		if _news.has(action):
			_highlight(row)

	# Fortunas kept in hand (Just Say No...): shown here so you know you have them.
	var kept := {}   # effect -> [card, count]
	for card in Fortunas.fortunas_owned:
		var effect: String = card.get("effect", card.get("name", ""))
		if kept.has(effect):
			kept[effect][1] += 1
		else:
			kept[effect] = [card, 1]
	for effect in kept:
		var row = ACTION_ROW_SCENE.instantiate()
		list_of_actions.add_child(row)
		row.setup_card(kept[effect][0], kept[effect][1])
		row.use_requested.connect(_on_kept_fortuna_pressed)
		if _news.has("fortuna:" + str(effect)):
			_highlight(row)

	var nothing: bool = Actions.actions_owned.is_empty() and Fortunas.fortunas_owned.is_empty()
	title.text = "You have no Actions" if nothing else ""

# A new or extra token: its card's outline fades in and out (and it's scrolled into view).
func _highlight(row: Control) -> void:
	var panel: Control = row.get_node("Panel")
	Notices.pulse_outline(panel, 30, 6.0, 5)
	var scroll := list_of_actions.get_parent() as ScrollContainer
	if scroll:
		(func(): if is_instance_valid(row): scroll.ensure_control_visible(row)).call_deferred()

func _on_use_requested(_data: Dictionary, key: String) -> void:
	match key:
		"sabotage":
			_use_sabotage()
		"golden_lock":   # pick the property in My Properties
			if Global.ACTIONS <= 0:
				Global.error("You are out of Actions. End your turn for more.", "home")
				return
			Global.assigning_token = "golden_lock"
			Global.save_scene("res://Scenes/my_actions.tscn")
			get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
		_:
			_explain_or_go(key)

# Every token does something when tapped: it opens the screen where it's used, with a
# tip, or (for ones that work by themselves) says what it's doing for you.
const GO_TO := {
	"contractor": ["my_properties", "Contractor: pick a property to upgrade, or a lot to build on."],
	"listing_agent": ["my_properties", "Listing Agent: pick the property to sell. It's used when you sell (wins on 1 to 5)."],
	"skybnb": ["my_properties", "SkyBnB: pick a property to add it to (doubles the rent)."],
	"double": ["my_properties", "Double: pick a property to add it to (doubles the value)."],
	"insurance": ["my_properties", "Insurance: pick a property to insure."],
	"land_expansion": ["my_properties", "Land Expansion: build on your empty lot with a Contractor."],
	"hotel_suite": ["my_properties", "Suite: open your Hotel Resort to add it with a Contractor."],
	"cruise_suite": ["my_properties", "Suite: open your Luxury Cruise to add it with a Contractor."],
	"certificate_of_deposit": ["bank", "Certificates of Deposit: shown under Investments. One is worth $50, a pair $110."],
	"realtor": ["real_estate", "Realtor: choose Realtor to see 3 properties and pick one ($3 if you buy none)."],
}
const EXPLAIN := {
	"llc": "LLC: you get 5 Actions every turn instead of 3.",
	"attorney": "Attorney: blocks the next legal Fortuna that hits you (Auction, Lawsuits, Mold, Swap) by itself.",
}

func _explain_or_go(key: String) -> void:
	if GO_TO.has(key):
		Global.go_to(GO_TO[key][0], GO_TO[key][1])
	elif EXPLAIN.has(key):
		Global.banner(EXPLAIN[key])
	else:
		Global.banner(Actions.details_of(Actions.all_actions.get(key, {})) if Actions.all_actions.has(key) else "This is kept until it's needed.")


func _on_kept_fortuna_pressed(card: Dictionary) -> void:
	if card.get("effect", "") == "block_fortuna":
		Global.banner("Just Say No is offered when a harmful Fortuna or a sabotage hits you.")
	else:
		Global.banner("%s is kept for when it's needed." % card.get("name", "This card"))


## ---- SABOTAGE ----
var _choosing_target := false   # the "who to sabotage" menu is open (ignore repeat taps)

func _use_sabotage() -> void:
	if _choosing_target:
		return
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions. End your turn for more.", "home")
		return
	var names := {}   # display name -> peer id
	for id in Network.players:
		if id != multiplayer.get_unique_id():
			names[Network.players[id]] = id
	if not Network.is_online() or names.is_empty():
		Global.error("There's nobody to sabotage.")
		return

	var menu = CHOICE_MENU.new()
	get_tree().root.add_child(menu)
	var options: Array = names.keys()
	options.append(CANCEL)
	menu.setup("Who do you want to sabotage?", options)
	_choosing_target = true
	var choice = await menu.chosen
	_choosing_target = false
	if choice == CANCEL or not names.has(choice):
		return
	var target_id: int = names[choice]
	if not Network.players.has(target_id):
		Global.error("%s has left the game." % choice)
		return

	if not Actions.consume("sabotage"):   # checked again: it may have been used meanwhile
		Global.error("You need a Sabotage token.", "market")
		return
	Global.action_used()
	Fortunas.sabotage(target_id)
	_build_list()
