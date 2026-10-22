extends Node
## Action tokens: market definitions (with shared stock) and the player's inventory.
## actions_owned holds keys like "contractor", matching all_actions below. It is private
## to this player; the stock numbers are shared and synced by Market.gd.

var actions_owned: Array = []


## ---- TOKEN DEFINITIONS ----
var attorney = {
	"name": "Attorney",
	"cost": 4,
	"stock": 10,
	"art": "res://Assets/icons/attorney_icon.png",
	"description": "Protects the assigned Property from specific legal Fortuna cards."
}
var certificate_of_deposit = {   # TODO: needs its own image
	"name": "Certificate of Deposit",
	"cost": 50,
	"stock": 12,
	"art": "res://Assets/icons/sell_icon.png",
	"description": "Reserves your cash. Gain $10 for every two of these you own."
}
var contractor = {   # TODO: needs its own image
	"name": "Contractor",
	"cost": 2,
	"stock": 15,
	"art": "res://Assets/icons/tokens/contractor_icon.png",
	"description": "Upgrades a property's condition to the next level. Builds a new Property on land."
}
var double = {
	"name": "Double",
	"cost": 25,
	"stock": 12,
	"art": "res://Assets/icons/double_icon.png",
	"description": "Doubles the Value of applicable properties it is assigned to."
}
var golden_lock = {
	"name": "Golden Lock",
	"cost": 75,
	"stock": 4,
	"art": "res://Assets/icons/tokens/lock_icon.png",
	"description": "Keeps the assigned property fixed, unable to be harmed nor sold."
}
var llc = {
	"name": "LLC",
	"cost": 20,
	"stock": 4,
	"art": "res://Assets/icons/llc_icon.png",
	"description": "Increases the number of Actions per turn to 5."
}
var sabotage = {
	"name": "Sabotage",
	"cost": 10,
	"stock": 12,
	"art": "res://Assets/icons/tokens/sabotage_icon.png",
	"description": "Make another player draw a Fortuna. Any penalty they pay goes to you, and you take any benefit."
}
var insurance = {
	"name": "Insurance",
	"cost": 10,
	"stock": 12,
	"art": "res://Assets/icons/insurance_icon.png",
	"description": "Keeps property safe from specific Fortunas. Lost once used as defence."
}
var skybnb = {
	"name": "SkyBnB",
	"cost": 10,
	"stock": 12,
	"art": "res://Assets/icons/skybnb_icon.png",
	"description": "Doubles the Rent of applicable properties it is assigned to."
}
var land_expansion = {   # TODO: description
	"name": "Land Expansion",
	"cost": 50,
	"stock": 4,
	"art": "res://Assets/icons/tokens/expansion_icon.png",
	"description": "Increases your Property capacity by one."
}
var listing_agent = {   # TODO: needs art and description
	"name": "Listing Agent",
	"cost": 2,
	"stock": 12,
	"art": "res://Assets/icons/tokens/listing_agent_icon.png",
	"description": "Increase the probability of selling your property."
}
var realtor = {
	"name": "Realtor",
	"cost": 3,
	"stock": 12,
	"art": "res://Assets/icons/realtor.png",
	"description": "Reveals 3 Properties at purchase instead of 1. Fine is $3 if you back out of sale."
}

var action_types = [
	attorney,
	certificate_of_deposit,
	contractor,
	double,
	golden_lock,
	llc,
	sabotage,
	insurance,
	skybnb,
	land_expansion,
	listing_agent,
	realtor
]

var all_actions = {
	"attorney": attorney,
	"certificate_of_deposit": certificate_of_deposit,
	"contractor": contractor,
	"double": double,
	"golden_lock": golden_lock,
	"llc": llc,
	"sabotage": sabotage,
	"insurance": insurance,
	"skybnb": skybnb,
	"land_expansion": land_expansion,
	"listing_agent": listing_agent,
	"realtor": realtor,
}

var _starting_stock: Dictionary = {}


func _ready() -> void:
	for key in all_actions:
		_starting_stock[key] = all_actions[key]["stock"]

# Shared market stock back to full (host / solo, at the start of a game).
func reset_stock() -> void:
	for key in all_actions:
		all_actions[key]["stock"] = _starting_stock[key]

# Removes one owned token by key (e.g. "realtor"). Returns false if none was owned.
func consume(key: String) -> bool:
	var index = actions_owned.find(key)
	if index == -1:
		return false
	actions_owned.remove_at(index)
	return true

# Call BEFORE appending "llc" to actions_owned.
func llc_added() -> void:
	if "llc" in actions_owned:
		return
	Global.A_CAPACITY = 5
	Global.banner("You now have 5 Actions per round.")

# Certificates of Deposit are worth $110 per pair and $50 for a single one.
func get_CD_worth() -> int:
	var count = actions_owned.count("certificate_of_deposit")
	@warning_ignore("integer_division")
	return (count / 2) * 110 + (count % 2) * 50
