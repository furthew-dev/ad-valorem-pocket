extends Node2D
## Details for one owned property (Cards.selected_id). Lets the player apply
## Double / SkyBnB / Insurance / Contractor tokens or go to the sale screen.
## When a token changes the numbers, the changed values count up on screen.

const VBOX := "CanvasLayer/Panel/VBoxContainer/box/MarginContainer2/Panel/MarginContainer/VBoxContainer/"
const INSURANCE_ICON := "res://Assets/icons/insurance_icon.png"
const RISE_COLOR := Color("7fd17f")   # flash on numbers that went up
const COUNT_TIME := 0.9

# --- Emblem / token badges ---
@onready var property_icon: TextureRect = $CanvasLayer/Panel/VBoxContainer/box/property_icon
@onready var double_status: Panel = $CanvasLayer/tokens/HBoxContainer/double_status2
@onready var skybnb_status: Panel = $CanvasLayer/tokens/HBoxContainer/skybnb_status
@onready var text_edit: Label = get_node(VBOX + "TextEdit")
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"

# --- Property details ---
@onready var property_name: Label = get_node(VBOX + "details/property_name")
@onready var property_value: Label = get_node(VBOX + "details/property_value")
@onready var property_rent: Label = get_node(VBOX + "details/property_rent")

# --- Condition rows: label, value, rent, highlight ---
@onready var excellent: Label = get_node(VBOX + "excellent/excellent")
@onready var e_value: Label = get_node(VBOX + "excellent/e_value")
@onready var e_rent: Label = get_node(VBOX + "excellent/e_rent")
@onready var excellent_condition: Panel = get_node(VBOX + "excellent/excellent/excellent_condition")
@onready var good: Label = get_node(VBOX + "good/good")
@onready var g_value: Label = get_node(VBOX + "good/g_value")
@onready var g_rent: Label = get_node(VBOX + "good/g_rent")
@onready var good_condition: Panel = get_node(VBOX + "good/good/good_condition")
@onready var fair: Label = get_node(VBOX + "fair/fair")
@onready var f_value: Label = get_node(VBOX + "fair/f_value")
@onready var f_rent: Label = get_node(VBOX + "fair/f_rent")
@onready var fair_condition: Panel = get_node(VBOX + "fair/fair/fair_condition")
@onready var poor: Label = get_node(VBOX + "poor/poor")
@onready var p_value: Label = get_node(VBOX + "poor/p_value")
@onready var p_rent: Label = get_node(VBOX + "poor/p_rent")
@onready var poor_condition: Panel = get_node(VBOX + "poor/poor/poor_condition")

# --- Token buttons ---
@onready var adddouble: Panel = get_node(VBOX + "add_action/adddouble")
@onready var addskybnb: Panel = get_node(VBOX + "add_action/addskybnb")
@onready var contractor: Panel = $CanvasLayer/contractor
@onready var sell: Button = $CanvasLayer/Sell/Label/sell

var current_property: Dictionary = {}
var _build_btn: Button   # only shown for empty lots (Land / Inheritance / Land Expansion)
var addinsurance: Panel   # "Add Insurance", a copy of the Add SkyBnB button (built in _ready)
var insurance_status: Panel   # badge next to the SkyBnB / Double badges
var current_scene := "res://Scenes/property_info.tscn"


func _ready() -> void:
	# The highlight behind the property's current condition: drawn BEHIND the row's writing
	# (not over it), so the text stays crisp whatever colour the theme gives the band.
	for highlight in [excellent_condition, good_condition, fair_condition, poor_condition]:
		highlight.z_index = 0
		highlight.show_behind_parent = true
		var row := highlight.get_parent().get_parent() as Control   # label -> its row
		row.resized.connect(_stretch_highlight.bind(highlight))
		_stretch_highlight.call_deferred(highlight)
	for p in Cards.properties_owned:
		if p.get("id") == Cards.selected_id:
			current_property = p
			break
	if current_property.is_empty():   # the property is gone (sold, swapped...): no blank page
		get_tree().change_scene_to_file.call_deferred("res://Scenes/my_properties.tscn")
		return
	_add_build_button()
	_add_special_button()
	_add_insurance_controls()
	setup_card()

# Fills every label from current_property. Safe to call again after a token is used,
# which keeps the UI frame (and its banner) alive instead of reloading the scene.
func setup_card() -> void:
	var details := current_property
	property_name.text = str(details["name"])
	property_name.clip_text = true   # long names (Traditional Japanese Home) mustn't push the columns
	property_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	e_value.text = "$%s" % details["e_value"]
	e_rent.text = "$%s" % details["e_rent"]
	g_value.text = "$%s" % details["g_value"]
	g_rent.text = "$%s" % details["g_rent"]
	f_value.text = "$%s" % details["f_value"]
	f_rent.text = "$%s" % details["f_rent"]
	p_value.text = "$%s" % details["p_value"]
	p_rent.text = "$%s" % details["p_rent"]
	text_edit.text = str(details["p_details"])
	if details.get("has_golden_lock", false):
		text_edit.text += "\n\nGolden Lock: protected from harm and can't be sold."
	if details["name"] == "Apartment" and details.has("tenants") and Cards.properties_owned.has(details):
		var tenants: int = details["tenants"]
		text_edit.text += "\n\nThis round: %d tenant%s, $%d rent." % [tenants, "" if tenants == 1 else "s", details["rent"]]
	text_edit.text += _expansion_notes(details)
	_show_purchase_loan(details)
	_show_special_button(details)

	if details["has_condition"]:
		var condition: String = details["condition"]
		excellent_condition.visible = condition == "excellent"
		good_condition.visible = condition == "good"
		fair_condition.visible = condition == "fair"
		poor_condition.visible = condition == "poor"
		contractor.visible = Actions.actions_owned.has("contractor") and condition != "excellent"
		# Traditional Japanese Home has only Excellent and Poor.
		var both: bool = not details.get("two_conditions", false)
		for node in [good, g_value, g_rent, fair, f_value, f_rent]:
			node.visible = both
		_nudge_contractor()
	else:
		# Fixed-value property: only the single value/rent row is meaningful.
		excellent.visible = false
		property_name.visible = false
		for node in [g_value, g_rent, f_value, f_rent, p_value, p_rent, good, fair, poor]:
			node.visible = false
		for node in [excellent_condition, good_condition, fair_condition, poor_condition, contractor]:
			node.visible = false
		# Hotel Resort / Luxury Cruise: the Contractor builds a Suite instead.
		contractor.visible = _can_add_suite(details) and Actions.actions_owned.has("contractor")
		_nudge_contractor()

	skybnb_status.visible = details["allow_skybnb"] and details["has_skybnb"]
	_mark_not_allowed(skybnb_status, not details["allow_skybnb"], "SkyBnB")
	addskybnb.visible = details["allow_skybnb"] and not details["has_skybnb"] \
			and Actions.actions_owned.has("skybnb")
	double_status.visible = details["allow_double"] and details["has_double"]
	_mark_not_allowed(double_status, not details["allow_double"], "Double")
	adddouble.visible = details["allow_double"] and not details["has_double"] \
			and Actions.actions_owned.has("double")

	insurance_status.visible = details.get("has_insurance", false)
	addinsurance.visible = not details.get("has_insurance", false) \
			and Actions.actions_owned.has("insurance")

	_build_btn.visible = Cards.is_lot(details)
	_show_suites.call_deferred()
	_layout_token_buttons.call_deferred()

	var art_path: String = details["art"]
	if art_path != "" and ResourceLoader.exists(art_path):
		property_icon.texture = Cards.round_icon(art_path)
		property_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # stay round in any box

# Builds the Add Insurance button (a copy of Add SkyBnB, in the same row) and the badge.
func _add_insurance_controls() -> void:
	# Copy without signals, so the new button doesn't also trigger SkyBnB.
	var copy_flags := Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION
	addinsurance = addskybnb.duplicate(copy_flags)
	addinsurance.name = "addinsurance"
	addinsurance.get_node("add_skybnb2").text = "Add Insurance"
	addinsurance.get_node("add_skybnb").pressed.connect(_on_add_insurance_pressed)
	addskybnb.add_sibling(addinsurance)
	var row := addskybnb.get_parent() as HBoxContainer
	row.add_theme_constant_override("separation", 12)
	(row.get_parent() as Control).resized.connect(_layout_token_buttons)

	# The badge sits in the left column, one slot ABOVE the SkyBnB badge, so it never
	# covers the property picture / name in the middle of the screen.
	insurance_status = skybnb_status.duplicate(copy_flags)
	insurance_status.name = "insurance_status"
	insurance_status.get_node("TextureRect").texture = load(INSURANCE_ICON)
	var badge_row := skybnb_status.get_parent() as Control
	badge_row.get_parent().add_child(insurance_status)
	insurance_status.size = skybnb_status.custom_minimum_size
	insurance_status.position = badge_row.position + Vector2(19, -insurance_status.size.y - 10)

# Add SkyBnB / Add Double / Add Insurance sit side by side and share the row's width.
# Each label shrinks until its text fits inside its button.
const TOKEN_FONT_SIZE := 45
const TOKEN_FONT_MIN := 18
const TOKEN_TEXT_PADDING := 24
var _laying_out := false

func _layout_token_buttons() -> void:
	if _laying_out:
		return
	_laying_out = true
	var row := addskybnb.get_parent() as HBoxContainer
	var shown := [addskybnb, adddouble, addinsurance].filter(func(p): return p.visible)
	# Let the row shrink first: the buttons' own minimum widths can stretch it (and
	# everything around it) past the screen edge, which would spoil the measurement.
	for panel in shown:
		panel.custom_minimum_size.x = 0
	await get_tree().process_frame
	if not is_inside_tree():
		return   # the player already left this screen
	var available: float = (row.get_parent() as Control).size.x
	if not shown.is_empty() and available > 0:
		var separation := row.get_theme_constant("separation")
		var width := minf(300.0, (available - separation * (shown.size() - 1)) / shown.size())
		row.alignment = BoxContainer.ALIGNMENT_CENTER if shown.size() > 1 else BoxContainer.ALIGNMENT_BEGIN
		for panel in shown:
			panel.custom_minimum_size.x = width
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if shown.size() > 1 else Control.SIZE_SHRINK_BEGIN
			var label: Label = panel.get_child(0)
			var font := label.get_theme_font("font")
			var size := TOKEN_FONT_SIZE
			while size > TOKEN_FONT_MIN and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width - TOKEN_TEXT_PADDING:
				size -= 1
			label.add_theme_font_size_override("font_size", size)
			label.clip_text = true
	if is_inside_tree():
		await get_tree().process_frame
	_laying_out = false

func _add_build_button() -> void:
	_build_btn = Button.new()
	_build_btn.text = "Build with Contractor"
	_build_btn.custom_minimum_size = Vector2(0, 80)
	_build_btn.add_theme_font_size_override("font_size", 34)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.482353, 0.494118, 0.388235)
	style.set_corner_radius_all(30)
	for state in ["normal", "hover", "pressed"]:
		_build_btn.add_theme_stylebox_override(state, style)
	_build_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_build_btn.pressed.connect(_on_build_pressed)
	text_edit.add_sibling(_build_btn)

# Empty lot -> property_reveal in build mode (pick any property, then a condition).
func _on_build_pressed() -> void:
	if not _still_owned():
		return
	if not Actions.actions_owned.has("contractor"):
		Global.error("You need a Contractor to build here.", "market")
		return
	if not _has_action_left():
		return
	if Cards.buildable_names().is_empty():
		Global.error("There are no properties left to build.")
		return
	Sound.play("continue")
	Global.build_lot_id = current_property["id"]
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/property_reveal.tscn")

## ---- NOT ALLOWED ----
# A property that can't take a SkyBnB / Double shows that token's badge crossed out
# (tap it to be told), so a token you own that won't go on it doesn't look like a bug.
func _mark_not_allowed(badge: Panel, not_allowed: bool, token: String) -> void:
	var cross: Control = badge.get_node_or_null("not_allowed")
	if not not_allowed:
		if cross:
			cross.queue_free()
			badge.modulate.a = 1.0
		return
	badge.visible = true
	badge.modulate.a = 0.75
	if cross:
		return
	cross = Control.new()
	cross.name = "not_allowed"
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_STOP
	cross.z_index = 2
	cross.draw.connect(func():
		var r := cross.size
		cross.draw_line(Vector2(r.x * 0.15, r.y * 0.15), Vector2(r.x * 0.85, r.y * 0.85), Color("c94040"), maxf(5.0, r.x * 0.09), true))
	cross.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Global.error("A %s can't be added to the %s." % [token, current_property.get("name", "property")]))
	badge.add_child(cross)

## ---- EXPANSION ----
# Region, environment token, Suites on a Hotel / Cruise, a Cabin that already swapped.
func _expansion_notes(details: Dictionary) -> String:
	if not Network.expansion_on():
		return ""
	var notes := ""
	var region: String = details.get("region", "")
	if region != "":
		notes += "\n\nRegion: %s" % region
		if region.to_lower() == Expansion.my_region.to_lower():
			notes += "  (your region: earns an Environment token)"
	if details.get("special", "") == "suite_host":
		var suites: Array = details.get("suites", [])
		notes += "\n\nSuites: %d of %d  (+$%d rent)" % [suites.size(), Expansion.MAX_SUITES, suites.size() * Expansion.SUITE_RENT]
	if details.get("cabin_swapped", false):
		notes += "\n\nThis Cabin has already been swapped once."
	return notes

# One button for the expansion actions that live on a property's page:
# Cabin -> swap it, Suite -> add it to your Hotel / Cruise.
var _special_btn: Button

func _add_special_button() -> void:
	_special_btn = Button.new()
	_special_btn.custom_minimum_size = Vector2(0, 80)
	_special_btn.add_theme_font_size_override("font_size", 32)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.482353, 0.494118, 0.388235)
	style.set_corner_radius_all(30)
	for state in ["normal", "hover", "pressed"]:
		_special_btn.add_theme_stylebox_override(state, style)
	_special_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_special_btn.pressed.connect(_on_special_pressed)
	_special_btn.visible = false
	text_edit.add_sibling(_special_btn)

func _show_special_button(details: Dictionary) -> void:
	if _special_btn == null:
		return
	var kind: String = details.get("special", "")
	if kind == "cabin" and not details.get("cabin_swapped", false) and Network.is_online():
		_special_btn.text = "Swap this Cabin (1 action)"
		_special_btn.visible = true
	elif _can_add_suite(details):
		_special_btn.text = "Add Suite for $%d + Contractor" % Expansion.SUITE_COST
		_special_btn.visible = true
	else:
		_special_btn.visible = false

func _on_special_pressed() -> void:
	if not _has_action_left():
		return
	Sound.play("click")
	match current_property.get("special", ""):
		"cabin":
			_special_btn.disabled = true
			var message: String = await Expansion.cabin_swap(current_property)
			_special_btn.disabled = false
			if message != "":
				Global.banner(message)
			if not Cards.properties_owned.has(current_property):
				get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
		"suite_host":
			await _build_suite()

# Hotel Resort / Luxury Cruise: a Contractor adds the next Suite, right here on the page.
func _build_suite() -> void:
	var problem := Expansion.suite_problem(current_property)
	if problem != "":
		Global.error(problem, "market" if problem.contains("Contractor") else "")
		return
	# Say what it costs before building.
	var popup = load("res://Scenes/pop_up.tscn").instantiate()
	get_tree().root.add_child(popup)
	popup.layout("Add Suite for $%d?\nUses a Contractor and 1 action.\n+$%d rent." \
			% [Expansion.SUITE_COST, Expansion.SUITE_RENT], "Yes", "No")
	var answer := [false]
	popup.left_pressed.connect(func(): answer[0] = true)
	await popup.tree_exited
	if not answer[0] or not is_inside_tree():
		return
	if _special_btn:
		_special_btn.disabled = true
	var before := current_property.duplicate()
	var message: String = await Expansion.build_suite(current_property)
	if _special_btn:
		_special_btn.disabled = false
	if message.begins_with("Suite added"):
		Global.banner(message)
		_refresh(before)
		_show_suites(true)
	else:
		Global.error(message, "market" if message.contains("Contractor") else "")

func _can_add_suite(details: Dictionary) -> bool:
	return details.get("special", "") == "suite_host" and Network.expansion_on() \
			and details.get("suites", []).size() < Expansion.MAX_SUITES

## ---- SUITE STACK ----
# The Suites on a Hotel Resort / Luxury Cruise: their pictures, stacked to the left of its
# picture like cards (newest on top; the Contractor sits on the right). A Suite added now
# drops onto the stack.
const SUITE_ICON := 112.0
const SUITE_STEP := 40.0
var _suite_stack: Control

func _show_suites(added_one: bool = false) -> void:
	if not is_instance_valid(property_icon):
		return
	if _suite_stack == null:
		_suite_stack = Control.new()
		_suite_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		property_icon.add_child(_suite_stack)
	for child in _suite_stack.get_children():
		child.queue_free()
	var suites: Array = current_property.get("suites", [])
	if current_property.get("special", "") != "suite_host" or suites.is_empty():
		return
	# Left of the round picture (which is centred in its box).
	var side := minf(property_icon.size.x, property_icon.size.y)
	_suite_stack.position = Vector2(property_icon.size.x / 2.0 - side / 2.0 - SUITE_ICON + 4.0, (property_icon.size.y - side) / 2.0 - 12.0)
	for i in suites.size():
		var icon := TextureRect.new()
		icon.texture = Cards.round_icon(str(suites[i].get("art", "")))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(SUITE_ICON, SUITE_ICON)
		icon.position = Vector2(-(i % 2) * 14.0, i * SUITE_STEP)
		icon.pivot_offset = icon.size / 2.0
		icon.rotation = [-0.08, 0.06, -0.04, 0.09][i % 4]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ColorTheme.keep(icon)
		_suite_stack.add_child(icon)
		if added_one and i == suites.size() - 1:   # the new Suite drops onto the stack
			icon.scale = Vector2(1.6, 1.6)
			icon.modulate.a = 0.0
			var drop := icon.create_tween().set_parallel(true)
			drop.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			drop.tween_property(icon, "modulate:a", 1.0, 0.2)

func _refresh(before: Dictionary = {}) -> void:
	setup_card()
	ui_menu_frame.refresh_labels()   # expected rent may have changed
	if not before.is_empty():
		_animate_changes(before)


## ---- NUMBERS GOING UP ----
# Compares the property before/after a token and counts every changed number up.
# Contractor: the new condition row counts up from the old condition's value and rent,
# and its highlight fades in.
func _animate_changes(before: Dictionary) -> void:
	var rows := {
		"e": [e_value, e_rent], "g": [g_value, g_rent],
		"f": [f_value, f_rent], "p": [p_value, p_rent],
	}
	var after := current_property
	for tier in rows:
		for i in 2:
			var key: String = tier + ("_value" if i == 0 else "_rent")
			if before.get(key) is int and after.get(key) is int and before[key] != after[key]:
				_count_up(rows[tier][i], before[key], after[key])

	var old_condition: String = before.get("condition", "")
	var new_condition: String = after.get("condition", "")
	if after.get("has_condition", false) and old_condition != new_condition:
		var tier: String = Fortunas.CONDITION_PREFIX[new_condition]
		_count_up(rows[tier][0], before["value"], after["value"])
		_count_up(rows[tier][1], before["rent"], after["rent"])
		var highlight: Panel = {"e": excellent_condition, "g": good_condition,
				"f": fair_condition, "p": poor_condition}[tier]
		highlight.modulate.a = 0.0
		highlight.create_tween().tween_property(highlight, "modulate:a", 1.0, COUNT_TIME)

func _count_up(label: Label, from: int, to: int) -> void:
	label.pivot_offset = label.size / 2
	var tween := label.create_tween()
	tween.tween_method(func(v: int): label.text = "$%d" % v, from, to, COUNT_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", RISE_COLOR, COUNT_TIME * 0.4)
	tween.parallel().tween_property(label, "scale", Vector2(1.25, 1.25), COUNT_TIME * 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 0.4)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.4)

func _has_action_left() -> bool:
	if not _still_owned():
		return false
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions. End your turn for more.", "home")
		return false
	return true

# Bought (or built) with a loan: say what's still owed on it, with a button to My Loans.
var _loan_button: Button

func _show_purchase_loan(details: Dictionary) -> void:
	var loan: Dictionary = {}
	for l in Global.loans:
		if l["loan_number"] == details.get("loan_number", -1):
			loan = l
	if loan.is_empty():
		if _loan_button:
			_loan_button.visible = false
		return
	text_edit.text += "\n\nBought with Loan #%d: $%d still owed." % [loan["loan_number"], loan["loan_balance"]]
	if _loan_button == null:
		_loan_button = Button.new()
		_loan_button.add_theme_font_size_override("font_size", 24)
		_loan_button.custom_minimum_size = Vector2(0, 52)
		_loan_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		InkBox.apply(_loan_button, Color("ddcf99"))
		_loan_button.pressed.connect(func(): Global.open_link("my_loans"))
		text_edit.add_sibling(_loan_button)
	_loan_button.text = "  View loan ($%d owed)  >  " % loan["loan_balance"]
	_loan_button.visible = true

# The highlight lives inside the condition's label; make it span the whole row (label,
# value and rent) at any screen width.
func _stretch_highlight(highlight: Control) -> void:
	var label := highlight.get_parent() as Control
	var row := label.get_parent() as Control
	highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	highlight.position = Vector2(-label.position.x + 6, 0)
	highlight.size = Vector2(row.size.x - 12, label.size.y)

# A sabotage, auction or swap can take this property while its page is open.
func _still_owned() -> bool:
	for p in Cards.properties_owned:
		if p["id"] == current_property.get("id", -1):
			return true
	Global.error("You no longer own this property.")
	get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
	return false


func _on_add_double_pressed() -> void:
	if not _has_action_left():
		return
	var before := current_property.duplicate()
	Global.activate_double(current_property)   # spends the action
	Actions.consume("double")
	Global.banner("Double applied. Value doubled.")
	_refresh(before)

func _on_add_skybnb_pressed() -> void:
	if not _has_action_left():
		return
	var before := current_property.duplicate()
	Global.activate_skybnb(current_property)   # spends the action
	Actions.consume("skybnb")
	Global.banner("SkyBnB applied. Rent doubled.")
	_refresh(before)

# A Contractor could upgrade this property: the hammer gives a little shake every couple
# of seconds and an "Upgrade?" tag (like the money notices) sits beside it. Tapping
# either uses the Contractor.
const NUDGE_GREEN := Color("4c9a52")
var _upgrade_tag: Panel
var _nudge_tween: Tween

func _nudge_contractor() -> void:
	if _nudge_tween:
		_nudge_tween.kill()
		_nudge_tween = null
	contractor.rotation = 0.0
	contractor.scale = Vector2.ONE
	if _upgrade_tag:
		_upgrade_tag.visible = contractor.visible
	if not contractor.visible:
		return
	if _upgrade_tag == null:
		_upgrade_tag = Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = NUDGE_GREEN.darkened(0.15)
		style.set_corner_radius_all(26)
		_upgrade_tag.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "Add Suite: $%d" % Expansion.SUITE_COST if current_property.get("special", "") == "suite_host" else "Upgrade?"
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color("f6f2e1"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_upgrade_tag.add_child(label)
		_upgrade_tag.size = Vector2(190 if current_property.get("special", "") == "suite_host" else 150, 52)
		_upgrade_tag.position = contractor.position + Vector2(contractor.size.x + 10, (contractor.size.y - 52) / 2.0)
		_upgrade_tag.z_index = contractor.z_index
		_upgrade_tag.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_upgrade_tag.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_use_contractor_pressed())
		contractor.add_sibling(_upgrade_tag)   # beside the hammer, so it doesn't shake with it
		_upgrade_tag.modulate.a = 0.0
		_upgrade_tag.create_tween().tween_property(_upgrade_tag, "modulate:a", 1.0, 0.4).set_delay(0.3)
	contractor.pivot_offset = contractor.size / 2.0
	_nudge_tween = contractor.create_tween().set_loops()
	_nudge_tween.tween_interval(1.6)
	for angle in [0.18, -0.18, 0.14, -0.12, 0.06, 0.0]:
		_nudge_tween.tween_property(contractor, "rotation", angle, 0.06)
	_nudge_tween.parallel().tween_property(contractor, "scale", Vector2.ONE, 0.1)

func _on_use_contractor_pressed() -> void:
	if not _has_action_left():
		return
	if current_property.get("special", "") == "suite_host":
		await _build_suite()
		return
	var needed := 2 if current_property.get("special", "") == "historical" else 1
	if Actions.actions_owned.count("contractor") < needed:
		Global.error("The Historical Estate takes 2 Contractors to improve.", "market")
		return
	var before := current_property.duplicate()
	if not Global.activate_contractor(current_property):   # spends the action
		Global.error("This property is already in excellent condition.")
		return
	for i in needed:
		Actions.consume("contractor")
	Global.banner("Contractor used. Now in %s condition." % current_property["condition"])
	_refresh(before)

# Insurance: protects this property from the Fortunas insurance covers (used up when it does).
func _on_add_insurance_pressed() -> void:
	if not _has_action_left():
		return
	var needed: int = current_property.get("insurance_needed", 1)   # Volcano Reserve: 2
	if Actions.actions_owned.count("insurance") < needed:
		Global.error("The %s needs %d Insurance tokens to be insured." % [current_property["name"], needed] if needed > 1 else "You need an Insurance token.", "market")
		return
	for i in needed:
		Actions.consume("insurance")
	current_property["has_insurance"] = true
	Global.action_used()
	Sound.play("continue")
	Global.banner("%s is insured." % current_property["name"])
	_refresh()

func _on_sell_pressed() -> void:
	if not _still_owned():
		return
	if current_property.get("has_golden_lock", false):
		Global.error("This property has a Golden Lock and can't be sold.")
		return
	Sound.play("click")
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/sell_property.tscn")
