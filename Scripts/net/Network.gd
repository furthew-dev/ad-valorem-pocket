extends Node
## Multiplayer session: host or join a room, keep the lobby's player list in sync,
## and start the game for everyone. Autoloaded as "Network".
##
## Uses Godot's high-level multiplayer API over RelayPeer. The host is peer 1 and owns
## the player list; clients register their name with the host when they connect.

signal room_ready(key: String)          # hosted or joined: show the lobby
signal connection_failed(message: String)
signal players_changed
signal session_ended(message: String)   # host left / connection lost
signal game_starting
signal settings_changed   # the host changed the game settings (lobby)

# Host-adjustable game settings (lobby > Game Settings). Synced to everyone.
const DEFAULT_SETTINGS := {"start_cash": 20, "start_properties": 4, "end_goal": 200}
const SETTING_LIMITS := {"start_cash": [0, 100], "start_properties": [0, 4], "end_goal": [100, 750]}

const MAX_PLAYERS := 8
const MIN_PLAYERS_TO_START := 1   # 1 lets the host play solo; raise to 2 to require company
const MAX_NAME_LENGTH := 12
const CONNECT_TIMEOUT := 75.0     # free relay hosts can take ~50 s to wake up

# Where the relay runs. Editor builds use a relay on this computer (cd server && npm start).
const RELAY_URL := "wss://ad-valorem-relay.onrender.com"
const DEV_RELAY_URL := "ws://localhost:9080"

var players: Dictionary = {}   # peer id -> display name (host's copy is the truth)
var room_key := ""
var my_name := ""
var in_game := false
var game_settings: Dictionary = DEFAULT_SETTINGS.duplicate()

var _peer: RelayPeer
var _connect_timer: SceneTreeTimer


const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	my_name = load_setting("player", "name", "")
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## ---- PUBLIC ----
func relay_url() -> String:
	for arg in OS.get_cmdline_user_args():   # e.g. godot -- --relay=ws://192.168.1.5:9080
		if arg.begins_with("--relay="):
			return arg.trim_prefix("--relay=")
	return DEV_RELAY_URL if OS.has_feature("editor") else RELAY_URL

func is_online() -> bool:
	return _peer != null and room_key != ""

func is_host() -> bool:
	return _peer != null and multiplayer.is_server() and room_key != ""

func host_game(player_name: String) -> void:
	_start_session(player_name)
	game_settings = DEFAULT_SETTINGS.duplicate()
	game_settings.merge(load_setting("host", "game_settings", {}), true)   # last time's choices
	_activate(_peer.host(relay_url()))

func join_game(player_name: String, key: String) -> void:
	_start_session(player_name)
	_activate(_peer.join(relay_url(), key))

func start_game() -> void:
	if not is_host() or players.size() < MIN_PLAYERS_TO_START:
		return
	_peer.lock_room()
	Market.setup_new_game()   # fresh shared decks/stock, sent to everyone first
	_begin_game.rpc()

# After a finished game: back to the lobby, and let new players join again.
func return_to_lobby() -> void:
	in_game = false
	if is_host():
		_peer.lock_room(false)

func leave() -> void:
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	room_key = ""
	in_game = false

# Changes this player's name (settings pop-up). Saved for next time.
func rename(new_name: String) -> void:
	my_name = clean_name(new_name)
	save_setting("player", "name", my_name)
	Global.PLAYER = my_name
	if is_online():
		_rename_player.rpc_id(1, my_name)

func load_setting(section: String, key: String, default = null):
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return config.get_value(section, key, default)

func save_setting(section: String, key: String, value) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)

static func clean_name(raw: String) -> String:
	var name := raw.strip_edges().left(MAX_NAME_LENGTH)
	return name if name != "" else "Player"

# Looks like a room key: 6 letters/digits, dash optional ("SJ4-GT7" or "sj4gt7").
static func is_valid_key(raw: String) -> bool:
	var regex := RegEx.create_from_string("^[A-Za-z0-9]{3}-?[A-Za-z0-9]{3}$")
	return regex.search(raw.strip_edges()) != null

# Players in the order they joined the lobby (host first).
func ordered_players() -> Array:
	var list := []
	for id in players:
		list.append({"id": id, "name": players[id], "is_host": id == 1,
				"is_me": id == multiplayer.get_unique_id()})
	return list


## ---- SESSION ----
func _start_session(player_name: String) -> void:
	leave()
	my_name = clean_name(player_name)
	save_setting("player", "name", my_name)
	_peer = RelayPeer.new()
	_peer.room_hosted.connect(_on_room_hosted)
	_peer.room_joined.connect(_on_room_joined)
	_peer.relay_error.connect(_on_relay_error)
	_peer.room_closed.connect(_on_room_closed)
	_connect_timer = get_tree().create_timer(CONNECT_TIMEOUT)
	_connect_timer.timeout.connect(_on_connect_timeout.bind(_peer))

# The peer must already be connecting before Godot will accept it.
func _activate(err: Error) -> void:
	if err != OK:
		_fail("Couldn't start a connection (error %d)." % err)
		return
	multiplayer.multiplayer_peer = _peer

func _fail(message: String) -> void:
	leave()
	connection_failed.emit(message)

func _on_connect_timeout(peer: RelayPeer) -> void:
	if peer == _peer and room_key == "":
		_fail("The game server didn't answer. Try again in a minute.")

func _on_room_hosted(key: String) -> void:
	room_key = key
	players = {1: my_name}
	room_ready.emit(key)
	players_changed.emit()

func _on_room_joined(key: String) -> void:
	room_key = key
	room_ready.emit(key)   # the player list arrives from the host after registering

func _on_relay_error(message: String) -> void:
	if room_key == "":
		_fail(message)
	else:
		push_warning("Relay: " + message)

func _on_room_closed() -> void:
	_end_session("The host closed the room.")

func _on_server_disconnected() -> void:
	_end_session("Lost connection to the host.")

func _end_session(message: String) -> void:
	if _peer == null:
		return
	leave()
	session_ended.emit(message)

func _on_connected_to_server() -> void:
	_register_player.rpc_id(1, my_name)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.erase(id):
		_sync_players.rpc(players)


## ---- RPCs ----
# Client -> host: "this is my name".
@rpc("any_peer", "reliable")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS or in_game:
		return   # the relay already enforces both; this is a backstop
	players[id] = _unique_name(clean_name(player_name))
	_sync_players.rpc(players)
	_sync_settings.rpc_id(id, game_settings)

# Client -> host: "call me this instead" (from the settings pop-up).
@rpc("any_peer", "call_local", "reliable")
func _rename_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	players.erase(id)
	players[id] = _unique_name(clean_name(player_name))
	_sync_players.rpc(players)

# Host -> everyone (host included): the full player list.
@rpc("authority", "call_local", "reliable")
func _sync_players(list: Dictionary) -> void:
	players = list
	if in_game:
		Global.PLAYER = players.get(multiplayer.get_unique_id(), Global.PLAYER)
	players_changed.emit()

## ---- GAME SETTINGS ----
# Returns why these settings can't be used, or "" if they're fine.
static func settings_problem(settings: Dictionary) -> String:
	for key in SETTING_LIMITS:
		var limits: Array = SETTING_LIMITS[key]
		if not settings.has(key) or settings[key] < limits[0] or settings[key] > limits[1]:
			return "%s must be between %d and %d." % [key.capitalize(), limits[0], limits[1]]
	if settings["start_cash"] >= settings["end_goal"]:
		return "Starting cash must be less than the end goal."
	return ""

# Host only (lobby). Saved so the host gets the same settings next time.
func set_game_settings(settings: Dictionary) -> String:
	var problem := settings_problem(settings)
	if problem != "" or not is_host():
		return problem
	save_setting("host", "game_settings", settings)
	_sync_settings.rpc(settings)
	return ""

@rpc("authority", "call_local", "reliable")
func _sync_settings(settings: Dictionary) -> void:
	game_settings = settings
	settings_changed.emit()

# Host -> everyone: leave the lobby and start playing.
@rpc("authority", "call_local", "reliable")
func _begin_game() -> void:
	in_game = true
	Global.PLAYER = players.get(multiplayer.get_unique_id(), my_name)
	Fortunas.new_game()
	game_starting.emit()
	Global.start_game()   # draws the starting hand from the shared deck

func _unique_name(wanted: String) -> String:
	var taken := players.values()
	if not taken.has(wanted):
		return wanted
	var n := 2
	while taken.has("%s %d" % [wanted, n]):
		n += 1
	return "%s %d" % [wanted, n]
