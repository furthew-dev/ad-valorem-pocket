extends Node2D
## My Actions: one row per kind of owned token, with a count. Tapping Sabotage
## lets you pick a player to sabotage.

const ACTION_ROW_SCENE = preload("res://Scenes/list_of_actions.tscn")
const CHOICE_MENU = preload("res://Scripts/choice_menu.gd")
const CANCEL := "Cancel"

@onready var list_of_actions: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/ScrollContainer/list_of_actions
@onready var title: Label = $CanvasLayer/Panel/VBoxContainer/Title/header/title


func _ready() -> void:
	Cards.reset_id()
	_build_list()

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

	title.text = "You have no Actions" if Actions.actions_owned.is_empty() else ""

func _on_use_requested(_data: Dictionary, key: String) -> void:
	match key:
		"sabotage":
			_use_sabotage()
		"golden_lock":   # pick the property in My Properties
			if Global.ACTIONS <= 0:
				Global.error("You are out of Actions")
				return
			Global.assigning_token = "golden_lock"
			Global.save_scene("res://Scenes/my_actions.tscn")
			get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
		"double", "skybnb", "contractor":
			Global.banner("Open a property in My Properties to use this.")


## ---- SABOTAGE ----
func _use_sabotage() -> void:
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions")
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
	var choice = await menu.chosen
	if choice == CANCEL or not names.has(choice):
		return
	var target_id: int = names[choice]
	if not Network.players.has(target_id):
		Global.error("%s has left the game." % choice)
		return

	Actions.consume("sabotage")
	Global.action_used()
	Fortunas.sabotage(target_id)
	_build_list()
