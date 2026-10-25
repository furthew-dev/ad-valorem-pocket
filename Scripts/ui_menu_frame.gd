extends Control
## Shared header/footer frame. Shows cash, actions, round, the message banners (Banner)
## and the money notices (Banner2).
## Every notification gets its OWN copy of the banner, animated like the original and
## freed when it finishes. Copies that overlap in time stack downward like a VBox and
## slide up when the one above them leaves.

signal home_pressed
signal back_pressed

const LOSS_COLOR := Color("c94040")   # Banner2 when money is taken out
const GAIN_COLOR := Color("4c9a52")   # Banner2 when money is received
const BANNER_SPACING := 108.0   # vertical distance between stacked message banners
const MONEY_SPACING := 84.0     # ...and between stacked money notices
const MONEY_SIZE := Vector2(75, 75)
const REASON_FONT_SIZE := 26
const MONEY_POSITION := Vector2(8, 176)   # top-left of the screen, where income_loss sits in the scene
const MAX_STACK := 4            # more than this wait for a free slot
const WAITING_BG := Color(0.32549, 0.235294, 0.266667, 0.92)
const SETTINGS_POPUP = preload("res://Scripts/settings_popup.gd")

# --- HEADER ---
@onready var player_name: Label = $Panel/MarginContainer/vbox/top_menu/left/player_name
@onready var misc: Label = $Panel/MarginContainer/vbox/top_menu/left/misc
@onready var checking_bal: Label = $Panel/MarginContainer/vbox/top_menu/checking_bal
@onready var round_number: Label = $Panel/MarginContainer/vbox/top_menu/right/round_number
@onready var actions_left: Label = $Panel/MarginContainer/vbox/top_menu/right/actions_left

# --- BANNER (messages) ---
@onready var anim_frame: NinePatchRect = $Panel2/Banner/anim_frame
@onready var text: Label = $Panel2/Banner/anim_frame/text
@onready var animation_player: AnimationPlayer = $Panel2/AnimationPlayer

# --- BANNER2 (income / loss) ---
@onready var income_loss: Panel = $Panel2/Banner2/income_loss
@onready var amount: Label = $Panel2/Banner2/income_loss/amount
@onready var money_player: AnimationPlayer = $Panel2/MoneyAnimationPlayer

# --- BOTTOM MENU ---
@onready var home_btn: Button = $Panel/MarginContainer/vbox/bottom_menu/home/home_btn
@onready var settings_btn: Button = $Panel/MarginContainer/vbox/bottom_menu/settings/settings_btn
@onready var back_btn: Button = $Panel/MarginContainer/vbox/bottom_menu/back/back_btn

# When true, Home/Back only emit home_pressed/back_pressed and the scene decides
# what to do (the lobby uses this to confirm leaving the room).
var custom_navigation := false

var _banner_queue: Array = []   # [message, link] waiting for a free slot
var _active_banners: Array[Control] = []
var _active_money: Array[Control] = []
var _banner_rest: Vector2       # anim_frame's on-screen / off-screen spots (from banner_drop)
var _banner_hidden: Vector2
var _money_origin: Vector2
var _banner_root: Control       # banners live here, on their own layer above the screen
var _layer: CanvasLayer
var _waiting_bar: PanelContainer
var _waiting_label: Label


func _ready() -> void:
	Global.cash_changed.connect(_on_cash_changed)
	Global.actions_changed.connect(_on_actions_changed)
	Global.round_changed.connect(_on_round_changed)
	Global.banner_requested.connect(run_animation)
	Global.animation_requested.connect(run_income_loss)
	settings_btn.pressed.connect(open_settings)
	_build_waiting_bar()
	Turns.waiting_changed.connect(_on_waiting_changed)
	Network.players_changed.connect(_show_my_face)   # characters arrive / change
	_on_waiting_changed(Turns.waiting_on)
	refresh_labels()
	_setup_banner_templates()


## ---- LABELS ----
func refresh_labels() -> void:
	checking_bal.text = "$%d" % Global.CASH
	player_name.text = str(Global.PLAYER)
	_show_my_face()
	actions_left.text = "%d Actions left" % Global.ACTIONS
	round_number.text = "Round %d" % Global.ROUND
	misc.text = "Expected Rent: $%d" % Global.expected_rent()

# Your character, just left of your name in the header.
const HEADER_FACE := 50
var _my_face: Control
var _face_hidden := false   # a title screen (lobby, results...): no header name

func _show_my_face() -> void:
	if _face_hidden or not Network.in_game or not AvatarArt.has_name(Global.PLAYER):
		return
	if not is_instance_valid(_my_face):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_vertical = player_name.size_flags_vertical
		var column := player_name.get_parent()
		column.add_child(row)
		column.move_child(row, player_name.get_index())
		player_name.reparent(row, false)
		player_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_my_face = AvatarArt.for_player(Global.PLAYER, HEADER_FACE)
		row.add_child(_my_face)
		row.move_child(_my_face, 0)
	else:
		AvatarArt.update(_my_face, AvatarArt.for_name(Global.PLAYER))
	_my_face.visible = true

func _on_cash_changed(new_value: int) -> void:
	checking_bal.text = "$%d" % new_value

func _on_actions_changed(new_value: int) -> void:
	actions_left.text = "%d Actions left" % new_value

func _on_round_changed(new_value: int) -> void:
	round_number.text = "Round %d" % new_value
	misc.text = "Expected Rent: $%d" % Global.expected_rent()

func clear_ui() -> void:
	player_name.text = ""
	_face_hidden = true
	if is_instance_valid(_my_face):
		_my_face.visible = false
	misc.text = ""
	checking_bal.text = "Hello!"
	round_number.text = ""
	actions_left.text = ""

# Replaces the header (name / cash / round) with a big title and a smaller subtitle,
# e.g. "Ad Valorem Pocket Edition" over "Main Menu". The title shrinks to fit the width.
const TITLE_SIZE := 64
const SUBTITLE_SIZE := 34

func show_title(title: String, subtitle: String = "") -> void:
	var top_menu: HBoxContainer = checking_bal.get_parent()
	for child in top_menu.get_children():
		child.visible = false
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	var h1 := _title_label(title, TITLE_SIZE)
	box.add_child(h1)
	if subtitle != "":
		var h2 := _title_label(subtitle, SUBTITLE_SIZE)
		h2.modulate.a = 0.8
		box.add_child(h2)
	top_menu.add_child(box)
	await get_tree().process_frame   # wait for the real width before fitting the title
	if is_instance_valid(h1) and h1.size.x > 0:
		var font := h1.get_theme_font("font")
		var size := TITLE_SIZE
		while size > 24 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > h1.size.x - 10:
			size -= 2
		h1.add_theme_font_size_override("font_size", size)

func _title_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true   # don't let a long title push the header wider than the screen
	label.add_theme_font_override("font", checking_bal.get_theme_font("font"))
	label.add_theme_color_override("font_color", checking_bal.get_theme_color("font_color"))
	label.add_theme_font_size_override("font_size", size)
	return label

func disable_buttons() -> void:
	home_btn.disabled = true
	back_btn.disabled = true


## ---- BANNERS ----
# The nodes in the scene are templates: hidden, duplicated per notification.
func _setup_banner_templates() -> void:
	animation_player.stop()
	money_player.stop()
	_banner_hidden = Vector2(450, 176)   # matches the banner_drop animation keys
	_banner_rest = Vector2(-14, 176)
	_money_origin = MONEY_POSITION
	anim_frame.visible = false
	income_loss.visible = false
	_banner_root = Control.new()
	_banner_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_layer().add_child(_banner_root)

# Message banner: slides in from the right, holds, slides back out (2.5 s).
# `link` (a Global.LINKS key): the banner can be tapped while it shows to open that screen,
# and says so ("Tap to open the Market"). It also stays up a little longer.
func run_animation(message: String, link: String = "") -> void:
	if _active_banners.size() >= MAX_STACK:
		_banner_queue.append([message, link])
		return
	var banner: Control = anim_frame.duplicate()
	var label: Label = banner.get_node("text")
	label.text = message
	banner.visible = true
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE   # plain banners never block taps
	if Global.LINKS.has(link):
		_make_tappable(banner, label, link)
	_add_player_face(banner, message)
	var y := _banner_rest.y + _active_banners.size() * BANNER_SPACING
	banner.position = Vector2(_banner_hidden.x, y)
	var spot := (anim_frame.get_parent() as Control).get_global_transform_with_canvas()
	_banner_root.position = spot.origin   # same place and size on screen as the banner area
	_banner_root.scale = spot.get_scale()
	_banner_root.size = (anim_frame.get_parent() as Control).size
	_banner_root.add_child(banner)
	_active_banners.append(banner)

	var tween := banner.create_tween()
	tween.tween_property(banner, "position:x", _banner_rest.x, 0.42)
	tween.tween_interval(3.0 if Global.LINKS.has(link) else 1.6)
	tween.tween_property(banner, "position:x", _banner_hidden.x, 0.48)
	tween.finished.connect(_remove_from_stack.bind(banner, _active_banners, _banner_rest.y, BANNER_SPACING))

# A banner about another player ("Erika is waiting on you!", "Sam sabotaged you") shows
# their character over the bell.
const AvatarArt = preload("res://Scripts/avatar.gd")

func _add_player_face(banner: Control, message: String) -> void:
	var who := other_player_in(message)
	if who == "":
		return
	var face := AvatarArt.for_player(who, 76)
	face.position = Vector2(14, (anim_frame.size.y - 76) / 2.0)
	face.z_index = 3
	banner.add_child(face)

# The name of another player mentioned in `text` ("" if none). Longest names are tried
# first, so "Sam" doesn't match inside "Samantha".
static func other_player_in(text: String) -> String:
	var names: Array = Network.avatars.keys()
	names.sort_custom(func(a, b): return a.length() > b.length())
	for player_name in names:
		if player_name != Global.PLAYER and player_name != "" and text.contains(player_name):
			return player_name
	return ""

func _make_tappable(banner: Control, label: Label, link: String) -> void:
	label.offset_bottom = -22   # make room for the hint line
	var hint: Label = label.duplicate()
	hint.text = "Tap to open %s  >" % Global.LINKS[link][1]
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint.offset_top = 0
	hint.offset_bottom = -8
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate.a = 0.85
	banner.add_child(hint)
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	banner.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			banner.mouse_filter = Control.MOUSE_FILTER_IGNORE   # one tap is enough
			Global.open_link(link))

# Money notice: a 75x75 circle at the top-left, with the reason on a tag to its right
# ("+$12" | Rent). Fades in, holds, fades out (2 s). Red for money out, green for money in.
# Built fresh each time so its size can't drift.
func run_income_loss(type: String, total: int, reason: String = "") -> void:
	var is_loss := type == "loss"
	var color := LOSS_COLOR if is_loss else GAIN_COLOR
	var notice := Control.new()   # holds the tag and the circle; this is what fades and stacks
	notice.custom_minimum_size = MONEY_SIZE
	notice.size = MONEY_SIZE
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.z_index = 5

	if reason != "":
		var tag := Panel.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = color.darkened(0.15)
		tag_style.set_corner_radius_all(26)
		tag.add_theme_stylebox_override("panel", tag_style)
		var why: Label = amount.duplicate()
		why.text = reason
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		why.add_theme_font_size_override("font_size", REASON_FONT_SIZE)
		var width := why.get_theme_font("font").get_string_size(reason, HORIZONTAL_ALIGNMENT_LEFT, -1, REASON_FONT_SIZE).x
		tag.size = Vector2(MONEY_SIZE.x / 2 + 16 + width + 22, 52)
		tag.position = Vector2(MONEY_SIZE.x / 2, (MONEY_SIZE.y - tag.size.y) / 2)
		why.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		why.offset_left = MONEY_SIZE.x / 2 + 12
		tag.add_child(why)
		notice.add_child(tag)

	var circle := Panel.new()
	circle.size = MONEY_SIZE
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(35)
	circle.add_theme_stylebox_override("panel", style)
	var label: Label = amount.duplicate()   # same theme and font as the scene's label
	label.text = ("-$%d" if is_loss else "+$%d") % total
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.clip_text = true
	if label.text.length() > 5:
		label.add_theme_font_size_override("font_size", 18)   # e.g. "+$1000" still fits
	circle.add_child(label)
	notice.add_child(circle)

	notice.modulate.a = 0.0
	notice.position = _money_origin + Vector2(0, _active_money.size() * MONEY_SPACING)
	add_child(notice)
	_active_money.append(notice)

	var tween := notice.create_tween()
	tween.tween_property(notice, "modulate:a", 1.0, 0.36)
	tween.tween_interval(1.6 if reason != "" else 1.3)   # a little longer when there's a reason to read
	tween.tween_property(notice, "modulate:a", 0.0, 0.34)
	tween.finished.connect(_remove_from_stack.bind(notice, _active_money, _money_origin.y, MONEY_SPACING))

# Frees a finished copy and slides the ones below it up into place.
func _remove_from_stack(node: Control, stack: Array[Control], top: float, spacing: float) -> void:
	stack.erase(node)
	node.queue_free()
	for i in stack.size():
		var slide := stack[i].create_tween()
		slide.tween_property(stack[i], "position:y", top + i * spacing, 0.2)
	if is_same(stack, _active_banners) and not _banner_queue.is_empty():
		var next: Array = _banner_queue.pop_front()
		run_animation(next[0], next[1])


# Banners and the waiting bar get their own layer, so a tappable one is on top for taps too
# (not only for drawing): otherwise the screen's own buttons and pictures under it would
# take the tap.
func _top_layer() -> CanvasLayer:
	if _layer == null:
		_layer = CanvasLayer.new()
		# One above the layer this frame's screen is drawn on: above a normal screen (so
		# pop-ups, added later on layer 2, still cover it) and above a Fortuna card when the
		# frame belongs to the card.
		var own := get_canvas_layer_node()
		_layer.layer = (own.layer if own else 1) + 1
		add_child(_layer)
	return _layer


## ---- WAITING BAR (after End Turn) ----
# A strip above the bottom bar: "Waiting on: Sam, Jo" (tap to poke them), or, when everyone
# is waiting on YOU, a red strip with the seconds left to end your turn (tap to go Home).
const URGENT_BG := Color("c94040")
const WAITING_BAR_BOTTOM := 200.0   # distance from the bottom of the screen
var _waiting_style: StyleBoxFlat
var _waiting_faces: HBoxContainer
var _faces_for := []
var _waiting_hint: Label

func _build_waiting_bar() -> void:
	var holder := Control.new()   # full screen, like this frame
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_layer().add_child(holder)
	_waiting_bar = PanelContainer.new()
	# Just above the Back / Home / Menu bar, so it never collides with the banners up top.
	_waiting_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_waiting_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_waiting_bar.offset_left = 30
	_waiting_bar.offset_right = -30
	_waiting_bar.offset_top = 0
	_waiting_bar.offset_bottom = -WAITING_BAR_BOTTOM
	_waiting_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting_style = StyleBoxFlat.new()
	_waiting_style.bg_color = WAITING_BG
	_waiting_style.set_corner_radius_all(24)
	_waiting_style.content_margin_left = 20
	_waiting_style.content_margin_right = 20
	_waiting_style.content_margin_top = 8
	_waiting_style.content_margin_bottom = 8
	_waiting_bar.add_theme_stylebox_override("panel", _waiting_style)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 0)
	_waiting_label = Label.new()
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_waiting_label.add_theme_font_size_override("font_size", 26)
	lines.add_child(_waiting_label)
	_waiting_hint = Label.new()
	_waiting_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_hint.add_theme_font_size_override("font_size", 18)
	_waiting_hint.modulate.a = 0.85
	lines.add_child(_waiting_hint)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()   # the message, and an × to put it away
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_waiting_faces = HBoxContainer.new()   # the characters of who we're waiting on
	_waiting_faces.add_theme_constant_override("separation", -10)   # overlapping, like a stack
	_waiting_faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting_faces.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_waiting_faces)
	row.add_child(lines)
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(56, 56)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 40)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(_dismiss_waiting_bar)
	row.add_child(close)
	_waiting_bar.add_child(row)
	_waiting_bar.gui_input.connect(_on_waiting_bar_input)
	_waiting_bar.visible = false
	holder.add_child(_waiting_bar)
	Turns.countdown_changed.connect(func(_n, _s): _refresh_waiting_bar())
	Turns.poked_list_changed.connect(_refresh_waiting_bar)

func _on_waiting_changed(_names: Array) -> void:
	_refresh_waiting_bar()

func _urgent() -> bool:   # everyone is waiting on me
	return Turns.countdown_name != "" and Turns.countdown_name == Turns.my_name() and not Turns.my_turn_done

# The × hides the bar (it can sit over a screen's own buttons) until something changes:
# someone else finishes, a countdown starts... Remembered across screens.
static var _dismissed_key := "-"

func _waiting_key() -> String:
	return "%s|%s|%s|%s|%d" % [_urgent(), Turns.my_turn_done, Turns.waiting_on, Turns.countdown_name, Global.ROUND]

func _dismiss_waiting_bar() -> void:
	Sound.play("back")
	_dismissed_key = _waiting_key()
	_waiting_bar.visible = false

func _refresh_waiting_bar() -> void:
	if _waiting_bar == null:
		return
	if _waiting_key() == _dismissed_key:
		_waiting_bar.visible = false
		return
	var names := Turns.waiting_on
	if _urgent():
		_show_waiting_faces([])
		_waiting_bar.visible = true
		_waiting_style.bg_color = URGENT_BG
		_waiting_label.text = "Everyone is waiting on you! %ds" % ceili(Turns.countdown_left)
		_waiting_hint.text = "Tap to go Home and end your turn"
		_waiting_hint.visible = true
		_waiting_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	_waiting_style.bg_color = WAITING_BG
	_waiting_bar.visible = Turns.my_turn_done and not names.is_empty()
	var shown := []
	for n in names:
		shown.append("%s (%ds)" % [n, ceili(Turns.countdown_left)] if n == Turns.countdown_name else str(n))
	_waiting_label.text = "Turn ended. Waiting on: " + ", ".join(PackedStringArray(shown))
	_show_waiting_faces(names)
	var can_poke := not Turns.pokeable().is_empty()
	_waiting_hint.visible = can_poke
	_waiting_hint.text = "Tap to poke them"
	_waiting_bar.mouse_filter = Control.MOUSE_FILTER_STOP if can_poke else Control.MOUSE_FILTER_IGNORE

func _show_waiting_faces(names: Array) -> void:
	var wanted := names.slice(0, 3)
	if wanted == _faces_for:
		return
	_faces_for = wanted
	for child in _waiting_faces.get_children():
		child.queue_free()
	for n in wanted:
		_waiting_faces.add_child(AvatarArt.for_player(str(n), 46))
	_waiting_faces.visible = not wanted.is_empty()

func _process(_delta: float) -> void:
	if Turns.countdown_name != "" and _waiting_bar and (_waiting_bar.visible or _urgent()):
		_refresh_waiting_bar()   # the seconds tick down

func _on_waiting_bar_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _urgent():
		Global.open_link("home")
		return
	var names := Turns.pokeable()
	if names.is_empty():
		return
	if names.size() == 1:
		Turns.poke(names[0])
		return
	var menu = load("res://Scripts/choice_menu.gd").new()
	get_tree().root.add_child(menu)
	menu.setup("Poke who? (once each per round)", names + ["Cancel"])
	var choice = await menu.chosen
	if choice != "Cancel":
		Turns.poke(choice)


## ---- BUTTONS ----
func open_settings() -> void:
	var popup = SETTINGS_POPUP.new()
	get_tree().root.add_child(popup)

func _on_home_btn_pressed() -> void:
	Sound.play("back")
	home_pressed.emit()
	if custom_navigation:
		return
	Cards.reset_id()
	get_tree().change_scene_to_file("res://Scenes/home_screen.tscn")

func _on_back_btn_pressed() -> void:
	Sound.play("back")
	back_pressed.emit()
	if custom_navigation:
		return
	Global.go_back()
