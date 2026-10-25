extends Node
## Live auctions (the Auction Fortuna). Autoloaded as "Auction".
##
## The owner's property goes up for auction on EVERY phone at once. Anyone (the owner
## included) can bid. Each bid resets the clock to BID_RESET seconds; when it runs out
## the highest bidder pays and gets the property, and the owner receives the money.
## The host runs the clock and decides the winner; everyone else just shows it.
##
## The clock only starts once every player is free to bid (not reading their own Fortuna
## or answering a menu), or after MAX_READY_WAIT seconds, so nobody gets skipped.

signal _owner_result(winner_id: int, winner_name: String, bid: int)

const OPENING_TIME := 10.0   # seconds before the first bid must come in
const MAX_READY_WAIT := 30.0 # never wait longer than this for busy players
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
var clock_running := false     # false while waiting for busy players
var waiting_for: Array = []     # names of players still busy (shown on the auction screen)

var _ready_ids: Dictionary = {}   # host: players who are free to bid
var _wait_started := 0.0          # host: when this auction opened
var _my_run_pending := false      # we're the owner, waiting for our auction's result

var _queue: Array = []   # host only: auctions waiting for the current one to finish
var _overlay: CanvasLayer
var _bid_label: Label
var _bid_row: HBoxContainer
var _bid_face: Control
const AvatarArt = preload("res://Scripts/avatar.gd")
var _time_label: Label
var _bid_buttons: Array[Button] = []


func _ready() -> void:
	Network.players_changed.connect(_on_players_changed)
	Network.host_back.connect(_on_host_back)


## ---- OWNER (called from the Auction Fortuna) ----
# Puts `property` up for auction and waits for the result. Returns a banner message.
func run(property: Dictionary) -> String:
	_my_run_pending = true
	_request_start.rpc_id(1, Global.PLAYER, property)
	var result: Array = await _owner_result
	_my_run_pending = false
	var winner_id: int = result[0]
	var bid: int = result[2]
	if winner_id == 0:
		return "No sale. You kept your %s." % property["name"]
	if winner_id == multiplayer.get_unique_id():
		return "You won your own auction and kept your %s." % property["name"]
	# Hand it over and get paid first, then the animation (a crash mid-animation can't
	# leave the property with two owners).
	Cards.properties_owned.erase(_find_owned(property["id"]))
	Global.add_cash(bid, "Auction Sale")
	await DiscardFx.play(get_tree(), property, "Sold at auction to %s for $%d" % [result[1], bid])
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
	if not clock_running:
		if multiplayer.is_server():
			_check_ready()   # also starts the clock once MAX_READY_WAIT has passed
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
	if not multiplayer.is_server() or not active or not clock_running or amount <= high_bid:
		return
	var sender := multiplayer.get_remote_sender_id()
	_update.rpc(amount, sender if sender != 0 else 1, BID_RESET)

func _on_players_changed() -> void:
	if not (active and multiplayer.is_server()):
		return
	if not Network.players.has(owner_id):   # the owner left mid-auction: call it off
		active = false
		_close.rpc(0, "", 0)
	else:
		_check_ready()   # maybe the player we were waiting for left


## ---- WAITING FOR EVERYONE TO BE FREE ----
# Each phone reports in once nothing is covering the auction (its own Fortuna card, a
# menu, a sabotage screen...).
func _report_ready_when_free() -> void:
	var opened_item := item
	while is_inside_tree() and active and item == opened_item and _screen_busy():
		await get_tree().create_timer(0.25).timeout
	if active and item == opened_item:
		_ready_to_bid.rpc_id(1)

func _screen_busy() -> bool:
	for node in get_tree().root.get_children():
		if node.has_signal("dismissed") or node.has_signal("chosen") or node is DiscardFx:
			return true   # a Fortuna card, a pick-one menu, the trash animation
		if node is CanvasLayer and node.layer == 95:
			return true   # the "Sabotaged!" screen
	return false

@rpc("any_peer", "call_local", "reliable")
func _ready_to_bid() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_ready_ids[sender if sender != 0 else 1] = true
	_check_ready()

# Host: start the clock when everyone is free (or we've waited long enough); otherwise
# tell everyone who we're waiting for.
func _check_ready() -> void:
	if not active or clock_running:
		return
	var busy := []
	for id in Network.players:
		if not _ready_ids.has(id):
			busy.append(Network.players[id])
	var waited := Time.get_ticks_msec() / 1000.0 - _wait_started
	if busy.is_empty() or waited >= MAX_READY_WAIT:
		_start_clock.rpc()
	elif busy != waiting_for:
		_sync_waiting.rpc(busy)

@rpc("authority", "call_local", "reliable")
func _sync_waiting(names: Array) -> void:
	waiting_for = names
	_refresh()

@rpc("authority", "call_local", "reliable")
func _start_clock() -> void:
	clock_running = true
	waiting_for = []
	time_left = OPENING_TIME
	Sound.play("notify")
	_refresh()

# The host refreshed and came back: it no longer knows about any auction, so call ours off
# (everyone keeps what they had) instead of leaving the auction screen up forever.
func _on_host_back() -> void:
	if active:
		active = false
		clock_running = false
		if is_instance_valid(_overlay):
			_overlay.queue_free()
		Global.banner("The auction was called off (the host reconnected).")
	if _my_run_pending:
		_owner_result.emit(0, "", 0)


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
	clock_running = false
	waiting_for = []
	if multiplayer.is_server():
		_ready_ids.clear()
		_wait_started = Time.get_ticks_msec() / 1000.0
	Sound.play("notify")
	_build_overlay()
	_refresh()
	_report_ready_when_free()

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
	clock_running = false
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	var me := multiplayer.get_unique_id()
	if winner_id == me and me != owner_id:
		_pay(bid)
		var won := item.duplicate(true)
		Cards.properties_owned.append(won)
		Stats.add("auctions_won")
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
		Global.remove_cash(amount, "Auction")
		return
	var shortfall := amount - Global.CASH
	Global.remove_cash(Global.CASH, "Auction")
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
		watermark.texture = Cards.round_icon(item["art"])
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
	var owner_row := HBoxContainer.new()   # [owner's character] Sam's property is up for bids
	owner_row.alignment = BoxContainer.ALIGNMENT_CENTER
	owner_row.add_theme_constant_override("separation", 14)
	owner_row.add_child(AvatarArt.for_player(owner_name, 64))
	var owner_label := _text("%s's property is up for bids" % owner_name, 36)
	owner_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	owner_row.add_child(owner_label)
	box.add_child(owner_row)
	var art := TextureRect.new()
	if ResourceLoader.exists(str(item.get("art", ""))):
		art.texture = Cards.round_icon(item["art"])
	art.custom_minimum_size = Vector2(0, 260)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(art)
	var condition: String = item.get("condition", "")
	box.add_child(_text("%s%s  |  value $%d  rent $%d" % [item["name"],
			" (%s)" % condition if condition != "" else "", item["value"], item["rent"]], 34))

	_bid_label = _text("", 46)
	_bid_row = HBoxContainer.new()   # [leader's character] Highest bid: $40 (Erika)
	_bid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bid_row.add_theme_constant_override("separation", 14)
	_bid_face = AvatarArt.make([0, 0, 0, 0], 72)
	_bid_face.visible = false
	_bid_row.add_child(_bid_face)
	_bid_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bid_row.add_child(_bid_label)
	box.add_child(_bid_row)
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
	if not clock_running:   # waiting for busy players: no bidding yet
		if waiting_for.is_empty():
			_bid_label.text = "Getting everyone ready..."
		else:
			_bid_label.text = "Waiting for %s\nto finish their Fortuna..." % ", ".join(waiting_for)
		_time_label.text = "..."
		for button in _bid_buttons:
			button.text = "Bid $%d" % (high_bid + INCREMENTS[_bid_buttons.find(button)])
			button.disabled = true
		return
	if high_bidder == 0:
		_bid_label.text = "No bids yet"
		_bid_face.visible = false
	else:
		var who: String = "You" if high_bidder == multiplayer.get_unique_id() else Network.players.get(high_bidder, "?")
		_bid_label.text = "Highest bid: $%d  (%s)" % [high_bid, who]
		AvatarArt.update(_bid_face, AvatarArt.for_name(Network.players.get(high_bidder, "")))
		_bid_face.visible = true
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
