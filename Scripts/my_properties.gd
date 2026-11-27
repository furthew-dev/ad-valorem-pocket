extends Node2D
## My Properties: one card per owned property.
## Assign mode (Global.assigning_token = "golden_lock"): tapping a property locks it
## instead of opening it.

const PROPERTY_CARD_SCENE = preload("res://Scenes/properties.tscn")
const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
# Sort: the order you got them in (""), A-Z ("name") or highest value first ("value").

@onready var list_of_properties: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/ScrollContainer/list_of_properties
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"
@onready var header: HBoxContainer = $CanvasLayer/Panel/VBoxContainer/Title/header

var _sort_mode := ""
var _sort_button: Button


func _ready() -> void:
	Cards.reset_id()
	if Global.new_property and not Cards.properties_owned.is_empty():
		var added := Global.new_property_name
		if added == "":
			added = Cards.properties_owned[-1]["name"]
		Global.banner("%s added to inventory." % added)
	Global.new_property = false
	Global.new_property_name = ""
	var arrived := Global.new_property_id
	Global.new_property_id = 0
	if Global.assigning_token == "golden_lock":
		Global.banner("Choose a property to protect with the Golden Lock.")
	if arrived != 0:
		Notices.mark_property(arrived)   # it slides in with a glow: no dot needed too
	_sort_mode = Network.load_setting("my_properties", "sort", "")
	_build_list()
	Global.properties_changed.connect(_build_list)   # e.g. a new round while this page is open
	if arrived != 0:
		_slide_in.call_deferred(arrived)
	else:
		_scroll_to_news.call_deferred()
	Notices.mark_app("my_properties")   # the app's own dot goes; each card keeps its dot
	_add_lock_button()

## ---- CAPACITY ("Capacity 3 / 5 Properties") ----
# 4 to start; each Land Expansion and Inheritance adds one. Empty lots count, as they do
# when buying. Shown in the header band so players know if they can keep buying.
var capacity_pill: PanelContainer   # (the tutorial points at it)

func capacity_text() -> String:
	return "Capacity  %d / %d Properties" % [Cards.properties_owned.size(), Global.PROPERTY_CAPACITY]

func _add_capacity_label() -> void:
	var full := Cards.properties_owned.size() >= Global.PROPERTY_CAPACITY
	capacity_pill = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2e2328") if not full else Color("793c44")
	style.border_color = Color("ddcf99")
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	capacity_pill.add_theme_stylebox_override("panel", style)
	capacity_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	capacity_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = capacity_text() + ("  ·  Full" if full else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("f6f2e1"))
	capacity_pill.add_child(label)
	ColorTheme.keep(label)   # cream on the dark pill in every theme (Rosey / Retro turned it dark)
	var centre := CenterContainer.new()   # top of the list (the header band sits under the frame)
	centre.custom_minimum_size = Vector2(0, 76)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(capacity_pill)
	list_of_properties.add_child(centre)

## ---- SORTING ----
# A small "Sort  Bought | A-Z | Value" pill, centred under Capacity and above the list.
# The chosen order is lit (purple with a gold edge) and remembered on this phone.
const SORT_OPTIONS := [["", "Bought"], ["name", "A-Z"], ["value", "Value"]]

func _add_sort_control() -> void:
	var centre := CenterContainer.new()
	centre.custom_minimum_size = Vector2(0, 74)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_of_properties.add_child(centre)
	var pill := PanelContainer.new()
	var bg := _sort_style(Color("2e2328"), Color(Color("ddcf99"), 0.6), 2, 30)
	bg.content_margin_left = 18
	bg.content_margin_right = 6
	bg.content_margin_top = 5
	bg.content_margin_bottom = 5
	pill.add_theme_stylebox_override("panel", bg)
	centre.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	pill.add_child(row)
	var caption := Label.new()
	caption.text = "Sort"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Regular.ttf"))
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color(Color("f6f2e1"), 0.7))
	caption.custom_minimum_size.x = 70
	row.add_child(caption)
	for option in SORT_OPTIONS:
		var b := Button.new()
		b.text = option[1]
		b.name = "sort_" + (option[0] if option[0] != "" else "bought")
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 50)
		b.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Bold.ttf"))
		b.add_theme_font_size_override("font_size", 24)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color("f6f2e1"))
		var on: bool = option[0] == _sort_mode
		var look := _sort_style(Color("7a6d79"), Color("ddcf99"), 2, 25) if on else _sort_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 25)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, look)
		b.pressed.connect(_on_sort_chosen.bind(option[0]))
		row.add_child(b)
	_sort_button = row.get_child(1) as Button   # (kept for older callers: the first option)
	for node in [pill, caption] + row.get_children():
		ColorTheme.keep(node)   # the same dark pill in every theme

func _sort_style(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _on_sort_chosen(mode: String) -> void:
	if mode == _sort_mode:
		return
	Sound.play("switch")
	_sort_mode = mode
	Network.save_setting("my_properties", "sort", _sort_mode)
	_build_list()

# The properties in display order (the list itself stays in the order you got them).
func _sorted_properties() -> Array:
	var list: Array = Cards.properties_owned.duplicate()
	match _sort_mode:
		"name":
			list.sort_custom(func(a, b): return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
		"value":
			list.sort_custom(func(a, b):
				if a.get("value", 0) != b.get("value", 0):
					return a.get("value", 0) > b.get("value", 0)
				return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return list

func _exit_tree() -> void:
	Global.assigning_token = ""   # leaving the page cancels assign mode
	Notices.mark_app("my_properties")   # changes made here (Golden Lock...) are seen

func _build_list() -> void:
	for child in list_of_properties.get_children():
		child.queue_free()
	_add_capacity_label()
	_add_sort_control()
	for property_data in _sorted_properties():
		var card_instance = PROPERTY_CARD_SCENE.instantiate()
		list_of_properties.add_child(card_instance)
		card_instance.setup_card(property_data)
		if Notices.property_dirty(property_data.get("id", 0)):   # changed since last opened
			Notices.dot(card_instance.panel, 38.0, Vector2(2, 2))
		card_instance.assign_requested.connect(_on_assign_requested.bind(property_data))
	if _lock_button:
		_update_lock_button.call_deferred()


# The first property with a red dot is brought into view (it may be further down).
func _scroll_to_news() -> void:
	await get_tree().process_frame   # laid out first
	var scroll := list_of_properties.get_parent() as ScrollContainer
	for child in list_of_properties.get_children():
		var card_panel = child.get("panel")
		if card_panel is Control and card_panel.get_node_or_null("NewDot") and scroll:
			scroll.ensure_control_visible(child)
			return

## ---- A NEW PROPERTY ARRIVES ----
# Just bought (or built): its row slides in from the right with a little bounce and a
# gold glow, so it's clear what was added. (This replaced the purchasing animation.)
func _slide_in(property_id: int) -> void:
	var row: Control = null
	for child in list_of_properties.get_children():
		if child.get("this_card_id") == property_id and not child.is_queued_for_deletion():
			row = child
	if row == null:
		return
	var panel: Control = row.get("panel")
	if panel == null:
		return
	var rest := panel.position
	panel.position.x = rest.x + 720
	panel.modulate.a = 0.0
	await get_tree().process_frame   # laid out: now it can be scrolled to
	if not is_instance_valid(row):
		return
	var scroll := list_of_properties.get_parent() as ScrollContainer
	if scroll:
		scroll.ensure_control_visible(row)
	var slide := panel.create_tween().set_parallel(true)
	slide.tween_property(panel, "position:x", rest.x, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_property(panel, "modulate:a", 1.0, 0.2)
	await slide.finished
	if not is_instance_valid(panel):
		return
	Sound.play("switch")
	var glow := Panel.new()   # a gold ring that pulses twice and fades
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("ddcf99")
	style.set_border_width_all(5)
	style.set_corner_radius_all(34)
	style.expand_margin_left = 6
	style.expand_margin_right = 6
	style.expand_margin_top = 6
	style.expand_margin_bottom = 6
	glow.add_theme_stylebox_override("panel", style)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(glow)
	panel.add_child(glow)
	var pulse := glow.create_tween()
	for i in 2:
		pulse.tween_property(glow, "modulate:a", 0.25, 0.28)
		pulse.tween_property(glow, "modulate:a", 1.0, 0.28)
	pulse.tween_property(glow, "modulate:a", 0.0, 0.5)
	pulse.tween_callback(glow.queue_free)

## ---- GOLDEN LOCK ----
# Own a Golden Lock? A gold button above the bottom bar: tap it, then tap a property
# (saves going through My Actions). While choosing it reads "Cancel".
const LOCK_ICON = preload("res://Assets/icons/tokens/lock_icon.png")
var _lock_button: Button

func _add_lock_button() -> void:
	_lock_button = Button.new()
	_lock_button.name = "use_golden_lock"
	_lock_button.icon = LOCK_ICON
	_lock_button.expand_icon = true
	_lock_button.add_theme_constant_override("icon_max_width", 44)
	_lock_button.add_theme_font_override("font", FONT)
	_lock_button.add_theme_font_size_override("font_size", 40)
	_lock_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD.darkened(0.15) if state == "pressed" else GOLD
		style.border_color = Color("f6f2e1")
		style.set_border_width_all(3)
		style.set_corner_radius_all(40)
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
		style.content_margin_left = 28
		style.content_margin_right = 34
		_lock_button.add_theme_stylebox_override(state, style)
	for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_lock_button.add_theme_color_override(colour, Color(0.1, 0.08, 0.05))
	ColorTheme.keep(_lock_button)   # gold in every theme
	_lock_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lock_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lock_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lock_button.custom_minimum_size = Vector2(0, 84)
	_lock_button.offset_bottom = -LOCK_BUTTON_LIFT
	_lock_button.pressed.connect(_on_lock_button_pressed)
	$CanvasLayer/Panel.add_child(_lock_button)
	_update_lock_button()
	Global.actions_changed.connect(func(_v): _update_lock_button())

const GOLD_BUTTON := Color("d4af37")
const LOCK_BUTTON_LIFT := 190.0   # just above the Back / Home / Menu bar
const GOLD := GOLD_BUTTON

func _update_lock_button() -> void:
	if _lock_button == null:
		return
	var assigning := Global.assigning_token == "golden_lock"
	_lock_button.visible = (Actions.actions_owned.has("golden_lock") or assigning) and not Turns.my_turn_done
	_lock_button.text = "Cancel" if assigning else "Use Golden Lock"
	_lock_button.icon = null if assigning else LOCK_ICON
	_lock_button.reset_size()
	_lock_button.offset_bottom = -LOCK_BUTTON_LIFT
	_lock_button.offset_top = _lock_button.offset_bottom - 84
	var half := _lock_button.get_combined_minimum_size().x / 2.0
	_lock_button.offset_left = -half
	_lock_button.offset_right = half
	_list_bottom_room(_lock_button.visible)

# Room under the last card so it can scroll clear of the button.
func _list_bottom_room(needed: bool) -> void:
	var room := list_of_properties.get_node_or_null("lock_room")
	if room and room.is_queued_for_deletion():
		room = null
	if needed and room == null:
		room = Control.new()
		room.name = "lock_room"
		room.custom_minimum_size = Vector2(0, 110)
		room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list_of_properties.add_child(room)
	elif not needed and room:
		room.queue_free()

func _on_lock_button_pressed() -> void:
	Sound.play("click")
	if Global.assigning_token == "golden_lock":
		Global.assigning_token = ""
		Global.banner("Golden Lock: cancelled.")
	else:
		if Global.ACTIONS <= 0:
			Global.error("You are out of Actions. End your turn for more.", "home")
			return
		Global.assigning_token = "golden_lock"
		Global.banner("Choose a property to protect with the Golden Lock.")
	_update_lock_button()

func _on_assign_requested(property: Dictionary) -> void:
	if property.get("has_golden_lock", false):
		Global.error("%s is already locked." % property["name"])
		return
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout("Lock your %s with the Golden Lock?" % property["name"], "Yes", "No")
	popup.left_pressed.connect(_lock.bind(property))

func _lock(property: Dictionary) -> void:
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions. End your turn for more.", "home")
		return
	if not Actions.consume("golden_lock"):
		Global.error("You need a Golden Lock token.", "market")
		return
	property["has_golden_lock"] = true
	Global.action_used()
	Global.assigning_token = ""
	Sound.play("sparkle")
	var note := "%s is locked: it can't be harmed or sold." % property["name"]
	Activity.add(note, "info")
	Global.banner_requested.emit(note, "")   # (the sparkle, not the banner chime)
	Notices.mark_property(property["id"])   # your own change: no dot
	_build_list()
	_update_lock_button()
