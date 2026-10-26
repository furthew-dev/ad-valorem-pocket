extends Node
## Property card templates, the shared property deck, and the player's hand.

var apartment = {
	"name": "Apartment",
	"region": "City",
	"has_condition": false,
	"condition": "excellent",
	"has_loan": false,
	"allow_skybnb": false,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"value": 20,
	"rent": 3 * tenants(),
	"art": "res://Assets/icons/apartment_icon.png",
	"sale_art": "res://Assets/properties_sale/apartment_listing.png",
	"description": "Number of tenants varies per round. Rent is calculated by multiplying $3 by the number of tenants."
}
var barn = {
	"name": "Barn",
	"region": "Country",
	"art": "res://Assets/icons/barn_icon.png",
	"sale_art": "res://Assets/properties_sale/barn_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 6,
			"good": 4,
			"fair": 2,
			"poor": 0,
		},
		"rent": {
			"excellent": 3,
			"good": 2,
			"fair": 1,
			"poor": 0,
		}
	}
}
var barndominium = {
	"name": "Barndominium",
	"region": "Country",
	"art": "res://Assets/icons/barndominium_icon.png",
	"sale_art": "res://Assets/properties_sale/barndominium_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 14,
			"good": 10,
			"fair": 10,
			"poor": 8,
		},
		"rent": {
			"excellent": 13,
			"good": 9,
			"fair": 9,
			"poor": 7,
		}
	}
}
var beach_house = {
	"name": "Beach House",
	"region": "Beach",
	"art": "res://Assets/icons/beach_icon.png",
	"sale_art": "res://Assets/properties_sale/beachhouse_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 14,
			"good": 12,
			"fair": 10,
			"poor": 8,
		},
		"rent": {
			"excellent": 13,
			"good": 11,
			"fair": 9,
			"poor": 7,
		}
	}
}
var castle = {
	"name": "Castle",
	"region": "Mountains",
	"has_condition": false,
	"condition": "excellent",
	"has_loan": false,
	"allow_skybnb": false,
	"allow_double": false,
	"has_skybnb": false,
	"has_double": false,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"value": 100,
	"rent": 30,
	"art": "res://Assets/icons/castle_icon.png",
	"sale_art": "res://Assets/properties_sale/castle_listing.png",
	"description": "All other players gain $5 per round."
}
var condo = {
	"name": "Condo",
	"region": "City",
	"art": "res://Assets/icons/condo_icon.png",
	"sale_art": "res://Assets/properties_sale/condo_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 10,
			"good": 8,
			"fair": 6,
			"poor": 4,
		},
		"rent": {
			"excellent": 9,
			"good": 7,
			"fair": 5,
			"poor": 3,
		}
	}
}
var duplex = {
	"name": "Duplex",
	"region": "City",
	"art": "res://Assets/icons/duplex_icond.png",
	"sale_art": "res://Assets/properties_sale/duplex_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 8,
			"good": 6,
			"fair": 4,
			"poor": 2,
		},
		"rent": {
			"excellent": 4,
			"good": 3,
			"fair": 2,
			"poor": 1,
		}
	}
}
var lake_house = {
	"name": "Lake House",
	"region": "Mountains",
	"art": "res://Assets/icons/lakehouse_icon.png",
	"sale_art": "res://Assets/properties_sale/lakehouse_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"has_condition": true,
	"description": "",
	"condition": {
		"value": {
			"excellent": 18,
			"good": 16,
			"fair": 14,
			"poor": 12,
		},
		"rent": {
			"excellent": 14,
			"good": 12,
			"fair": 10,
			"poor": 8,
		}
	}
}
var land = {
	"name": "Land",
	"region": "Country",
	"has_condition": false,
	"has_loan": false,
	"allow_skybnb": false,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"condition": "excellent",
	"value": 10,
	"rent": 0,
	"art": "res://Assets/icons/land_icon.png",
	"sale_art": "res://Assets/properties_sale/land_listing.png",
	"description": "Player may use contractor to build any property on Land in any condition"
}
var lighthouse =  {
	"name": "Lighthouse",
	"region": "Beach",
	"art": "res://Assets/icons/lighthouse_icon.png",
	"sale_art": "res://Assets/properties_sale/lighthouse_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 12,
			"good": 12,
			"fair": 6,
			"poor": 6,
		},
		"rent": {
			"excellent": 11,
			"good": 11,
			"fair": 5,
			"poor": 5,
		}
	}
}
var lodge =  {
	"name": "Lodge",
	"region": "Mountains",
	"art": "res://Assets/icons/lodge_icon.png",
	"sale_art": "res://Assets/properties_sale/lodge_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"description": "",
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"condition": {
		"value": {
			"excellent": 12,
			"good": 10,
			"fair": 8,
			"poor": 6,
		},
		"rent": {
			"excellent": 12,
			"good": 10,
			"fair": 8,
			"poor": 6,
		}
	}
}
var mansion =  {
	"name": "Mansion",
	"region": "Country",
	"art": "res://Assets/icons/mansion_icon.png",
	"sale_art": "res://Assets/properties_sale/mansion_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 18,
			"good": 16,
			"fair": 12,
			"poor": 10,
		},
		"rent": {
			"excellent": 14,
			"good": 11,
			"fair": 9,
			"poor": 8,
		}
	}
}
var mobile_home =  {
	"name": "Mobile Home",
	"region": "Mountains",
	"art": "res://Assets/icons/mobile_home_icon.png",
	"sale_art": "res://Assets/properties_sale/mobilehome_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 4,
			"good": 3,
			"fair": 2,
			"poor": 1,
		},
		"rent": {
			"excellent": 3,
			"good": 2,
			"fair": 1,
			"poor": 0,
		}
	}
}
var quadruplex =  {
	"name": "Quadruplex",
	"region": "Beach",
	"art": "res://Assets/icons/quadruplex_icon.png",
	"sale_art": "res://Assets/properties_sale/quadruplex_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 16,
			"good": 14,
			"fair": 12,
			"poor": 10,
		},
		"rent": {
			"excellent": 13,
			"good": 11,
			"fair": 9,
			"poor": 8,
		}
	}
}
var rv =  {
	"name": "RV",
	"region": "Beach",
	"art": "res://Assets/icons/rv_icon.png",
	"sale_art": "res://Assets/properties_sale/rv_listing.png",
	"allow_skybnb": false,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 4,
			"good": 3,
			"fair": 2,
			"poor": 1,
		},
		"rent": {
			"excellent": 5,
			"good": 4,
			"fair": 3,
			"poor": 2,
		}
	}
}
var terraced_house =  {
	"name": "Terraced House",
	"region": "City",
	"has_condition": false,
	"condition": "excellent",
	"has_loan": false,
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"value": 12,
	"rent": 10,
	"art": "res://Assets/icons/terraced_house_icon.png",
	"sale_art": "res://Assets/properties_sale/terracedhouse_listing.png",
	"description": "Each round, value and rent increase by $1.",
	"round": 0
}
var tiny_house =  {
	"name": "Tiny House",
	"region": "Mountains",
	"has_condition": false,
	"condition": "excellent",
	"has_loan": false,
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"value": 6,
	"rent": 10,
	"art": "res://Assets/icons/tiny_house_icon.png",
	"sale_art": "res://Assets/properties_sale/tinyhouse_listing.png",
	"description": "",
}
var two_story_home =  {
	"name": "Two Story Home",
	"region": "Country",
	"art": "res://Assets/icons/two_story_home_icon.png",
	"sale_art": "res://Assets/properties_sale/twostoryhome_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 14,
			"good": 12,
			"fair": 10,
			"poor": 8,
		},
		"rent": {
			"excellent": 7,
			"good": 6,
			"fair": 5,
			"poor": 4,
		}
	}
}
var victorian_home =  {
	"name": "Victorian Home",
	"region": "City",
	"has_condition": false,
	"condition": "excellent",
	"has_loan": false,
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"value": 70,
	"rent": 5,
	"art": "res://Assets/icons/victorian_home_icon.png",
	"sale_art": "res://Assets/properties_sale/victorianhome_listing.png",
	"description": ""
}
var yurt =  {
	"name": "Yurt",
	"region": "Country",
	"art": "res://Assets/icons/yurt_icon.png",
	"sale_art": "res://Assets/properties_sale/yurt_listing.png",
	"allow_skybnb": true,
	"allow_double": true,
	"has_skybnb": false,
	"has_double": false,
	"has_condition": true,
	"has_golden_lock": false,
	"has_attorney": false,
	"has_insurance": false,
	"description": "",
	"condition": {
		"value": {
			"excellent": 8,
			"good": 6,
			"fair": 4,
			"poor": 2,
		},
		"rent": {
			"excellent": 14,
			"good": 12,
			"fair": 10,
			"poor": 8,
		}
	}
}

var property_deck: Array = [apartment, apartment, apartment, apartment,
barn,barn,barn,
barndominium,barndominium,barndominium,barndominium,barndominium,
beach_house,beach_house,beach_house,beach_house,beach_house,
castle,castle,castle,castle,castle,
condo,condo,condo,condo,
duplex,duplex,duplex,duplex,
lake_house,lake_house,lake_house,lake_house,lake_house,
land,land,land,land,land,land,
lighthouse,lighthouse,lighthouse,lighthouse,lighthouse,
lodge,lodge,lodge,lodge,
mansion,mansion,mansion,mansion,mansion,
mobile_home,mobile_home,mobile_home,
quadruplex,quadruplex,quadruplex,quadruplex,quadruplex,
rv,rv,rv,rv,rv,
terraced_house,terraced_house,terraced_house,terraced_house,
tiny_house,tiny_house,tiny_house,tiny_house,tiny_house,
two_story_home,two_story_home,two_story_home,two_story_home,two_story_home,
victorian_home,victorian_home,victorian_home,victorian_home,
yurt,yurt,yurt,yurt]

## ---- EXPANSION EDITION ----
# Built into full templates in _ready (see _expansion_template). Columns:
# name, copies in deck, region, skybnb?, double?, [value, rent] or {condition: [value, rent]},
# art, description, extra keys.
const EXP_ART := "res://Assets/expansion/expansion_property_icons/"
const EXPANSION_DATA := [
	["Cabin", 5, "Country", true, true, [12, 12], "cabin.jpg",
		"As 1 action, swap this Cabin with another player's property that has no Insurance. Each Cabin can only be swapped once.", {"special": "cabin"}],
	["Dome", 4, "Mountains", true, true, [15, 13], "dome.jpg",
		"When you buy, receive or inherit a Dome, you get a free SkyBnB or Double to put on any property.", {"special": "dome"}],
	["Gothic Mansion", 4, "City", false, true, [24, 0], "gothic_mansion.jpg",
		"Rent: every other player pays you $1 for each property they own ($2 for each with a SkyBnB) every round.", {"special": "gothic"}],
	["Haunted Mansion", 4, "City", true, true, {"excellent": [14, 13], "good": [16, 14], "fair": [18, 16], "poor": [20, 18]}, "haunted_mansion.jpg",
		"The spookier the better: worth more in worse condition.", {}],
	["Historical Estate", 5, "Mountains", true, true, {"excellent": [28, 24], "good": [24, 22], "fair": [18, 16], "poor": [12, 10]}, "historical_estate.jpg",
		"Immune to all Fortunas. Takes 2 Contractors to improve by one condition.", {"special": "historical", "immune": true}],
	["Hotel Resort", 4, "City", false, true, [60, 0], "hotel_resort.jpg",
		"Collect up to 4 Hotel Suites: each costs $10 and a Contractor, and adds +$15 rent.", {"special": "suite_host", "suite_kind": "Hotel Suite"}],
	["Luxury Cruise", 4, "Beach", false, true, [40, 0], "luxury_cruise.jpg",
		"Collect up to 4 Cruise Suites: each costs $10 and a Contractor, and adds +$15 rent.", {"special": "suite_host", "suite_kind": "Cruise Suite"}],
	["Hotel Suite", 4, "City", false, false, [0, 0], "cruise_resort_suites/for_hotel_resort/suite1.jpg",
		"Earns $15 rent once added to a Hotel Resort you own. On its own it earns nothing.", {"special": "suite", "suite_for": "Hotel Resort",
		"art_variants": ["cruise_resort_suites/for_hotel_resort/suite1.jpg", "cruise_resort_suites/for_hotel_resort/suite2.jpg",
			"cruise_resort_suites/for_hotel_resort/suite3.jpg", "cruise_resort_suites/for_hotel_resort/suit4.jpg"]}],
	["Cruise Suite", 4, "Beach", false, false, [0, 0], "cruise_resort_suites/for_luxury_cruise/beach_suite1.jpg",
		"Earns $15 rent once added to a Luxury Cruise you own. On its own it earns nothing.", {"special": "suite", "suite_for": "Luxury Cruise",
		"art_variants": ["cruise_resort_suites/for_luxury_cruise/beach_suite1.jpg", "cruise_resort_suites/for_luxury_cruise/beach_suite2.jpg",
			"cruise_resort_suites/for_luxury_cruise/beach_suite3.jpg", "cruise_resort_suites/for_luxury_cruise/beach_suite5.jpg"]}],
	["Mediterranean Villa", 7, "Beach", true, true, {"excellent": [16, 15], "good": [14, 13], "fair": [12, 11], "poor": [10, 9]}, "mediterranian_villa.jpg",
		"Own two Villas and you get two free Certificates of Deposit.", {"special": "villa"}],
	["Mountain Ranch", 4, "Country", true, true, {"excellent": [20, 18], "good": [18, 16], "fair": [16, 14], "poor": [14, 12]}, "mountain_ranch.jpg",
		"While you own it, your Land, Inheritance and Private Island land is worth double, even with a property built on it.", {"special": "ranch"}],
	["Nordic Cottage", 5, "Mountains", false, true, [8, 10], "nordichome3.jpg",
		"You gain a free Sabotage every round you own this.", {"special": "nordic"}],
	["Private Island", 4, "Beach", false, false, [15, 0], "private_island.jpg",
		"Land. Use a Contractor to build any property here in any condition. Build a Beach property and you also get a free SkyBnB.", {"special": "island", "lot": "private_island"}],
	["Renovated Farm House", 5, "Country", true, true, {"excellent": [15, 15], "good": [14, 14], "fair": [13, 11], "poor": [12, 10]}, "country_home.jpg",
		"While you own it, Land Expansions cost half ($25 instead of $50).", {"special": "farm_house"}],
	["Traditional Japanese Home", 5, "City", true, true, {"excellent": [18, 16], "good": [0, 0], "fair": [0, 0], "poor": [0, 0]}, "traditional_japanese_home.jpg",
		"Always arrives in poor condition. A Contractor takes it straight to excellent.", {"special": "japanese", "two_conditions": true}],
	["Tudor Manor", 4, "Country", true, true, {"excellent": [26, 24], "good": [22, 20], "fair": [18, 16], "poor": [14, 12]}, "tudor_manor.jpg",
		"", {}],
	["Volcano Reserve", 5, "Mountains", true, true, {"excellent": [22, 20], "good": [16, 14], "fair": [12, 10], "poor": [8, 6]}, "Volano.jpg",
		"Prone to damage: it takes 2 Insurance tokens to insure it.", {"special": "volcano", "insurance_needed": 2}],
]
# "For sale" posters for the property picker (space top-right / bottom-left for the text).
# A property not listed here uses its own picture.
const EXP_LISTING_ART := "res://Assets/expansion/icons_for_the_market/"
const EXP_LISTINGS := {
	"Cabin": "cabin_listing.png", "Renovated Farm House": "renovated_listing.png",
	"Dome": "dome_listing.png", "Gothic Mansion": "gothic_listing.png", "Haunted Mansion": "haunted_listing.png",
	"Historical Estate": "historical_listing.png", "Hotel Resort": "resort_listing.png",
	"Luxury Cruise": "cruise_listing.png", "Mediterranean Villa": "villa_listing.png",
	"Mountain Ranch": "ranch_listing.png", "Nordic Cottage": "nors_listing.png",
	"Private Island": "island_listing.png", "Traditional Japanese Home": "japanese_listing.png",
	"Tudor Manor": "tudor_listing.png", "Volcano Reserve": "volcano_listing.png",
}
var _base_deck: Array = []
var _expansion_deck: Array = []

func _expansion_template(row: Array) -> Dictionary:
	var template := {
		"name": row[0], "region": row[2], "edition": "expansion",
		"allow_skybnb": row[3], "allow_double": row[4],
		"has_skybnb": false, "has_double": false, "has_golden_lock": false,
		"has_attorney": false, "has_insurance": false, "has_loan": false,
		"art": EXP_ART + row[6], "sale_art": EXP_ART + row[6], "description": row[7],
	}
	if EXP_LISTINGS.has(row[0]):
		template["sale_art"] = EXP_LISTING_ART + EXP_LISTINGS[row[0]]
	if row[5] is Dictionary:
		var values := {}
		var rents := {}
		for level in row[5]:
			values[level] = row[5][level][0]
			rents[level] = row[5][level][1]
		template["has_condition"] = true
		template["condition"] = {"value": values, "rent": rents}
	else:
		template["has_condition"] = false
		template["condition"] = "excellent"
		template["value"] = row[5][0]
		template["rent"] = row[5][1]
	var extra: Dictionary = row[8]
	for key in extra:
		if key == "art_variants":
			template[key] = extra[key].map(func(a): return EXP_ART + a)
		else:
			template[key] = extra[key]
	return template

var properties_owned: Array = []      # the player's hand (private)
var properties_revealed: Array = []   # cards shown in property_reveal, not yet bought
var selected_id := 0                  # id of the property being viewed / sold

# The deck itself is shared: in multiplayer the host owns it (see Market.gd) and
# property_deck here is a synced mirror. Templates are looked up by name.
var templates_by_name: Dictionary = {}
var _full_deck: Array = []


func _ready() -> void:
	_base_deck = property_deck.duplicate()
	for template in _base_deck:
		template["edition"] = "base"
	for row in EXPANSION_DATA:
		var template := _expansion_template(row)
		if template.get("special", "") == "suite":
			templates_by_name[template["name"]] = template
			continue   # Suites have a deck of their own (Actions "hotel_suite" / "cruise_suite")
		for i in row[1]:
			_expansion_deck.append(template)
	_full_deck = _base_deck + _expansion_deck
	for template in _full_deck:
		templates_by_name[template["name"]] = template

# The shared deck for a new game, from the editions the host picked.
func reset_deck(base: bool = true, expansion: bool = false) -> void:
	property_deck = (_base_deck if base else []) + (_expansion_deck if expansion else [])
	if property_deck.is_empty():
		property_deck = _base_deck.duplicate()

func set_deck_from_names(names: Array) -> void:
	property_deck = names.map(func(n): return templates_by_name[n])

func reset_id() -> void:
	selected_id = 0

# 1 poor, 2 fair, 2 good, 1 excellent out of 6.
func randomize_condition() -> String:
	match randi_range(1, 6):
		1:
			return "poor"
		2, 3:
			return "fair"
		4, 5:
			return "good"
		_:
			return "excellent"

func tenants() -> int:
	return randi_range(1, 6)

# Apartment: a new number of tenants each round; rent is $3 each (x2 with a Double).
func roll_tenants(property: Dictionary) -> void:
	var count := tenants()
	property["tenants"] = count
	var rent := 3 * count * (2 if property.get("has_double", false) else 1)
	property["rent"] = rent
	property["e_rent"] = rent

func has_condition(property: Dictionary) -> bool:
	return property.get("has_condition", false)

# Draws `count` cards from the shared deck straight into the hand.
func draw_into_hand(count: int) -> void:
	for property_name in await Market.draw_properties(count):
		properties_owned.append(_make_property(templates_by_name[property_name], randomize_condition()))

# Draws `count` cards from the shared deck into the revealed row. Returns the new cards.
func reveal(count: int) -> Array:
	var cards := []
	for property_name in await Market.draw_properties(count):
		cards.append(_make_property(templates_by_name[property_name], randomize_condition()))
	properties_revealed.append_array(cards)
	return cards

# Puts every revealed card back into the shared deck.
func return_revealed() -> void:
	var names = properties_revealed.map(func(p): return p["name"])
	properties_revealed.clear()
	await Market.return_properties(names)

# First template still in the deck with this name, or {} if none are left.
func find_template(property_name: String) -> Dictionary:
	for template in property_deck:
		if template["name"] == property_name:
			return template
	return {}

## ---- EMPTY LOTS (Land, Inheritance, Land Expansion) ----
# A lot sits in My Properties until the player builds on it with a Contractor.
# The new property replaces the lot and keeps the lot's value on top of its own.
const LOTS := {
	"inheritance": {
		"name": "Inheritance",
		"value": 10,
		"art": "res://Assets/fortunas/hidden cash.png",
		"description": "Inherited land. Use a Contractor to build any property here in any condition. Land value: $10.",
	},
	"land_expansion": {
		"name": "Land Expansion",
		"value": 50,
		"art": "res://Assets/icons/tokens/expansion_icon.png",
		"description": "Extra land. Use a Contractor to build any property here in any condition. Land value: $50.",
	},
}

static func is_lot(property: Dictionary) -> bool:
	return property.get("lot_kind", "") != ""

# A new Inheritance or Land Expansion lot (Land lots come from the deck).
func make_lot(kind: String) -> Dictionary:
	var info: Dictionary = LOTS[kind]
	var lot := _make_property(templates_by_name["Land"], "excellent")
	lot.merge({
		"name": info["name"], "art": info["art"], "sale_art": "",
		"p_details": info["description"], "lot_kind": kind,
		"value": info["value"], "e_value": info["value"],
		"land_value": info["value"], "region": "",
		"allow_double": false,
	}, true)
	return lot

func owns_land_expansion() -> bool:
	for p in properties_owned:
		if p.get("lot_kind", "") == "land_expansion" or p.get("built_on", "") == "land_expansion":
			return true
	return false

# Property types you can build on a lot: everything still in the shared deck except Land.
func buildable_names() -> Array:
	var names := []
	for template in property_deck:
		if template.has("lot") or template.get("special", "") == "suite":
			continue   # no land on land, and Suites only go on a Hotel / Cruise
		if template["name"] != "Land" and not names.has(template["name"]):
			names.append(template["name"])
	names.sort()
	return names

# Price of a property type in a given condition (fixed-value types ignore the condition).
func price_of(property_name: String, condition: String) -> int:
	var template: Dictionary = templates_by_name[property_name]
	if has_condition(template):
		return template["condition"]["value"][condition]
	return template["value"]

# Replaces `lot` in the hand with a new property. The card must already be taken
# from the shared deck (Market.take_property). Every value tier gets the lot's value.
func build_on_lot(lot: Dictionary, property_name: String, condition: String) -> Dictionary:
	var property := _make_property(templates_by_name[property_name], condition)
	var bonus: int = lot.get("land_value", lot["value"])
	for key in ["value", "e_value", "g_value", "f_value", "p_value"]:
		if property[key] is int:
			property[key] += bonus
	property["built_on"] = lot["lot_kind"]
	property["land_value"] = bonus   # Mountain Ranch doubles this part
	property["p_details"] = "%s\n\nBuilt on %s: +$%d value." % [property["p_details"], lot["name"], bonus]
	var index := properties_owned.find(lot)
	if index == -1:
		properties_owned.append(property)
	else:
		properties_owned[index] = property
	return property

# Turns a deck template into an owned/revealed property card.
func _make_property(template: Dictionary, condition: String) -> Dictionary:
	var property := {
		"id": randi_range(100000, 999999),
		"name": template["name"],
		"art": template["art"],
		"sale_art": template["sale_art"],
		"p_details": template["description"],
		"allow_skybnb": template["allow_skybnb"],
		"allow_double": template["allow_double"],
		"has_skybnb": template["has_skybnb"],
		"has_double": template["has_double"],
		"has_golden_lock": template["has_golden_lock"],
		"has_attorney": template["has_attorney"],
		"has_insurance": template["has_insurance"],
		"is_new": false,
		"round": 0,
		"lot_kind": "land" if template["name"] == "Land" else template.get("lot", ""),
		"region": template.get("region", ""),
		"edition": template.get("edition", "base"),
	}
	for key in ["special", "immune", "two_conditions", "suite_kind", "suite_for", "insurance_needed"]:
		if template.has(key):
			property[key] = template[key]
	if template.has("art_variants"):
		property["art"] = template["art_variants"].pick_random()
		property["sale_art"] = property["art"]
	if template.get("two_conditions", false):
		condition = "poor"   # Traditional Japanese Home always arrives in poor condition
	if has_condition(template):
		var values: Dictionary = template["condition"]["value"]
		var rents: Dictionary = template["condition"]["rent"]
		property.merge({
			"has_condition": true,
			"condition": condition,
			"value": values[condition],
			"rent": rents[condition],
			"e_value": values["excellent"], "e_rent": rents["excellent"],
			"g_value": values["good"], "g_rent": rents["good"],
			"f_value": values["fair"], "f_rent": rents["fair"],
			"p_value": values["poor"], "p_rent": rents["poor"],
		})
	else:
		# Fixed-value properties (Castle, Land, Apartment...) have a single value/rent.
		property.merge({
			"has_condition": false,
			"condition": "",
			"value": template["value"],
			"rent": template["rent"],
			"e_value": template["value"], "e_rent": template["rent"],
			"g_value": "", "g_rent": "",
			"f_value": "", "f_rent": "",
			"p_value": "", "p_rent": "",
		})
		if template["name"] == "Apartment":
			roll_tenants(property)
	if property["lot_kind"] != "":
		property["land_value"] = property["value"]
	return property


## ---- ROUND PROPERTY ICONS ----
# Property pictures are square; everywhere they're shown they're drawn as a circle with a
# border. Use Cards.round_icon(property["art"]) instead of load(). Made once per picture.
const ICON_BORDER_COLOR := Color("533c44")
const ICON_BORDER_WIDTH := 0.045   # share of the picture's width
const MAX_ICON_SIDE := 400

var _round_icons: Dictionary = {}   # path -> ImageTexture
var _icon_masks: Dictionary = {}    # size -> [mask Image, border ring Image]

func round_icon(path: String) -> Texture2D:
	if _round_icons.has(path):
		return _round_icons[path]
	if not ColorTheme.theme_changed.is_connected(_on_theme_changed):
		ColorTheme.theme_changed.connect(_on_theme_changed)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	var image: Image = texture.get_image() if texture else null
	if image == null:
		return texture
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var side := mini(image.get_width(), image.get_height())
	if image.get_width() != image.get_height():   # centre square
		image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	if side > MAX_ICON_SIDE:   # the expansion's big pictures: icons never show this large
		image.resize(MAX_ICON_SIDE, MAX_ICON_SIDE, Image.INTERPOLATE_LANCZOS)
		side = MAX_ICON_SIDE
	var masks: Array = _masks_for(side)
	var result := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	result.blit_rect_mask(image, masks[0], Rect2i(0, 0, side, side), Vector2i.ZERO)
	result.blend_rect(masks[1], Rect2i(0, 0, side, side), Vector2i.ZERO)
	var round_texture := ImageTexture.create_from_image(result)
	_round_icons[path] = round_texture
	return round_texture

# The border follows the colour theme: icons made from now on use the new colour.
func _on_theme_changed(_key: String) -> void:
	_round_icons.clear()
	_icon_masks.clear()

# A circle mask (what to keep) and an anti-aliased border ring, for pictures `side` px wide.
func _masks_for(side: int) -> Array:
	if _icon_masks.has(side):
		return _icon_masks[side]
	var mask := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var ring := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side, side) / 2.0
	var outer := side / 2.0 - 1.0
	var width := maxf(2.0, side * ICON_BORDER_WIDTH)
	var inner := outer - width
	var border := ColorTheme.map_color(ICON_BORDER_COLOR, "fill")
	for y in side:
		for x in side:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= outer - width * 0.5:
				mask.set_pixel(x, y, Color.WHITE)
			# coverage of the ring at this pixel, softened over 1px at both edges
			var a := clampf(outer - d + 0.5, 0.0, 1.0) * clampf(d - inner + 0.5, 0.0, 1.0)
			if a > 0.0:
				ring.set_pixel(x, y, Color(border, a))
	_icon_masks[side] = [mask, ring]
	return _icon_masks[side]
