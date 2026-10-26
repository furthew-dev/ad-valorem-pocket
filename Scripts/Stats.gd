extends Node
## Running totals for the local player (money in and out, Fortunas, sabotages, loans...).
## Sent with the final report at game over, where final_results.gd turns them into awards.
## Saved with the game so Resume keeps them.

const KEYS := [
	"income",            # every dollar received (loans not counted)
	"expenses",          # every dollar paid out
	"rent",              # rent collected
	"sales",             # properties sold
	"sale_income",       # money from property sales
	"fortunas_good",     # Fortunas that helped (or were kept in hand)
	"fortunas_bad",      # Fortunas that hurt
	"fortuna_losses",    # money lost while a Fortuna was being played
	"sabotages_sent",
	"sabotages_received",
	"sabotage_income",   # penalties victims paid to you
	"blocks",            # Just Say No played
	"properties_owned",  # every property that was ever yours, sold or not
	"investments",       # Certificates of Deposit bought
	"actions_bought",    # Market purchases
	"loans",             # loans taken (active and paid off)
	"borrowed",          # dollars borrowed
	"loans_paid_off",
	"auctions_won",
	"peak_cash",
	"priciest_value",    # most valuable property ever owned...
]

var data: Dictionary = {}
var priciest_name := ""        # ...and its name
var _seen_ids: Dictionary = {} # property ids already counted in properties_owned
var _scan_clock := 0.0


func _ready() -> void:
	reset()
	Global.cash_changed.connect(_on_cash_changed)
	Global.animation_requested.connect(_on_money)
	Fortunas.fortuna_drawn.connect(_on_fortuna_drawn)

func reset() -> void:
	data.clear()
	for key in KEYS:
		data[key] = 0
	priciest_name = ""
	_seen_ids.clear()

func add(key: String, amount: int = 1) -> void:
	data[key] = data.get(key, 0) + amount


## ---- AUTOMATIC TRACKING ----
# Every cash change goes through Global.income_loss, which emits animation_requested.
func _on_money(type: String, total: int, reason: String) -> void:
	if type == "gain":
		if reason == "Loan":
			return
		add("income", total)
		match reason:
			"Rent": add("rent", total)
			"Property Sale": add("sale_income", total)
			"Sabotage": add("sabotage_income", total)
	else:
		add("expenses", total)
		if Fortunas._busy:
			add("fortuna_losses", total)

func _on_cash_changed(cash: int) -> void:
	if cash > data.get("peak_cash", 0):
		data["peak_cash"] = cash

func _on_fortuna_drawn(card: Dictionary) -> void:
	if Fortunas.is_unlucky(card):
		add("fortunas_bad")
	else:
		add("fortunas_good")

# Properties arrive many ways (start hand, buying, building, auctions, swaps), so rather
# than hook each one, look at the hand a couple of times a second and count new ids.
func _process(delta: float) -> void:
	_scan_clock -= delta
	if _scan_clock > 0.0:
		return
	_scan_clock = 0.5
	scan_properties()

func scan_properties() -> void:
	for p in Cards.properties_owned:
		if Cards.is_lot(p) or _seen_ids.has(p["id"]):
			continue
		_seen_ids[p["id"]] = true
		add("properties_owned")
		var value: int = p.get("value", 0) if p.get("value", 0) is int else 0
		if value > data.get("priciest_value", 0):
			data["priciest_value"] = value
			priciest_name = p["name"]


## ---- REPORT / SAVE ----
# What goes to the other players at game over, plus a few end-of-game numbers.
func report() -> Dictionary:
	scan_properties()
	var out := data.duplicate()
	out["priciest_name"] = priciest_name
	out["interest_paid"] = Global.total_interest_paid
	out["cd_worth"] = Actions.get_CD_worth()
	out["env_tokens"] = Expansion.tokens if Network.expansion_on() else 0
	out["portfolio"] = Global.equity()
	out["cash"] = Global.CASH
	out["debt"] = Global.all_loans()
	out["end_properties"] = Cards.properties_owned.filter(func(p): return not Cards.is_lot(p)).size()
	return out

func snapshot() -> Dictionary:
	return {"data": data.duplicate(), "priciest_name": priciest_name, "seen": _seen_ids.keys()}

func restore(saved: Dictionary) -> void:
	reset()
	if saved.is_empty():
		scan_properties()   # an old save: at least count what's in hand now
		return
	for key in saved.get("data", {}):
		data[key] = saved["data"][key]
	priciest_name = saved.get("priciest_name", "")
	for id in saved.get("seen", []):
		_seen_ids[id] = true
