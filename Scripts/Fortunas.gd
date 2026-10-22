extends Node

var fortunas_owned = []

var inheritance = {
	"name": "Inheritance",
	"value": 10,
	"fee": 0,
	"stock": 2,
	"art": "res://Assets/fortunas/hidden cash.png",
	"description": "Use a Contractor to search the Property deck and build a property in any condition. Land Value: $10 | Max Property Limit +1",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "build_free_property",
	"target": "none"
}

var appraisal_revaluation = {
	"name": "Appraisal Revaluation",
	"value": 0,
	"fee": 0,
	"stock": 2,
	"art": "res://Assets/fortunas/appraisal revaluation.png",
	"description": "An appraiser evaluated your lowest-value property and found it undervalued. Increase its condition by 1 level (e.g., Fair to Good). If fixed, target 2nd-lowest. Null if all properties have fixed values.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "raise_condition",
	"target": "lowest"
}

var auction = {
	"name": "Auction",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/auction.png",
	"description": "Your highest-value property is up for auction. You and your opponents may bid; the highest bidder wins the property.",
	"voidable_by_attorney": true,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "auction_property",
	"target": "highest"
}

var breach_of_contract = {
	"name": "Breach of Contract",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/breach of contract.png",
	"description": "A renter broke their contract on your highest-value property. Receive no rent on this property next round.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "no_rent_next_round",
	"target": "highest"
}

var confidential = {
	"name": "Confidential",
	"value": 0,
	"fee": 0,
	"stock": 2,
	"art": "res://Assets/fortunas/confidential.png",
	"description": "Keep secret. Play when targeted by a sabotage or penalty from another player to reverse the penalty onto them twofold.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": true,
	"keep_in_hand": true,
	"effect": "reverse_penalty",
	"target": "none"
}

var cyber_attack = {
	"name": "Cyber Attack",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/cyber attack.png",
	"description": "You got scammed! Discard all tokens from your Environment Mat.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": true,
	"keep_in_hand": false,
	"effect": "discard_environment_tokens",
	"target": "none"
}

var double_attack = {
	"name": "Double Attack",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/double.png",
	"description": "Draw the next Fortuna card and play its effect twice.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": true,
	"keep_in_hand": false,
	"effect": "double_next_fortuna",
	"target": "none"
}

var earthquake = {
	"name": "Earthquake",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/earthquake.png",
	"description": "An earthquake demolished your highest-value property. Discard it. (If immune, e.g., Golden Lock, target 2nd-highest property).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "destroy_property",
	"target": "highest"
}

var eminent_domain = {
	"name": "Eminent Domain",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/eminent domain.png",
	"description": "The government seized your highest-value property for public use. Discard the property and receive compensation equal to its value.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "seize_property_compensate",
	"target": "highest"
}

var error = {
	"name": "Error",
	"value": 0,
	"fee": 15,
	"stock": 1,
	"art": "res://Assets/fortunas/error.png",
	"description": "A flaw was found in one of your addendums and you were held liable for personal damages. Pay $15.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "none"
}

var escrow_shortage = {
	"name": "Escrow Shortage",
	"value": 0,
	"fee": 5,
	"stock": 2,
	"art": "res://Assets/fortunas/shortage.png",
	"description": "Annual tax and insurance increases caused an escrow shortage. Pay $5 per property owned.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_per_property",
	"target": "all"
}

var escrow_surplus = {
	"name": "Escrow Surplus",
	"value": 5,
	"fee": 0,
	"stock": 2,
	"art": "res://Assets/fortunas/surplus.png",
	"description": "Annual tax and insurance decreases resulted in an escrow surplus check. Gain $5 per property owned.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "gain_per_property",
	"target": "all"
}

var extended_warranty = {
	"name": "Extended Warranty",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/extended warranty.png",
	"description": "Gain 2 Insurance tokens and place them on any two properties. Keep excess tokens for future use if all properties are insured.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": true,
	"keep_in_hand": false,
	"effect": "gain_insurance_tokens",
	"target": "none"
}

var fire = {
	"name": "Fire",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/fire.png",
	"description": "Your highest-value property burned to the ground. Discard it. (If immune, e.g., Golden Lock, target 2nd-highest property).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "destroy_property",
	"target": "highest"
}

var flood = {
	"name": "Flood",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/flood.png",
	"description": "Your highest-value property flooded. Reduce its condition to Poor. (If fixed, target 2nd-highest. Null if all properties have fixed values).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "set_condition_poor",
	"target": "highest"
}

var free_token = {
	"name": "Free Token",
	"value": 0,
	"fee": 0,
	"stock": 2,
	"art": "res://Assets/fortunas/free token.png",
	"description": "Gain 1 free token of your choice (e.g., CD, LLC, Attorney, Skybnb, Double).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": true,
	"keep_in_hand": false,
	"effect": "gain_free_token",
	"target": "none"
}

var hidden_cash = {
	"name": "Hidden Cash",
	"value": 20,
	"fee": 0,
	"stock": 2,
	"art": "res://Assets/fortunas/hidden cash.png",
	"description": "Hidden cash was found on your property! Gain $20.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "gain_flat",
	"target": "none"
}

var hoa = {
	"name": "HOA",
	"value": 0,
	"fee": 5,
	"stock": 1,
	"art": "res://Assets/fortunas/hoa.png",
	"description": "Your HOA fined you for keeping an untamed lawn. Pay $5 per property owned.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": true,
	"keep_in_hand": false,
	"effect": "pay_per_property",
	"target": "all"
}

var just_say_no = {
	"name": "Just Say No",
	"value": 0,
	"fee": 0,
	"stock": 2,
	"art": "res://Assets/fortunas/just say no.png",
	"description": "Keep on hand. Play at any time to block or counteract one Fortuna card (including sabotages used against you).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": true,
	"keep_in_hand": true,
	"effect": "block_fortuna",
	"target": "none"
}

var lawsuit_asbestos = {
	"name": "Lawsuit (Asbestos)",
	"value": 0,
	"fee": 20,
	"stock": 1,
	"art": "res://Assets/fortunas/lawsuit.png",
	"description": "A renter sued you after finding asbestos on your property. Pay $20.",
	"voidable_by_attorney": true,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "none"
}

var lawsuit_fall = {
	"name": "Lawsuit (Fall)",
	"value": 0,
	"fee": 15,
	"stock": 1,
	"art": "res://Assets/fortunas/lawsuit.png",
	"description": "A passerby fell on your property and sued you. Pay $15.",
	"voidable_by_attorney": true,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "none"
}

var lead_paint = {
	"name": "Lead Paint",
	"value": 0,
	"fee": 20,
	"stock": 1,
	"art": "res://Assets/fortunas/lead based paint.png",
	"description": "Lead-based paint was found in your lowest-value property. Pay $20.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "lowest"
}

var mad_renter = {
	"name": "Mad Renter",
	"value": 0,
	"fee": 10,
	"stock": 1,
	"art": "res://Assets/fortunas/mad renter.png",
	"description": "A mad renter punched a hole in the dining room wall. Pay $10.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "none"
}

var mold = {
	"name": "Mold",
	"value": 0,
	"fee": 10,
	"stock": 1,
	"art": "res://Assets/fortunas/mold.png",
	"description": "Your renter sued you after finding mold. Pay $10.",
	"voidable_by_attorney": true,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "none"
}

var pests = {
	"name": "Pests",
	"value": 0,
	"fee": 12,
	"stock": 2,
	"art": "res://Assets/fortunas/pests.png",
	"description": "Pests were found on your property! Pay $12 per property owned.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_per_property",
	"target": "all"
}

var radon_gas = {
	"name": "Radon Gas",
	"value": 0,
	"fee": 20,
	"stock": 1,
	"art": "res://Assets/fortunas/radon gas.png",
	"description": "Radon gas was found on your 2nd highest-value property. Pay $20.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "second_highest"
}

var swap = {
	"name": "Swap",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/swap.png",
	"description": "Swap one of your properties with any opponent's property.",
	"voidable_by_attorney": true,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "swap_property",
	"target": "none"
}

var termites = {
	"name": "Termites",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/termites.png",
	"description": "Termites were found on your highest-value property. Reduce its condition by 1 level (e.g., Excellent to Good). (If fixed, target 2nd-highest. Null if all properties have fixed values).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "lower_condition",
	"target": "highest"
}

var tornado = {
	"name": "Tornado",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/tornado.png",
	"description": "A tornado destroyed your highest-value property. Discard it. (If insured, gain its value; otherwise, collect nothing).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "destroy_property_insured_payout",
	"target": "highest"
}

var tree = {
	"name": "Tree",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/tree.png",
	"description": "A tree fell on your highest-value property. Repair costs equal half the price of its current condition.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "repair_half_condition_price",
	"target": "highest"
}

var uneven_foundation = {
	"name": "Uneven Foundation",
	"value": 0,
	"fee": 20,
	"stock": 1,
	"art": "res://Assets/fortunas/uneven foundation.png",
	"description": "Uneven foundation found on your lowest-value property. Pay $20.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "lowest"
}

var vandalism = {
	"name": "Vandalism",
	"value": 0,
	"fee": 10,
	"stock": 1,
	"art": "res://Assets/fortunas/wasted.png",
	"description": "Your 2nd lowest-value property was vandalized with spray paint. Pay $10.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "second_lowest"
}

var wasted = {
	"name": "Wasted",
	"value": 0,
	"fee": 0,
	"stock": 1,
	"art": "res://Assets/fortunas/wasted.png",
	"description": "A renter trashed your lowest-value property. Receive no rent on it next round. (If tied for lowest, choose which property is affected).",
	"voidable_by_attorney": false,
	"voidable_by_insurance": false,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "no_rent_next_round",
	"target": "lowest"
}

var wreck = {
	"name": "Wreck",
	"value": 0,
	"fee": 15,
	"stock": 1,
	"art": "res://Assets/fortunas/wreck.png",
	"description": "A car crashed into your lowest-value property. Pay $15.",
	"voidable_by_attorney": false,
	"voidable_by_insurance": true,
	"in_expansion": false,
	"keep_in_hand": false,
	"effect": "pay_flat",
	"target": "lowest"
}

var fortuna_types = [
	inheritance,
	appraisal_revaluation,
	auction,
	breach_of_contract,
	confidential,
	cyber_attack,
	double_attack,
	earthquake,
	eminent_domain,
	error,
	escrow_shortage,
	escrow_surplus,
	extended_warranty,
	fire,
	flood,
	free_token,
	hidden_cash,
	hoa,
	just_say_no,
	lawsuit_asbestos,
	lawsuit_fall,
	lead_paint,
	mad_renter,
	mold,
	pests,
	radon_gas,
	swap,
	termites,
	tornado,
	tree,
	uneven_foundation,
	vandalism,
	wasted,
	wreck
]

var all_fortunas = {
	"inheritance": inheritance,
	"appraisal_revaluation": appraisal_revaluation,
	"auction": auction,
	"breach_of_contract": breach_of_contract,
	"confidential": confidential,
	"cyber_attack": cyber_attack,
	"double_attack": double_attack,
	"earthquake": earthquake,
	"eminent_domain": eminent_domain,
	"error": error,
	"escrow_shortage": escrow_shortage,
	"escrow_surplus": escrow_surplus,
	"extended_warranty": extended_warranty,
	"fire": fire,
	"flood": flood,
	"free_token": free_token,
	"hidden_cash": hidden_cash,
	"hoa": hoa,
	"just_say_no": just_say_no,
	"lawsuit_asbestos": lawsuit_asbestos,
	"lawsuit_fall": lawsuit_fall,
	"lead_paint": lead_paint,
	"mad_renter": mad_renter,
	"mold": mold,
	"pests": pests,
	"radon_gas": radon_gas,
	"swap": swap,
	"termites": termites,
	"tornado": tornado,
	"tree": tree,
	"uneven_foundation": uneven_foundation,
	"vandalism": vandalism,
	"wasted": wasted,
	"wreck": wreck
}

# Keys into all_fortunas. Shared: only the host's copy is used (see Market.gd).
var fortuna_deck: Array = []
var _deck_built: bool = false

## ======================================================================
## FORTUNA LOGIC
## Search for "TODO" to find anything still waiting on a decision or another script.
## ======================================================================

## ---- SIGNALS (your UI connects to these) ----
signal fortuna_drawn(card: Dictionary)
signal fortuna_resolved(card: Dictionary, message: String)
const CHOICE_MENU = preload("res://Scripts/choice_menu.gd")   # pick-one pop-up (built in code)

## ---- CONSTANTS ----
const CONDITION_ORDER = ["poor", "fair", "good", "excellent"]
const CONDITION_PREFIX = {"poor": "p", "fair": "f", "good": "g", "excellent": "e"}

# Cards that only work on properties that have a condition (has_condition == true).
# Properties like Castle/Land/Apartment have fixed values, so these cards skip them.
const CONDITION_EFFECTS = ["raise_condition", "set_condition_poor", "lower_condition"]

# If the target is already at this condition, the card moves on to the next property in line.
const LIMIT_CONDITION = {"raise_condition": "excellent", "lower_condition": "poor"}

# Cards that harm the property itself. Golden Lock ("unable to be harmed") makes it immune.
# TODO: confirm this list. Money-penalty cards (Lead Paint, Wreck, etc.) ignore Golden Lock here.
const LOCK_IMMUNE_EFFECTS = [
	"destroy_property", "destroy_property_insured_payout", "seize_property_compensate",
	"auction_property", "set_condition_poor", "lower_condition"
]

# Cards that help the player. Just Say No is never offered against these.
const BENEFICIAL_EFFECTS = [
	"gain_flat", "gain_per_property", "gain_insurance_tokens", "gain_free_token",
	"raise_condition", "build_free_property"
]

# Tokens offered by Free Token. These are the keys of Actions.all_actions, which is also the
# format the market uses when it adds a purchase to Actions.actions_owned.
# LLC and Golden Lock are left out when you already own one (see _free_token_options).
const TOKEN_KEYS = ["attorney", "certificate_of_deposit", "double", "golden_lock", "insurance", "llc", "skybnb"]

var expansion_enabled: bool = false
var _busy := false          # a Fortuna is on screen / resolving
var _saboteur_id := 0       # set while resolving a sabotage Fortuna
const SABOTAGE_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
# Toggled at game start once expansion add-ons exist (none yet).


## ---- PLAYER / OPPONENT ACCESSORS ----
# Multiplayer comes later. These are the only two places that will need to change.
func _props() -> Array:
	return Cards.properties_owned

# Other players' peer ids (empty in a solo game).
func get_opponents() -> Array:
	if not Network.is_online():
		return []
	var me := multiplayer.get_unique_id()
	return Network.players.keys().filter(func(id): return id != me)


## ---- DECK ----
# Called for every player at the start of a game (clears Fortunas kept in hand).
func new_game() -> void:
	fortunas_owned.clear()

# Host / solo: builds and shuffles the shared deck (Market.setup_new_game calls this).
func generate_fortuna_deck() -> void:
	fortuna_deck.clear()
	for key in all_fortunas:
		var fortuna: Dictionary = all_fortunas[key]
		if fortuna["in_expansion"] and not expansion_enabled:
			continue
		for i in fortuna["stock"]:
			fortuna_deck.append(key)
	fortuna_deck.shuffle()
	_deck_built = true
	validate_art()

# Prints a warning for every card whose art file is missing (catches filename typos early).
func validate_art() -> void:
	for card in fortuna_types:
		if not ResourceLoader.exists(card["art"]):
			push_warning("Fortuna art missing: %s" % card["art"])

# Host side of Market.draw_fortuna(): next key off the shared deck, or "".
func pop_fortuna_key() -> String:
	if not _deck_built:
		generate_fortuna_deck()
	return fortuna_deck.pop_back() if not fortuna_deck.is_empty() else ""

# Draws the next card from the shared deck. Returns {} once the deck has run out.
func draw_fortuna() -> Dictionary:
	var key := await Market.draw_fortuna()
	if key == "":
		return {}
	var card: Dictionary = all_fortunas[key].duplicate()
	card["key"] = key
	return card


## ---- ENTRY POINT: call this when a Fortuna must be drawn ----
# saboteur_id: when another player sabotaged us, penalties we pay go to them and
# beneficial cards are resolved on THEIR phone instead (see SABOTAGE below).
func play_fortuna(saboteur_id: int = 0) -> void:
	await _wait_turn()   # one Fortuna at a time (round draws and sabotage can overlap)
	_busy = true
	_saboteur_id = saboteur_id
	await _play_fortuna(saboteur_id)
	_saboteur_id = 0
	_busy = false

func _play_fortuna(saboteur_id: int) -> void:
	var card := await draw_fortuna()
	if card.is_empty():
		Global.banner("You're lucky! No more Fortunas available")
		return
	fortuna_drawn.emit(card)
	await show_card(card)   # waits until the player presses OK

	if card["keep_in_hand"]:
		fortunas_owned.append(card)
		Global.banner("You kept %s" % card["name"])
		return

	if saboteur_id != 0 and card["effect"] in BENEFICIAL_EFFECTS:
		var saboteur_name: String = Network.players.get(saboteur_id, "Your saboteur")
		_resolve_for_saboteur.rpc_id(saboteur_id, card["key"], Global.PLAYER)
		Global.banner("%s gets the benefit of %s." % [saboteur_name, card["name"]])
		return

	var message: String = await resolve_fortuna(card)
	Global.banner(message)
	fortuna_resolved.emit(card, message)

func _wait_turn() -> void:
	while _busy:
		await get_tree().process_frame


## ---- SABOTAGE ----
# Called from My Actions. Spends the token and an action; the target plays a Fortuna for us.
func sabotage(target_id: int) -> void:
	_receive_sabotage.rpc_id(target_id, Global.PLAYER)
	Global.banner("You sabotaged %s!" % Network.players.get(target_id, "them"))

@rpc("any_peer", "reliable")
func _receive_sabotage(saboteur_name: String) -> void:
	var saboteur_id := multiplayer.get_remote_sender_id()
	await _wait_turn()
	await _play_sabotage_curtain(saboteur_name)
	await play_fortuna(saboteur_id)

# A beneficial card drawn by our victim: we get it, so it resolves here.
@rpc("any_peer", "reliable")
func _resolve_for_saboteur(card_key: String, victim_name: String) -> void:
	await _wait_turn()
	_busy = true
	var card: Dictionary = all_fortunas[card_key].duplicate()
	card["key"] = card_key
	Global.banner("Sabotage paid off! %s drew %s for you." % [victim_name, card["name"]])
	await show_card(card)
	var message: String = await resolve_fortuna(card)
	Global.banner(message)
	_busy = false

# Our victim paid a penalty: the money comes to us.
@rpc("any_peer", "reliable")
func _sabotage_payout(amount: int, victim_name: String) -> void:
	Global.add_cash(amount)
	Global.banner("%s paid you $%d (sabotage)." % [victim_name, amount])

func _play_sabotage_curtain(saboteur_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95   # under the Fortuna card (100)
	var curtain := ColorRect.new()
	curtain.color = Color("5a1f22")
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.modulate.a = 0.0
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	var icon := TextureRect.new()
	icon.texture = load(Actions.sabotage["art"])
	icon.custom_minimum_size = Vector2(320, 320)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.pivot_offset = Vector2(160, 160)
	var label := Label.new()
	label.text = "Sabotaged!\n%s is making you draw a Fortuna." % saboteur_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", SABOTAGE_FONT)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(0.866667, 0.811765, 0.6))
	box.add_child(icon)
	box.add_child(label)
	curtain.add_child(box)
	layer.add_child(curtain)
	get_tree().root.add_child(layer)
	Sound.play("error")

	var tween := create_tween()
	tween.tween_property(curtain, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(icon, "scale", Vector2(1.15, 1.15), 0.4).from(Vector2(0.6, 0.6)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.8)
	tween.tween_property(curtain, "modulate:a", 0.0, 0.4)
	await tween.finished
	layer.queue_free()


# Puts Scenes/fortuna.tscn on top of whatever screen is open and waits for OK.
func show_card(card: Dictionary) -> void:
	var screen = load("res://Scenes/fortuna.tscn").instantiate()
	get_tree().root.add_child(screen)
	screen.show_card(card)
	await screen.dismissed


## ---- RESOLUTION ----
func resolve_fortuna(card: Dictionary) -> String:
	var effect: String = card["effect"]
	var target_rule: String = card["target"]

	# STEP 1: find the property the card targets (if any)
	var target = null
	if target_rule in ["highest", "lowest", "second_highest", "second_lowest"]:
		target = await get_target_property(
			target_rule,
			effect in CONDITION_EFFECTS,
			effect in LOCK_IMMUNE_EFFECTS,
			LIMIT_CONDITION.get(effect, "")
		)
		if target == null:
			return "%s had no valid property to affect." % card["name"]

	# STEP 2: Attorney / Insurance tokens (cards that hit "all" properties are checked per property below)
	# Tornado is skipped because Insurance pays out on it instead of voiding it.
	if target_rule != "all" and effect != "destroy_property_insured_payout":
		if _try_void(card, target):
			return "%s was voided by a protection token." % card["name"]

	# STEP 3: offer Just Say No against harmful cards
	if not (effect in BENEFICIAL_EFFECTS):
		var jsn_index = _find_in_hand("block_fortuna")
		if jsn_index != -1:
			var answer = await ask_player_to_choose("Play Just Say No to block %s?" % card["name"], ["Yes", "No"], 1)
			if answer == "Yes":
				fortunas_owned.remove_at(jsn_index)
				return "%s was blocked by Just Say No." % card["name"]

	# STEP 4: apply the effect
	match effect:
		"pay_flat":
			var forced = pay(card["fee"])
			return _with_loan("Paid %d Rebucks (%s)." % [card["fee"], card["name"]], forced)

		"pay_per_property":
			var chargeable = 0
			for p in _props():
				if _try_void(card, p):   # protected properties are exempt (Pests -> Insurance)
					continue
				chargeable += 1
			var total = card["fee"] * chargeable
			var forced = pay(total)
			return _with_loan("%s: paid %d Rebucks (%d properties)." % [card["name"], total, chargeable], forced)

		"gain_flat":
			gain(card["value"])
			return "Gained %d Rebucks!" % card["value"]

		"gain_per_property":
			var total = card["value"] * _props().size()
			gain(total)
			return "%s: gained %d Rebucks." % [card["name"], total]

		"destroy_property":
			var lost_name = target["name"]
			_remove_property(target)
			# Any loan on the property stays due: loans live in Global.loans, not on the property.
			return "%s destroyed your %s." % [card["name"], lost_name]

		"destroy_property_insured_payout":   # Tornado
			var payout = 0
			if target.get("has_insurance", false):
				payout = target["value"]
			var lost_name = target["name"]
			_remove_property(target)
			gain(payout)
			return "A tornado destroyed your %s. Insurance payout: %d Rebucks." % [lost_name, payout]

		"seize_property_compensate":   # Eminent Domain
			var compensation = target["value"]
			var lost_name = target["name"]
			_remove_property(target)
			gain(compensation)
			return "The government seized your %s. Compensation: %d Rebucks." % [lost_name, compensation]

		"raise_condition":   # Appraisal Revaluation
			shift_condition(target, 1)
			return "Your %s is now in %s condition." % [target["name"], target["condition"]]

		"set_condition_poor":   # Flood
			set_condition(target, "poor")
			return "Your %s flooded and is now in poor condition." % target["name"]

		"lower_condition":   # Termites
			shift_condition(target, -1)
			return "Your %s is now in %s condition." % [target["name"], target["condition"]]

		"repair_half_condition_price":   # Tree (half the current price, rounded up)
			var repair_cost: int = ceili(target["value"] / 2.0)
			var forced = pay(repair_cost)
			return _with_loan("Tree repair on your %s cost %d Rebucks." % [target["name"], repair_cost], forced)

		"no_rent_next_round":   # Breach of Contract, Wasted
			# Global.end_turn() increments ROUND *before* collecting rent, so skipping the collection
			# that happens right after the Fortuna draw IS "next round". No change needed there.
			target["no_rent_rounds"] = 1
			return "No rent from your %s next round." % target["name"]

		"gain_insurance_tokens":   # Extended Warranty
			for i in 2:
				await _take_stock("insurance")
				var uninsured = _props().filter(func(p): return not p.get("has_insurance", false))
				if uninsured.is_empty():
					Actions.actions_owned.append("insurance")   # excess token kept for later
				else:
					var chosen = await ask_player_to_choose("Place an Insurance token on:", uninsured)
					chosen["has_insurance"] = true
			return "You gained 2 Insurance tokens."

		"gain_free_token":
			var options = _free_token_options()
			if options.is_empty():
				return "No tokens are available to claim."
			var token = await ask_player_to_choose("Choose a free token:", options)
			if not await _take_stock(token):
				return "The %s token sold out just now." % Actions.all_actions[token]["name"]
			if token == "llc":
				Actions.llc_added()   # must run BEFORE the append below (it checks actions_owned)
			Actions.actions_owned.append(token)
			return "You gained a free %s token." % Actions.all_actions[token]["name"]

		"build_free_property":   # Inheritance: an empty lot to build on later
			Global.PROPERTY_CAPACITY += 1
			var lot := Cards.make_lot("inheritance")
			Cards.properties_owned.append(lot)
			Global.new_property = true
			Global.new_property_name = lot["name"]
			return "Inheritance! Property limit +1. Build on it from My Properties with a Contractor."

		"discard_environment_tokens":   # Cyber Attack (expansion)
			# TODO: Environment Mat tokens don't exist in code yet. Clear them here.
			return "Cyber Attack! Your Environment Mat tokens were discarded."

		"auction_property":   # everyone bids live; see Scripts/auction.gd
			if get_opponents().is_empty():
				return "Auction skipped (no opponents)."
			return await Auction.run(target)

		"swap_property":
			return await _swap_with_opponent()

		"double_next_fortuna":   # Double Attack (expansion)
			var next_card := await draw_fortuna()
			if next_card.is_empty():
				return "Double Attack fizzled: no more Fortunas available."
			fortuna_drawn.emit(next_card)
			await show_card(next_card)
			if next_card["keep_in_hand"]:
				fortunas_owned.append(next_card)
				# TODO: rule check -- should a kept card (Just Say No) be doubled, i.e. kept twice?
				return "Double Attack drew %s and you kept it." % next_card["name"]
			var first = await resolve_fortuna(next_card)
			var second = await resolve_fortuna(next_card)
			return "Double Attack! " + first + " " + second

		"reverse_penalty", "block_fortuna":
			# Confidential / Just Say No are kept in hand and never resolved from the deck.
			return ""

		_:
			push_warning("No handler for Fortuna effect: %s" % effect)
			return "%s has no effect yet." % card["name"]


## ---- SWAP ----
# Pick an opponent, peek at their properties, take one and give them one of yours.
const NO_SWAP := "Don't swap"

func _swap_with_opponent() -> String:
	var mine := _props().filter(func(p): return not p.get("has_golden_lock", false))
	if mine.is_empty():
		return "Swap skipped: you have no properties to trade."
	# Ask every opponent for their (swappable) properties.
	var holdings := {}   # name -> [peer id, properties]
	for id in get_opponents():
		var theirs = await _ask_peer(id, "list_properties", [])
		if theirs is Array and not theirs.is_empty():
			holdings[Network.players.get(id, "?")] = [id, theirs]
	if holdings.is_empty():
		return "Swap skipped: no opponent has a property to swap."

	var who = await ask_player_to_choose("Swap with which player?", holdings.keys() + [NO_SWAP])
	if who == NO_SWAP:
		return "You chose not to swap."
	var opponent_id: int = holdings[who][0]
	var take = await ask_player_to_choose("%s's properties. Choose one to take:" % who, holdings[who][1] + [NO_SWAP])
	if take is String:
		return "You chose not to swap."
	var give = await ask_player_to_choose("Give %s which of yours?" % who, mine + [NO_SWAP])
	if give is String:
		return "You chose not to swap."

	var received = await _ask_peer(opponent_id, "swap", [take["id"], give])
	if not received is Dictionary or received.is_empty():
		return "Swap failed: %s no longer has that property." % who
	var index := _props().find(give)
	if index == -1:
		_props().append(received)
	else:
		_props()[index] = received
	return "You swapped your %s for %s's %s." % [give["name"], who, received["name"]]

# Opponent side: hand over property `their_id`, take `incoming` in its place.
func _accept_swap(their_id: int, incoming: Dictionary, from_name: String) -> Dictionary:
	for i in _props().size():
		var p: Dictionary = _props()[i]
		if p["id"] == their_id and not p.get("has_golden_lock", false):
			_props()[i] = incoming
			Global.banner("%s swapped your %s for their %s (Swap Fortuna)." % [from_name, p["name"], incoming["name"]])
			return p
	return {}


## ---- ASKING ANOTHER PLAYER (request / reply) ----
signal _peer_reply(request_id: int, result)
var _peer_request_id := 0

func _ask_peer(peer_id: int, request: String, args: Array):
	_peer_request_id += 1
	var id := _peer_request_id
	_peer_request.rpc_id(peer_id, id, request, args)
	var timer := get_tree().create_timer(15.0)   # they may have left
	timer.timeout.connect(func(): _peer_reply.emit(id, null))
	while true:
		var reply: Array = await _peer_reply
		if reply[0] == id:
			return reply[1]

@rpc("any_peer", "reliable")
func _peer_request(id: int, request: String, args: Array) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var result = null
	match request:
		"list_properties":
			result = _props().filter(func(p): return not p.get("has_golden_lock", false))
		"swap":
			result = _accept_swap(args[0], args[1], Network.players.get(sender, "Someone"))
	_peer_answer.rpc_id(sender, id, result)

@rpc("any_peer", "reliable")
func _peer_answer(id: int, result) -> void:
	_peer_reply.emit(id, result)


## ---- HELPERS: money ----
# Takes money INSTANTLY. If the player can't cover it, they pay all the cash they have and are
# forced to take a loan for the shortfall. Returns the loan amount (0 if no loan was needed).
# Instant on purpose so back-to-back payments (e.g. Double Attack) can't overlap.
func pay(amount: int) -> int:
	if amount <= 0:
		return 0
	if _saboteur_id != 0 and Network.is_online():
		_sabotage_payout.rpc_id(_saboteur_id, amount, Global.PLAYER)   # penalty goes to them
	if Global.can_afford(amount):
		Global.remove_cash(amount)
		return 0
	var shortfall = amount - Global.CASH
	Global.remove_cash(Global.CASH)
	Global.take_loan(shortfall)
	return shortfall

func gain(amount: int) -> void:
	Global.add_cash(amount)

func _with_loan(message: String, loan: int) -> String:
	if loan > 0:
		return message + " Forced loan: $%d." % loan
	return message


## ---- HELPERS: properties ----
# rule: "highest", "lowest", "second_highest", "second_lowest". Returns the property Dictionary or null.
# exclude_condition: properties already at this condition are skipped ("next property in line").
func get_target_property(rule: String, needs_condition: bool = false, skip_locked: bool = false, exclude_condition: String = ""):
	var pool: Array = []
	for p in _props():
		if skip_locked and p.get("has_golden_lock", false):
			continue   # immune -> the card moves on to the next property
		if needs_condition and not p.get("has_condition", false):
			continue   # fixed-value property -> card is null for it
		if exclude_condition != "" and p.get("condition", "") == exclude_condition:
			continue   # already at the limit -> next in line
		pool.append(p)

	var index = 1 if rule.begins_with("second") else 0
	if pool.size() <= index:
		return null

	var from_top = rule.ends_with("highest")
	pool.sort_custom(func(a, b): return a["value"] > b["value"] if from_top else a["value"] < b["value"])

	# Ties: the player picks which property is affected (this is the rule printed on Wasted).
	var target_value = pool[index]["value"]
	var tied = pool.filter(func(p): return p["value"] == target_value)
	if tied.size() > 1:
		return await ask_player_to_choose("Tied properties -- choose which is affected:", tied)
	return pool[index]

func set_condition(prop: Dictionary, level: String) -> void:
	var prefix = CONDITION_PREFIX[level]
	prop["condition"] = level
	prop["value"] = prop[prefix + "_value"]
	prop["rent"] = prop[prefix + "_rent"]

# Moves a property up (+1) or down (-1) a condition level. Safe to call on fixed-value properties.
func shift_condition(prop: Dictionary, steps: int) -> void:
	if not prop.get("has_condition", false):
		return
	var i = CONDITION_ORDER.find(prop["condition"])
	i = clampi(i + steps, 0, CONDITION_ORDER.size() - 1)
	set_condition(prop, CONDITION_ORDER[i])

func _remove_property(prop: Dictionary) -> void:
	var props = _props()
	for i in props.size():
		if props[i]["id"] == prop["id"]:
			props.remove_at(i)
			return


## ---- HELPERS: Attorney / Insurance / tokens ----
# Returns true if a protection token voids the card. The token is used up (Attorney AND Insurance).
# Cards with no target property (Lawsuit, Mold, Mad Renter, Swap): ANY property carrying the
# matching token can void it.
func _try_void(card: Dictionary, prop) -> bool:
	var candidates: Array = []
	if prop != null:
		candidates = [prop]
	else:
		candidates = _props()
	for p in candidates:
		if card["voidable_by_attorney"] and p.get("has_attorney", false):
			p["has_attorney"] = false
			return true
		if card["voidable_by_insurance"] and p.get("has_insurance", false):
			p["has_insurance"] = false
			return true
	return false

# Takes one token out of the shared supply, like the market does when you buy one.
func _take_stock(key: String) -> bool:
	return await Market.buy_action(key)

func _owns_golden_lock() -> bool:
	if "golden_lock" in Actions.actions_owned:
		return true
	for p in _props():
		if p.get("has_golden_lock", false):
			return true
	return false

# Tokens the player may pick: still in stock, and no second LLC / Golden Lock.
func _free_token_options() -> Array:
	var options = []
	for key in TOKEN_KEYS:
		var action = Actions.all_actions.get(key)
		if action == null or action["stock"] <= 0:
			continue
		if key == "llc" and "llc" in Actions.actions_owned:
			continue
		if key == "golden_lock" and _owns_golden_lock():
			continue
		options.append(key)
	return options


## ---- HELPERS: cards in hand / UI ----
func _find_in_hand(effect_id: String) -> int:
	for i in fortunas_owned.size():
		if fortunas_owned[i]["effect"] == effect_id:
			return i
	return -1

# Opens a pick-one pop-up and waits for the player. Options can be Strings or property
# Dictionaries; returns the chosen element. (default_index is kept for compatibility, unused.)
func ask_player_to_choose(prompt: String, options: Array, default_index: int = 0):
	if options.is_empty():
		return null
	var menu = CHOICE_MENU.new()
	get_tree().root.add_child(menu)
	menu.setup(prompt, options)
	return await menu.chosen


## ---- TESTING ----
# Makes the NEXT draw a specific card. Example (temporarily, e.g. in a button handler):
#   Fortunas.debug_force_next("flood")
#   await Fortunas.play_fortuna()
func debug_force_next(card_id: String) -> void:
	if not all_fortunas.has(card_id):
		push_warning("Unknown Fortuna id: %s" % card_id)
		return
	if not _deck_built:
		generate_fortuna_deck()
	fortuna_deck.append(card_id)   # host / solo only: the deck lives on the host
