class_name RelayPeer
extends MultiplayerPeerExtension
## A MultiplayerPeer that tunnels Godot's high-level multiplayer (RPCs, synchronizers)
## through the room relay in server/relay.js over a WebSocket. Works in web exports,
## where a browser can't open a listening server.
##
## The host is always peer 1. Every peer learns about every other peer (a mesh), so
## RPCs go straight to their target via the relay; no server-side relaying is needed.

signal room_hosted(key: String)
signal room_joined(key: String)
signal relay_error(message: String)
signal room_closed
signal host_away(seconds: int)   # the host dropped mid-game; the relay is holding the room
signal host_back                 # ...and has returned

const MAX_PACKET := 60000

var room_key := ""

var _ws := WebSocketPeer.new()
var _status := CONNECTION_DISCONNECTED
var _unique_id := 0
var _peers: Dictionary = {}          # peer id -> true
var _incoming: Array = []            # [[from_id, PackedByteArray], ...]
var _pending_control: Dictionary = {}  # sent as soon as the socket opens
var _target_peer := 0
var _transfer_mode := TRANSFER_MODE_RELIABLE
var _transfer_channel := 0
var _refuse_new := false


## ---- PUBLIC ----
# `secret` lets the host reclaim the room if its connection drops mid-game.
func host(url: String, secret: String = "") -> Error:
	return _open(url, {"op": "host", "secret": secret})

# rejoin: coming back to a game in progress (the host checks who we are).
# secret: only for the host itself, reclaiming its room as peer 1.
func join(url: String, key: String, rejoin: bool = false, secret: String = "") -> Error:
	return _open(url, {"op": "join", "key": key, "rejoin": rejoin, "secret": secret})

# Host only: stop new players joining (call when the game starts).
func lock_room(locked: bool = true) -> void:
	_send_control({"op": "lock" if locked else "unlock"})

func get_peer_ids() -> Array:
	return _peers.keys()


## ---- MultiplayerPeerExtension ----
func _poll() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	_ws.poll()
	var state := _ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _pending_control.is_empty():
		_ws.send_text(JSON.stringify(_pending_control))
		_pending_control = {}

	while _ws.get_available_packet_count() > 0:
		var packet := _ws.get_packet()
		if _ws.was_string_packet():
			_handle_control(packet.get_string_from_utf8())
		elif packet.size() >= 4 and _status == CONNECTION_CONNECTED:
			_incoming.append([packet.decode_s32(0), packet.slice(4)])

	if state == WebSocketPeer.STATE_CLOSED and _status != CONNECTION_DISCONNECTED:
		if _status == CONNECTION_CONNECTING and _unique_id == 0:
			relay_error.emit("Couldn't reach the game server.")
		_drop_all()

func _get_available_packet_count() -> int:
	return _incoming.size()

# Godot asks for the sender/channel/mode of the NEXT packet before reading it.
func _get_packet_peer() -> int:
	return _incoming[0][0] if not _incoming.is_empty() else 0

func _get_packet_channel() -> int:
	return 0

func _get_packet_mode() -> TransferMode:
	return TRANSFER_MODE_RELIABLE   # the relay is TCP: everything arrives, in order

func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	return _incoming.pop_front()[1]

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, _target_peer)   # 0 = everyone, -N = everyone but N
	out.append_array(buffer)
	return _ws.send(out)

func _get_max_packet_size() -> int:
	return MAX_PACKET

func _set_target_peer(peer: int) -> void:
	_target_peer = peer

func _set_transfer_mode(mode: TransferMode) -> void:
	_transfer_mode = mode

func _get_transfer_mode() -> TransferMode:
	return _transfer_mode

func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel

func _get_transfer_channel() -> int:
	return _transfer_channel

func _get_unique_id() -> int:
	return _unique_id

func _is_server() -> bool:
	return _unique_id == 1

func _is_server_relay_supported() -> bool:
	return false   # every peer can reach every other peer directly through the relay

func _get_connection_status() -> ConnectionStatus:
	return _status

func _set_refuse_new_connections(enable: bool) -> void:
	_refuse_new = enable
	if _is_server():
		lock_room(enable)

func _is_refusing_new_connections() -> bool:
	return _refuse_new

func _disconnect_peer(peer: int, _force: bool) -> void:
	if _peers.erase(peer):
		peer_disconnected.emit(peer)

func _close() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"op": "leave"}))
		_ws.close()
	_drop_all()


## ---- INTERNALS ----
func _open(url: String, control: Dictionary) -> Error:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		return err
	_status = CONNECTION_CONNECTING
	_unique_id = 0
	_peers.clear()
	_incoming.clear()
	_pending_control = control
	return OK

func _send_control(control: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(control))

func _handle_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not msg is Dictionary:
		return
	match msg.get("op", ""):
		"hosted":
			room_key = msg["key"]
			_unique_id = 1
			_status = CONNECTION_CONNECTED
			room_hosted.emit(room_key)
		"joined":
			room_key = msg["key"]
			_unique_id = int(msg["id"])
			_status = CONNECTION_CONNECTED
			for id in msg["peers"]:
				_add_peer(int(id))
			room_joined.emit(room_key)
		"peer_joined":
			_add_peer(int(msg["id"]))
		"peer_left":
			var id := int(msg["id"])
			if _peers.erase(id):
				peer_disconnected.emit(id)
		"host_away":
			host_away.emit(int(msg.get("seconds", 0)))
		"host_back":
			# The host is a fresh program now: forget what Godot's multiplayer cached about
			# peer 1 (node paths etc.) by reconnecting it.
			if _peers.has(1):
				_peers.erase(1)
				peer_disconnected.emit(1)
			_add_peer(1)
			host_back.emit()
		"room_closed":
			room_closed.emit()
			_ws.close()
			_drop_all()
		"error":
			relay_error.emit(str(msg.get("msg", "Unknown error")))
			if _status == CONNECTION_CONNECTING:
				_ws.close()
				_drop_all()

func _add_peer(id: int) -> void:
	if id == _unique_id or _peers.has(id):
		return
	_peers[id] = true
	peer_connected.emit(id)

func _drop_all() -> void:
	for id in _peers.keys():
		peer_disconnected.emit(id)
	_peers.clear()
	_incoming.clear()
	_status = CONNECTION_DISCONNECTED
