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
signal resumed            # Resume Game worked: back in the game
signal host_away(seconds: int)   # the host dropped; the relay holds the room for a while
signal host_back

# Host-adjustable game settings (lobby > Game Settings). Synced to everyone.
const DEFAULT_SETTINGS := {"start_cash": 20, "start_properties": 4, "end_goal": 200}
const SETTING_LIMITS := {"start_cash": [0, 100], "start_properties": [0, 4], "end_goal": [100, 750]}

const MAX_PLAYERS := 8
const MIN_PLAYERS_TO_START := 1   # 1 lets the host play solo; raise to 2 to require company
const MAX_NAME_LENGTH := 12
const CONNECT_TIMEOUT := 75.0     # free relay hosts can take ~50 s to wake up
const AWAY_GRACE := 180.0         # seconds a dropped player has to come back (Resume Game)

# Where the relay runs. Editor builds use a relay on this computer (cd server && npm start).
const RELAY_URL := "wss://ad-valorem-relay.onrender.com/"
const DEV_RELAY_URL := "ws://localhost:9080"

var players: Dictionary = {}   # peer id -> display name (host's copy is the truth)
var room_key := ""
var my_name := ""
var in_game := false
var game_settings: Dictionary = DEFAULT_SETTINGS.duplicate()

# Reconnecting. Every player gets a secret token for the game; the host remembers who is
# who by token, so a player who refreshes can come back (with a new peer id) as themselves.
var my_token := ""
var host_secret := ""             # lets the host reclaim its room after a refresh
var tokens: Dictionary = {}       # host: peer id -> token
var away: Dictionary = {}         # host: token -> name, players who dropped mid-game
var away_names: Array = []        # everyone: names of players currently reconnecting
var _resuming: Dictionary = {}    # the save being resumed (see resume_game)
var _wait_overlay: CanvasLayer

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
	my_token = _new_token()
	host_secret = _new_token()
	game_settings = DEFAULT_SETTINGS.duplicate()
	game_settings.merge(load_setting("host", "game_settings", {}), true)   # last time's choices
	_activate(_peer.host(relay_url(), host_secret))

func join_game(player_name: String, key: String) -> void:
	_start_session(player_name)
	my_token = _new_token()
	_activate(_peer.join(relay_url(), key))

# Title screen > Resume Game: reconnect to the saved game as the same player.
func resume_game() -> void:
	var snapshot := SaveGame.load_snapshot()
	if snapshot.is_empty():
		connection_failed.emit("There's no game to resume.")
		return
	_start_session(snapshot["name"])
	_resuming = snapshot
	my_token = snapshot["token"]
	host_secret = snapshot.get("host_secret", "")
	var secret: String = host_secret if snapshot.get("was_host", false) else ""
	_activate(_peer.join(relay_url(), snapshot["room_key"], true, secret))

static func _new_token() -> String:
	var bytes := PackedByteArray()
	for i in 16:
		bytes.append(randi() % 256)
	return bytes.hex_encode()

func start_game() -> void:
	if not is_host() or in_game or players.size() < MIN_PLAYERS_TO_START:
		return   # in_game: Start was already pressed (a double tap must not deal twice)
	_peer.lock_room()
	Market.setup_new_game()   # fresh shared decks/stock, sent to everyone first
	_begin_game.rpc()

# After a finished game: back to the lobby, and let new players join again.
func return_to_lobby() -> void:
	in_game = false
	if is_host():
		_peer.lock_room(false)

func leave() -> void:
	if _peer and in_game and not is_host() and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_leaving_on_purpose.rpc_id(1)   # don't hold a seat for us
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	tokens.clear()
	away.clear()
	away_names.clear()
	_resuming = {}
	_hide_wait_overlay()
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
	_peer.host_away.connect(_on_host_away)
	_peer.host_back.connect(_on_host_back)
	_connect_timer = get_tree().create_timer(CONNECT_TIMEOUT)
	_connect_timer.timeout.connect(_on_connect_timeout.bind(_peer))

# The peer must already be connecting before Godot will accept it.
func _activate(err: Error) -> void:
	if err != OK:
		_fail("Couldn't start a connection (error %d)." % err)
		return
	multiplayer.multiplayer_peer = _peer

func _fail(message: String) -> void:
	if not _resuming.is_empty() and message == "That game has ended.":
		SaveGame.clear()
	leave()
	connection_failed.emit(message)

func _on_connect_timeout(peer: RelayPeer) -> void:
	if peer == _peer and room_key == "":
		_fail("The game server didn't answer. Try again in a minute.")

func _on_room_hosted(key: String) -> void:
	room_key = key
	players = {1: my_name}
	tokens = {1: my_token}
	room_ready.emit(key)
	players_changed.emit()

func _on_room_joined(key: String) -> void:
	room_key = key
	if not _resuming.is_empty():
		if multiplayer.get_unique_id() == 1:
			_restore_as_host()
		return   # a player waits for the host to accept them (see _register_player)
	room_ready.emit(key)   # the player list arrives from the host after registering

func _on_relay_error(message: String) -> void:
	if room_key == "":
		_fail(message)
	else:
		push_warning("Relay: " + message)

func _on_room_closed() -> void:
	SaveGame.clear()   # the room is gone, so there's nothing to resume
	_end_session("The host closed the room.")

func _on_server_disconnected() -> void:
	if in_game and SaveGame.has_resume():
		_end_session("Lost connection to the game.\nTap Resume Game on the title screen to rejoin.")
	else:
		_end_session("Lost connection to the host.")

func _end_session(message: String) -> void:
	if _peer == null:
		return
	leave()
	session_ended.emit(message)

func _on_connected_to_server() -> void:
	if in_game:
		return   # the host came back after a refresh; it already knows us (see _on_host_back)
	_register_player.rpc_id(1, my_name, my_token)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var name: String = players[id]
	players.erase(id)
	var token: String = tokens.get(id, "")
	tokens.erase(id)
	if in_game and token != "":
		# Mid-game: keep their seat for a while so they can Resume.
		away[token] = name
		get_tree().create_timer(AWAY_GRACE).timeout.connect(_on_away_expired.bind(token))
		_announce.rpc("%s lost connection. Waiting for them to come back..." % name)
	_sync_players.rpc(players, away.values())

func _on_away_expired(token: String) -> void:
	if not away.has(token) or not is_host():
		return
	var name: String = away[token]
	away.erase(token)
	Turns.forget(token)
	_sync_players.rpc(players, away.values())
	_announce.rpc("%s left the game." % name)


## ---- RECONNECTING ----
# Host after a refresh: the relay gave us peer 1 back. Restore the shared game and tell
# everyone what it looks like.
func _restore_as_host() -> void:
	var snapshot := _resuming
	_resuming = {}
	in_game = true
	SaveGame.restore_private(snapshot)
	SaveGame.restore_shared(snapshot)
	var shared: Dictionary = snapshot["shared"]
	var connected := _peer.get_peer_ids()
	players = {1: snapshot["name"]}
	tokens = {1: my_token}
	away = shared["away"].duplicate()
	for id in shared["players"]:
		if id == 1:
			continue
		var token: String = shared["tokens"].get(id, "")
		if id in connected:
			players[id] = shared["players"][id]
			tokens[id] = token
		elif token != "":   # dropped while we were gone: they can still come back
			away[token] = shared["players"][id]
	for token in away:
		get_tree().create_timer(AWAY_GRACE).timeout.connect(_on_away_expired.bind(token))
	Turns.restore_finished(shared["finished"])
	_sync_players.rpc(players, away.values())
	Market.send_state_to_all()
	_announce.rpc("The host is back.")
	Turns.resume(Global.ROUND, snapshot["private"]["round"], snapshot["private"]["turn_done"])
	Turns.resync_waiting()
	resumed.emit()

# Host -> a returning player: you're in. Restore your own things and carry on.
@rpc("authority", "reliable")
func _resume_accepted(current_round: int, turn_done: bool) -> void:
	var snapshot := _resuming
	_resuming = {}
	if snapshot.is_empty():
		return
	in_game = true
	SaveGame.restore_private(snapshot)
	Turns.resume(current_round, snapshot["private"]["round"], turn_done)
	resumed.emit()

@rpc("authority", "reliable")
func _resume_rejected(message: String) -> void:
	SaveGame.clear()
	_fail(message)

# Player -> host: "I'm leaving for good" (so they aren't marked as reconnecting).
@rpc("any_peer", "reliable")
func _leaving_on_purpose() -> void:
	tokens.erase(multiplayer.get_remote_sender_id())

# Host -> everyone: a short banner ("Sam lost connection...").
@rpc("authority", "call_local", "reliable")
func _announce(message: String) -> void:
	Global.banner(message)

# Everyone else while the host is away: block the game with a "reconnecting" notice.
func _on_host_away(seconds: int) -> void:
	host_away.emit(seconds)
	_show_wait_overlay("The host lost connection.\nWaiting up to %d minutes for them to come back..." % ceili(seconds / 60.0))

func _on_host_back() -> void:
	_hide_wait_overlay()
	Market.resend_pending()   # anything we asked while the host was gone
	Turns.resend_turn_done()
	host_back.emit()

func _show_wait_overlay(text: String) -> void:
	_hide_wait_overlay()
	_wait_overlay = CanvasLayer.new()
	_wait_overlay.layer = 150
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 40)
	dim.add_child(label)
	_wait_overlay.add_child(dim)
	get_tree().root.add_child(_wait_overlay)

func _hide_wait_overlay() -> void:
	if is_instance_valid(_wait_overlay):
		_wait_overlay.queue_free()
	_wait_overlay = null


## ---- RPCs ----
# Client -> host: "this is my name" (and my secret token, for reconnecting later).
@rpc("any_peer", "reliable")
func _register_player(player_name: String, token: String = "") -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_game:
		if token != "" and tokens.get(id, "") == token:
			return   # already back in
		# Only someone who dropped out of THIS game may come back, as themselves.
		for old_id in tokens.keys():
			if token != "" and tokens[old_id] == token and old_id != id:
				# Their old connection hasn't timed out yet: this is them again.
				away[token] = players.get(old_id, player_name)
				players.erase(old_id)
				tokens.erase(old_id)
		if token == "" or not away.has(token) or Turns.game_over:
			_resume_rejected.rpc_id(id, "That game has ended." if Turns.game_over else "That game has already started.")
			return
		players[id] = away[token]
		tokens[id] = token
		away.erase(token)
		_sync_players.rpc(players, away.values())
		_sync_settings.rpc_id(id, game_settings)
		Market.send_state_to(id)
		_resume_accepted.rpc_id(id, Global.ROUND, Turns.is_finished(token))
		_announce.rpc("%s is back." % players[id])
		Turns.resync_waiting()
		return
	if players.size() >= MAX_PLAYERS:
		return   # the relay already enforces this; this is a backstop
	players[id] = _unique_name(clean_name(player_name))
	tokens[id] = token
	_sync_players.rpc(players, away.values())
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
	_sync_players.rpc(players, away.values())

# Host -> everyone (host included): the full player list, and who is reconnecting.
@rpc("authority", "call_local", "reliable")
func _sync_players(list: Dictionary, reconnecting: Array = []) -> void:
	players = list
	away_names = reconnecting
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
