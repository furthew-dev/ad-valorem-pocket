extends Node
## Messages (autoload "Messages"): the phone's texting app, filled by the game.
##   - A thread per other player: what they did to you ("Steve took $4 from you for their
##     Gothic Mansion rent.") and the reactions you send each other ("Ha!", "Ouch!").
##   - "Everyone": the table's big moments (purchases, sales, Fortunas, sabotage) as they
##     happen, plus reactions sent to the whole table. Online games only.
##   - "Bank": rent, interest, loans (forced loans included). "Fortuna": your cards.
## Texts from players pop up as a banner ("Steve: ...") that opens the thread.
## The moments also feed the round-end recap (round_recap.gd). Saved with the game.

signal changed
signal open_asked   # a Messages banner was tapped while the app is already open

const BANK := "Bank"
const FORTUNA := "Fortuna"
const EVERYONE := "Everyone"
const MAX_PER_THREAD := 80
# Preset replies: quick to send, nothing to moderate. (No emoji: the fonts don't have them.)
const REACTIONS := ["Ha!", "Ouch!", "Nice one!", "Not again...", "Revenge is coming", "Pleasure doing business", "Hurry up!"]
const REACT_GAP := 1.5   # seconds between reactions (no spamming)

# contact -> [{text, mine, from, kind, round, at}], oldest first
var threads: Dictionary = {}
var unread: Dictionary = {}       # contact -> count
var last_at: Dictionary = {}      # contact -> when its last message arrived (for sorting)
var moments: Array = []           # [{who, kind, text, amount, target, round}] (recap)
var viewing := ""                 # the thread open on screen (its texts arrive read)
var wanted := ""                  # open this thread when the app opens (a tapped banner)
var asked_at := -100.0            # when a "Tap to open Messages" banner was tapped
var dirty := false

var _sent_at := -100.0
var _stamp := 0


func _ready() -> void:
	Fortunas.fortuna_drawn.connect(_on_fortuna_drawn)
	Fortunas.fortuna_resolved.connect(func(_card: Dictionary, message: String):
		if message != "":
			post(FORTUNA, message))


## ---- THREADS ----
# Adds a text to a thread on this phone.
func post(contact: String, text: String, kind: String = "info", mine: bool = false, from: String = "") -> void:
	if text.strip_edges() == "" or contact == "":
		return
	if not threads.has(contact):
		threads[contact] = []
	_stamp += 1
	var entry := {"text": text, "mine": mine, "from": from if from != "" else contact,
			"kind": kind, "round": Global.ROUND, "at": _stamp}
	threads[contact].append(entry)
	if threads[contact].size() > MAX_PER_THREAD:
		threads[contact] = threads[contact].slice(threads[contact].size() - MAX_PER_THREAD)
	last_at[contact] = _stamp
	if not mine and contact != viewing:
		unread[contact] = int(unread.get(contact, 0)) + 1
	dirty = true
	changed.emit()

# A text from another player about something they did to you: into their thread, into
# Activity, and (unless `quiet`) a banner preview that opens the thread when tapped.
func incoming(contact: String, text: String, kind: String = "event", quiet: bool = false, sound: String = "notify") -> void:
	post(contact, text, kind)
	Activity.add(text, "info")
	if quiet or contact == viewing:
		return
	if sound != "":
		Sound.play(sound)
	_want(contact)
	# The text usually names them already ("Steve took $4..."); otherwise "Steve: Ha!".
	Global.banner_requested.emit(text if text.begins_with(contact) else "%s: %s" % [contact, text], "messages")

func _want(contact: String) -> void:
	wanted = contact

# A Messages banner was tapped (Global.open_link): open the thread it was about.
func banner_tapped() -> void:
	asked_at = Time.get_ticks_msec() / 1000.0
	open_asked.emit()

# The thread a just-tapped banner was about ("" if the app was opened another way).
func take_wanted() -> String:
	var contact := wanted if Time.get_ticks_msec() / 1000.0 - asked_at < 3.0 else ""
	asked_at = -100.0
	return contact

func total_unread() -> int:
	var n := 0
	for contact in unread:
		n += int(unread[contact])
	return n

func mark_read(contact: String) -> void:
	if unread.get(contact, 0) != 0:
		unread[contact] = 0
		dirty = true
		changed.emit()

# Threads, most recent first.
func contacts() -> Array:
	var list := threads.keys()
	list.sort_custom(func(a, b): return int(last_at.get(a, 0)) > int(last_at.get(b, 0)))
	return list

func is_player(contact: String) -> bool:
	return not contact in [BANK, FORTUNA, EVERYONE]


## ---- PLAYER TO PLAYER ----
func _peer_of(player_name: String) -> int:
	for id in Network.players:
		if Network.players[id] == player_name:
			return id
	return 0

# A text about an event, sent to one player (it lands in MY thread on their phone).
func send_event(player_name: String, text: String, quiet: bool = false) -> void:
	var id := _peer_of(player_name)
	if id == 0 or not Network.is_online():
		return
	_receive_event.rpc_id(id, text, quiet)

@rpc("any_peer", "reliable")
func _receive_event(text: String, quiet: bool) -> void:
	var sender: String = Network.players.get(multiplayer.get_remote_sender_id(), "Someone")
	incoming(sender, text, "event", quiet)

func can_react() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _sent_at >= REACT_GAP

# A preset reaction to one player, or to the whole table (EVERYONE).
func react(contact: String, phrase: String) -> bool:
	if not phrase in REACTIONS or not can_react() or not Network.is_online():
		return false
	_sent_at = Time.get_ticks_msec() / 1000.0
	post(contact, phrase, "reaction", true, Turns.my_name())
	if contact == EVERYONE:
		_receive_reaction.rpc(phrase, true)
	else:
		var id := _peer_of(contact)
		if id == 0:
			return false
		_receive_reaction.rpc_id(id, phrase, false)
	Sound.play("switch")
	return true

@rpc("any_peer", "reliable")
func _receive_reaction(phrase: String, to_everyone: bool) -> void:
	if not phrase in REACTIONS:
		return
	var sender: String = Network.players.get(multiplayer.get_remote_sender_id(), "Someone")
	var contact := EVERYONE if to_everyone else sender
	post(contact, phrase, "reaction", false, sender)
	if contact == viewing:
		return
	Sound.play("notify")
	_want(contact)
	Global.banner_requested.emit("%s: %s" % [sender if not to_everyone else sender + " (to everyone)", phrase], "messages")


## ---- THE TABLE'S MOMENTS ----
# Something worth telling the table: everyone's "Everyone" thread and the round recap.
#   kind: "buy", "sell", "fortuna_good", "fortuna_bad", "sabotage", "auction"
#   text: what happened, without the name ("bought a Castle for $100"); "{target}" is
#   replaced by the target's name, or "you" on the target's phone.
func share_moment(kind: String, text: String, amount: int = 0, target: String = "") -> void:
	if get_tree().root.has_node("Tutorial"):
		return
	var moment := {"who": Turns.my_name(), "kind": kind, "text": text, "amount": amount,
			"target": target, "round": Global.ROUND}
	if Network.is_online():
		_receive_moment.rpc(moment)
	_store_moment(moment)

@rpc("any_peer", "reliable")
func _receive_moment(moment: Dictionary) -> void:
	moment["who"] = Network.players.get(multiplayer.get_remote_sender_id(), str(moment.get("who", "?")))
	_store_moment(moment)

func _store_moment(moment: Dictionary) -> void:
	moments.append(moment)
	if moments.size() > 120:
		moments = moments.slice(moments.size() - 120)
	dirty = true
	if Network.is_online():
		var mine: bool = moment["who"] == Turns.my_name()
		post(EVERYONE, describe(moment), str(moment["kind"]), mine, str(moment["who"]))

# "Steve bought a Castle for $100" (or "You bought..."); without_name: "bought a Castle...".
func describe(moment: Dictionary, with_name: bool = true) -> String:
	var me := Turns.my_name()
	var target: String = str(moment.get("target", ""))
	var text: String = str(moment.get("text", "")).replace("{target}", "you" if target == me else target)
	if not with_name:
		return text.left(1).to_upper() + text.substr(1)
	var who: String = "You" if moment.get("who", "") == me else str(moment.get("who", "?"))
	return "%s %s" % [who, text]

func moments_in(round_number: int) -> Array:
	return moments.filter(func(m): return int(m.get("round", 0)) == round_number)

func _on_fortuna_drawn(card: Dictionary) -> void:
	var card_name: String = str(card.get("name", "a Fortuna"))
	post(FORTUNA, "You drew %s." % card_name, "fortuna_bad" if Fortunas.is_unlucky(card) else "fortuna_good")
	share_moment("fortuna_bad" if Fortunas.is_unlucky(card) else "fortuna_good", "drew %s" % card_name)


## ---- SAVE / NEW GAME ----
func clear() -> void:
	threads = {}
	unread = {}
	last_at = {}
	moments = []
	viewing = ""
	wanted = ""
	_stamp = 0
	dirty = true
	changed.emit()

func snapshot() -> Dictionary:
	return {"threads": threads.duplicate(true), "unread": unread.duplicate(), "last_at": last_at.duplicate(),
			"moments": moments.duplicate(true), "stamp": _stamp}

func restore(saved) -> void:
	clear()
	if not saved is Dictionary:
		return
	for contact in saved.get("threads", {}):
		var list = saved["threads"][contact]
		if list is Array:
			threads[str(contact)] = list.filter(func(m): return m is Dictionary and m.has("text"))
	unread = saved.get("unread", {}) if saved.get("unread", {}) is Dictionary else {}
	last_at = saved.get("last_at", {}) if saved.get("last_at", {}) is Dictionary else {}
	moments = saved.get("moments", []) if saved.get("moments", []) is Array else []
	_stamp = int(saved.get("stamp", 0))
	dirty = false
	changed.emit()
