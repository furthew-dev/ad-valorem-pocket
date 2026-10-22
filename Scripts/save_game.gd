extends Node
## Keeps a copy of this player's game on the device so a page refresh (or a dropped
## connection) doesn't lose anything. Autoloaded as "SaveGame".
##
## While a multiplayer game is running it saves every SAVE_EVERY seconds. Every player saves
## their private things (cash, properties, loans, actions...). The host also saves the shared
## market, decks, player list and who has ended their turn. "Resume Game" on the title screen
## loads it back (see Network.resume_game).

const SAVE_EVERY := 2.0
const MAX_AGE := 6 * 60 * 60   # a save older than this (seconds) is ignored
const VERSION := 1

var _timer := 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer < SAVE_EVERY:
		return
	_timer = 0.0
	if Network.in_game and Network.is_online() and not Turns.game_over:
		save()

func save_path() -> String:
	for arg in OS.get_cmdline_user_args():   # testing several players on one PC
		if arg.begins_with("--save-file="):
			return arg.trim_prefix("--save-file=")
	return "user://resume.save"


## ---- WRITE ----
func save() -> void:
	var snapshot := {
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"room_key": Network.room_key,
		"token": Network.my_token,
		"host_secret": Network.host_secret,
		"was_host": Network.is_host(),
		"name": Global.PLAYER,
		"private": _private_state(),
	}
	if Network.is_host():
		snapshot["shared"] = _shared_state()
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file:
		file.store_var(snapshot)

func clear() -> void:
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(save_path())

func _private_state() -> Dictionary:
	return {
		"cash": Global.CASH,
		"actions": Global.ACTIONS,
		"round": Global.ROUND,
		"action_capacity": Global.A_CAPACITY,
		"property_capacity": Global.PROPERTY_CAPACITY,
		"end_goal": Global.END_GOAL,
		"loans": Global.loans.duplicate(true),
		"interest_paid": Global.total_interest_paid,
		"properties": Cards.properties_owned.duplicate(true),
		"actions_owned": Actions.actions_owned.duplicate(),
		"fortunas_owned": Fortunas.fortunas_owned.duplicate(true),
		"turn_done": Turns.my_turn_done,
		"settings": Network.game_settings.duplicate(),
	}

func _shared_state() -> Dictionary:
	var stock := {}
	for key in Actions.all_actions:
		stock[key] = Actions.all_actions[key]["stock"]
	return {
		"stock": stock,
		"deck": Cards.property_deck.map(func(t): return t["name"]),
		"fortuna_deck": Fortunas.fortuna_deck.duplicate(),
		"players": Network.players.duplicate(),
		"tokens": Network.tokens.duplicate(),
		"away": Network.away.duplicate(),
		"finished": Turns.finished_snapshot(),
	}


## ---- READ ----
# The saved game, or {} if there's nothing usable to resume.
func load_snapshot() -> Dictionary:
	if not FileAccess.file_exists(save_path()):
		return {}
	var file := FileAccess.open(save_path(), FileAccess.READ)
	if file == null:
		return {}
	var snapshot = file.get_var()
	if not snapshot is Dictionary or snapshot.get("version", 0) != VERSION:
		return {}
	if int(Time.get_unix_time_from_system()) - int(snapshot.get("saved_at", 0)) > MAX_AGE:
		return {}
	return snapshot

func has_resume() -> bool:
	return not load_snapshot().is_empty()

# Puts this player's own things back (cash, properties, loans, actions...).
func restore_private(snapshot: Dictionary) -> void:
	var p: Dictionary = snapshot["private"]
	Global.PLAYER = snapshot["name"]
	Global.A_CAPACITY = p["action_capacity"]
	Global.PROPERTY_CAPACITY = p["property_capacity"]
	Global.END_GOAL = p["end_goal"]
	Global.loans = p["loans"]
	Global.total_interest_paid = p["interest_paid"]
	Cards.properties_owned = p["properties"]
	Cards.properties_revealed.clear()
	Actions.actions_owned = p["actions_owned"]
	Fortunas.fortunas_owned = p["fortunas_owned"]
	Network.game_settings = p["settings"]
	Global.ROUND = p["round"]
	Global.CASH = p["cash"]
	Global.ACTIONS = p["actions"]
	Global.erase_scenes()

# Host only: the shared market and decks.
func restore_shared(snapshot: Dictionary) -> void:
	var s: Dictionary = snapshot["shared"]
	for key in s["stock"]:
		if Actions.all_actions.has(key):
			Actions.all_actions[key]["stock"] = s["stock"][key]
	Cards.set_deck_from_names(s["deck"])
	Fortunas.fortuna_deck = s["fortuna_deck"]
	Fortunas._deck_built = true
