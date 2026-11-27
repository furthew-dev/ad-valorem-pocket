extends CanvasLayer
## Guided tour for new players: a practice game on this phone only (nothing is online and
## nothing is saved). The screen dims except one spot (the "hole"); a speech bubble
## explains it. "Next" steps wait for a tap on Next; "do" steps wait for the player to
## tap the highlighted thing themselves (only the hole takes taps).
##     Tutorial.start(get_tree())          # from the title screen
## Finishing or skipping returns to the title screen and remembers the tour was seen.

const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const TITLE_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const LAYER := 110   # above pop-ups, the Fortuna card and menus
const BUBBLE_BG := Color("2e2328")
const CREAM := Color("f6f2e1")
const GOLD := Color("ddcf99")
const DIM := Color(0, 0, 0, 0.62)
const TITLE_SCENE := "res://Scenes/main.tscn"
const PRACTICE_ACTIONS := 6
const PRACTICE_LOAN := 30
const PRACTICE_DECK := ["Duplex", "Condo", "Yurt", "Mobile Home"]   # cheap, so the practice purchase is affordable
const POPUP_SCRIPTS := ["pop_up.gd", "choice_menu.gd", "settings_popup.gd", "avatar_editor.gd"]

var _steps: Array = []
var _index := -1
var _shade: _Shade
var _ring: Panel
var _bubble: PanelContainer
var _title: Label
var _text: Label
var _next_btn: Button
var _step_label: Label
var _check_clock := 0.0
var _running := false
var _scrolled_for := -1   # step whose target was already scrolled into view


static func start(tree: SceneTree) -> void:
	if tree.root.has_node("Tutorial"):
		return
	var tour = load("res://Scripts/tutorial.gd").new()
	tour.name = "Tutorial"
	tree.root.add_child(tour)

static func seen() -> bool:
	return Network.load_setting("tutorial", "seen", false)

func _ready() -> void:
	layer = LAYER
	_build()
	_steps = _make_steps()
	await _setup_practice_game()
	_running = true
	_go_to(0)


## ---- THE PRACTICE GAME ----
func _setup_practice_game() -> void:
	Network.game_settings = Network.DEFAULT_SETTINGS.duplicate()
	Network.game_settings["start_properties"] = 0
	Network.game_settings["expansion"] = false
	Network.in_game = true
	Global.PLAYER = Network.my_name if Network.my_name.strip_edges() != "" else "You"
	Network.avatars = {Global.PLAYER: Network.my_avatar()}
	Market.setup_new_game()
	await Global.start_game()
	Cards.properties_owned.clear()
	for pick in [["Two Story Home", "fair"], ["Beach House", "good"], ["Tiny House", "excellent"]]:
		Cards.properties_owned.append(Cards._make_property(Cards.templates_by_name[pick[0]], pick[1]))
	Actions.actions_owned.append("contractor")
	Global.CASH = 60
	Global.ACTIONS = PRACTICE_ACTIONS   # enough to buy, sell and pay a loan in one go
	Cards.property_deck = Cards._full_deck.filter(func(t): return t["name"] in PRACTICE_DECK)
	Global.loans.clear()
	Global.take_loan(PRACTICE_LOAN)   # an old loan to pay off in the Bank
	Activity.clear()
	Messages.clear()
	get_tree().change_scene_to_file("res://Scenes/home_screen.tscn")
	await get_tree().create_timer(0.6).timeout

func _end_practice_game() -> void:
	for node in get_tree().root.get_children():   # an open Settings / pop-up
		if node != self and _is_popup(node):
			node.queue_free()
	Turns.reset(false)   # (false: keep any real saved game for Resume)
	Network.in_game = false
	Network.avatars = {}
	Network.game_settings = Network.DEFAULT_SETTINGS.duplicate()
	Cards.properties_owned.clear()
	Cards.properties_revealed.clear()
	Actions.actions_owned.clear()
	Global.loans.clear()
	Global.tab_history.clear()
	Global.CASH = 0
	Activity.clear()
	Messages.clear()
	Network.save_setting("tutorial", "seen", true)


## ---- THE STEPS ----
# text, target (Callable -> Control or null), and either a "do" condition (Callable -> bool)
# or nothing (wait for Next). "enter" runs when the step starts.
func _make_steps() -> Array:
	return [
		{"title": "Welcome!", "text": "This short practice game shows you the basics. Nothing here counts, so tap around without worry.\n\nYou can skip it any time."},
		# 1. The header
		{"title": "Your cash", "text": "The big number is your cash. Expected rent is what your properties will pay you next round.\n\nThe gold bar fills as you near the End Goal: more than that in cash, with no loans, ends the game, and the highest net worth wins. Tap the bar any time for the numbers.",
			"target": _frame_part.bind("checking_bal")},
		{"title": "Actions", "text": "Everyone plays each round at the same time. Buying, selling, upgrading and paying a loan each use 1 Action: you get 3 a round (5 with an LLC), and 6 in this practice.\n\nTap your name any time to see how everyone else's turn is going.",
			"target": _frame_part.bind("actions_left")},
		# 2. Your properties
		{"title": "My Properties", "text": "Let's look at what you own. Tap My Properties.",
			"target": _tile.bind("my_properties_button"), "do": _scene_is.bind("my_properties")},
		{"title": "Your properties", "text": "Each one shows its value (what it's worth, and what it sells for), its rent (paid to you every round) and its condition (better condition, more of both). You can hold 4.\n\nTap the Two Story Home.",
			"target": _first_row_part.bind("panel"), "do": _scene_is.bind("property_info")},
		{"title": "The card", "text": "Tap All conditions to compare every condition's value and rent. Tokens glow green when they're on; a + means you own one (tap to add it); faded ones are sold in the Market.\n\nYou own a Contractor, so Upgrade appears: it raises the condition.",
			"target": _info_table},
		# 3. Selling, with a Listing Agent from the Market
		{"title": "Selling", "text": "Need cash? Sell a property. Tap Sell.",
			"target": _page_part.bind("sell_button"), "do": _scene_is.bind("sell_property")},
		{"title": "Two ways to sell", "text": "On your own, the die says SOLD on only 2 of its 6 sides. A Listing Agent makes it 5 of 6. You don't have one yet, so let's buy one.",
			"target": _sell_choice.bind("Realtor")},
		{"title": "The Market", "text": "Tokens and helpers are sold in the Market app. The ones you own are in My Actions.\n\nTap Home, then Market.",
			"target": _first_found.bind([_tile.bind("shop_button"), _frame_part.bind("home_btn")]),
			"do": _on_shop_page},
		{"title": "Buy a Listing Agent", "text": "Tap Listing Agent, then BUY, then Yes.",
			"target": _listing_agent_target, "do": _owns_listing_agent},
		{"title": "Sell a property", "text": "Back to the Two Story Home. Tap the Listing Agent card, then Sell.",
			"enter": _open_sell_page, "target": _sell_target, "do": _dice_open},
		{"title": "Roll the die", "text": "Press on the tray, pull back (down), and let go to throw. The further you pull, the harder it flies.\n\nIn this practice a FAIL just lets you throw again.",
			"target": _dice_part.bind("roll"), "do": _scene_is.bind("my_properties")},
		# 4. Buying
		{"title": "Dwellio", "text": "Sold! Its value went into your cash and the Listing Agent is used up, so there's room for a new property. Properties are bought in Dwellio.\n\nTap Home, then Dwellio.",
			"target": _first_found.bind([_tile.bind("market_button"), _frame_part.bind("home_btn")]),
			"do": _scene_is.bind("realtor_or_random")},
		{"title": "Buy Solo", "text": "A Realtor (from the Market) shows you three listings to pick from. Buy Solo shows one at random, and backing out still uses an Action.\n\nTap Buy Solo, then Reveal 1 Property.",
			"target": _buy_target, "do": _scene_is.bind("property_reveal")},
		{"title": "Purchase", "text": "Tap the listing, then Purchase. It costs its price and 1 Action. Short of cash? A Loan Agreement opens so you can borrow the rest.",
			"target": _purchase_target, "do": _scene_is.bind("my_properties")},
		# 5. The Bank and loans
		{"title": "The Bank", "text": "It's yours, and it pays rent from next round.\n\nNow tap Home, then the Bank.",
			"target": _first_found.bind([_tile.bind("bank_button"), _frame_part.bind("home_btn")]),
			"do": _scene_is.bind("bank_account")},
		{"title": "Your account", "text": "Cash, properties, savings and loans make up your net worth.\n\nYou have a $%d loan from earlier. Loans grow 10%% every round, and you can't end the game while you owe anything." % PRACTICE_LOAN,
			"target": _part.bind("bank_account", "account_card")},
		{"title": "Pay it off", "text": "Tap Make a Payment, then Make a Payment on the loan, then Pay. It uses 1 Action.",
			"target": _pay_target, "do": _loans_paid},
		{"title": "Debt free!", "text": "Keep an eye on loans: the interest adds up fast. Tap Home.",
			"target": _frame_part.bind("home_btn"), "do": _scene_is.bind("home_screen")},
		# 6. Home
		{"title": "Red dots", "text": "A red dot on an app means something changed there: a new round, a Fortuna, a purchase. Open it and what's new is highlighted. You can turn them off in Settings.",
			"target": _tile.bind("my_properties_button")},
		{"title": "Messages", "text": "Receive texts from the other players, table's big moments, the Bank and your Fortunas. Send back a quick reply like \"Ha!\".",
			"target": _tile.bind("messages_button")},
		{"title": "End Turn", "text": "When you're done, end your turn. When everyone has, a recap shows who's ahead, then the new round starts: with $25 or more you draw a Fortuna card (two with $100 or more), rent is paid and interest is added to loans.\n\nSwipe left on Home to see everything that happened.",
			"target": _tile.bind("end_turn_btn")},
		{"title": "Settings", "text": "Tap the menu button for your settings.",
			"target": _frame_part.bind("settings_btn"), "do": _settings_open},
		{"title": "You're ready!", "text": "Change your name, sounds, red dots, the round recap or the colour theme here, or leave a game.\n\nTap New Game to host and share the room key, or Play Solo on your own. Have fun!", "at": "top", "last": true},
	]

# The first of these targets that's on screen now (a step that crosses screens).
func _first_found(targets: Array) -> Control:
	for target in targets:
		var node = target.call()
		if node is Control and is_instance_valid(node) and node.is_visible_in_tree():
			return node
	return null

# Buy Solo's card until it's chosen, then the Reveal button.
func _buy_target() -> Control:
	if _solo_chosen():
		return _scene_node("CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/proceed")
	return _buy_choice("Private Purchase")

# The listing until it's chosen, then Purchase.
func _purchase_target() -> Control:
	if _listing_chosen():
		return _scene_node("CanvasLayer/Panel/VBoxContainer/revealed_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/HBoxContainer/Purchase")
	return _first_listing()

# The Bank's Make a Payment, then the loan's Make a Payment, then its Pay box.
func _pay_target() -> Control:
	if _scene_is("bank_account"):
		return _part("bank_account", "pay_button")
	return _loan_part("panel" if _loan_open() else "pay_button")


## ---- FINDING THINGS ON SCREEN ----
func _scene() -> Node:
	return get_tree().current_scene

func _scene_is(name: String) -> bool:
	var scene := _scene()
	return scene != null and scene.scene_file_path.ends_with("/%s.tscn" % name)

func _frame() -> Node:
	var scene := _scene()
	return scene.find_child("UI Menu Frame", true, false) if scene else null

func _frame_part(part: String) -> Control:
	var frame := _frame()
	if frame == null:
		return null
	var node = frame.get(part)
	if node is Button:   # the bottom buttons: highlight the whole icon
		return node.get_parent()
	return node as Control

func _tile(button: String) -> Control:
	var scene := _scene()
	if scene == null or not _scene_is("home_screen"):
		return null
	var found := scene.find_child(button, true, false)
	return found.get_parent().get_parent() if found else null   # the app's picture and name

func _scene_node(path: String) -> Control:
	var scene := _scene()
	return scene.get_node_or_null(path) as Control if scene else null

func _capacity_pill() -> Control:
	var scene := _scene()
	return scene.get("capacity_pill") if scene and _scene_is("my_properties") else null

func _first_row() -> Node:
	var scene := _scene()
	if scene == null or not _scene_is("my_properties"):
		return null
	var wanted = Cards.properties_owned[0]["id"] if not Cards.properties_owned.is_empty() else -1
	for row in scene.list_of_properties.get_children():   # the Two Story Home (fair: it can be upgraded)
		if row.has_method("setup_card") and not row.is_queued_for_deletion() and row.this_card_id == wanted:
			return row
	return null

func _first_row_part(part: String) -> Control:
	var row := _first_row()
	return row.get(part) as Control if row else null

func _info_table() -> Control:
	return _page_part("stats_box")

# A part of the Property Details card (property_info.gd builds it in code).
# A control a screen's script keeps by name (e.g. the Bank's "account_card").
func _part(scene_name: String, part: String) -> Control:
	var scene := _scene()
	return scene.get(part) as Control if scene and _scene_is(scene_name) else null

func _page_part(part: String) -> Control:
	var scene := _scene()
	return scene.get(part) as Control if scene and _scene_is("property_info") else null

func _sell_choice(which: String) -> Control:
	if not _scene_is("sell_property"):
		return null
	return _scene_node("CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/select/" + which)

func _buy_choice(which: String) -> Control:
	if not _scene_is("realtor_or_random"):
		return null
	return _scene_node("CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/select/" + which)

# The Listing Agent row until it's picked, then the BUY button.
func _listing_agent_target() -> Control:
	var scene := _scene()
	if scene == null or not _scene_is("shop"):
		return null
	if scene.selected_action.get("name", "") == "Listing Agent":
		return scene.buy
	for row in scene.shop_list.get_children():
		if row.get("selected_card_data") is Dictionary and row.selected_card_data.get("name", "") == "Listing Agent":
			if _scrolled_for != _index:
				_scrolled_for = _index
				var scroll: Node = scene.shop_list.get_parent()
				while scroll and not scroll is ScrollContainer:
					scroll = scroll.get_parent()
				if scroll:
					scroll.ensure_control_visible.call_deferred(row)
			return row
	return null

# The Listing Agent box until it's picked, then the Sell button.
func _sell_target() -> Control:
	var scene := _scene()
	if scene == null or not _scene_is("sell_property"):
		return null
	if scene.using_agent and not scene.sell_btn.disabled:
		return scene.sell_btn.get_parent()
	return _sell_choice("Realtor")

func _solo_chosen() -> bool:
	var scene := _scene()
	return scene != null and _scene_is("realtor_or_random") and not scene.proceed_btn.disabled and not Global.using_realtor

func _first_listing() -> Control:
	var scene := _scene()
	if scene == null or not _scene_is("property_reveal") or scene.list_of_properties.get_child_count() == 0:
		return null
	return scene.list_of_properties.get_child(0) as Control

func _listing_chosen() -> bool:
	var scene := _scene()
	return scene != null and _scene_is("property_reveal") and not scene.selected_card.is_empty()

# The property just bought (last in the list), scrolled into view.
func _newest_row() -> Control:
	var scene := _scene()
	if scene == null or not _scene_is("my_properties") or Cards.properties_owned.is_empty():
		return null
	var wanted = Cards.properties_owned[-1]["id"]
	for row in scene.list_of_properties.get_children():
		if row.has_method("setup_card") and not row.is_queued_for_deletion() and row.this_card_id == wanted:
			if _scrolled_for != _index:
				_scrolled_for = _index
				var scroll: Node = scene.list_of_properties.get_parent()
				while scroll and not scroll is ScrollContainer:
					scroll = scroll.get_parent()
				if scroll:
					scroll.ensure_control_visible.call_deferred(row)
			return row.get("panel") as Control   # the row itself is a zero-width holder
	return null

func _loan_row() -> Node:
	var scene := _scene()
	if scene == null or not _scene_is("my_loans"):
		return null
	for row in scene.list_of_loans.get_children():
		if not row.is_queued_for_deletion() and row.get("loan_id") != null:   # a loan card (not "debt free")
			return row
	return null

# "pay_button": the row's Make Payment; "panel": the payment box that opens under it.
func _loan_part(part: String) -> Control:
	var row := _loan_row()
	if row == null:
		return null
	return row.make_pymt_btn.get_parent() if part == "pay_button" else row.pay.get_parent()

func _loan_open() -> bool:
	var row := _loan_row()
	return row != null and row.make_payment.visible

func _loans_paid() -> bool:
	return Global.loans.is_empty()

# The die screen (dice_roll.gd), and its tray (press, pull back, let go).
func _dice() -> Node:
	return get_tree().root.get_node_or_null("DiceRoll")

func _dice_open() -> bool:
	return _dice() != null

func _dice_part(part: String) -> Control:
	var dice := _dice()
	if dice == null or part != "roll":
		return null
	return dice._tray if not dice._rolling and not dice._done else null

# An app animation is playing, or the die is rolling: let it be seen, undimmed.
func _transition_playing() -> bool:
	var dice := _dice()
	if dice != null and (dice._rolling or dice._done):
		return true
	var scene := _scene()
	return scene != null and scene.get_children().any(func(n): return _script_name(n) == "transition.gd")

func _actions_part(part: String) -> Control:
	var scene := _scene()
	return scene.get(part) as Control if scene and _scene_is("my_actions") else null

func _on_shop_page() -> bool:
	var scene := _scene()
	return scene != null and _scene_is("shop")

func _owns_listing_agent() -> bool:
	return Actions.actions_owned.has("listing_agent") and not _popup_open()

func _settings_open() -> bool:
	return get_tree().root.get_children().any(func(n): return _script_name(n) == "settings_popup.gd")

func _open_sell_page() -> void:
	Cards.selected_id = Cards.properties_owned[0]["id"]
	_open_scene("res://Scenes/sell_property.tscn")

func _open_scene(path: String) -> void:
	Global.erase_scenes()
	get_tree().change_scene_to_file(path)

func _script_name(node: Node) -> String:
	var script: Script = node.get_script()
	return script.resource_path.get_file() if script else ""

func _is_popup(node: Node) -> bool:
	return _script_name(node) in POPUP_SCRIPTS

# A pop-up (are you sure / message / menu) is open: during a "do" step it must be usable.
func _popup_open() -> bool:
	var places: Array = get_tree().root.get_children()
	if _scene():
		places.append_array(_scene().get_children())
	return places.any(func(n): return n != self and _is_popup(n) and n.visible)


## ---- RUNNING ----
func _go_to(index: int) -> void:
	_index = index
	if _index >= _steps.size():
		_finish()
		return
	var step: Dictionary = _steps[_index]
	if step.has("enter"):
		step["enter"].call()
	_title.text = step.get("title", "")
	_text.text = step.get("text", "")
	_step_label.text = "%d / %d" % [_index + 1, _steps.size()]
	_next_btn.visible = not step.has("do")
	_next_btn.text = "Finish" if step.get("last", false) else "Next"
	_bubble.modulate.a = 0.0
	_bubble.create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.25)
	Sound.play("notify")
	_step_time = 0.0
	_arrow.visible = false
	_update_hole(true)

func _on_next() -> void:
	if not _running:
		return
	Sound.play("char_next")
	_go_to(_index + 1)

func _process(delta: float) -> void:
	if not _running or _index < 0 or _index >= _steps.size():
		return
	_update_hole()
	_step_time += delta
	_update_arrow()
	var step: Dictionary = _steps[_index]
	if step.has("do"):
		_check_clock -= delta
		if _check_clock <= 0.0:
			_check_clock = 0.15
			if step["do"].call():
				_go_to(_index + 1)

func _target() -> Control:
	var step: Dictionary = _steps[_index]
	if not step.has("target"):
		return null
	var node = step["target"].call()
	if node is Control and is_instance_valid(node) and node.is_visible_in_tree():
		return node
	return null

# Moves the hole / ring / bubble when the target moves (only redraws when it changes).
func _update_hole(force: bool = false) -> void:
	var step: Dictionary = _steps[_index]
	var acting: bool = step.has("do")
	var popup := (acting and _popup_open()) or _transition_playing()
	var target := _target()
	var rect := Rect2()
	if target:
		var xf := target.get_global_transform_with_canvas()
		rect = Rect2(xf.origin, target.size * xf.get_scale()).grow(10)
	_shade.set_state(rect, not popup, acting)   # "do" steps: taps reach the hole only
	_ring.visible = target != null and not popup
	if _ring.visible and (force or _ring.position != rect.position or _ring.size != rect.size):
		_ring.position = rect.position
		_ring.size = rect.size
	_bubble.visible = not popup
	if force or _bubble.get_meta("for", Rect2(-1, -1, 0, 0)) != rect:
		_bubble.set_meta("for", rect)
		_place_bubble.call_deferred(rect)

# The tip sits at the bottom of the screen (over the menu bar). It only moves up when the
# spot to tap is down there too (Home, the menu button...) or would be under it.
const BUBBLE_MARGIN := 14.0
const TOP_BAR := 150.0
const ARROW_ROOM := 120.0   # between a raised tip and its spot, where the arrow goes
# A step that needs a tap: after ARROW_AFTER seconds, an arrow bobs next to the spot,
# pointing at it (from above, or from below when the spot is near the top).
const ARROW_AFTER := 3.0
var _step_time := 0.0
var _arrow: Node2D

func _update_arrow() -> void:
	var step: Dictionary = _steps[_index]
	var hole: Rect2 = _bubble.get_meta("for", Rect2())
	var show: bool = step.has("do") and _step_time >= ARROW_AFTER and hole.size != Vector2.ZERO and _ring.visible
	if not show:
		_arrow.visible = false
		return
	if not _arrow.visible:
		_arrow.visible = true
		_arrow.modulate.a = 0.0
		_arrow.create_tween().tween_property(_arrow, "modulate:a", 1.0, 0.25)
	var bob := absf(sin(_step_time * 5.0)) * 16.0
	var from_below := hole.position.y < TOP_BAR + 120.0
	if from_below:
		_arrow.position = Vector2(hole.get_center().x, hole.end.y + 8.0 + bob)
		_arrow.rotation = PI   # points up
	else:
		_arrow.position = Vector2(hole.get_center().x, hole.position.y - 8.0 - bob)
		_arrow.rotation = 0.0  # points down

func _place_bubble(hole: Rect2) -> void:
	var screen := get_viewport().get_visible_rect().size
	var width := minf(screen.x - 32.0, 680.0)
	_bubble.custom_minimum_size.x = width
	_bubble.size = Vector2(width, 0)
	_bubble.reset_size()   # shrink to this step's text
	await get_tree().process_frame
	_bubble.reset_size()
	var height := _bubble.size.y
	var x := (screen.x - width) / 2.0
	var y := screen.y - height - BUBBLE_MARGIN   # the bottom
	if _index >= 0 and _index < _steps.size() and _steps[_index].get("at", "") == "top":
		y = TOP_BAR   # out of the way of a pop-up in the middle
	elif hole.size != Vector2.ZERO and hole.end.y + 12.0 > y:   # the spot is under the tip
		y = hole.position.y - ARROW_ROOM - height               # above the spot, leaving room for the arrow
		if y < TOP_BAR:
			y = TOP_BAR
	_bubble.position = Vector2(x, y)

func _skip() -> void:
	if not _running:
		return
	var popup = load("res://Scenes/pop_up.tscn").instantiate()
	get_tree().root.add_child(popup)
	if popup.has_method("bring_to_front"):
		popup.bring_to_front(LAYER + 5)
	popup.layout("End the tour?\nYou can take it again from How to Play on the title screen.", "End tour", "Keep going")
	popup.left_pressed.connect(_finish)

func _finish() -> void:
	if not _running:
		return
	_running = false
	Sound.play("saved")
	_end_practice_game()
	get_tree().change_scene_to_file(TITLE_SCENE)
	queue_free()


## ---- LOOKS ----
func _build() -> void:
	_shade = _Shade.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)

	_ring = Panel.new()
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = GOLD
	ring_style.set_border_width_all(5)
	ring_style.set_corner_radius_all(26)
	_ring.add_theme_stylebox_override("panel", ring_style)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	var pulse := _ring.create_tween().set_loops()   # a slow glow so the spot is easy to find
	pulse.tween_property(_ring, "modulate:a", 0.35, 0.7)
	pulse.tween_property(_ring, "modulate:a", 1.0, 0.7)

	_arrow = _Arrow.new()
	_arrow.visible = false
	add_child(_arrow)

	_bubble = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BUBBLE_BG
	style.border_color = GOLD
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bubble)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_bubble.add_child(box)
	_title = _label("", 44, TITLE_FONT, GOLD)
	box.add_child(_title)
	_text = _label("", 28, FONT, CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var skip := _button("Skip tour", _skip, false)
	row.add_child(skip)
	_step_label = _label("", 22, FONT, Color(CREAM, 0.6))
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_step_label)
	_next_btn = _button("Next", _on_next, true)
	row.add_child(_next_btn)
	for node in find_children("*", "", true, false):
		ColorTheme.keep(node)   # the tour looks the same in every theme

func _label(text: String, size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable, solid: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150 if solid else 0, 64)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 28 if solid else 24)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD if solid else Color(0, 0, 0, 0)
	normal.set_corner_radius_all(22)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var pressed := normal.duplicate()
	pressed.bg_color = GOLD.darkened(0.2) if solid else Color(1, 1, 1, 0.08)
	for state in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("pressed", pressed)
	var ink := BUBBLE_BG if solid else Color(CREAM, 0.7)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.pressed.connect(action)
	return button


# The dimmed screen with a clear spot. In "do" steps taps inside the spot go through
# to the game underneath (and nowhere else); otherwise every tap stops here.
# A chunky arrow pointing down, its tip at (0, 0): gold with a dark outline.
class _Arrow extends Node2D:
	const SHAPE := [Vector2(0, 0), Vector2(-38, -42), Vector2(-15, -42), Vector2(-15, -92), Vector2(15, -92), Vector2(15, -42), Vector2(38, -42)]
	func _draw() -> void:
		var points := PackedVector2Array(SHAPE)
		draw_colored_polygon(points, Color("ddcf99"))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color("2a2229"), 5.0, true)

class _Shade extends Control:
	var hole := Rect2()
	var blocking := true
	var pass_through := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_state(new_hole: Rect2, block: bool, through: bool) -> void:
		if new_hole == hole and block == blocking and through == pass_through:
			return
		hole = new_hole
		blocking = block
		pass_through = through
		visible = block
		queue_redraw()

	func _has_point(point: Vector2) -> bool:
		if not blocking:
			return false
		if pass_through and hole.size != Vector2.ZERO and hole.has_point(point):
			return false   # let the tap reach the highlighted thing
		return Rect2(Vector2.ZERO, size).has_point(point)

	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		if hole.size == Vector2.ZERO:
			draw_rect(full, DIM)
			return
		var h := hole.intersection(full)
		draw_rect(Rect2(0, 0, size.x, h.position.y), DIM)
		draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), DIM)
		draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)
		draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), DIM)
