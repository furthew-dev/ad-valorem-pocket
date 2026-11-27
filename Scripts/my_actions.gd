extends Node2D
## Two apps share this script (Matt, 11-27: each is its own Home app now):
##   My Actions (Scenes/my_actions.tscn): the tokens you own (and the lucky Fortunas you
##     keep), with how many. Tap one to use it: it opens the screen where it's used, or
##     says what it's doing for you.
##   Market (Scenes/shop.tscn): every token for sale, with price and stock; tap one, then BUY.
## (Properties are bought in Dwellio.) Both pages are always built (buying refreshes Mine);
## the scene decides which one shows, with a title in place of the old Mine | Shop tabs.

const ROW_SCENE = preload("res://Scenes/actions_template.tscn")
const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const CHOICE_MENU = preload("res://Scripts/choice_menu.gd")
const THEME = preload("res://main_theme.tres")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")
const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const CANCEL := "Cancel"
const CREAM := Color("f6f2e1")
const GOLD := Color("ddcf99")
const TAB_BG := Color("49343d")
const TAB_ON := Color("7a6d79")
const MAX_LIST_WIDTH := 720.0
const SWIPE_DECIDE := 24.0     # finger movement before we decide sideways vs up/down
const SWIPE_CHANGE := 0.2      # share of the width to let go past to change page

@onready var panel: Panel = $CanvasLayer/Panel
@onready var old_column: VBoxContainer = $CanvasLayer/Panel/VBoxContainer
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"

var current_scene := "res://Scenes/my_actions.tscn"
var page := 0                    # 0 = Mine (My Actions), 1 = Shop (Market)
var only_shop := false           # this is the Market app (shop.tscn)
var list_of_actions: VBoxContainer   # Mine
var shop_list: VBoxContainer         # Shop
var buy: Button
var selected_card: Control = null
var selected_action: Dictionary = {}
var shop_tab: Control
var mine_tab: Control

var _news: Array = []
var _pager: Control
var _strip: Control
var _pages: Array[Control] = []
var _scrolls: Array[ScrollContainer] = []
var _tab_marker: Panel
var _button_group := ButtonGroup.new()
var _buying_key := ""
var _confirming := false
var _choosing_target := false
# One finger on the pages: where it went down, whether it's sliding the pages sideways.
var _touch := {"down": false, "at": Vector2.ZERO, "decided": false, "sideways": false, "scroll": 0, "moved": false}


func _ready() -> void:
	Cards.reset_id()
	only_shop = scene_file_path.ends_with("shop.tscn")
	current_scene = scene_file_path
	_news = [] if only_shop else Notices.new_actions()
	if not only_shop:
		Notices.mark_app("my_actions")
	old_column.visible = false   # the old single list; rebuilt below as two pages
	_build()
	_build_mine()
	_build_shop()
	_news = []   # pulse once, not again after using a token
	Global.actions_tab = ""
	show_page(1 if only_shop else 0, false)
	Market.stock_changed.connect(_on_stock_changed)
	get_viewport().size_changed.connect(func(): show_page(page, false))

func _exit_tree() -> void:
	if not only_shop:
		Notices.mark_app("my_actions")


## ---- LAYOUT ----
func _build() -> void:
	var screen := get_viewport().get_visible_rect().size
	# Tabs: "Mine | Shop", a pill with a sliding marker.
	var tabs := Panel.new()
	var tabs_style := _style(TAB_BG, 30)
	tabs.add_theme_stylebox_override("panel", tabs_style)
	tabs.size = Vector2(minf(560.0, screen.x - 80.0), 64)
	tabs.position = Vector2((screen.x - tabs.size.x) / 2.0, 184)
	panel.add_child(tabs)
	_tab_marker = Panel.new()
	_tab_marker.add_theme_stylebox_override("panel", _style(TAB_ON, 26, Color(GOLD, 0.7), 2))
	_tab_marker.size = Vector2(tabs.size.x / 2.0 - 8, tabs.size.y - 8)
	_tab_marker.position = Vector2(4, 4)
	_tab_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_child(_tab_marker)
	mine_tab = _tab_button(tabs, 0, "Mine")
	shop_tab = _tab_button(tabs, 1, "Shop")
	tabs.visible = false   # one app, one page: a title instead of the tabs
	var heading := Label.new()
	heading.text = "Market" if only_shop else "My Actions"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.position = Vector2(0, 182)
	heading.size = Vector2(screen.x, 70)
	heading.add_theme_font_override("font", preload("res://Assets/fonts/Handwriting-Regular.otf"))
	heading.add_theme_font_size_override("font_size", 58)
	heading.add_theme_color_override("font_color", CREAM)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(heading)

	# The two pages, side by side in a strip that slides.
	_pager = Control.new()
	_pager.clip_contents = true
	_pager.position = Vector2(0, 268)
	_pager.size = Vector2(screen.x, screen.y - 268 - 168)
	_pager.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(_pager)
	panel.move_child(_pager, ui_menu_frame.get_index() + 1)   # above the frame, or it eats the taps
	panel.move_child(tabs, _pager.get_index() + 1)
	_strip = Control.new()
	_strip.size = Vector2(screen.x * 2.0, _pager.size.y)
	_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	_pager.add_child(_strip)
	for i in 2:
		var page_box := VBoxContainer.new()
		page_box.position = Vector2(screen.x * i, 0)
		page_box.size = _pager.size
		page_box.add_theme_constant_override("separation", 10)
		page_box.mouse_filter = Control.MOUSE_FILTER_PASS
		_strip.add_child(page_box)
		_pages.append(page_box)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		page_box.add_child(scroll)
		_scrolls.append(scroll)
		var centre := HBoxContainer.new()   # phone-width list, centred on a wide screen
		centre.alignment = BoxContainer.ALIGNMENT_CENTER
		centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		centre.mouse_filter = Control.MOUSE_FILTER_PASS
		scroll.add_child(centre)
		var list := VBoxContainer.new()
		list.custom_minimum_size.x = minf(MAX_LIST_WIDTH, screen.x)
		list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		list.add_theme_constant_override("separation", 6)
		list.mouse_filter = Control.MOUSE_FILTER_PASS
		centre.add_child(list)
		if i == 0:
			list_of_actions = list
		else:
			shop_list = list
	_pages[1].add_child(_buy_bar())

func _tab_button(tabs: Panel, index: int, text: String) -> Control:
	var tab := Button.new()
	tab.text = text
	tab.flat = true
	tab.focus_mode = Control.FOCUS_NONE
	tab.position = Vector2(tabs.size.x / 2.0 * index, 0)
	tab.size = Vector2(tabs.size.x / 2.0, tabs.size.y)
	tab.add_theme_font_override("font", BOLD)
	tab.add_theme_font_size_override("font_size", 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		tab.add_theme_color_override(c, CREAM)
	ColorTheme.keep_text(tab)
	tab.pressed.connect(func():
		if page != index:
			Sound.play("switch")
			show_page(index))
	tabs.add_child(tab)
	return tab

# The Buy button under the Market list: the same rounded green button as "Go to the
# Market" and Dwellio's "Reveal" (dimmed until a token is picked).
const Cozy = preload("res://Scripts/cozy.gd")
func _buy_bar() -> Control:
	var holder := MarginContainer.new()
	holder.custom_minimum_size.y = 112
	for side in ["left", "right"]:
		holder.add_theme_constant_override("margin_" + side, 40)
	holder.add_theme_constant_override("margin_top", 10)
	holder.add_theme_constant_override("margin_bottom", 10)
	buy = Cozy.button("Choose a token to buy", Cozy.GREEN, 88, 30)
	buy.disabled = true
	buy.pressed.connect(_on_buy_pressed)
	holder.add_child(buy)
	_refresh_buy()
	return holder

func _refresh_buy() -> void:
	if buy == null:
		return
	Cozy.set_enabled(buy, not buy.disabled)
	if selected_action.is_empty():
		buy.text = "Choose a token to buy"
	else:
		buy.text = "Buy %s for $%d" % [selected_action.get("name", ""), Actions.price_of(selected_action)]

# Slides to a page (0 Mine, 1 Shop) and moves the tab marker.
func show_page(index: int, animate: bool = true) -> void:
	page = clampi(index, 0, 1)
	var width := get_viewport().get_visible_rect().size.x
	var target := Vector2(-width * page, 0)
	var marker_x := 4.0 + (_tab_marker.get_parent() as Control).size.x / 2.0 * page
	if animate:
		var tween := create_tween().set_parallel()
		tween.tween_property(_strip, "position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_tab_marker, "position:x", marker_x, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_strip.position = target
		_tab_marker.position.x = marker_x


## ---- SWIPING BETWEEN THE PAGES ----
# Watched before the lists see the finger: a mostly-sideways drag on the pages slides them
# (and the rows don't treat it as a tap); up/down stays the list's scroll.
func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _pager.get_global_rect().has_point(event.position):
				_touch = {"down": true, "at": event.position, "decided": false, "sideways": false,
						"scroll": _scrolls[page].scroll_vertical, "moved": false}
		elif _touch["down"]:
			_touch["down"] = false
			if _touch["sideways"]:
				_end_swipe(event.position.x - _touch["at"].x)
	elif event is InputEventMouseMotion and _touch["down"]:
		var delta: Vector2 = event.position - _touch["at"]
		if delta.length() > Global.TAP_SLOP:
			_touch["moved"] = true
		if not _touch["decided"] and delta.length() >= SWIPE_DECIDE:
			_touch["decided"] = true
			# (Not under a pop-up, a Fortuna or the recap: then the pages stay put.)
			# One page per app now (My Actions / Market): never slide sideways, only tell taps from scrolls.
			_touch["sideways"] = false
		if _touch["sideways"]:
			var width := get_viewport().get_visible_rect().size.x
			var x := -width * page + delta.x
			if (page == 0 and delta.x > 0) or (page == 1 and delta.x < 0):
				x = -width * page + delta.x * 0.3   # rubber band past the ends
			_strip.position.x = x
			var marker_x := 4.0 + (_tab_marker.get_parent() as Control).size.x / 2.0 * clampf(-x / width, 0.0, 1.0)
			_tab_marker.position.x = marker_x
			_scrolls[page].scroll_vertical = _touch["scroll"]   # sideways: don't scroll too

func _overlay_open() -> bool:
	for n in get_tree().root.get_children():
		if n is CanvasLayer and n.visible and n.layer >= 40 and n.name != "Tutorial":
			return true
	return false

func _end_swipe(dx: float) -> void:
	var width := get_viewport().get_visible_rect().size.x
	var target := page
	if dx < -width * SWIPE_CHANGE:
		target = 1
	elif dx > width * SWIPE_CHANGE:
		target = 0
	if target != page:
		Sound.play("switch")
	show_page(target)

# A row counts a tap only if the finger barely moved and the page didn't slide or scroll.
func _is_tap() -> bool:
	return not _touch["moved"] and not _touch["sideways"] \
			and absi(_scrolls[page].scroll_vertical - int(_touch["scroll"])) < 4


## ---- MINE ----
const HINTS := {
	"sabotage": "Tap to pick a player",
	"golden_lock": "Tap to pick a property",
	"certificate_of_deposit": "Tap to see it in the Bank",
	"realtor": "Tap to use in Dwellio",
	"llc": "Working for you",
	"attorney": "Working for you",
}

func _build_mine() -> void:
	for child in list_of_actions.get_children():
		child.queue_free()
	var counts := {}
	for action in Actions.actions_owned:
		counts[action] = counts.get(action, 0) + 1
	for action in counts:
		if not Actions.all_actions.has(action):
			push_warning("Unknown action: %s" % action)
			continue
		var row = ROW_SCENE.instantiate()
		list_of_actions.add_child(row)
		row.setup_owned(Actions.all_actions[action], counts[action], HINTS.get(action, "Tap to use"))
		row.use_taps(func(_r): _on_use_requested(action), _is_tap)
		if _news.has(action):
			_highlight(row)
	# Fortunas kept in hand (Just Say No...): shown here so you know you have them.
	var kept := {}   # effect -> [card, count]
	for card in Fortunas.fortunas_owned:
		var effect: String = card.get("effect", card.get("name", ""))
		if kept.has(effect):
			kept[effect][1] += 1
		else:
			kept[effect] = [card, 1]
	for effect in kept:
		var row = ROW_SCENE.instantiate()
		list_of_actions.add_child(row)
		row.setup_owned(kept[effect][0], kept[effect][1], "Kept for when it's needed")
		var card: Dictionary = kept[effect][0]
		row.use_taps(func(_r): _on_kept_fortuna_pressed(card), _is_tap)
		if _news.has("fortuna:" + str(effect)):
			_highlight(row)
	if list_of_actions.get_child_count() == 0:
		_empty_mine()

func _empty_mine() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size.y = 420
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	list_of_actions.add_child(box)
	var note := Label.new()
	note.text = "You don't own any Actions yet.\nTokens and helpers are sold in the Market."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", FONT)
	note.add_theme_font_size_override("font_size", 28)
	note.add_theme_color_override("font_color", CREAM)
	ColorTheme.keep(note)
	box.add_child(note)
	var go := Button.new()
	go.text = "Go to the Market"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(340, 84)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_override("font", BOLD)
	go.add_theme_font_size_override("font_size", 28)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		go.add_theme_color_override(c, CREAM)
	ColorTheme.keep_text(go)
	for state in ["normal", "hover", "pressed", "focus"]:
		go.add_theme_stylebox_override(state, _style(Color("5d6558").darkened(0.12 if state == "pressed" else 0.0), 42, CREAM, 3))
	go.pressed.connect(func():
		Sound.play("switch")
		Global.open_link("market"))
	box.add_child(go)

# A new or extra token: its card's outline fades in and out (and it's scrolled into view).
func _highlight(row: Control) -> void:
	var row_panel: Control = row.get_node("Panel")
	Notices.pulse_outline(row_panel, 22, 6.0, 5)
	(func(): if is_instance_valid(row): _scrolls[0].ensure_control_visible(row)).call_deferred()

func _on_use_requested(key: String) -> void:
	Sound.play("click")
	match key:
		"sabotage":
			_use_sabotage()
		"golden_lock":   # pick the property in My Properties
			if Global.ACTIONS <= 0:
				Global.error("You are out of Actions. End your turn for more.", "home")
				return
			Global.assigning_token = "golden_lock"
			Global.save_scene("res://Scenes/my_actions.tscn")
			get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
		_:
			_explain_or_go(key)

# Every token does something when tapped: it opens the screen where it's used, with a
# tip, or (for ones that work by themselves) says what it's doing for you.
const GO_TO := {
	"contractor": ["my_properties", "Contractor: pick a property to upgrade, or a lot to build on."],
	"listing_agent": ["my_properties", "Listing Agent: pick the property to sell. It's used when you sell (wins on 1 to 5)."],
	"skybnb": ["my_properties", "SkyBnB: pick a property to add it to (doubles the rent)."],
	"double": ["my_properties", "Double: pick a property to add it to (doubles the value)."],
	"insurance": ["my_properties", "Insurance: pick a property to insure."],
	"land_expansion": ["my_properties", "Land Expansion: build on your empty lot with a Contractor."],
	"hotel_suite": ["my_properties", "Suite: open your Hotel Resort to add it with a Contractor."],
	"cruise_suite": ["my_properties", "Suite: open your Luxury Cruise to add it with a Contractor."],
	"certificate_of_deposit": ["bank", "Certificates of Deposit: shown under Investments. One is worth $50, a pair $110."],
	"realtor": ["real_estate", "Realtor: choose Realtor to see 3 properties and pick one ($3 if you buy none)."],
}
const EXPLAIN := {
	"llc": "LLC: you get 5 Actions every turn instead of 3.",
	"attorney": "Attorney: blocks the next legal Fortuna that hits you (Auction, Lawsuits, Mold, Swap) by itself.",
}

func _explain_or_go(key: String) -> void:
	if GO_TO.has(key):
		Global.go_to(GO_TO[key][0], GO_TO[key][1])
	elif EXPLAIN.has(key):
		Global.banner(EXPLAIN[key])
	else:
		Global.banner(Actions.details_of(Actions.all_actions.get(key, {})) if Actions.all_actions.has(key) else "This is kept until it's needed.")

func _on_kept_fortuna_pressed(card: Dictionary) -> void:
	Sound.play("click")
	if card.get("effect", "") == "block_fortuna":
		Global.banner("Just Say No is offered when a harmful Fortuna or a sabotage hits you.")
	else:
		Global.banner("%s is kept for when it's needed." % card.get("name", "This card"))

func _use_sabotage() -> void:
	if _choosing_target:
		return
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions. End your turn for more.", "home")
		return
	var names := {}   # display name -> peer id
	for id in Network.players:
		if id != multiplayer.get_unique_id():
			names[Network.players[id]] = id
	if not Network.is_online() or names.is_empty():
		Global.error("There's nobody to sabotage.")
		return
	var menu = CHOICE_MENU.new()
	get_tree().root.add_child(menu)
	var options: Array = names.keys()
	options.append(CANCEL)
	menu.setup("Who do you want to sabotage?", options)
	_choosing_target = true
	var choice = await menu.chosen
	_choosing_target = false
	if choice == CANCEL or not names.has(choice):
		return
	var target_id: int = names[choice]
	if not Network.players.has(target_id):
		Global.error("%s has left the game." % choice)
		return
	if not Actions.consume("sabotage"):   # checked again: it may have been used meanwhile
		Global.error("You need a Sabotage token.", "market")
		return
	Global.action_used()
	Fortunas.sabotage(target_id)
	_build_mine()


## ---- SHOP ----
func _build_shop() -> void:
	_button_group.pressed.connect(_on_group_pressed)
	for action_data in Actions.action_types:
		var row = ROW_SCENE.instantiate()
		shop_list.add_child(row)
		row.setup_card(action_data, _button_group)
		row.use_taps(func(r): _select(r), _is_tap)

func _select(row: Control) -> void:
	row.button.button_pressed = true   # the group un-picks the others
	_on_group_pressed(row.button)

func _on_stock_changed(key: String, _stock: int) -> void:
	if key == _buying_key:
		return
	for row in shop_list.get_children():
		if _key_of(row.selected_card_data) == key:
			row.update_stock()

func _key_of(action: Dictionary) -> String:
	return str(action.get("name", "")).to_lower().replace(" ", "_")

func _on_group_pressed(button: BaseButton) -> void:
	Sound.play("switch")
	buy.disabled = false
	selected_card = button.get_meta("row", button.owner)   # the row the button belongs to
	selected_action = selected_card.selected_card_data
	_refresh_buy()

func _on_buy_pressed() -> void:
	if _confirming or _buying_key != "" or selected_action.is_empty():
		return
	var problem := _purchase_problem()
	if problem != "":
		Sound.play("error")
		_show_message(problem)
		return
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout("Are you sure you want to buy %s?" % selected_action["name"], "Yes", "No")
	popup.left_pressed.connect(_on_popup_confirm)
	_confirming = true
	popup.tree_exited.connect(func(): _confirming = false)

# Returns why this purchase can't happen, or "" if it can.
func _purchase_problem() -> String:
	if Global.ACTIONS <= 0:
		return "You are out of Actions."
	if selected_action["stock"] <= 0:
		return "%s is out of stock." % selected_action["name"]
	if not Global.can_afford(Actions.price_of(selected_action)):
		return "You don't have enough funds."
	if selected_action["name"] == "Land Expansion" and Cards.owns_land_expansion():
		return "You cannot own more than one Land Expansion."
	if selected_action["name"] == "LLC" and "llc" in Actions.actions_owned:
		return "You already own an LLC."
	return ""

func _on_popup_confirm() -> void:
	if _buying_key != "":
		return   # a purchase is already on its way
	var problem := _purchase_problem()   # re-check at the moment of purchase
	if problem != "":
		Sound.play("error")
		_show_message(problem)
		return
	var key := _key_of(selected_action)
	var card := selected_card
	_buying_key = key
	buy.disabled = true
	_refresh_buy()
	var result: Dictionary = await Market.purchase_action(key)   # finishes even if this screen closes
	if not is_inside_tree():
		return
	buy.disabled = false
	_refresh_buy()
	if not result["ok"]:
		_buying_key = ""
		Sound.play("error")
		_show_message(result["message"])
		if is_instance_valid(card):
			card.update_stock()
		return
	await _show_message(result["message"])
	_buying_key = ""
	if is_instance_valid(card):
		card.update_stock()   # animate once the pop-up is out of the way
	_build_mine()   # it's yours now: on the Mine page too

func _show_message(text: String) -> void:
	var popup = POPUP_SCENE.instantiate()
	add_child(popup)
	popup.layout(text, "OK", "")
	await popup.tree_exited


## ---- HELPERS ----
func _style(bg: Color, radius: int, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	return style
