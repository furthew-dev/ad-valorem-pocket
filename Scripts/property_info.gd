extends Node2D
## Property Details (Cards.selected_id), laid out like a card from a card game:
##
##   ┌ Name ......................... [region] ┐   title bar
##   │ ┌───────┐   VALUE      RENT             │
##   │ │  art  │   $12        $10              │   the picture, and the numbers that matter
##   │ └───────┘   ( Good condition )          │   condition chip (6 tenants x $3...)
##   │ All conditions ▾                        │   the full table folds away
##   │ TOKENS  [SkyBnB][Double][Insurance][Lock]│   active / add now / buy / not allowed
##   │ SUITES  [ ][ ][ ][ ]   (Hotel / Cruise) │
##   │ description, notes, loan                │
##   └─────────────────────────────────────────┘
##   [ Upgrade to Good ]            [ Sell ]      pinned above the menu bar
##
## The card scrolls when it's long, so text stays a readable size. Tokens are applied by
## tapping their card in the Tokens row; numbers that change count up or down.

const RISE_COLOR := Color("7fd17f")   # flash on numbers that went up
const FALL_COLOR := Color("ff7a6e")   # flash on numbers that went down
const COUNT_TIME := 0.9

const TITLE_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")
const SELL_ICON := preload("res://Assets/icons/sell_icon.png")
const CONTRACTOR_ICON := preload("res://Assets/icons/tokens/contractor_icon.png")

# Palette colours, so every theme recolours the card.
const CARD_BG := Color("533c44")
const CARD_EDGE := Color("ddcf99")
const CREAM := Color("f6f2e1")
const SLOT_BG := Color("49343d")
const BAND := Color("7a6d79")
const GREEN := Color("5d6558")
const SELL_RED := Color("b76051")
const GOLD := Color("d4af37")         # Golden Lock (gold in every theme)
const NOT_ALLOWED := Color("c94040")
const CONDITION_COLORS := {"excellent": Color("749c5c"), "good": Color("7b7e63"),
		"fair": Color("c2855f"), "poor": Color("96514b")}
const CONDITION_ORDER := ["poor", "fair", "good", "excellent"]

const TOKENS := [
	{"key": "skybnb", "name": "SkyBnB", "icon": "res://Assets/icons/skybnb_icon.png", "flag": "has_skybnb", "allow": "allow_skybnb", "does": "doubles rent"},
	{"key": "double", "name": "Double", "icon": "res://Assets/icons/double_icon.png", "flag": "has_double", "allow": "allow_double", "does": "doubles value"},
	{"key": "insurance", "name": "Insurance", "icon": "res://Assets/icons/insurance_icon.png", "flag": "has_insurance", "allow": "", "does": "blocks disasters"},
	{"key": "golden_lock", "name": "Golden Lock", "icon": "res://Assets/icons/tokens/lock_icon.png", "flag": "has_golden_lock", "allow": "", "does": "can't be harmed or sold"},
]

const CREAM_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * COLOR.a); }
"""

@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"
@onready var page: Control = $CanvasLayer/Panel

var current_property: Dictionary = {}
var current_scene := "res://Scenes/property_info.tscn"

# --- built in _build() ---
var scroll: ScrollContainer
var card: PanelContainer
var _card_style: StyleBoxFlat
var property_name: Label
var region_icon: TextureRect
var art_frame: Panel
var property_icon: TextureRect
var stats_box: VBoxContainer         # value, rent, condition (the tutorial points at it)
var value_label: Label
var rent_label: Label
var condition_chip: PanelContainer
var condition_text: Label
var _chip_style: StyleBoxFlat
var tenants_label: Label
var conditions_toggle: HBoxContainer   # "All conditions" + a drawn arrow
var _chevron: Control
var _table_ready := false
var conditions_table: VBoxContainer
var _rows := {}                      # "e"/"g"/"f"/"p" -> the row
# The table's labels and the band behind the current row (names kept from the old page).
var excellent: Label
var good: Label
var fair: Label
var poor: Label
var e_value: Label
var e_rent: Label
var g_value: Label
var g_rent: Label
var f_value: Label
var f_rent: Label
var p_value: Label
var p_rent: Label
var excellent_condition: Panel
var good_condition: Panel
var fair_condition: Panel
var poor_condition: Panel
var tokens_row: HBoxContainer
var token_slots := {}                # key -> {"panel", "icon", "slash", "plus", "style", "state", "glow"}
var suites_section: VBoxContainer
var suites_title: HBoxContainer
var suites_row: HBoxContainer
var text_edit: Label                 # the description
var _about_title: HBoxContainer
var _loan_button: Button
var action_bar: HBoxContainer
var upgrade_button: Button           # Upgrade / Build / Add Suite (the tutorial points at it)
var special_button: Button           # Swap this Cabin
var sell_button: Button
var contractor: Button:              # (old name, used by the tutorial)
	get: return upgrade_button
var _cream_shader: Shader


func _ready() -> void:
	for p in Cards.properties_owned:
		if p.get("id") == Cards.selected_id:
			current_property = p
			break
	if current_property.is_empty():   # the property is gone (sold, swapped...): no blank page
		get_tree().change_scene_to_file.call_deferred("res://Scenes/my_properties.tscn")
		return
	_cream_shader = Shader.new()
	_cream_shader.code = CREAM_SHADER
	_build()
	setup_card()
	Global.properties_changed.connect(_on_properties_changed)
	Global.actions_changed.connect(func(_v): if is_inside_tree() and _owned_quietly(): setup_card())
	get_viewport().size_changed.connect(_settle_card)   # the phone turned, or Safari's bars came and went
	# What changed since you last looked (a new round, a Fortuna...): play it now.
	var news := Notices.property_before(int(current_property.get("id", 0)))
	Notices.mark_property(int(current_property.get("id", 0)))
	if not news.is_empty():
		_play_news(news)

func _exit_tree() -> void:
	if not current_property.is_empty():
		Notices.mark_property(int(current_property.get("id", 0)))   # changes made here are seen

# A new round changed the numbers (Terraced House) while this page is open.
func _on_properties_changed() -> void:
	if _still_owned():
		setup_card()

func _owned_quietly() -> bool:
	return Cards.properties_owned.any(func(p): return p.get("id", -1) == current_property.get("id", -2))


## ---- BUILDING THE CARD ----
func _build() -> void:
	var column := VBoxContainer.new()
	_column = column
	column.name = "Card Column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 176
	column.offset_bottom = -182
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(column)   # above the frame: the frame covers the whole screen and would eat every tap

	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(margin)

	card = PanelContainer.new()
	card.name = "Card"
	_card_style = _style(CARD_BG, 34, CARD_EDGE, 4)
	_card_style.shadow_color = Color(0, 0, 0, 0.35)
	_card_style.shadow_size = 10
	_card_style.shadow_offset = Vector2(0, 6)
	for side in ["left", "right"]:
		_card_style.set("content_margin_" + side, 22)
	_card_style.content_margin_top = 16
	_card_style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", _card_style)
	margin.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	card.add_child(body)

	body.add_child(_title_bar())
	body.add_child(_top_section())
	body.add_child(_conditions_section())
	body.add_child(_divider("TOKENS"))
	tokens_row = HBoxContainer.new()
	tokens_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tokens_row.add_theme_constant_override("separation", 26)
	for token in TOKENS:
		tokens_row.add_child(_token_slot(token))
	body.add_child(tokens_row)
	suites_section = VBoxContainer.new()
	suites_section.add_theme_constant_override("separation", 10)
	suites_title = _divider("SUITES")
	suites_section.add_child(suites_title)
	suites_row = HBoxContainer.new()
	suites_row.alignment = BoxContainer.ALIGNMENT_CENTER
	suites_row.add_theme_constant_override("separation", 12)
	suites_section.add_child(suites_row)
	body.add_child(suites_section)
	_about_title = _divider("ABOUT")
	body.add_child(_about_title)
	text_edit = _label("", FONT, 27, CREAM)
	text_edit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_edit.add_theme_constant_override("line_spacing", 4)
	body.add_child(text_edit)
	_let_swipes_through(scroll)

	action_bar = HBoxContainer.new()
	action_bar.name = "Actions"
	action_bar.add_theme_constant_override("separation", 14)
	action_bar.custom_minimum_size.y = 92
	var bar_margin := MarginContainer.new()
	for side in ["left", "right"]:
		bar_margin.add_theme_constant_override("margin_" + side, 22)
	bar_margin.add_child(action_bar)
	_dots_row = HBoxContainer.new()   # which of your properties this is (swipe for the others)
	_dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_row.add_theme_constant_override("separation", 10)
	_dots_row.custom_minimum_size.y = 12
	_dots_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_dots_row)
	column.add_child(bar_margin)
	scroll.gui_input.connect(_on_swipe_input)
	special_button = _action_button("", GREEN, null)
	special_button.pressed.connect(_on_special_pressed)
	action_bar.add_child(special_button)
	upgrade_button = _action_button("Upgrade", GREEN, CONTRACTOR_ICON)
	upgrade_button.name = "upgrade"
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	action_bar.add_child(upgrade_button)
	sell_button = _action_button("Sell", SELL_RED, SELL_ICON)
	sell_button.name = "sell"
	sell_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	sell_button.custom_minimum_size.x = 190
	sell_button.pressed.connect(_on_sell_pressed)
	action_bar.add_child(sell_button)

func _title_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	property_name = _label("", TITLE_FONT, 56, CREAM)
	property_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_name.clip_text = true
	property_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(property_name)
	region_icon = TextureRect.new()
	region_icon.custom_minimum_size = Vector2(52, 52)
	region_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	region_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	region_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ColorTheme.keep(region_icon)
	bar.add_child(region_icon)
	return bar

func _top_section() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	art_frame = Panel.new()
	art_frame.custom_minimum_size = Vector2(250, 250)
	art_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	art_frame.add_theme_stylebox_override("panel", _style(SLOT_BG, 26, CARD_EDGE, 3))
	property_icon = TextureRect.new()
	property_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top"]:
		property_icon.set("offset_" + side, 3)
	for side in ["right", "bottom"]:
		property_icon.set("offset_" + side, -3)
	property_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	property_icon.stretch_mode = TextureRect.STRETCH_SCALE   # a square picture with rounded corners
	property_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(property_icon)
	art_frame.add_child(property_icon)
	row.add_child(art_frame)

	stats_box = VBoxContainer.new()
	stats_box.name = "Stats"
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_box.add_theme_constant_override("separation", 10)
	var numbers := HBoxContainer.new()
	numbers.add_theme_constant_override("separation", 8)
	var value_col := _stat("VALUE")
	value_label = value_col.get_child(1)
	var rent_col := _stat("RENT")
	rent_label = rent_col.get_child(1)
	numbers.add_child(value_col)
	numbers.add_child(rent_col)
	stats_box.add_child(numbers)
	condition_chip = PanelContainer.new()
	_chip_style = _style(CONDITION_COLORS["good"], 30)
	_chip_style.content_margin_left = 18
	_chip_style.content_margin_right = 18
	_chip_style.content_margin_top = 6
	_chip_style.content_margin_bottom = 8
	condition_chip.add_theme_stylebox_override("panel", _chip_style)
	ColorTheme.keep(condition_chip)   # each condition keeps its own colour
	condition_text = _label("", BOLD, 28, CREAM)
	condition_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ColorTheme.keep(condition_text)
	condition_chip.add_child(condition_text)
	stats_box.add_child(condition_chip)
	tenants_label = _label("", FONT, 24, CREAM)
	tenants_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tenants_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_box.add_child(tenants_label)
	row.add_child(stats_box)
	return row

func _stat(caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -4)
	var small := _label(caption, BOLD, 20, CARD_EDGE)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(small)
	var big := _label("$0", BOLD, 64, CREAM)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(big)
	return col

# "All conditions" folds open into the full table (the current row has a band behind it).
func _conditions_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	# The arrow is drawn: phone browsers have no font with a ▾ in it (it showed as "25BE").
	conditions_toggle = HBoxContainer.new()
	conditions_toggle.custom_minimum_size.y = 52
	conditions_toggle.add_theme_constant_override("separation", 12)
	conditions_toggle.add_child(_label("All conditions", BOLD, 26, CARD_EDGE))
	_chevron = Control.new()
	_chevron.custom_minimum_size = Vector2(22, 22)
	_chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chevron.draw.connect(func():
		var w := _chevron.size
		_chevron.draw_polyline(PackedVector2Array([Vector2(3, w.y * 0.32), Vector2(w.x / 2.0, w.y * 0.72), Vector2(w.x - 3, w.y * 0.32)]),
				ColorTheme.map_color(CARD_EDGE, "text"), 3.5, true))
	conditions_toggle.add_child(_chevron)
	_on_tap(conditions_toggle, func(): _open_conditions(not conditions_table.visible, true))
	box.add_child(conditions_toggle)
	conditions_table = VBoxContainer.new()
	conditions_table.add_theme_constant_override("separation", 2)
	conditions_table.visible = false
	var head := _table_row("", "Value", "Rent", 22)
	conditions_table.add_child(head)
	for tier in ["e", "g", "f", "p"]:
		var tier_name: String = {"e": "Excellent", "g": "Good", "f": "Fair", "p": "Poor"}[tier]
		var row := _table_row(tier_name, "$0", "$0", 30)
		conditions_table.add_child(row)
		_rows[tier] = row
		var labels: Array = row.get_meta("labels")
		set(tier_name.to_lower(), labels[0])
		set(tier + "_value", labels[1])
		set(tier + "_rent", labels[2])
		set(tier_name.to_lower() + "_condition", row.get_meta("band"))
	box.add_child(conditions_table)
	return box

func _table_row(first: String, second: String, third: String, size: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var band := Panel.new()   # behind the current condition
	var band_style := _style(BAND, 16)
	band.add_theme_stylebox_override("panel", band_style)
	band.visible = false
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(band)
	var line := HBoxContainer.new()
	var labels := []
	for i in 3:
		var text: String = [first, second, third][i]
		var label := _label(text, BOLD if size < 26 else FONT, size, CARD_EDGE if size < 26 else CREAM)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = 1.4 if i == 0 else 1.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_CENTER
		if i == 0:
			label.text = "   " + text if text != "" else ""
		line.add_child(label)
		labels.append(label)
	row.add_child(line)
	row.set_meta("labels", labels)
	row.set_meta("band", band)
	return row

func _open_conditions(open: bool, sound: bool = false) -> void:
	conditions_table.visible = open
	_table_ready = true
	_chevron.pivot_offset = _chevron.custom_minimum_size / 2.0
	if sound:
		_chevron.create_tween().tween_property(_chevron, "rotation", PI if open else 0.0, 0.18)
	else:
		_chevron.rotation = PI if open else 0.0
	if sound:
		Sound.play("open" if open else "back")

## ---- TOKEN BADGES ----
# One round badge per token, like ability tokens on a game board. No writing: active
# ones glow green, ones you could add now are bright with a small + (and wiggle), ones
# you'd need to buy are faded, and ones that can't go here are faded with a red strike.
const TOKEN_SIZE := 118.0
const GLOW := Color("6fe07c")        # active token: icon, ring and glow
const GLOW_BG := Color("1f3a26")
const GOLD_GLOW := Color("f2c94c")   # the Golden Lock glows gold instead
const GOLD_BG := Color("3d3216")

func _token_slot(token: Dictionary) -> Control:
	var holder := Control.new()   # keeps the circle round whatever the row does
	holder.name = token["key"]
	holder.custom_minimum_size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Drawn as real circles (a rounded box left faint seams in the ring).
	var look := {"bg": SLOT_BG, "ring": CARD_EDGE, "width": 3.0, "glow": 0.0}
	holder.draw.connect(func():
		var c := holder.size / 2.0
		var r := TOKEN_SIZE / 2.0 - 2.0
		var glow: float = look["glow"]
		if glow > 0.0:   # a soft green halo, fading outwards
			var steps := int(glow)
			for i in steps:
				var a := 0.5 * pow(1.0 - float(i) / steps, 2.0)
				holder.draw_arc(c, r + i + 1.0, 0.0, TAU, 72, Color(look.get("shine", GLOW), a), 2.0, true)
		holder.draw_circle(c, r, ColorTheme.map_color(look["bg"], "fill"), true, -1.0, true)
		holder.draw_arc(c, r - look["width"] / 2.0, 0.0, TAU, 72,
				look["ring"] if look["ring"] in [GLOW, GOLD_GLOW] else ColorTheme.map_color(look["ring"], "border"), look["width"], true))
	var icon := TextureRect.new()
	icon.texture = load(token["icon"])
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top"]:
		icon.set("offset_" + side, 28)
	for side in ["right", "bottom"]:
		icon.set("offset_" + side, -28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _cream_shader
	material.set_shader_parameter("tint", CREAM)
	icon.material = material
	icon.set_meta("ct_skip", true)
	holder.add_child(icon)
	var slash := Control.new()   # "not allowed": a red line across
	slash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.visible = false
	slash.draw.connect(func():
		var r := slash.size
		slash.draw_line(Vector2(r.x * 0.2, r.y * 0.8), Vector2(r.x * 0.8, r.y * 0.2), NOT_ALLOWED, 7.0, true))
	slash.set_meta("ct_skip", true)
	holder.add_child(slash)
	var plus := Control.new()   # "you have one": a small green + on the rim (drawn, so it's dead centre)
	plus.size = Vector2(40, 40)
	plus.position = Vector2(TOKEN_SIZE - 36, -4)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.draw.connect(func():
		var c := plus.size / 2.0
		plus.draw_circle(c, 19.0, GLOW, true, -1.0, true)
		plus.draw_arc(c, 18.0, 0.0, TAU, 48, CREAM, 2.0, true)
		var arm := 9.0
		var bar := 4.0
		plus.draw_rect(Rect2(c.x - arm, c.y - bar / 2.0, arm * 2.0, bar), GLOW_BG)
		plus.draw_rect(Rect2(c.x - bar / 2.0, c.y - arm, bar, arm * 2.0), GLOW_BG))
	plus.set_meta("ct_skip", true)
	holder.add_child(plus)
	_on_tap(holder, _on_token_pressed.bind(token))   # the whole badge takes the tap
	token_slots[token["key"]] = {"panel": holder, "icon": icon, "slash": slash, "plus": plus,
			"look": look, "state": "", "glow": null}
	return holder

# "active", "add" (you have one and it can go here), "buy", "no" (not allowed here).
func _token_state(token: Dictionary) -> String:
	var p := current_property
	if p.get(token["flag"], false):
		return "active"
	if token["allow"] != "" and not p.get(token["allow"], false):
		return "no"
	if Cards.is_lot(p) and token["key"] != "golden_lock":
		return "no"
	var needed: int = p.get("insurance_needed", 1) if token["key"] == "insurance" else 1
	return "add" if Actions.actions_owned.count(token["key"]) >= needed else "buy"

func _show_tokens() -> void:
	for token in TOKENS:
		var slot: Dictionary = token_slots[token["key"]]
		var state := _token_state(token)
		slot["state"] = state
		var look: Dictionary = slot["look"]
		var holder: Control = slot["panel"]
		var icon_material: ShaderMaterial = (slot["icon"] as TextureRect).material
		var glow: Tween = slot["glow"]
		if glow and glow.is_valid():
			glow.kill()
		var active := state == "active"
		var gold: bool = token["key"] == "golden_lock"
		var shine := GOLD_GLOW if gold else GLOW
		look["bg"] = (GOLD_BG if gold else GLOW_BG) if active else SLOT_BG
		look["ring"] = shine if active else CARD_EDGE
		look["shine"] = shine
		look["width"] = 5.0 if active else 3.0
		look["glow"] = 14.0 if active else 0.0
		icon_material.set_shader_parameter("tint", shine if active else CREAM)
		holder.modulate.a = {"active": 1.0, "add": 1.0, "buy": 0.45, "no": 0.35}[state]
		(slot["plus"] as Control).visible = state == "add"
		var slash: Control = slot["slash"]
		slash.visible = state == "no"
		slash.queue_redraw()
		holder.queue_redraw()
		if active:   # the glow breathes
			var set_glow := func(v: float):
				look["glow"] = v
				holder.queue_redraw()
			var breathe := holder.create_tween().set_loops()
			breathe.tween_method(set_glow, 10.0, 20.0, 1.1).set_trans(Tween.TRANS_SINE)
			breathe.tween_method(set_glow, 20.0, 10.0, 1.1).set_trans(Tween.TRANS_SINE)
			slot["glow"] = breathe
	_jiggle_tokens()

func _on_token_pressed(token: Dictionary) -> void:
	if not _still_owned():
		return
	Sound.play("click")
	match token_slots[token["key"]]["state"]:
		"active":
			Global.banner("%s is on this property: it %s." % [token["name"], token["does"]])
		"buy":
			Global.banner("Buy a %s in the Market to put it here (it %s)." % [token["name"], token["does"]], "market")
		"no":
			Global.error("A %s can't be added to the %s." % [token["name"], current_property.get("name", "property")])
		"add":
			match token["key"]:
				"skybnb": _on_add_skybnb_pressed()
				"double": _on_add_double_pressed()
				"insurance": _on_add_insurance_pressed()
				"golden_lock": _on_add_lock_pressed()

## ---- "USE ME" JIGGLE ----
# Token cards you could add right now give a little wiggle every couple of seconds.
var _jiggles: Array = []

func _jiggle_tokens() -> void:
	for tween in _jiggles:
		if tween and tween.is_valid():
			tween.kill()
	_jiggles.clear()
	var i := 0
	for key in token_slots:
		var panel: Control = token_slots[key]["panel"]
		panel.rotation = 0.0
		if token_slots[key]["state"] != "add":
			continue
		panel.pivot_offset = panel.size / 2.0
		var tween := panel.create_tween().set_loops()
		tween.tween_interval(1.8 + i * 0.25)
		tween.tween_callback(func(): panel.pivot_offset = panel.size / 2.0)
		for angle in [0.06, -0.06, 0.04, -0.03, 0.015, 0.0]:
			tween.tween_property(panel, "rotation", angle, 0.06)
		_jiggles.append(tween)
		i += 1

## ---- SUITES (Hotel Resort / Luxury Cruise) ----
func _show_suites(added_one: bool = false) -> void:
	var is_host: bool = current_property.get("special", "") == "suite_host" and Network.expansion_on()
	suites_section.visible = is_host
	if not is_host:
		return
	var suites: Array = current_property.get("suites", [])
	(suites_title.get_child(1) as Label).text = "SUITES  %d / %d  ·  +$%d rent" % [suites.size(), Expansion.MAX_SUITES, suites.size() * Expansion.SUITE_RENT]
	for child in suites_row.get_children():
		child.queue_free()
	for i in Expansion.MAX_SUITES:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(120, 120)
		var filled := i < suites.size()
		var style := _style(SLOT_BG, 20, CARD_EDGE if filled else Color(CARD_EDGE, 0.35), 3 if filled else 2)
		slot.add_theme_stylebox_override("panel", style)
		if filled:
			var art := TextureRect.new()
			art.texture = _rounded_art(str(suites[i].get("art", "")), 17)
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for side in ["left", "top"]:
				art.set("offset_" + side, 3)
			for side in ["right", "bottom"]:
				art.set("offset_" + side, -3)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_SCALE
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ColorTheme.keep(art)
			slot.add_child(art)
		else:
			var plus := _label("+", FONT, 48, Color(CARD_EDGE, 0.45))
			plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(plus)
		suites_row.add_child(slot)
		if added_one and i == suites.size() - 1:   # the new Suite drops in
			slot.pivot_offset = Vector2(60, 60)
			slot.scale = Vector2(1.5, 1.5)
			slot.modulate.a = 0.0
			var drop := slot.create_tween().set_parallel(true)
			drop.tween_property(slot, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			drop.tween_property(slot, "modulate:a", 1.0, 0.2)
	_let_swipes_through(suites_row)   # (built after _build's pass, so a swipe starting on a slot used to do nothing)


## ---- FILLING IN THE CARD ----
# Safe to call again after a token is used (keeps the frame and its banner alive).
func setup_card() -> void:
	var p := current_property
	property_name.text = str(p["name"])
	_fit_title()
	var art_path: String = p.get("art", "")
	property_icon.texture = _rounded_art(art_path, 23)
	var region: String = p.get("region", "")
	region_icon.visible = Network.expansion_on() and region != ""
	if region_icon.visible:
		region_icon.texture = Expansion.region_icon(region)
		region_icon.tooltip_text = region
	value_label.text = "$%d" % int(p.get("value", 0))
	rent_label.text = "$%d" % int(p.get("rent", 0))
	_show_condition(str(p.get("condition", "")))
	_show_table()
	_show_tenants()
	_show_tokens()
	_show_suites()
	_show_description()
	_show_actions()
	_card_style.border_color = GOLD if p.get("has_golden_lock", false) else CARD_EDGE
	_show_dots()

func _fit_title() -> void:
	var size := 56
	var width := 560.0 if not region_icon.visible else 500.0
	while size > 32 and TITLE_FONT.get_string_size(property_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 2
	property_name.add_theme_font_size_override("font_size", size)

func _show_condition(condition: String) -> void:
	var p := current_property
	if Cards.is_lot(p):
		condition_text.text = "Empty lot"
		_chip_style.bg_color = GREEN
	elif p.get("has_condition", false):
		condition_text.text = condition.capitalize()
		_chip_style.bg_color = CONDITION_COLORS.get(condition, GREEN)
	else:
		condition_text.text = "Fixed value"
		_chip_style.bg_color = BAND

func _show_table() -> void:
	var p := current_property
	var has := bool(p.get("has_condition", false))
	conditions_toggle.visible = has
	if not has:
		conditions_table.visible = false
		return
	if not _table_ready:
		_open_conditions(false)
	for tier in _rows:
		var labels: Array = _rows[tier].get_meta("labels")
		labels[1].text = "$%s" % p.get(tier + "_value", 0)
		labels[2].text = "$%s" % p.get(tier + "_rent", 0)
	var both: bool = not p.get("two_conditions", false)   # Traditional Japanese Home: Excellent / Poor
	_rows["g"].visible = both
	_rows["f"].visible = both
	_show_band(str(p.get("condition", "")))

func _show_band(condition: String) -> void:
	for tier in _rows:
		var band: Panel = _rows[tier].get_meta("band")
		band.visible = Fortunas.CONDITION_PREFIX.get(condition, "") == tier

# Apartment you own: this round's tenants, right under the rent.
func _show_tenants() -> void:
	var p := current_property
	var owned: bool = p["name"] == "Apartment" and p.has("tenants")
	tenants_label.visible = owned
	if not owned:
		return
	var tenants := int(p["tenants"])
	var each := 3 * (2 if p.get("has_double", false) else 1)
	tenants_label.text = "%d tenant%s × $%d" % [tenants, "" if tenants == 1 else "s", each]

func _show_description() -> void:
	var p := current_property
	var text := str(p.get("p_details", ""))
	if p.get("has_golden_lock", false):
		text += "\n\nGolden Lock: protected from harm and can't be sold nor modified."
	if p.get("has_insurance", false):
		text += "\n\nInsured: the next disaster Fortuna that Insurance covers will be blocked or you will be compensated."
	if p["name"] == "Terraced House":
		text += "\n\nRounds owned: %d" % int(p.get("round", 0))
	if int(p.get("no_rent_rounds", 0)) > 0:
		text += "\n\nNo rent next round."
	text += _expansion_notes(p)
	text_edit.text = text.strip_edges()
	_show_purchase_loan(p)
	text_edit.text = text_edit.text.strip_edges()
	text_edit.visible = text_edit.text != ""
	_about_title.visible = text_edit.visible

## ---- THE BUTTONS AT THE BOTTOM ----
func _show_actions() -> void:
	var p := current_property
	# Expansion: swap a Cabin.
	special_button.visible = p.get("special", "") == "cabin" and not p.get("cabin_swapped", false) and Network.is_online()
	special_button.text = "Swap Cabin"
	# The main action: build on a lot, add a Suite, or upgrade with a Contractor.
	var text := ""
	if Cards.is_lot(p):
		text = "Build"
	elif _can_add_suite(p):
		text = "Add Suite  $%d" % Expansion.SUITE_COST
	elif p.get("has_condition", false) and p.get("condition", "") != "excellent" and Actions.actions_owned.has("contractor"):
		var next: String = CONDITION_ORDER[mini(CONDITION_ORDER.find(str(p["condition"])) + 1, 3)]
		text = "Upgrade to %s" % next.capitalize()
	upgrade_button.visible = text != ""
	upgrade_button.text = text
	_fit_button_text(upgrade_button)
	sell_button.size_flags_horizontal = Control.SIZE_SHRINK_END if (upgrade_button.visible or special_button.visible) else Control.SIZE_EXPAND_FILL
	sell_button.modulate.a = 0.5 if p.get("has_golden_lock", false) else 1.0   # a locked property can't be sold
	_nudge_upgrade()

func _fit_button_text(button: Button) -> void:
	var size := 32
	var room := 640.0 - 190.0 - 14.0 - 90.0
	while size > 22 and BOLD.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		size -= 1
	button.add_theme_font_size_override("font_size", size)

# A Contractor could upgrade this property: the button gives a little shake now and then.
var _nudge_tween: Tween

func _nudge_upgrade() -> void:
	if _nudge_tween:
		_nudge_tween.kill()
		_nudge_tween = null
	upgrade_button.rotation = 0.0
	if not upgrade_button.visible or not upgrade_button.text.begins_with("Upgrade"):
		return
	_nudge_tween = upgrade_button.create_tween().set_loops()
	_nudge_tween.tween_interval(2.0)
	_nudge_tween.tween_callback(func(): upgrade_button.pivot_offset = upgrade_button.size / 2.0)
	for angle in [0.03, -0.03, 0.02, -0.015, 0.0]:
		_nudge_tween.tween_property(upgrade_button, "rotation", angle, 0.06)

func _on_upgrade_pressed() -> void:
	var p := current_property
	if Cards.is_lot(p):
		_on_build_pressed()
	elif p.get("special", "") == "suite_host":
		if _has_action_left():
			await _build_suite()
	else:
		_on_use_contractor_pressed()

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

func _on_special_pressed() -> void:
	if not _has_action_left():
		return
	Sound.play("click")
	if current_property.get("special", "") == "cabin":
		special_button.disabled = true
		var message: String = await Expansion.cabin_swap(current_property)
		if is_instance_valid(special_button):
			special_button.disabled = false
		if message != "":
			Global.banner(message)
		if not Cards.properties_owned.has(current_property):
			get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")

# Hotel Resort / Luxury Cruise: a Contractor adds the next Suite, right here on the page.
func _build_suite() -> void:
	var problem := Expansion.suite_problem(current_property)
	if problem != "":
		Global.error(problem, "market" if problem.contains("Contractor") else "")
		return
	var popup = load("res://Scenes/pop_up.tscn").instantiate()
	get_tree().root.add_child(popup)
	popup.layout("Add Suite for $%d?\nUses a Contractor and 1 action.\n+$%d rent." \
			% [Expansion.SUITE_COST, Expansion.SUITE_RENT], "Yes", "No")
	var answer := [false]
	popup.left_pressed.connect(func(): answer[0] = true)
	await popup.tree_exited
	if not answer[0] or not is_inside_tree():
		return
	upgrade_button.disabled = true
	var before := current_property.duplicate()
	var message: String = await Expansion.build_suite(current_property)
	if is_instance_valid(upgrade_button):
		upgrade_button.disabled = false
	if message.begins_with("Suite added"):
		Global.banner(message)
		_refresh(before)
		_show_suites(true)
	else:
		Global.error(message, "market" if message.contains("Contractor") else "")

func _can_add_suite(details: Dictionary) -> bool:
	return details.get("special", "") == "suite_host" and Network.expansion_on() \
			and details.get("suites", []).size() < Expansion.MAX_SUITES

func _on_sell_pressed() -> void:
	if not _still_owned():
		return
	if current_property.get("has_golden_lock", false):
		Global.error("This property has a Golden Lock and can't be sold.")
		return
	Sound.play("click")
	sell_button.pivot_offset = sell_button.size / 2.0
	var pop := sell_button.create_tween()
	pop.tween_property(sell_button, "scale", Vector2(0.94, 0.94), 0.06)
	pop.tween_property(sell_button, "scale", Vector2.ONE, 0.08)
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/sell_property.tscn")


## ---- PUTTING TOKENS ON ----
func _on_add_double_pressed() -> void:
	if not _has_action_left():
		return
	var before := current_property.duplicate()
	Global.activate_double(current_property)   # spends the action
	Actions.consume("double")
	Global.banner("Double applied. Value doubled.")
	_refresh(before)
	_bubble_pop.call_deferred(token_slots["double"]["panel"])

func _on_add_skybnb_pressed() -> void:
	if not _has_action_left():
		return
	var before := current_property.duplicate()
	Global.activate_skybnb(current_property)   # spends the action
	Actions.consume("skybnb")
	Global.banner("SkyBnB applied. Rent doubled.")
	_refresh(before)
	_bubble_pop.call_deferred(token_slots["skybnb"]["panel"])

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
	_bubble_pop.call_deferred(token_slots["insurance"]["panel"])

# Golden Lock, straight from the card (same as My Properties' Golden Lock button).
func _on_add_lock_pressed() -> void:
	if not _has_action_left():
		return
	var popup = load("res://Scenes/pop_up.tscn").instantiate()
	get_tree().root.add_child(popup)
	popup.layout("Lock your %s with the Golden Lock?\nIt can't be harmed or sold." % current_property["name"], "Yes", "No")
	var answer := [false]
	popup.left_pressed.connect(func(): answer[0] = true)
	await popup.tree_exited
	if not answer[0] or not is_inside_tree() or not _has_action_left():
		return
	if not Actions.consume("golden_lock"):
		Global.error("You need a Golden Lock token.", "market")
		return
	current_property["has_golden_lock"] = true
	Global.action_used()
	Sound.play("sparkle")
	var note := "%s is locked: it can't be harmed or sold." % current_property["name"]
	Activity.add(note, "info")
	Global.banner_requested.emit(note, "")
	_refresh()
	_bubble_pop.call_deferred(token_slots["golden_lock"]["panel"])

func _has_action_left() -> bool:
	if not _still_owned():
		return false
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions. End your turn for more.", "home")
		return false
	return true

# A sabotage, auction or swap can take this property while its page is open.
func _still_owned() -> bool:
	if _owned_quietly():
		return true
	Global.error("You no longer own this property.")
	get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
	return false

func _refresh(before: Dictionary = {}) -> void:
	setup_card()
	ui_menu_frame.refresh_labels()   # expected rent may have changed
	if not before.is_empty():
		_animate_changes(before)


## ---- NUMBERS GOING UP ----
# After a token or Contractor: the value and rent count to their new numbers, and a new
# condition pops its chip (and moves the band if the table is open).
func _animate_changes(before: Dictionary) -> void:
	var after := current_property
	if before.get("value") is int and before["value"] != after.get("value"):
		_count_up(value_label, before["value"], int(after["value"]))
	if before.get("rent") is int and before["rent"] != after.get("rent"):
		_count_up(rent_label, before["rent"], int(after["rent"]))
	var old_condition: String = before.get("condition", "")
	var new_condition: String = after.get("condition", "")
	if after.get("has_condition", false) and old_condition != new_condition and old_condition != "":
		_pop_chip(CONDITION_ORDER.find(new_condition) > CONDITION_ORDER.find(old_condition))
		if conditions_table.visible:
			_show_band(old_condition)
			_slide_band(old_condition, new_condition)

func _count_up(label: Label, from: int, to: int) -> void:
	label.pivot_offset = label.size / 2
	var tween := label.create_tween()
	tween.tween_method(func(v: int): label.text = "$%d" % v, from, to, COUNT_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", RISE_COLOR if to >= from else FALL_COLOR, COUNT_TIME * 0.4)
	tween.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), COUNT_TIME * 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 0.4)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.4)

# A label swells and flashes green (up) or red (down), then settles.
func _flash(label: Control, up: bool) -> void:
	label.pivot_offset = label.size / 2
	var tween := label.create_tween()
	tween.tween_property(label, "modulate", RISE_COLOR if up else FALL_COLOR, COUNT_TIME * 0.4)
	tween.parallel().tween_property(label, "scale", Vector2(1.25, 1.25), COUNT_TIME * 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color.WHITE, 0.4)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.4)

# The condition chip flips over to the new condition.
func _pop_chip(up: bool) -> void:
	condition_chip.pivot_offset = condition_chip.size / 2
	var tween := condition_chip.create_tween()
	tween.tween_property(condition_chip, "scale", Vector2(1.0, 0.05), 0.12)
	tween.tween_callback(func(): _show_condition(str(current_property.get("condition", ""))))
	tween.tween_property(condition_chip, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(condition_chip, "scale", Vector2.ONE, 0.18)
	_flash(condition_text, up)

# The band glides from one row of the table to another.
func _slide_band(from_condition: String, to_condition: String) -> void:
	var from: Panel = _rows[Fortunas.CONDITION_PREFIX[from_condition]].get_meta("band")
	var to: Panel = _rows[Fortunas.CONDITION_PREFIX[to_condition]].get_meta("band")
	await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	var ghost := Panel.new()
	ghost.add_theme_stylebox_override("panel", from.get_theme_stylebox("panel"))
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.top_level = true
	ghost.show_behind_parent = true
	ColorTheme.keep(ghost)
	from.get_parent().add_child(ghost)
	ghost.global_position = from.global_position
	ghost.size = from.size
	ghost.modulate.a = 0.6   # the rows' writing shows through as it passes
	from.visible = false
	Sound.play("switch")
	var glide := ghost.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	glide.tween_property(ghost, "global_position", to.global_position, 0.6)
	await glide.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	if is_instance_valid(to):
		to.visible = true
		Notices.pulse_outline(to, 16, 4.0, 3)


## ---- WHAT'S NEW (notices.gd) ----
# The property changed since its page was last opened. `before` is how it looked then
# ({"new": true} = it just arrived). Tenants: the caption and rent change size and colour.
# Condition: the chip shows the OLD condition, then flips, while the table opens and its
# band slides to the new row; value and rent count up or down.
func _play_news(before: Dictionary) -> void:
	var after := current_property
	var was: String = before.get("condition", "")
	var condition_moved: bool = after.get("has_condition", false) and Fortunas.CONDITION_PREFIX.has(was) \
			and was != after.get("condition", "")
	if condition_moved:   # open on how it WAS
		_open_conditions(true)
		_show_condition(was)
		_show_band(was)
	if before.has("value") and not before.get("new", false):
		value_label.text = "$%d" % int(before["value"])
		rent_label.text = "$%d" % int(before["rent"])
	await get_tree().create_timer(0.45).timeout   # let the page appear first
	if not is_inside_tree() or not _owned_quietly():
		return
	if before.get("new", false):
		Notices.pulse_outline(art_frame, 26, 6.0, 3)
		return
	if after.has("tenants") and before.get("tenants") != after.get("tenants"):
		_flash(tenants_label, int(after["tenants"]) >= int(before.get("tenants", 0)))
		Sound.play("switch")
	if int(before.get("value", 0)) != int(after.get("value", 0)):
		_count_up(value_label, int(before["value"]), int(after["value"]))
	if int(before.get("rent", 0)) != int(after.get("rent", 0)):
		_count_up(rent_label, int(before["rent"]), int(after["rent"]))
	if condition_moved:
		var better := CONDITION_ORDER.find(str(after["condition"])) > CONDITION_ORDER.find(was)
		_pop_chip(better)
		Sound.play("bloop" if better else "cash_out")
		await _slide_band(was, str(after["condition"]))


## ---- NOTES ----
# Region, environment token, Suites on a Hotel / Cruise, a Cabin that already swapped.
func _expansion_notes(details: Dictionary) -> String:
	if not Network.expansion_on():
		return ""
	var notes := ""
	var region: String = details.get("region", "")
	if region != "":
		notes += "\n\nRegion: %s" % region
		if region.to_lower() == Expansion.my_region.to_lower():
			notes += " (your region: earns an Environment token)"
	if details.get("cabin_swapped", false):
		notes += "\n\nThis Cabin has already been swapped once."
	return notes

# Bought (or built) with a loan: say what's still owed on it, with a button to My Loans.
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
		_loan_button.add_theme_font_size_override("font_size", 26)
		_loan_button.custom_minimum_size = Vector2(0, 60)
		_loan_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		InkBox.apply(_loan_button, CARD_EDGE)
		_on_tap(_loan_button, func(): Global.open_link("my_loans"))
		text_edit.add_sibling(_loan_button)
	_loan_button.text = "  View loan ($%d owed)  >  " % loan["loan_balance"]
	_loan_button.visible = true


## ---- BUBBLE POP (a token just went on) ----
# The token's card swells and settles with a wobble, a ring ripples out and a few small
# bubbles float up.
func _bubble_pop(badge: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(badge) or not badge.visible:
		return
	Sound.play("double")
	var centre := badge.size / 2.0
	badge.pivot_offset = centre
	badge.scale = Vector2(0.6, 0.6)
	var pop := badge.create_tween()
	pop.tween_property(badge, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(badge, "scale", Vector2(0.95, 1.04), 0.1)
	pop.tween_property(badge, "scale", Vector2(1.03, 0.97), 0.1)
	pop.tween_property(badge, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), 24, CREAM, 4))
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.top_level = true
	ring.global_position = badge.global_position
	ring.size = badge.size
	ring.pivot_offset = centre
	ring.set_meta("ct_skip", true)
	badge.add_child(ring)
	var ripple := ring.create_tween().set_parallel(true)
	ripple.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.55).set_ease(Tween.EASE_OUT)
	ripple.tween_property(ring, "modulate:a", 0.0, 0.55)
	ripple.chain().tween_callback(ring.queue_free)
	for i in 5:
		var bubble := Panel.new()
		var b_style := _style(Color(1, 1, 1, 0.25), 40, Color(1, 1, 1, 0.8), 2)
		bubble.add_theme_stylebox_override("panel", b_style)
		var d := randf_range(12.0, 24.0)
		bubble.size = Vector2(d, d)
		bubble.top_level = true
		bubble.global_position = badge.global_position + centre + Vector2(randf_range(-30, 30), randf_range(0, 25)) - bubble.size / 2.0
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.set_meta("ct_skip", true)
		badge.add_child(bubble)
		var rise := bubble.create_tween().set_parallel(true)
		var time := randf_range(0.5, 0.8)
		rise.tween_property(bubble, "global_position:y", bubble.global_position.y - randf_range(70, 110), time).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		rise.tween_property(bubble, "modulate:a", 0.0, 0.12).set_delay(i * 0.05 + time - 0.12)
		rise.chain().tween_callback(bubble.queue_free)


## ---- SWIPING BETWEEN PROPERTIES ----
# Swipe left or right anywhere on the card for your next / previous property, in the
# order My Properties shows them (like Home's swipe to Activity). The card follows the
# finger; let go past ~18% of the screen and the next one slides in, otherwise it springs
# back. A mostly up/down swipe still scrolls the card. Dots show where you are.
const SWIPE_DECIDE := 24.0      # finger movement before we decide sideways vs up/down
const SWIPE_CHANGE := 0.18      # share of the width to let go past
var _column: VBoxContainer
var _dots_row: HBoxContainer
var _swipe_from := Vector2.INF
var _swipe_scroll := 0
var _swipe_mode := ""           # "" undecided, "side", "scroll"
var _swipe_tween: Tween

# Your properties in My Properties' order (its Sort button: as bought, A-Z or by value).
func _ordered() -> Array:
	var list: Array = Cards.properties_owned.duplicate()
	match Network.load_setting("my_properties", "sort", ""):
		"name":
			list.sort_custom(func(a, b): return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
		"value":
			list.sort_custom(func(a, b):
				if a.get("value", 0) != b.get("value", 0):
					return a.get("value", 0) > b.get("value", 0)
				return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return list

func _index_of_current() -> int:
	var list := _ordered()
	for i in list.size():
		if list[i].get("id", -1) == current_property.get("id", -2):
			return i
	return -1

func _show_dots() -> void:
	var count := Cards.properties_owned.size()
	var at := _index_of_current()
	while _dots_row.get_child_count() < count:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", _style(CARD_EDGE, 5))
		_dots_row.add_child(dot)
	while _dots_row.get_child_count() > count:
		var extra := _dots_row.get_child(_dots_row.get_child_count() - 1)
		_dots_row.remove_child(extra)
		extra.queue_free()
	for i in count:
		(_dots_row.get_child(i) as Control).modulate.a = 1.0 if i == at else 0.35
	_dots_row.visible = count > 1

func _swiping_allowed() -> bool:
	return not get_tree().root.has_node("Tutorial") and Cards.properties_owned.size() > 0

func _on_swipe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _swipe_tween and _swipe_tween.is_running():
				return
			_swipe_from = event.global_position
			_swipe_scroll = scroll.scroll_vertical
			_swipe_mode = ""
		else:
			if _swipe_mode == "side":
				_end_side_swipe(event.global_position.x - _swipe_from.x)
			_swipe_from = Vector2.INF
			_swipe_mode = ""
		return
	if not (event is InputEventMouseMotion) or _swipe_from == Vector2.INF:
		return
	if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return
	var moved: Vector2 = event.global_position - _swipe_from
	if _swipe_mode == "":
		if moved.length() < SWIPE_DECIDE:
			return
		_swipe_mode = "side" if absf(moved.x) > absf(moved.y) * 1.3 and _swiping_allowed() else "scroll"
	if _swipe_mode == "side":
		scroll.scroll_vertical = _swipe_scroll   # stay put while it's a sideways swipe
		_column.position.x = _drag_offset(moved.x)
		_place_peek(_column.position.x)

# Safety net: the card must never be left part-way off the screen (a player saw it
# hanging off the right edge). A finger that lifts where the card can't hear it (a second
# finger, an iOS edge gesture, the screen rotating) still ends the swipe here, and any
# leftover offset with no swipe or slide running is put back.
func _input(event: InputEvent) -> void:
	if _swipe_mode == "side" and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var dx: float = event.global_position.x - _swipe_from.x
		_swipe_from = Vector2.INF
		_swipe_mode = ""
		_end_side_swipe(dx)

func _process(_delta: float) -> void:
	if _column == null or _column.position.x == 0.0 or _swipe_mode == "side":
		return
	if _swipe_tween and _swipe_tween.is_valid() and _swipe_tween.is_running():
		return
	_settle_card()

func _settle_card() -> void:
	if _column == null or _swipe_mode == "side":
		return
	if _swipe_tween and _swipe_tween.is_valid() and _swipe_tween.is_running():
		return
	_column.position.x = 0.0
	_clear_peek()

# Past the first / last property the card only stretches a little (rubber band).
func _drag_offset(dx: float) -> float:
	var at := _index_of_current()
	var last := Cards.properties_owned.size() - 1
	if (at <= 0 and dx > 0) or (at >= last and dx < 0):
		return dx * 0.3
	return dx

func _end_side_swipe(dx: float) -> void:
	var width := get_viewport().get_visible_rect().size.x
	var at := _index_of_current()
	var list := _ordered()
	var step := 0
	if dx < -width * SWIPE_CHANGE and at < list.size() - 1:
		step = 1
	elif dx > width * SWIPE_CHANGE and at > 0:
		step = -1
	if step == 0:   # spring back
		_swipe_tween = _column.create_tween()
		_swipe_tween.tween_method(func(x: float):
			_column.position.x = x
			_place_peek(x), _column.position.x, 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_swipe_tween.tween_callback(_clear_peek)
		return
	show_property(list[at + step], step)

# While swiping, a preview of the neighbouring property (name, picture, numbers,
# condition) rides in beside the card, like Home's pages; the full card replaces it.
var _peek: Control
var _peek_for := 0   # -1 = the previous property, 1 = the next

func _place_peek(x: float) -> void:
	var side := -1 if x > 0 else 1
	var list := _ordered()
	var at := _index_of_current() + side
	if x == 0.0 or at < 0 or at >= list.size():
		_clear_peek()
		return
	if _peek == null or _peek_for != side:
		_clear_peek()
		_peek = _make_peek(list[at])
		_peek_for = side
	var width := get_viewport().get_visible_rect().size.x
	_peek.position.x = _column.position.x + side * width + 22

func _clear_peek() -> void:
	if _peek:
		_peek.queue_free()
		_peek = null
		_peek_for = 0

func _make_peek(p: Dictionary) -> Control:
	var area := scroll.get_global_rect()
	var peek := PanelContainer.new()
	peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _card_style.duplicate()
	style.border_color = GOLD if p.get("has_golden_lock", false) else CARD_EDGE
	peek.add_theme_stylebox_override("panel", style)
	peek.position = Vector2(22, area.position.y + 6)
	peek.size = Vector2(area.size.x - 44, minf(area.size.y - 20, 560))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	peek.add_child(box)
	box.add_child(_label(str(p.get("name", "")), TITLE_FONT, 52, CREAM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var art := TextureRect.new()
	art.texture = _rounded_art(str(p.get("art", "")), 23)
	art.custom_minimum_size = Vector2(250, 250)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	ColorTheme.keep(art)
	row.add_child(art)
	var stats := VBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var numbers := HBoxContainer.new()
	for pair in [["VALUE", p.get("value", 0)], ["RENT", p.get("rent", 0)]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", -4)
		var small := _label(pair[0], BOLD, 20, CARD_EDGE)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(small)
		var big := _label("$%d" % int(pair[1]), BOLD, 64, CREAM)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(big)
		numbers.add_child(col)
	stats.add_child(numbers)
	var chip := PanelContainer.new()
	var chip_style := _style(BAND, 30)
	chip_style.content_margin_top = 6
	chip_style.content_margin_bottom = 8
	var condition := ""
	if Cards.is_lot(p):
		condition = "Empty lot"
	elif p.get("has_condition", false):
		condition = str(p.get("condition", "")).capitalize()
		chip_style.bg_color = CONDITION_COLORS.get(str(p.get("condition", "")), GREEN)
	else:
		condition = "Fixed value"
	chip.add_theme_stylebox_override("panel", chip_style)
	ColorTheme.keep(chip)
	var chip_text := _label(condition, BOLD, 28, CREAM)
	chip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(chip_text)
	stats.add_child(chip)
	row.add_child(stats)
	box.add_child(row)
	page.add_child(peek)
	page.move_child(peek, _column.get_index())   # under the card, above the background
	return peek

# Slides the card out to one side and the next property in from the other.
func show_property(property: Dictionary, direction: int = 1) -> void:
	var width := get_viewport().get_visible_rect().size.x
	Sound.play("switch")
	_swipe_tween = _column.create_tween()
	_swipe_tween.tween_method(func(x: float):
		_column.position.x = x
		_place_peek(x), _column.position.x, -direction * width, 0.16).set_ease(Tween.EASE_OUT)
	await _swipe_tween.finished
	if not is_inside_tree():
		return
	Notices.mark_property(int(current_property.get("id", 0)))
	current_property = property
	Cards.selected_id = int(property.get("id", 0))   # Back from the sale screen returns here
	scroll.scroll_vertical = 0
	setup_card()
	_column.position.x = 0.0   # the full card takes the preview's place, where it landed
	_clear_peek()
	var news := Notices.property_before(int(property.get("id", 0)))
	Notices.mark_property(int(property.get("id", 0)))
	if not news.is_empty():
		_play_news(news)

## ---- SWIPING AND TAPPING ----
# The card scrolls with a finger swipe anywhere on it. Every part of the card lets the
# finger through to the scroll list (by default a panel or a button keeps it, so a swipe
# that started on the picture or a token didn't scroll). Tappable parts use _on_tap: it
# only counts when the finger barely moved and the card didn't scroll.
func _let_swipes_through(node: Node) -> void:
	if node is Control and node != scroll and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_let_swipes_through(child)

func _on_tap(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	if control is BaseButton:
		(control as BaseButton).action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	control.gui_input.connect(func(event: InputEvent):
		if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if event.pressed:
			control.set_meta("tap_from", event.global_position)
			control.set_meta("tap_scroll", scroll.scroll_vertical)
			return
		var from: Vector2 = control.get_meta("tap_from", Vector2.INF)
		control.set_meta("tap_from", Vector2.INF)
		if from.distance_to(event.global_position) > Global.TAP_SLOP:
			return   # a swipe, not a tap
		if absi(scroll.scroll_vertical - int(control.get_meta("tap_scroll", 0))) > 4:
			return   # the card scrolled under the finger
		action.call())

## ---- SMALL HELPERS ----
# The picture as a square with rounded corners (centre-cropped; made once per picture).
static var _rounded := {}
func _rounded_art(path: String, radius: int) -> Texture2D:
	var key := "%s@%d" % [path, radius]
	if _rounded.has(key):
		return _rounded[key]
	if path == "" or not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	var image := texture.get_image() if texture else null
	if image == null:
		return texture
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var side := mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	var r := int(radius * side / 244.0)   # the radius as drawn on screen (~244 px across)
	for corner in [Vector2i(0, 0), Vector2i(side - r, 0), Vector2i(0, side - r), Vector2i(side - r, side - r)]:
		var centre := Vector2(corner.x + (r if corner.x == 0 else 0), corner.y + (r if corner.y == 0 else 0))
		for y in r:
			for x in r:
				var px := Vector2(corner.x + x + 0.5, corner.y + y + 0.5)
				var d := px.distance_to(centre) - r
				if d > -1.0:
					var c := image.get_pixel(corner.x + x, corner.y + y)
					c.a *= clampf(-d, 0.0, 1.0)
					image.set_pixel(corner.x + x, corner.y + y, c)
	var rounded := ImageTexture.create_from_image(image)
	_rounded[key] = rounded
	return rounded

func _style(bg: Color, radius: int, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	return style

func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if colour == CREAM:
		# The card is dark in every theme, so its writing stays cream. (Retro and Rosey
		# turn cream writing dark brown / plum for their light screens: unreadable here.)
		ColorTheme.keep(label)
	return label

# "── TOKENS ──────": a small heading with a line after it.
func _divider(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := ColorRect.new()
	left.color = Color(CARD_EDGE, 0.5)
	left.custom_minimum_size = Vector2(18, 2)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	row.add_child(_label(title, BOLD, 22, CARD_EDGE))
	var line := ColorRect.new()
	line.color = Color(CARD_EDGE, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row

func _action_button(text: String, colour: Color, icon: Texture2D) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 88
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 32)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(c, CREAM)
	ColorTheme.keep_text(button)   # cream writing on the themed button in every theme
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := _style(colour.darkened(0.12) if state == "pressed" else colour, 44, CREAM, 3)
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 5)
		style.content_margin_left = 20
		style.content_margin_right = 24
		button.add_theme_stylebox_override(state, style)
	if icon:
		button.icon = _cream_copy(icon)   # the icon in cream, like the text
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 46)
		button.add_theme_constant_override("h_separation", 12)
	return button

# A one-colour cream copy of an icon (kept, so it's only made once).
static var _cream_icons := {}
func _cream_copy(texture: Texture2D) -> Texture2D:
	if _cream_icons.has(texture):
		return _cream_icons[texture]
	var image := texture.get_image()
	if image == null:
		return texture
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var a := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(CREAM, a))
	var copy := ImageTexture.create_from_image(image)
	_cream_icons[texture] = copy
	return copy
