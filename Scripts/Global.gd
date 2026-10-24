extends Node
## Game-wide state for the local player: cash, actions, round, loans, navigation history.
## UI listens to the signals below rather than polling these values.

signal cash_changed(new_value: int)
signal actions_changed(new_value: int)
signal round_changed(new_value: int)
signal banner_requested(message: String, link: String)   # link: a LINKS key ("" = not tappable)
signal animation_requested(type: String, total: int, reason: String)   # Banner2 money notice: "gain"/"loss" + why

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")

const FORTUNA_THRESHOLD := 25          # cash at end of turn that requires one Fortuna
const SECOND_FORTUNA_THRESHOLD := 100  # cash that requires a second one
var END_GOAL := 200   # set from the lobby's game settings at the start of each game

var PLAYER := "player1"
var A_CAPACITY := 3          # actions per turn: 3 by default, 5 with an LLC
var PROPERTY_CAPACITY := 4
var interest_rate := 0.1
var loans: Array = []
var total_interest_paid := 0

var SOLD := false            # result of the last sale attempt (read by results.gd)
var using_realtor := false   # set by buy_property.gd, read by property_reveal.gd
var new_property := false    # my_properties shows "<name> added to inventory" when true
var new_property_name := ""  # ...with this name (defaults to the last card in the hand)
var build_lot_id := 0        # set while property_reveal is building on an empty lot
var assigning_token := ""    # e.g. "golden_lock": My Properties is picking a property for it
var new_loan := false
# How far this round's start-of-round steps got, so Resume Game carries on from there
# instead of redoing them: {"round": n, "fortunas": Fortunas drawn and finished, "rent": paid?}
var round_progress: Dictionary = {}

var CASH: int = 20:
	set(value):
		CASH = value
		cash_changed.emit(CASH)

var ACTIONS: int = 3:
	set(value):
		ACTIONS = value
		actions_changed.emit(ACTIONS)

var ROUND: int = 1:
	set(value):
		ROUND = value
		round_changed.emit(ROUND)

var _cash_tween: Tween
var _cash_target: int = 0   # where the running cash tween will land


# The Handwriting font has no digits, "$", "-" or most symbols. On a PC Godot quietly
# borrows them from Windows fonts, but phone browsers have none to borrow, so they showed
# as boxes. Comfortaa now fills in any character Handwriting is missing, everywhere.
const HANDWRITING_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const FALLBACK_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")

func _ready() -> void:
	var handwriting: FontFile = HANDWRITING_FONT   # the shared, cached font every scene uses
	if not handwriting.fallbacks.has(FALLBACK_FONT):
		handwriting.fallbacks = handwriting.fallbacks + [FALLBACK_FONT]


## ---- UI HELPERS ----
# `link` makes the banner tappable while it shows: tapping opens that screen
# (e.g. "You need a Contractor" -> the Market). See LINKS.
func banner(message: String, link: String = "") -> void:
	Sound.play("notify")
	banner_requested.emit(message, link)

# Same banner, with the error sound. Use for "you can't do that" messages.
func error(message: String, link: String = "") -> void:
	Sound.play("error")
	banner_requested.emit(message, link)

# Where a tappable banner can take you: key -> [screen, name shown in "Tap to open ..."].
const LINKS := {
	"market": ["res://Scenes/market_actions.tscn", "the Market"],
	"my_properties": ["res://Scenes/my_properties.tscn", "My Properties"],
	"my_actions": ["res://Scenes/my_actions.tscn", "My Actions"],
	"my_loans": ["res://Scenes/my_loans.tscn", "My Loans"],
	"home": ["res://Scenes/home_screen.tscn", "Home"],   # "Tap to open Home"
}

# A tapped banner: go there (Back returns to where you were).
func open_link(link: String) -> void:
	if not LINKS.has(link):
		return
	var target: String = LINKS[link][0]
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == target:
		return   # already there
	Sound.play("click")
	if scene and scene.scene_file_path != "":
		save_scene(scene.scene_file_path)   # keeps the selected property, so Back works
	get_tree().change_scene_to_file(target)

# `reason` is shown next to the amount ("+$12 Rent", "-$10 Sabotage").
func income_loss(type: String, total: int, reason: String = "") -> void:
	Sound.play("cash_in" if type == "gain" else "cash_out")
	animation_requested.emit(type, total, reason)

# Shows the standard pop-up with a single OK button and waits until it is closed.
func show_notice(message: String) -> void:
	var popup = POPUP_SCENE.instantiate()
	get_tree().root.add_child(popup)
	popup.layout(message, "OK", "")
	await popup.tree_exited


## ---- GAME FLOW ----
# Every player runs this when the game starts. Private state only; the shared
# decks/stock were already set up by the host (Market.setup_new_game).
func start_game() -> void:
	Stats.reset()
	A_CAPACITY = 3
	PROPERTY_CAPACITY = 4
	loans.clear()
	total_interest_paid = 0
	Actions.actions_owned.clear()
	Cards.properties_owned.clear()
	Cards.properties_revealed.clear()
	tab_history.clear()
	round_progress = {}
	var settings: Dictionary = Network.game_settings   # chosen by the host in the lobby
	END_GOAL = settings["end_goal"]
	ROUND = 1
	CASH = settings["start_cash"]
	ACTIONS = A_CAPACITY
	await Cards.draw_into_hand(settings["start_properties"])

# Pressing End Turn: hand over to Turns, which waits for every player.
func end_turn() -> void:
	Turns.end_turn()

# Runs on every phone once all players have ended their turn and the "Round N"
# transition has played: Fortuna (if needed), special properties, rent, loan interest.
# (Winning is checked by Turns before the round starts: > END_GOAL cash and no loans.)
# Start of a round: Fortuna(s), then rent and loan interest. Each step is recorded in
# round_progress as it finishes, so after Resume Game this picks up where it stopped.
func process_new_round() -> void:
	if round_progress.get("round", -1) != ROUND:
		round_progress = {"round": ROUND, "fortunas": 0, "rent": false}
	if round_progress["rent"]:
		return   # this round's start is already done
	await has_fortuna()
	await get_tree().create_timer(0.75).timeout   # let Fortuna cash changes settle first

	special_property()
	# Fortuna resolves before rent, so "no rent next round" skips THIS collection.
	var rent_earned = expected_rent()
	for property in Cards.properties_owned:
		property["no_rent_rounds"] = max(property.get("no_rent_rounds", 0) - 1, 0)
	income(rent_earned, "Rent")
	updating_loan_balance()
	round_progress["rent"] = true

func round_start_finished() -> bool:
	return round_progress.get("round", -1) == ROUND and round_progress.get("rent", false)

func has_fortuna() -> void:
	var drawn: int = round_progress.get("fortunas", 0)
	if drawn == 0:
		if CASH < FORTUNA_THRESHOLD:
			print("You're safe, no need for fortuna.")
			round_progress["fortunas"] = 2
			return
		await _draw_required_fortuna("You must draw a Fortuna card.")
		round_progress["fortunas"] = 1
	if round_progress.get("fortunas", 0) == 1:
		if CASH >= SECOND_FORTUNA_THRESHOLD:
			await _draw_required_fortuna("You must draw another Fortuna card.")
		round_progress["fortunas"] = 2

func _draw_required_fortuna(message: String) -> void:
	await show_notice(message)
	await Fortunas.play_fortuna()

# Specials are Apartment, Terraced House and Castle.
func special_property() -> void:
	for property in Cards.properties_owned:
		match property["name"]:
			"Apartment":
				property["rent"] = 3 * Cards.tenants()
			"Terraced House":   # value and rent grow by 1 each round owned
				property["round"] += 1
				property["rent"] += 1
				property["value"] += 1
			"Castle":
				pass   # TODO (multiplayer): all players gain $5

func action_used() -> bool:
	if ACTIONS <= 0:
		print("No more actions!")
		return false
	ACTIONS -= 1
	print("1 Action used, %d left" % ACTIONS)
	return true


## ---- CASH ----
# Every change to CASH should go through one of these so the Banner2 notice
# shows and a running tween can never overwrite (and lose) a payment.

func can_afford(amount: int) -> bool:
	return amount <= _settled_cash()

# Instantly adds cash and shows the green notice.
func add_cash(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	_finish_cash_tween()
	CASH += amount
	income_loss("gain", amount, reason)

# Instantly removes cash and shows the red notice. Can go below zero (fines).
func remove_cash(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	_finish_cash_tween()
	CASH -= amount
	income_loss("loss", amount, reason)

# Animated gain (rent). The notice shows first, then the balance counts up.
func income(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	income_loss("gain", amount, reason)
	await get_tree().create_timer(0.75).timeout
	_tween_cash_to(_settled_cash() + amount, 0.8, Tween.TRANS_BACK)   # slight bounce

# Animated spend. Returns false (and charges nothing) if the player can't afford it.
func spend(amount: int, reason: String = "", duration: float = 0.5) -> bool:
	if not can_afford(amount):
		return false
	if amount == 0:
		return true
	income_loss("loss", amount, reason)
	_tween_cash_to(_settled_cash() - amount, duration, Tween.TRANS_QUAD)
	return true

# Charges instantly if affordable, otherwise shows "Insufficient funds".
func has_enough_funds(amount: int, reason: String = "") -> bool:
	if amount == 0:
		return true
	if not can_afford(amount):
		error("Insufficient funds")
		return false
	remove_cash(amount, reason)
	return true

func _settled_cash() -> int:
	if _cash_tween and _cash_tween.is_valid():
		return _cash_target
	return CASH

func _finish_cash_tween() -> void:
	if _cash_tween and _cash_tween.is_valid():
		_cash_tween.kill()
		CASH = _cash_target

func _tween_cash_to(target: int, duration: float, trans: Tween.TransitionType) -> void:
	_finish_cash_tween()
	_cash_target = target
	_cash_tween = create_tween()
	_cash_tween.set_trans(trans)
	_cash_tween.set_ease(Tween.EASE_OUT)
	_cash_tween.tween_property(self, "CASH", target, duration)   # setter fires cash_changed

func expected_rent() -> int:
	var rent = 0
	for property in Cards.properties_owned:
		if property.get("no_rent_rounds", 0) > 0:
			continue
		rent += property["rent"]
	return rent

# Cash + property values + CDs - loans. Used for the final standings.
func net_worth() -> int:
	return CASH + equity() + Actions.get_CD_worth() - all_loans()

func equity() -> int:
	var total = 0
	for home in Cards.properties_owned:
		total += home["value"]
	return total


## ---- LOANS ----
func all_loans() -> int:
	var balance = 0
	for loan in loans:
		balance += loan["loan_balance"]
	return balance

func updating_loan_balance() -> void:
	for loan in loans:
		var new_balance = plus_interest(loan["loan_balance"])
		total_interest_paid += new_balance - loan["loan_balance"]
		loan["loan_balance"] = new_balance

# Returns the balance after one round of interest (e.g. 20 -> 22), interest rounded up.
func plus_interest(loan_balance: int) -> int:
	return loan_balance + interest_due(loan_balance)

func interest_due(loan_balance: int) -> int:
	# snappedf stops float noise (e.g. 2.0000000001) from rounding up an extra dollar
	return ceili(snappedf(loan_balance * interest_rate, 0.0001))

func take_loan(amount: int) -> Dictionary:
	var loan = {"loan_number": randi_range(100000, 999999), "loan_balance": amount}
	loans.append(loan)
	new_loan = true
	Stats.add("loans")
	Stats.add("borrowed", amount)
	return loan

func pay_loan(loan_number: int, amount: int) -> bool:
	if ACTIONS <= 0:
		error("You are out of Actions. End your turn for more.", "home")
		return false
	if amount <= 0 or not has_enough_funds(amount, "Loan Payment"):   # has_enough_funds deducts CASH
		return false
	for i in loans.size():
		if loans[i]["loan_number"] == loan_number:
			loans[i]["loan_balance"] -= amount
			if loans[i]["loan_balance"] <= 0:
				loans.remove_at(i)
				_celebrate_paid_off(loan_number)
			return true
	return false


# A loan just hit $0: confetti!
func _celebrate_paid_off(loan_number: int) -> void:
	Stats.add("loans_paid_off")
	ConfettiFx.play(get_tree())
	Sound.play("saved")
	banner("Loan #%d is paid off!" % loan_number if all_loans() > 0 else "Loan paid off! You're debt free!")


## ---- ACTION TOKENS ON PROPERTIES ----
# Each of these spends one action.
func activate_skybnb(property: Dictionary) -> void:
	property["has_skybnb"] = true
	for key in ["rent", "e_rent"]:
		property[key] *= 2
	if property["has_condition"]:
		for key in ["g_rent", "f_rent", "p_rent"]:
			property[key] *= 2
	action_used()

func activate_double(property: Dictionary) -> void:
	property["has_double"] = true
	for key in ["value", "e_value"]:
		property[key] *= 2
	if property["has_condition"]:
		for key in ["g_value", "f_value", "p_value"]:
			property[key] *= 2
	action_used()

# Raises the condition one level (value AND rent). Returns false if it can't be upgraded.
func activate_contractor(property: Dictionary) -> bool:
	if not property.get("has_condition", false) or property["condition"] == "excellent":
		return false
	Fortunas.shift_condition(property, 1)
	action_used()
	return true


## ---- TRANSITION ANIMATION DATA ----
var my_properties_app = {"app_color": "92868b", "app_anim": "my_properties", "app_url": "res://Scenes/my_properties.tscn"}
var market_app = {"app_color": "b76051", "app_anim": "market", "app_url": "res://Scenes/market.tscn"}
var bank_app = {"app_color": "5d6558", "app_anim": "bank", "app_url": "res://Scenes/bank_account.tscn"}
var my_loans_app = {"app_color": "744145", "app_anim": "my_loans", "app_url": "res://Scenes/my_loans.tscn"}
var my_actions_app = {"app_color": "a78767", "app_anim": "my_actions", "app_url": "res://Scenes/my_actions.tscn"}
var mystery = {"app_color": "534650", "app_anim": "mystery", "app_url": "res://Scenes/results.tscn"}
var sold = {"app_color": "96514b", "app_anim": "sold", "app_url": "res://Scenes/results.tscn"}
var failed = {"app_color": "96514b", "app_anim": "failed", "app_url": "res://Scenes/results.tscn"}
var intro = {"app_color": "533c44", "app_anim": "intro", "app_url": "res://Scenes/home_screen.tscn"}
var purchasing = {"app_color": "533c44", "app_anim": "purchasing", "app_url": "res://Scenes/my_properties.tscn"}


## ---- BACK BUTTON ----
var tab_history: Array[String] = []

func save_scene(current_scene: String) -> void:
	tab_history.append(current_scene)

func erase_scenes() -> void:
	tab_history.clear()

func go_back() -> void:
	if tab_history.is_empty():
		return
	get_tree().change_scene_to_file(tab_history.pop_back())
