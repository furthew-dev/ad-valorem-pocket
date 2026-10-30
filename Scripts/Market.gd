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
	_watch_for_lag(id)
	while true:
		var reply: Array = await _reply_received
		if reply[0] == id:
			_pending.erase(id)
			_hide_processing()
			return reply[1]

## ---- "PROCESSING..." ----
# A slow answer from the host (a busy phone, a weak connection) used to look like the
# tap didn't register. If an answer takes longer than LAG_AFTER, the screen dims and
# shows "Processing..." until it arrives, so the player waits instead of leaving.
const LAG_AFTER := 0.4
const ESCAPE_AFTER := 20.0   # after this long, a tap lets them stop waiting
var _processing: CanvasLayer
var _processing_label: Label
var _processing_hint: Label

func _watch_for_lag(id: int) -> void:
	await get_tree().create_timer(LAG_AFTER).timeout
	if _pending.has(id):
		_show_processing(id)

func _show_processing(id: int) -> void:
	if _processing == null:
		_build_processing()
	if _processing.visible:
		return
	_processing.visible = true
	_processing_hint.visible = false
	var dots := 0
	var started := Time.get_ticks_msec()
	while is_instance_valid(_processing) and _processing.visible:
		dots = (dots + 1) % 4
		_processing_label.text = "Processing" + ".".repeat(dots)
		if (Time.get_ticks_msec() - started) / 1000.0 > ESCAPE_AFTER and not _processing_hint.visible:
			_processing_hint.visible = true
		await get_tree().create_timer(0.4).timeout

func _hide_processing() -> void:
	if _processing and _pending.is_empty():
		_processing.visible = false

func _build_processing() -> void:
	_processing = CanvasLayer.new()
	_processing.layer = 105   # over screens, pop-ups and menus
	add_child(_processing)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # the player waits for the answer
	dim.gui_input.connect(func(event: InputEvent):
		if _processing_hint.visible and event is InputEventMouseButton and event.pressed:
			_processing.visible = false)
	_processing.add_child(dim)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e2328")
	style.border_color = Color("ddcf99")
	style.set_border_width_all(3)
	style.set_corner_radius_all(26)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", style)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size = Vector2(380, 0)
	dim.add_child(card)
	var box := VBoxContainer.new()
	card.add_child(box)
	_processing_label = Label.new()
	_processing_label.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Regular.ttf"))
	_processing_label.add_theme_font_size_override("font_size", 40)
	_processing_label.add_theme_color_override("font_color", Color("f6f2e1"))
	_processing_label.custom_minimum_size.x = 300   # the dots don't make it jump
	box.add_child(_processing_label)
	_processing_hint = Label.new()
	_processing_hint.text = "Still waiting on the host.\nTap to stop waiting."
	_processing_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_processing_hint.add_theme_font_size_override("font_size", 24)
	_processing_hint.add_theme_color_override("font_color", Color("ddcf99"))
	box.add_child(_processing_hint)
	for node in _processing.find_children("*", "", true, false):
		ColorTheme.keep(node)
	_processing.visible = false


## ---- BUYING FROM THE ACTIONS MARKET ----
# The whole purchase runs here (an autoload), not on the Market screen: leaving the
# screen while the host is slow to answer no longer drops a purchase half-way (stock
# taken, but no token and no charge). Returns {"ok", "message"}.
func purchase_action(key: String) -> Dictionary:
	var action: Dictionary = Actions.all_actions[key]
	var action_name: String = action["name"]
	var price: int = Actions.price_of(action)
	if not await buy_action(key):
		return {"ok": false, "message": "Sorry, %s just sold out." % action_name}
	if not Global.spend(price, action_name):
		Global.remove_cash(price, action_name)   # cash dropped while asking the host: charge it anyway
	Stats.add("actions_bought")
	if key == "certificate_of_deposit":
		Stats.add("investments")
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
	Activity.add("Bought %s for $%d" % [action_name, price], "info")
	return {"ok": true, "message": "%s has been added to %s." % [action_name, where]}

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
