extends Node
## Live auctions (the Auction Fortuna). Autoloaded as "Auction".
##
## The owner's property goes up for auction on EVERY phone at once. Anyone (the owner
## included) can bid. Each bid resets the clock to BID_RESET seconds; when it runs out
## the highest bidder pays and gets the property, and the owner receives the money.
## The host runs the clock and decides the winner; everyone else just shows it.

signal _owner_result(winner_id: int, winner_name: String, bid: int)

const OPENING_TIME := 10.0   # seconds before the first bid must come in
const BID_RESET := 5.0       # clock resets to this after every bid
const INCREMENTS := [1, 5, 10]
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const CREAM := Color(0.866667, 0.811765, 0.6)

var active := false
var item: Dictionary = {}
var owner_id := 0
var owner_name := ""
var high_bid := 0
var high_bidder := 0
var time_left := 0.0

var _queue: Array = []   # host only: auctions waiting for the current one to finish
var _overlay: CanvasLayer
var _bid_label: Label
var _time_label: Label
var _bid_buttons: Array[Button] = []


func _ready() -> void:
	Network.players_changed.connect(_on_players_changed)


## ---- OWNER (called from the Auction Fortuna) ----
# Puts `property` up for auction and waits for the result. Returns a banner message.
func run(property: Dictionary) -> String:
	_request_start.rpc_id(1, Global.PLAYER, property)
	var result: Array = await _owner_result
	var winner_id: int = result[0]
	var bid: int = result[2]
	if winner_id == 0:
		return "No bids. You kept your %s." % property["name"]
	if winner_id == multiplayer.get_unique_id():
		return "You won your own auction and kept your %s." % property["name"]
	await DiscardFx.play(get_tree(), property, "Sold at auction to %s for $%d" % [result[1], bid])
	Cards.properties_owned.erase(_find_owned(property["id"]))
	Global.add_cash(bid)
	return "%s bought your %s at auction for $%d." % [result[1], property["name"], bid]

func _find_owned(id: int) -> Dictionary:
	for p in Cards.properties_owned:
		if p["id"] == id:
			return p
	return {}


## ---- HOST: runs the clock ----
@rpc("any_peer", "call_local", "reliable")
func _request_start(player_name: String, property: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_queue.append([sender if sender != 0 else 1, player_name, property])
	if not active:
		_start_next()

func _start_next() -> void:
	if _queue.is_empty():
		return
	var next: Array = _queue.pop_front()
	_open.rpc(next[0], next[1], next[2])

func _process(delta: float) -> void:
	if not active:
		return
	time_left = maxf(time_left - delta, 0.0)
	if _time_label:
		_time_label.text = "%d" % ceili(time_left)
	if multiplayer.is_server() and time_left <= 0.0:
		active = false   # stop the host closing twice before the RPC lands
		var winner := high_bidder if Network.players.has(high_bidder) else 0
		_close.rpc(winner, Network.players.get(winner, ""), high_bid if winner != 0 else 0)

@rpc("any_peer", "call_local", "reliable")
func _place_bid(amount: int) -> void:
	if not multiplayer.is_server() or not active or amount <= high_bid:
		return
	var sender := multiplayer.get_remote_sender_id()
	_update.rpc(amount, sender if sender != 0 else 1, BID_RESET)

func _on_players_changed() -> void:
	# The owner left mid-auction: call it off.
	if active and multiplayer.is_server() and not Network.players.has(owner_id):
		active = false
		_close.rpc(0, "", 0)


## ---- EVERYONE ----
@rpc("authority", "call_local", "reliable")
func _open(owner_peer: int, player_name: String, property: Dictionary) -> void:
	active = true
	owner_id = owner_peer
	owner_name = player_name
	item = property
	high_bid = 0
	high_bidder = 0
	time_left = OPENING_TIME
	Sound.play("notify")
	_build_overlay()
	_refresh()

@rpc("authority", "call_local", "reliable")
func _update(bid: int, bidder: int, clock: float) -> void:
	high_bid = bid
	high_bidder = bidder
	time_left = clock
	Sound.play("switch")
	_refresh()

@rpc("authority", "call_local", "reliable")
func _close(winner_id: int, winner_name: String, bid: int) -> void:
	active = false
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	var me := multiplayer.get_unique_id()
	if winner_id == me and me != owner_id:
		_pay(bid)
		var won := item.duplicate(true)
		Cards.properties_owned.append(won)
		Global.banner("You won the %s for $%d!" % [item["name"], bid])
	elif me != owner_id:
		if winner_id == 0:
			Global.banner("Auction over: no bids for %s's %s." % [owner_name, item["name"]])
		else:
			Global.banner("%s won %s's %s for $%d." % [winner_name, owner_name, item["name"], bid])
	if me == owner_id:
		_owner_result.emit(winner_id, winner_name, bid)
	if multiplayer.is_server():
		get_tree().create_timer(1.5).timeout.connect(_start_next)

# Winner pays. Short on cash: everything you have plus a loan for the rest.
func _pay(amount: int) -> void:
	if Global.can_afford(amount):
		Global.remove_cash(amount)
		return
	var shortfall := amount - Global.CASH
	Global.remove_cash(Global.CASH)
	Global.take_loan(shortfall)
	Global.banner("Auction loan: $%d" % shortfall)

func _bid(increment: int) -> void:
	var amount := high_bid + increment
	if not Global.can_afford(amount):
		Global.error("You can't afford $%d." % amount)
		return
	_place_bid.rpc_id(1, amount)


## ---- AUCTION SCREEN ----
func _build_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = CanvasLayer.new()
	_overlay.layer = 97   # above screens and the round curtain, below Fortuna cards
	var bg := ColorRect.new()
	bg.color = Color("2e2328")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 50
	box.offset_right = -50
	box.offset_top = 80
	box.offset_bottom = -80
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	# The property's picture, large and faded, behind the bids and countdown.
	if ResourceLoader.exists(str(item.get("art", ""))):
		var watermark := TextureRect.new()
		watermark.texture = load(item["art"])
		watermark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		watermark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		watermark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		watermark.offset_left = 40
		watermark.offset_right = -40
		watermark.offset_top = 520
		watermark.offset_bottom = -260
		watermark.modulate = Color(1, 1, 1, 0.14)
		watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(watermark)
	bg.add_child(box)

	box.add_child(_text("AUCTION", 110))
	box.add_child(_text("%s's property is up for bids" % owner_name, 36))
	var art := TextureRect.new()
	if ResourceLoader.exists(str(item.get("art", ""))):
		art.texture = load(item["art"])
	art.custom_minimum_size = Vector2(0, 260)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(art)
	var condition: String = item.get("condition", "")
	box.add_child(_text("%s%s  |  value $%d  rent $%d" % [item["name"],
			" (%s)" % condition if condition != "" else "", item["value"], item["rent"]], 34))

	_bid_label = _text("", 56)
	box.add_child(_bid_label)
	_time_label = _text("", 120)
	box.add_child(_time_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_bid_buttons.clear()
	for inc in INCREMENTS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 110)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", FONT)
		button.add_theme_font_size_override("font_size", 48)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.482353, 0.494118, 0.388235)
		style.set_corner_radius_all(30)
		var off := style.duplicate()
		off.bg_color.a = 0.35
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, style)
		button.add_theme_stylebox_override("disabled", off)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_bid.bind(inc))
		row.add_child(button)
		_bid_buttons.append(button)
	box.add_child(row)
	box.add_child(_text("Each bid resets the clock to %d seconds." % BID_RESET, 26))
	get_tree().root.add_child(_overlay)

func _refresh() -> void:
	if not is_instance_valid(_overlay):
		return
	if high_bidder == 0:
		_bid_label.text = "No bids yet"
	else:
		var who: String = "You" if high_bidder == multiplayer.get_unique_id() else Network.players.get(high_bidder, "?")
		_bid_label.text = "Highest bid: $%d  (%s)" % [high_bid, who]
	for i in INCREMENTS.size():
		var amount: int = high_bid + INCREMENTS[i]
		_bid_buttons[i].text = "Bid $%d" % amount
		_bid_buttons[i].disabled = not Global.can_afford(amount)

func _text(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", CREAM)
	return label
