extends Node
## The shared, public part of the game: action-token stock, the property deck and the
## Fortuna deck. Autoloaded as "Market".
##
## In multiplayer the HOST owns all three. Everyone else asks the host (an RPC request
## with an id) and awaits the answer; the host then broadcasts the new stock / deck so
## every phone stays in sync. Solo games just run the host side locally.
## Private things (your properties, cash, loans, owned actions) never go through here.
##
## Usage (always await):  if await Market.buy_action("contractor"): ...

signal stock_changed(key: String, stock: int)
signal deck_changed

# Requests clients may make. Each maps to a _host_<name>() function below.
const REQUESTS := ["buy_action", "draw_properties", "return_properties", "take_property", "draw_fortuna"]

signal _reply_received(request_id: int, result)

var _next_request_id := 0
var _pending: Dictionary = {}   # request id -> true, so they can be released on disconnect


func _ready() -> void:
	Network.session_ended.connect(func(_m): _release_pending())


## ---- PUBLIC API (works solo, as host, or as client) ----
# Takes one token from the shared stock. False if it sold out.
func buy_action(key: String) -> bool:
	return await _ask("buy_action", [key]) == true

# Draws `count` random cards off the property deck. Returns their names.
func draw_properties(count: int) -> Array:
	var names = await _ask("draw_properties", [count])
	return names if names is Array else []

# Puts cards (by name) back into the property deck.
func return_properties(names: Array) -> void:
	if not names.is_empty():
		await _ask("return_properties", [names])

# Takes one specific card out of the deck (Inheritance). False if none left.
func take_property(property_name: String) -> bool:
	return await _ask("take_property", [property_name]) == true

# Draws the next Fortuna. Returns its key in Fortunas.all_fortunas, or "" if the deck is empty.
func draw_fortuna() -> String:
	var key = await _ask("draw_fortuna", [])
	return key if key is String else ""

# Host / solo only: fresh decks and full stock for a new game, sent to everyone.
func setup_new_game() -> void:
	Actions.reset_stock()
	scale_stock(maxi(1, Network.players.size()))
	var settings: Dictionary = Network.game_settings
	Cards.reset_deck(settings.get("base", true), settings.get("expansion", false))
	Fortunas.expansion_enabled = settings.get("expansion", false)
	Fortunas.generate_fortuna_deck()
	_broadcast_all()

# Bigger tables need a bigger Market. LLC and Land Expansion: one per player. Everything
# else: the normal amount up to 4 players, +25% for each player past 4 (rounded up),
# so 5 players = x1.25 ... 8 players = x2.
const ONE_PER_PLAYER := ["llc", "land_expansion"]

func scale_stock(players: int) -> void:
	var factor := 1.0 + 0.25 * maxi(0, players - 4)
	for key in Actions.all_actions:
		var action: Dictionary = Actions.all_actions[key]
		if key in Actions.SUITE_KEYS:
			continue   # the Suites deck is always 4 + 4
		if key in ONE_PER_PLAYER:
			action["stock"] = players
		else:
			action["stock"] = ceili(action["stock"] * factor - 0.001)


## ---- REQUEST PLUMBING ----
func _is_remote() -> bool:
	return Network.is_online() and not multiplayer.is_server()

func _ask(request: String, args: Array):
	if not _is_remote():
		return callv("_host_" + request, args)
	_next_request_id += 1
	var id := _next_request_id
	_pending[id] = [request, args]
	_request.rpc_id(1, id, request, args)
	while true:
		var reply: Array = await _reply_received
		if reply[0] == id:
			_pending.erase(id)
			return reply[1]

# The host dropped and came back: ask again for anything still unanswered.
func resend_pending() -> void:
	for id in _pending:
		_request.rpc_id(1, id, _pending[id][0], _pending[id][1])

# Host: the whole market to one returning player, or to everyone.
func send_state_to(peer_id: int) -> void:
	var stock := {}
	for key in Actions.all_actions:
		stock[key] = Actions.all_actions[key]["stock"]
	_sync_all.rpc_id(peer_id, stock, _deck_names())

func send_state_to_all() -> void:
	_broadcast_all()

# If the host vanishes, wake every waiting caller with a "no" answer.
func _release_pending() -> void:
	for id in _pending.keys():
		_reply_received.emit(id, null)
	_pending.clear()

@rpc("any_peer", "reliable")
func _request(id: int, request: String, args: Array) -> void:
	if not multiplayer.is_server() or not request in REQUESTS:
		return
	var result = callv("_host_" + request, args)
	_reply.rpc_id(multiplayer.get_remote_sender_id(), id, result)

@rpc("authority", "reliable")
func _reply(id: int, result) -> void:
	_reply_received.emit(id, result)


## ---- HOST SIDE (the only code that changes shared state) ----
func _host_buy_action(key: String) -> bool:
	var action = Actions.all_actions.get(key)
	if action == null or action["stock"] <= 0:
		return false
	action["stock"] -= 1
	stock_changed.emit(key, action["stock"])
	if Network.is_online():
		_sync_stock.rpc(key, action["stock"])
	return true

func _host_draw_properties(count: int) -> Array:
	var names := []
	Cards.property_deck.shuffle()
	for i in mini(count, Cards.property_deck.size()):
		names.append(Cards.property_deck.pop_back()["name"])
	_broadcast_deck()
	return names

func _host_return_properties(names: Array) -> bool:
	for property_name in names:
		var template = Cards.templates_by_name.get(property_name)
		if template != null:
			Cards.property_deck.append(template)
	_broadcast_deck()
	return true

func _host_take_property(property_name: String) -> bool:
	var template := Cards.find_template(property_name)
	if template.is_empty():
		return false
	Cards.property_deck.erase(template)
	_broadcast_deck()
	return true

func _host_draw_fortuna() -> String:
	return Fortunas.pop_fortuna_key()

func _broadcast_deck() -> void:
	deck_changed.emit()
	if Network.is_online():
		_sync_deck.rpc(_deck_names())

func _broadcast_all() -> void:
	deck_changed.emit()
	for key in Actions.all_actions:
		stock_changed.emit(key, Actions.all_actions[key]["stock"])
	if Network.is_online():
		var stock := {}
		for key in Actions.all_actions:
			stock[key] = Actions.all_actions[key]["stock"]
		_sync_all.rpc(stock, _deck_names())

func _deck_names() -> Array:
	return Cards.property_deck.map(func(t): return t["name"])


## ---- EVERYONE ELSE: mirror the host's state ----
@rpc("authority", "reliable")
func _sync_stock(key: String, stock: int) -> void:
	if Actions.all_actions.has(key):
		Actions.all_actions[key]["stock"] = stock
		stock_changed.emit(key, stock)

@rpc("authority", "reliable")
func _sync_deck(names: Array) -> void:
	Cards.set_deck_from_names(names)
	deck_changed.emit()

@rpc("authority", "reliable")
func _sync_all(stock: Dictionary, names: Array) -> void:
	for key in stock:
		_sync_stock(key, stock[key])
	_sync_deck(names)
