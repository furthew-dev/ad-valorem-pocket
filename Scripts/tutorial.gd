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
	Global.ACTIONS = Global.A_CAPACITY
	Activity.clear()
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
	Network.save_setting("tutorial", "seen", true)


## ---- THE STEPS ----
# text, target (Callable -> Control or null), and either a "do" condition (Callable -> bool)
# or nothing (wait for Next). "enter" runs when the step starts.
func _make_steps() -> Array:
	return [
		{"title": "Welcome!", "text": "This quick tour walks you through a practice game. Nothing here counts, so tap around without worry.\n\nYou can skip it any time."},
		# 1. The numbers at the top
		{"title": "Your cash", "text": "The big number is the cash in your account. Buying properties, tokens and actions spends it; rent fills it back up.",
			"target": _frame_part.bind("checking_bal")},
		{"title": "Expected rent", "text": "What your properties will pay you at the start of the next round.",
			"target": _frame_part.bind("misc")},
		{"title": "Round", "text": "Everyone plays each round at the same time. When all players have ended their turn, a new round begins.",
			"target": _frame_part.bind("round_number")},
		{"title": "Actions", "text": "Each purchase or upgrade uses 1 Action. You get 3 every round (5 with an LLC).",
			"target": _frame_part.bind("actions_left")},
		# 2. My Properties
		{"title": "My Properties", "text": "Let's look at what you own. Tap My Properties.",
			"target": _tile.bind("my_properties_button"), "do": _scene_is.bind("my_properties")},
		{"title": "Capacity", "text": "You can hold up to 4 properties. A Land Expansion or an Inheritance gives you room for one more each.",
			"target": _capacity_pill},
		# 3. Property details
		{"title": "Value", "text": "Value is what the property is worth. It counts toward your net worth, and it's what you're paid when you sell.",
			"target": _first_row_part.bind("current_value")},
		{"title": "Rent", "text": "Rent is paid to you for this property at the start of every round.",
			"target": _first_row_part.bind("current_rent")},
		{"title": "Condition", "text": "Excellent, Good, Fair or Poor. Better condition means more value and more rent. Bad luck (Fortuna cards) can knock it down.",
			"target": _first_row_part.bind("condition")},
		# 4. Open the property
		{"title": "Take a closer look", "text": "Tap the property to see its details.",
			"target": _first_row_part.bind("panel"), "do": _scene_is.bind("property_info")},
		{"title": "Every condition", "text": "This table shows the value and rent for each condition. The highlighted row is where this property is now.",
			"target": _info_table},
		# 5. Contractor
		{"title": "Upgrades", "text": "You own a Contractor (the hammer). Using it upgrades a property one condition, so it's worth more and earns more rent. Contractors are sold in the Market.",
			"target": _scene_node.bind("CanvasLayer/contractor")},
		# 6. Selling
		{"title": "Selling", "text": "Need cash? You can sell a property. Tap Sell.",
			"target": _scene_node.bind("CanvasLayer/Sell"), "do": _scene_is.bind("sell_property")},
		{"title": "Private sale", "text": "Sell it yourself: a die is rolled and it only sells on a 1 or 2. Free, but risky.",
			"target": _sell_choice.bind("Private Sale")},
		{"title": "Listing Agent", "text": "A Listing Agent sells it on a 1 to 5, much safer. You don't have one yet, so let's buy one.",
			"target": _sell_choice.bind("Realtor")},
		# 7. The Market
		{"title": "Go Home", "text": "Tap Home.",
			"target": _frame_part.bind("home_btn"), "do": _scene_is.bind("home_screen")},
		{"title": "The Market", "text": "Tap the Market.",
			"target": _tile.bind("market_button"), "do": _scene_is.bind("market")},
		{"title": "Actions", "text": "Actions are the tools of the game: tokens and helpers. Tap Actions.",
			"target": _scene_node.bind("CanvasLayer/Panel/VBoxContainer/MarginContainer/options/buttons/actions"), "do": _scene_is.bind("market_actions")},
		{"title": "Buy a Listing Agent", "text": "Tap Listing Agent, then BUY, then Yes.",
			"target": _listing_agent_target, "do": _owns_listing_agent},
		# 8. Back to selling
		{"title": "Now you have one", "text": "Back on the Sell page, the Listing Agent option is now available. Pick it when you sell for a 5 in 6 chance. It's used up either way.",
			"enter": _open_sell_page, "target": _sell_choice.bind("Realtor")},
		# 9. Buying property
		{"title": "Buying property", "text": "In the Market, Real Estate is where you buy property.\n\nBuy Solo shows you one random listing.",
			"enter": _open_scene.bind("res://Scenes/realtor_or_random.tscn"), "target": _buy_choice.bind("Private Purchase")},
		{"title": "Realtor", "text": "Use Realtor shows you three listings to choose from. Buy a Realtor in the Market's Actions, like the Listing Agent.",
			"target": _buy_choice.bind("Realtor")},
		# 10-11. The Bank
		{"title": "Go Home", "text": "Tap Home.",
			"target": _frame_part.bind("home_btn"), "do": _scene_is.bind("home_screen")},
		{"title": "The Bank", "text": "Tap the Bank.",
			"target": _tile.bind("bank_button"), "do": _scene_is.bind("bank_account")},
		{"title": "Your account", "text": "Your cash, the value of your properties, your savings and anything you owe. Together they make your net worth: the highest net worth wins.",
			"target": _scene_node.bind("CanvasLayer/Panel/VBoxContainer/Panel2")},
		{"title": "Loans", "text": "Short on cash when you buy? The game offers you a loan. Loans grow 10% every round, and you can't win while you owe anything. Pay them off here.",
			"target": _scene_node.bind("CanvasLayer/Panel/VBoxContainer/Panel3")},
		# 12. The other apps
		{"title": "Go Home", "text": "Tap Home.",
			"target": _frame_part.bind("home_btn"), "do": _scene_is.bind("home_screen")},
		{"title": "My Loans", "text": "Every loan you've taken, what you owe on it, and where you pay it back.",
			"target": _tile.bind("my_loans_button")},
		{"title": "My Actions", "text": "The tokens you own (Sabotage, Insurance, Contractor...) and the lucky cards you keep. Tap one to use it.",
			"target": _tile.bind("actions_button")},
		{"title": "End Turn", "text": "When you're done, end your turn. When everyone has, the round ends: Fortuna cards are drawn, interest is added and rent is paid.",
			"target": _tile.bind("end_turn_btn")},
		{"title": "Activity", "text": "Swipe left on Home to see everything that happened: rent, purchases, Fortunas and more."},
		# 13. Settings
		{"title": "Settings", "text": "Tap the menu button for your settings.",
			"target": _frame_part.bind("settings_btn"), "do": _settings_open},
		{"title": "Settings", "text": "Change your name, turn sounds on or off, pick a colour theme, or leave a game here.", "at": "top"},
		{"title": "You're ready!", "text": "Host a game and share the room key, or join a friend's game with theirs. Have fun!", "last": true},
	]


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
	return _scene_node("CanvasLayer/Panel/VBoxContainer/box/MarginContainer2/Panel") if _scene_is("property_info") else null

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
	if scene == null or not _scene_is("market_actions"):
		return null
	if scene.selected_action.get("name", "") == "Listing Agent":
		return scene.buy
	for row in scene.list_of_actions.get_children():
		if row.get("selected_card_data") is Dictionary and row.selected_card_data.get("name", "") == "Listing Agent":
			if _scrolled_for != _index:
				_scrolled_for = _index
				var scroll: Node = scene.list_of_actions.get_parent()
				while scroll and not scroll is ScrollContainer:
					scroll = scroll.get_parent()
				if scroll:
					scroll.ensure_control_visible.call_deferred(row)
			return row
	return null

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
	var popup := acting and _popup_open()
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

func _place_bubble(hole: Rect2) -> void:
	var screen := get_viewport().get_visible_rect().size
	var width := minf(screen.x - 48.0, 660.0)
	_bubble.custom_minimum_size.x = width
	_bubble.size = Vector2(width, 0)
	_bubble.reset_size()   # shrink to this step's text
	await get_tree().process_frame
	_bubble.reset_size()
	var height := _bubble.size.y
	var x := (screen.x - width) / 2.0
	var y: float
	if _index >= 0 and _index < _steps.size() and _steps[_index].get("at", "") == "top":
		y = 150.0   # out of the way of a pop-up in the middle
	elif hole.size == Vector2.ZERO:
		y = (screen.y - height) / 2.0
	elif hole.end.y + 24.0 + height < screen.y - 210.0:
		y = hole.end.y + 24.0           # below the spot
	elif hole.position.y - 24.0 - height > 150.0:
		y = hole.position.y - 24.0 - height   # above it
	else:
		y = clampf(screen.y - 230.0 - height, 150.0, screen.y - height)
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
