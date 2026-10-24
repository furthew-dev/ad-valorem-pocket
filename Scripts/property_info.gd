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
	if current_property.is_empty():
		return
	_add_build_button()
	_add_insurance_controls()
	setup_card()

# Fills every label from current_property. Safe to call again after a token is used,
# which keeps the UI frame (and its banner) alive instead of reloading the scene.
func setup_card() -> void:
	var details := current_property
	property_name.text = str(details["name"])
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
	_show_purchase_loan(details)

	if details["has_condition"]:
		var condition: String = details["condition"]
		excellent_condition.visible = condition == "excellent"
		good_condition.visible = condition == "good"
		fair_condition.visible = condition == "fair"
		poor_condition.visible = condition == "poor"
		contractor.visible = Actions.actions_owned.has("contractor") and condition != "excellent"
		_nudge_contractor()
	else:
		# Fixed-value property: only the single value/rent row is meaningful.
		excellent.visible = false
		property_name.visible = false
		for node in [g_value, g_rent, f_value, f_rent, p_value, p_rent, good, fair, poor]:
			node.visible = false
		for node in [excellent_condition, good_condition, fair_condition, poor_condition, contractor]:
			node.visible = false

	skybnb_status.visible = details["allow_skybnb"] and details["has_skybnb"]
	addskybnb.visible = details["allow_skybnb"] and not details["has_skybnb"] \
			and Actions.actions_owned.has("skybnb")
	double_status.visible = details["allow_double"] and details["has_double"]
	adddouble.visible = details["allow_double"] and not details["has_double"] \
			and Actions.actions_owned.has("double")

	insurance_status.visible = details.get("has_insurance", false)
	addinsurance.visible = not details.get("has_insurance", false) \
			and Actions.actions_owned.has("insurance")

	_build_btn.visible = Cards.is_lot(details)
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
		label.text = "Upgrade?"
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color("f6f2e1"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_upgrade_tag.add_child(label)
		_upgrade_tag.size = Vector2(150, 52)
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
	var before := current_property.duplicate()
	if not Global.activate_contractor(current_property):   # spends the action
		Global.error("This property is already in excellent condition.")
		return
	Actions.consume("contractor")
	Global.banner("Contractor used. Now in %s condition." % current_property["condition"])
	_refresh(before)

# Insurance: protects this property from the Fortunas insurance covers (used up when it does).
func _on_add_insurance_pressed() -> void:
	if not _has_action_left():
		return
	if not Actions.consume("insurance"):
		Global.error("You need an Insurance token.", "market")
		return
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
