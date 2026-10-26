extends Node
## Expansion Edition (only active when the host turns it on). Autoloaded as "Expansion".
##
##  - Regions: at the start the host deals City / Country / Beach / Mountains to the
##    players (all different up to 4 players; with more, regions repeat).
##  - Environment tokens: every property you get in your own region earns 1 token, kept
##    even if the property is later sold or lost (Cyber Attack wipes them). $5 each at the
##    end (counted in net worth).
##  - The expansion properties' special rules that run by themselves: Dome's free token,
##    two Villas -> two CDs, Mountain Ranch doubling land, Nordic Cottage's sabotage each
##    round, Gothic Mansion rent from every other player. (Cabin swaps, Suites, the Estate's
##    and Volcano's needs are on the property's page: property_info.gd.)

signal changed   # tokens / region changed (the Environment app and Bank listen)

const REGIONS := ["City", "Country", "Beach", "Mountains"]
const TOKEN_WORTH := 5
const ART_DIR := "res://Assets/expansion/environment_framed/"
const ART_FRAME := 50   # the region pictures have a 50 px black frame

var regions: Dictionary = {}   # player name -> region (everyone's, from the host)
var my_region := ""
var tokens := 0
var earned: Array = []         # names of the properties that earned a token (newest last)
var villa_pairs_paid := 0
var _seen_ids: Dictionary = {} # property ids already looked at (each earns at most once)
var gothic_counts: Dictionary = {}   # peer id -> Gothic Mansions that player owns
var _gothic_shared := -1
var _clock := 0.0


func active() -> bool:
	return Network.expansion_on() and Network.in_game


## ---- GAME START / SAVE ----
# Host: one region per player, as different as possible.
static func deal_regions(player_names: Array) -> Dictionary:
	var dealt := {}
	var pool: Array = []
	for player_name in player_names:
		if pool.is_empty():
			pool = REGIONS.duplicate()
			pool.shuffle()
		dealt[player_name] = pool.pop_back()
	return dealt

func start_game(dealt: Dictionary) -> void:
	regions = dealt
	my_region = regions.get(Global.PLAYER, "")
	tokens = 0
	earned.clear()
	villa_pairs_paid = 0
	_seen_ids.clear()
	gothic_counts.clear()
	_gothic_shared = -1
	changed.emit()

func snapshot() -> Dictionary:
	return {"regions": regions.duplicate(), "my_region": my_region, "tokens": tokens,
			"earned": earned.duplicate(), "villa_pairs": villa_pairs_paid, "seen": _seen_ids.keys()}

func restore(saved: Dictionary) -> void:
	regions = saved.get("regions", {})
	my_region = saved.get("my_region", "")
	tokens = int(saved.get("tokens", 0))
	earned = saved.get("earned", [])
	villa_pairs_paid = int(saved.get("villa_pairs", 0))
	_seen_ids.clear()
	for id in saved.get("seen", []):
		_seen_ids[id] = true
	if saved.is_empty():   # an old save: don't hand out tokens for the whole hand again
		for p in Cards.properties_owned:
			_seen_ids[p["id"]] = true
	_gothic_shared = -1
	changed.emit()

func token_worth() -> int:
	return tokens * TOKEN_WORTH if Network.expansion_on() else 0

# Cyber Attack: "Discard all tokens from your Environment Mat."
func wipe_tokens() -> int:
	var lost := tokens
	tokens = 0
	earned.clear()
	changed.emit()
	return lost


## ---- WATCHING THE HAND ----
# New properties arrive many ways (buying, building, auctions, swaps, the starting hand);
# the hand is checked a couple of times a second and each new one is handled once.
func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.5
	if not active():
		return
	for p in Cards.properties_owned.duplicate():
		if not _seen_ids.has(p["id"]):
			_seen_ids[p["id"]] = true
			_on_acquired(p)
	_apply_ranch()
	_share_gothic_if_changed()

func _on_acquired(p: Dictionary) -> void:
	if my_region != "" and str(p.get("region", "")).to_lower() == my_region.to_lower():
		tokens += 1
		earned.append(p["name"])
		Global.banner("+1 Environment token: %s is in your region (%s)." % [p["name"], my_region])
		changed.emit()
	match p.get("special", ""):
		"dome":
			_dome_bonus.call_deferred(p)
		"villa":
			_villa_bonus.call_deferred()

# Dome: a free SkyBnB or Double, to put on any property from its page.
func _dome_bonus(p: Dictionary) -> void:
	await get_tree().create_timer(0.6).timeout
	while Fortunas._busy:
		await get_tree().create_timer(0.3).timeout
	var choice = await Fortunas.ask_player_to_choose("Dome bonus! Pick a free token:", ["SkyBnB", "Double"])
	var key := "skybnb" if choice == "SkyBnB" else "double"
	Actions.actions_owned.append(key)
	Sound.play("saved")
	Global.banner("Free %s from your %s. Add it from any property's page." % [choice, p["name"]], "my_properties")

# Two Villas: two free Certificates of Deposit (again for every further pair).
func _villa_bonus() -> void:
	var villas := owned_count("villa")
	while villa_pairs_paid < villas / 2:
		villa_pairs_paid += 1
		var given := 0
		for i in 2:
			if await Market.buy_action("certificate_of_deposit"):
				Actions.actions_owned.append("certificate_of_deposit")
				given += 1
		if given > 0:
			Sound.play("saved")
			Global.banner("Two Villas! You got %d free Certificate%s of Deposit." % [given, "" if given == 1 else "s"])
		else:
			Global.banner("Two Villas, but the Certificates of Deposit are sold out.")

func owned_count(special: String) -> int:
	return Cards.properties_owned.filter(func(p): return p.get("special", "") == special).size()

func owns(special: String) -> bool:
	return owned_count(special) > 0


## ---- MOUNTAIN RANCH: land worth double ----
# Land, Inheritance and Private Island (and whatever is built on them) carry
# "land_value"; with a Ranch in hand that part counts twice.
func _apply_ranch() -> void:
	var ranch := owns("ranch")
	for p in Cards.properties_owned:
		var land := int(p.get("land_value", 0))
		if land <= 0 or p.get("built_on", p.get("lot_kind", "")) == "land_expansion":
			continue
		var want := land if ranch else 0
		var have := int(p.get("ranch_extra", 0))
		if want == have:
			continue
		var delta := want - have
		for key in ["value", "e_value", "g_value", "f_value", "p_value"]:
			if p.get(key) is int:
				p[key] += delta
		p["ranch_extra"] = want


## ---- ROUND START ----
# Called by Global.process_new_round, after Fortunas and before rent.
func on_new_round() -> void:
	if not active():
		return
	var cottages := owned_count("nordic")
	for i in cottages:
		Actions.actions_owned.append("sabotage")
	if cottages > 0:
		Global.banner("Nordic Cottage: +%d free Sabotage%s." % [cottages, "" if cottages == 1 else "s"])

# Gothic Mansion rent: we pay each other player who owns one, $1 per property we own
# ($2 if it has a SkyBnB), once per Mansion.
func pay_gothic_rent() -> void:
	if not active():
		return
	var per_mansion := 0
	for p in Cards.properties_owned:
		per_mansion += 2 if p.get("has_skybnb", false) else 1
	var me := multiplayer.get_unique_id()
	for id in gothic_counts:
		if id == me or not Network.players.has(id) or gothic_counts[id] <= 0:
			continue
		var amount: int = per_mansion * gothic_counts[id]
		if amount <= 0:
			continue
		var owner_name: String = Network.players[id]
		if Global.can_afford(amount):
			Global.remove_cash(amount, "Gothic Mansion")
		else:   # short: everything we have, and a loan for the rest
			var shortfall := amount - Global.CASH
			Global.remove_cash(Global.CASH, "Gothic Mansion")
			Global.take_loan(shortfall)
		Global.banner("You paid %s $%d rent for their Gothic Mansion." % [owner_name, amount])
		_receive_gothic_rent.rpc_id(id, amount, Global.PLAYER)
		await get_tree().create_timer(0.6).timeout

@rpc("any_peer", "reliable")
func _receive_gothic_rent(amount: int, from_name: String) -> void:
	Global.add_cash(amount, "Gothic Mansion")
	Global.banner("%s paid you $%d Gothic Mansion rent." % [from_name, amount])

func _share_gothic_if_changed() -> void:
	if not Network.is_online():
		return
	var count := owned_count("gothic")
	if count != _gothic_shared:
		_gothic_shared = count
		_receive_gothic_count.rpc(count)

@rpc("any_peer", "reliable")
func _receive_gothic_count(count: int) -> void:
	gothic_counts[multiplayer.get_remote_sender_id()] = count

func _ready() -> void:
	Network.players_changed.connect(func(): _gothic_shared = -1)   # someone (re)joined: tell them


## ---- CABIN: swap with another player (once per Cabin) ----
# Returns a message for the banner, or "" if the player backed out.
func cabin_swap(cabin: Dictionary) -> String:
	var opponents := Fortunas.get_opponents()
	if opponents.is_empty():
		return "There's nobody to swap with."
	var holdings := {}   # player name -> [peer id, their swappable properties]
	for id in opponents:
		var theirs = await Fortunas._ask_peer(id, "list_properties", [])
		if theirs is Array:
			theirs = theirs.filter(func(p): return not p.get("has_insurance", false))
			if not theirs.is_empty():
				holdings[Network.players.get(id, "?")] = [id, theirs]
	if holdings.is_empty():
		return "No other player has an uninsured property to swap."
	var who = await Fortunas.ask_player_to_choose("Swap your Cabin with whom?", holdings.keys() + ["Cancel"])
	if who == null or who == "Cancel":
		return ""
	var take = await Fortunas.ask_player_to_choose("Take which of %s's properties?" % who, holdings[who][1] + ["Cancel"])
	if take == null or not take is Dictionary:
		return ""
	if not Global.action_used():
		return "You are out of Actions."
	var give := cabin.duplicate(true)
	give["cabin_swapped"] = true   # each Cabin swaps only once
	var received = await Fortunas._ask_peer(holdings[who][0], "swap", [take["id"], give])
	if not received is Dictionary or received.is_empty():
		return "Swap failed: %s no longer has that property." % who
	var index := Cards.properties_owned.find(cabin)
	if index == -1:
		Cards.properties_owned.append(received)
	else:
		Cards.properties_owned[index] = received
	Sound.play("switch")
	return "You swapped your Cabin for %s's %s." % [who, received["name"]]


## ---- SUITES ----
const SUITE_RENT := 15
const MAX_SUITES := 4
const SUITE_COST := 10   # paid on top of the Contractor and the action

# Suites never go into anyone's hand or the Market: they're added straight onto a Hotel
# Resort / Luxury Cruise from its page with a Contractor (+1 action), from the shared
# Suites deck (4 Hotel Suites, 4 Cruise Suites). Each one added shows the next of that
# kind's 4 pictures, stacked beside the Hotel / Cruise.

# The picture for the next Suite on this Hotel / Cruise (1st, 2nd, 3rd, 4th).
func suite_art(host: Dictionary) -> String:
	var template: Dictionary = Cards.templates_by_name.get(host.get("suite_kind", ""), {})
	var pictures: Array = template.get("art_variants", [template.get("art", "")])
	return pictures[mini(host.get("suites", []).size(), pictures.size() - 1)]

# Hotel Resort / Luxury Cruise page: take a Suite from the Suites deck with a Contractor.
# Returns a message for the banner ("Suite added..." when it worked).
func build_suite(host: Dictionary) -> String:
	var kind: String = host.get("suite_kind", "")
	var key := "hotel_suite" if kind == "Hotel Suite" else "cruise_suite"
	var problem := suite_problem(host)
	if problem != "":
		return problem
	if not await Market.buy_action(key):
		return "There are no %ss left." % kind
	if not Global.spend(SUITE_COST, "Suite"):   # cash dropped while asking the host: charge it anyway
		Global.remove_cash(SUITE_COST, "Suite")
	Global.action_used()
	Actions.consume("contractor")
	host_add(host, {"id": randi_range(100000, 999999), "name": kind, "art": suite_art(host)})
	Sound.play("hammer")
	return "Suite added! Your %s now earns $%d rent." % [host["name"], host["rent"]]

# Why a Suite can't be added right now ("" = it can).
func suite_problem(host: Dictionary) -> String:
	if host.get("suites", []).size() >= MAX_SUITES:
		return "This %s already has %d Suites." % [host["name"], MAX_SUITES]
	if not Actions.actions_owned.has("contractor"):
		return "You need a Contractor to add a Suite."
	if Global.ACTIONS <= 0:
		return "You are out of Actions."
	if not Global.can_afford(SUITE_COST):
		return "Adding a Suite costs $%d. You don't have enough cash." % SUITE_COST
	return ""

func host_add(host: Dictionary, suite: Dictionary) -> void:
	var stack: Array = host.get("suites", [])
	stack.append({"id": suite["id"], "name": suite["name"], "art": suite["art"]})
	host["suites"] = stack
	host["rent"] += SUITE_RENT
	host["e_rent"] = host["rent"]


## ---- REGION ART ----
var _region_icons: Dictionary = {}   # region -> small round picture (My Properties rows)

func region_icon(region: String) -> Texture2D:
	if _region_icons.has(region):
		return _region_icons[region]
	var atlas := region_texture(region, true) as AtlasTexture
	if atlas == null:
		return null
	var image: Image = atlas.atlas.get_image()
	if image == null:
		return null
	image = image.get_region(Rect2i(atlas.region))
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var side := 64
	image.resize(side, side, Image.INTERPOLATE_BILINEAR)
	var centre := Vector2(side, side) / 2.0
	for y in side:
		for x in side:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centre)
			if d > side / 2.0:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > side / 2.0 - 3.0:
				image.set_pixel(x, y, Color("533c44"))   # a thin ring, like the property icons
	var texture := ImageTexture.create_from_image(image)
	_region_icons[region] = texture
	return texture

# The region picture without its black frame; `square` crops the middle square (icons).
static func region_texture(region: String, square: bool) -> Texture2D:
	var path := ART_DIR + region + ".png"
	if region == "" or not ResourceLoader.exists(path):
		return null
	var source: Texture2D = load(path)
	var inner := Rect2(ART_FRAME, ART_FRAME, source.get_width() - ART_FRAME * 2, source.get_height() - ART_FRAME * 2)
	if square:
		var side := minf(inner.size.x, inner.size.y)
		inner = Rect2(inner.position + (inner.size - Vector2(side, side)) / 2.0, Vector2(side, side))
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = inner
	return atlas
