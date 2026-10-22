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

var _banner_queue: Array[String] = []
var _active_banners: Array[Control] = []
var _active_money: Array[Control] = []
var _banner_rest: Vector2       # anim_frame's on-screen / off-screen spots (from banner_drop)
var _banner_hidden: Vector2
var _money_origin: Vector2
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
	_on_waiting_changed(Turns.waiting_on)
	refresh_labels()
	_setup_banner_templates()


## ---- LABELS ----
func refresh_labels() -> void:
	checking_bal.text = "$%d" % Global.CASH
	player_name.text = str(Global.PLAYER)
	actions_left.text = "%d Actions left" % Global.ACTIONS
	round_number.text = "Round %d" % Global.ROUND
	misc.text = "Expected Rent: $%d" % Global.expected_rent()

func _on_cash_changed(new_value: int) -> void:
	checking_bal.text = "$%d" % new_value

func _on_actions_changed(new_value: int) -> void:
	actions_left.text = "%d Actions left" % new_value

func _on_round_changed(new_value: int) -> void:
	round_number.text = "Round %d" % new_value
	misc.text = "Expected Rent: $%d" % Global.expected_rent()

func clear_ui() -> void:
	player_name.text = ""
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

# Message banner: slides in from the right, holds, slides back out (2.5 s).
func run_animation(message: String) -> void:
	if _active_banners.size() >= MAX_STACK:
		_banner_queue.append(message)
		return
	var banner: Control = anim_frame.duplicate()
	banner.get_node("text").text = message
	banner.visible = true
	var y := _banner_rest.y + _active_banners.size() * BANNER_SPACING
	banner.position = Vector2(_banner_hidden.x, y)
	anim_frame.get_parent().add_child(banner)
	_active_banners.append(banner)

	var tween := banner.create_tween()
	tween.tween_property(banner, "position:x", _banner_rest.x, 0.42)
	tween.tween_interval(1.6)
	tween.tween_property(banner, "position:x", _banner_hidden.x, 0.48)
	tween.finished.connect(_remove_from_stack.bind(banner, _active_banners, _banner_rest.y, BANNER_SPACING))

# Money notice: a 75x75 circle at the top-left. Fades in, holds, fades out (2 s).
# Red for money out, green for money in. Built fresh each time so its size can't drift.
func run_income_loss(type: String, total: int) -> void:
	var is_loss := type == "loss"
	var notice := Panel.new()
	notice.custom_minimum_size = MONEY_SIZE
	notice.size = MONEY_SIZE
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.z_index = 5
	var style := StyleBoxFlat.new()
	style.bg_color = LOSS_COLOR if is_loss else GAIN_COLOR
	style.set_corner_radius_all(35)
	notice.add_theme_stylebox_override("panel", style)

	var label: Label = amount.duplicate()   # same theme and font as the scene's label
	label.text = ("-$%d" if is_loss else "+$%d") % total
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.clip_text = true
	if label.text.length() > 5:
		label.add_theme_font_size_override("font_size", 18)   # e.g. "+$1000" still fits
	notice.add_child(label)

	notice.modulate.a = 0.0
	notice.position = _money_origin + Vector2(0, _active_money.size() * MONEY_SPACING)
	add_child(notice)
	_active_money.append(notice)

	var tween := notice.create_tween()
	tween.tween_property(notice, "modulate:a", 1.0, 0.36)
	tween.tween_interval(1.3)
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
		run_animation(_banner_queue.pop_front())


## ---- WAITING BAR (after End Turn) ----
# A permanent strip under the header: "Waiting on: Sam, Jo".
func _build_waiting_bar() -> void:
	_waiting_bar = PanelContainer.new()
	_waiting_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_waiting_bar.offset_left = 30
	_waiting_bar.offset_right = -30
	_waiting_bar.offset_top = 165
	_waiting_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = WAITING_BG
	style.set_corner_radius_all(24)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_waiting_bar.add_theme_stylebox_override("panel", style)
	_waiting_label = Label.new()
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_waiting_label.add_theme_font_size_override("font_size", 26)
	_waiting_bar.add_child(_waiting_label)
	_waiting_bar.visible = false
	add_child(_waiting_bar)

func _on_waiting_changed(names: Array) -> void:
	_waiting_bar.visible = Turns.my_turn_done and not names.is_empty()
	_waiting_label.text = "Turn ended. Waiting on: " + ", ".join(PackedStringArray(names))


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
