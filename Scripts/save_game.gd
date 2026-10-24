extends Node
## Keeps a copy of this player's game on the device so a page refresh (or a dropped
## connection) doesn't lose anything. Autoloaded as "SaveGame".
##
## While a multiplayer game is running it checks every CHECK_EVERY seconds and saves as soon
## as anything changed. Every player saves their private things (cash, actions left,
## properties, loans, tokens, how far the round's Fortuna / rent got). The host also saves the
## shared market, decks, player list and who has ended their turn. "Resume Game" on the title
## screen loads it back (see Network.resume_game).
##
## In the browser the save goes into localStorage, which is written instantly. (Godot's own
## user:// files reach the browser's storage a moment later, which a crash can beat.) It also
## saves the moment the page is hidden: switching apps, locking the phone, closing the tab.

const CHECK_EVERY := 0.5
const MAX_AGE := 6 * 60 * 60   # a save older than this (seconds) is ignored
const VERSION := 2
const WEB_KEY := "ad_valorem_resume"

var _timer := 0.0
var _last_saved := PackedByteArray()
var _page_hidden_callback: JavaScriptObject   # kept so the browser callback stays alive


func _ready() -> void:
	if OS.has_feature("web"):
		_page_hidden_callback = JavaScriptBridge.create_callback(_on_page_hidden)
		var document := JavaScriptBridge.get_interface("document")
		var window := JavaScriptBridge.get_interface("window")
		if document:
			document.addEventListener("visibilitychange", _page_hidden_callback)
		if window:
			window.addEventListener("pagehide", _page_hidden_callback)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < CHECK_EVERY:
		return
	_timer = 0.0
	save_if_changed()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		save_if_changed()

func _on_page_hidden(_args) -> void:
	save_if_changed()

func should_save() -> bool:
	return Network.in_game and Network.is_online() and not Turns.game_over

# Saves now if the game is running and anything changed since the last save.
func save_if_changed() -> void:
	if not should_save():
		return
	var snapshot := _snapshot()
	var bytes := var_to_bytes(snapshot)
	if bytes == _last_saved:
		return
	_last_saved = bytes
	snapshot["saved_at"] = int(Time.get_unix_time_from_system())
	_write(var_to_bytes(snapshot))

func save_path() -> String:
	for arg in OS.get_cmdline_user_args():   # testing several players on one PC
		if arg.begins_with("--save-file="):
			return arg.trim_prefix("--save-file=")
	return "user://resume.save"


## ---- WRITE ----
func save() -> void:
	_last_saved = PackedByteArray()
	save_if_changed()

func _snapshot() -> Dictionary:
	var snapshot := {
		"version": VERSION,
		"room_key": Network.room_key,
		"token": Network.my_token,
		"host_secret": Network.host_secret,
		"was_host": Network.is_host(),
		"name": Global.PLAYER,
		"private": _private_state(),
	}
	if Network.is_host():
		snapshot["shared"] = _shared_state()
	return snapshot

func _write(bytes: PackedByteArray) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem('%s', '%s'); } catch (e) {}" % [WEB_KEY, Marshalls.raw_to_base64(bytes)])
		return
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)

func _read() -> PackedByteArray:
	if OS.has_feature("web"):
		var text = JavaScriptBridge.eval("(function () { try { return localStorage.getItem('%s') || ''; } catch (e) { return ''; } })()" % WEB_KEY)
		if text is String and text != "":
			return Marshalls.base64_to_raw(text)
	if FileAccess.file_exists(save_path()):
		return FileAccess.get_file_as_bytes(save_path())
	return PackedByteArray()

func clear() -> void:
	_last_saved = PackedByteArray()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.removeItem('%s'); } catch (e) {}" % WEB_KEY)
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
		"round_progress": Global.round_progress.duplicate(),
		"settings": Network.game_settings.duplicate(),
		"stats": Stats.snapshot(),
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
	var bytes := _read()
	if bytes.is_empty():
		return {}
	var snapshot = bytes_to_var(bytes)
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
	Global.round_progress = p.get("round_progress", {}).duplicate()
	Stats.restore(p.get("stats", {}))
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
