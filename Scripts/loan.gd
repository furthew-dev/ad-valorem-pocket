extends Control
## The loan agreement (Scenes/loan.tscn), opened when a purchase or a build costs more
## cash than the player has. A paper contract from the Bank of Ad Valorem: the amount at
## the top (adjust with - / +), the terms in a scrolling box, and Sign or Cancel. Signing
## writes the player's name on the line and a notary stamp thumps down before the money
## arrives. Frees itself either way, so callers can `await loan.tree_exited`.
##     var loan = LOAN_SCENE.instantiate(); add_child(loan)
##     loan.set_min_value(45); loan.set_reason("You're $12 short of the $45 price.")

signal completed

const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const STEP := 5
const MAX_LOAN := 200

const PAPER := Color("fbf7ec")
const INK := Color("2e2328")
const FAINT := Color("6d5f63")
const RULE := Color("c9bfa8")
const BOX := Color("f1e9d4")
const STAMP := Color("a3303a")
const PAPER_RECT := Rect2(36, 120, 648, 1050)
const STAMP_SCALE := 1.05

var _amount := 0
var _min := STEP
var _reason := ""
var _layer: CanvasLayer
var _paper: Panel
var _amount_label: Label
var _min_label: Label
var _first_interest: Label
var _terms: Label
var _signature: Label
var _stamp: Control
var _sign: Button
var _cancel: Button
var _minus: Button
var _plus: Button
var _signed := false


func _ready() -> void:
	for child in get_children():   # the old form in the scene file is replaced by this one
		child.queue_free()
	_amount = _min
	_build()
	_update()
	_arrive()

func set_min_value(value: int) -> void:
	_min = maxi(1, value)
	_amount = _min
	if is_node_ready():
		_update()

# A line under the title saying why the loan is needed.
func set_reason(text: String) -> void:
	_reason = text
	if is_node_ready() and _paper:
		var label: Label = _paper.find_child("reason", true, false)
		label.text = text
		label.visible = text != ""


## ---- BUILDING ----
func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	var dim := ColorRect.new()
	dim.name = "dim"
	dim.color = Color(0.05, 0.03, 0.04, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	_paper = Panel.new()
	_paper.position = PAPER_RECT.position
	_paper.size = PAPER_RECT.size
	_paper.pivot_offset = PAPER_RECT.size / 2.0
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = PAPER
	sheet.border_color = INK
	sheet.set_border_width_all(3)
	sheet.set_corner_radius_all(6)
	sheet.shadow_color = Color(0, 0, 0, 0.4)
	sheet.shadow_size = 14
	sheet.shadow_offset = Vector2(0, 8)
	_paper.add_theme_stylebox_override("panel", sheet)
	_paper.draw.connect(func():   # a thin second border, like printed stationery
		_paper.draw_rect(Rect2(Vector2(12, 12), PAPER_RECT.size - Vector2(24, 24)), Color(INK, 0.35), false, 1.5))
	dim.add_child(_paper)

	var column := VBoxContainer.new()
	column.position = Vector2(36, 30)
	column.size = Vector2(PAPER_RECT.size.x - 72, PAPER_RECT.size.y - 60)
	column.add_theme_constant_override("separation", 10)
	_paper.add_child(column)

	column.add_child(_text("BANK OF AD VALOREM", 20, BODY_FONT, FAINT))
	column.add_child(_text("Loan Agreement", 60, FONT, INK))
	var reason := _text(_reason, 22, BODY_FONT, STAMP)
	reason.name = "reason"
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.visible = _reason != ""
	column.add_child(reason)
	column.add_child(_rule())

	var parties := HBoxContainer.new()
	var borrower := _text("Borrower: %s" % _borrower(), 22, BODY_FONT, INK)
	borrower.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	borrower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parties.add_child(borrower)
	var dated := _text("Round %d" % Global.ROUND, 22, BODY_FONT, INK)
	dated.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parties.add_child(dated)
	column.add_child(parties)

	# The amount, big, with - and + either side.
	var amount_box := PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = BOX
	box_style.border_color = RULE
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(6)
	box_style.content_margin_top = 8
	box_style.content_margin_bottom = 10
	amount_box.add_theme_stylebox_override("panel", box_style)
	var amount_column := VBoxContainer.new()
	amount_column.add_theme_constant_override("separation", 0)
	amount_box.add_child(amount_column)
	amount_column.add_child(_text("LOAN AMOUNT", 20, BODY_FONT, FAINT))
	var amount_row := HBoxContainer.new()
	amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_row.add_theme_constant_override("separation", 26)
	_minus = _round_button("-", func(): _change(-STEP))
	_plus = _round_button("+", func(): _change(STEP))
	_amount_label = _text("$0", 84, FONT, INK)
	_amount_label.custom_minimum_size.x = 220
	_amount_label.pivot_offset = Vector2(110, 50)
	amount_row.add_child(_minus)
	amount_row.add_child(_amount_label)
	amount_row.add_child(_plus)
	amount_column.add_child(amount_row)
	_min_label = _text("", 20, BODY_FONT, FAINT)
	amount_column.add_child(_min_label)
	column.add_child(amount_box)

	var facts := HBoxContainer.new()
	var rate := _text("Interest: %d%% per round" % roundi(Global.interest_rate * 100), 22, BODY_FONT, INK)
	rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_child(rate)
	_first_interest = _text("", 22, BODY_FONT, INK)
	_first_interest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	facts.add_child(_first_interest)
	column.add_child(facts)

	# The terms: a bordered box that scrolls.
	var terms_title := _text("Terms and Conditions", 24, BODY_FONT, INK)
	terms_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(terms_title)
	var terms_frame := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color.WHITE.lerp(PAPER, 0.4)
	frame.border_color = RULE
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(4)
	frame.content_margin_left = 16
	frame.content_margin_right = 10
	frame.content_margin_top = 12
	frame.content_margin_bottom = 12
	terms_frame.add_theme_stylebox_override("panel", frame)
	terms_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 250
	terms_frame.add_child(scroll)
	_terms = _text("", 21, BODY_FONT, INK)
	_terms.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terms.custom_minimum_size.x = PAPER_RECT.size.x - 72 - 50
	_terms.add_theme_constant_override("line_spacing", 6)
	scroll.add_child(_terms)
	column.add_child(terms_frame)

	# The signature line.
	var sign_row := HBoxContainer.new()
	sign_row.add_theme_constant_override("separation", 14)
	var sign_caption := _text("Borrower\nsignature", 20, BODY_FONT, FAINT)
	sign_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sign_row.add_child(sign_caption)
	var line := Control.new()
	line.custom_minimum_size = Vector2(0, 76)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.draw.connect(func(): line.draw_line(Vector2(0, line.size.y - 8), Vector2(line.size.x, line.size.y - 8), INK, 2))
	_signature = _text(_borrower(), 54, FONT, Color("1f3a6b"))   # blue ink
	_signature.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_signature.offset_bottom = -6
	_signature.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_signature.rotation = -0.03
	_signature.visible_ratio = 0.0
	line.add_child(_signature)
	sign_row.add_child(line)
	column.add_child(sign_row)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	_cancel = _button("Cancel", false, _on_cancel)
	_sign = _button("Sign", true, _on_sign)
	buttons.add_child(_cancel)
	buttons.add_child(_sign)
	column.add_child(buttons)

	_stamp = _make_stamp()
	_paper.add_child(_stamp)
	for node in _layer.find_children("*", "", true, false):
		ColorTheme.keep(node)   # paper looks like paper in every theme

func _borrower() -> String:
	var who := str(Global.PLAYER).strip_edges()
	return who if who != "" else "Borrower"

func _rule() -> Control:
	var rule := Control.new()
	rule.custom_minimum_size.y = 8
	rule.draw.connect(func(): rule.draw_line(Vector2(0, 4), Vector2(rule.size.x, 4), Color(INK, 0.5), 2))
	return rule

func _text(text: String, size: int, font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label

func _button(text: String, primary: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 92)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 46)
	var style := StyleBoxFlat.new()
	style.bg_color = INK if primary else PAPER
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = style.bg_color.darkened(0.15) if primary else BOX
	for state in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("pressed", pressed)
	var colour := PAPER if primary else INK
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, colour)
	button.pressed.connect(action)
	return button

func _round_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(76, 76)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 44)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(38)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", Color(INK, 0.25))
	button.pressed.connect(action)
	return button

# The notary stamp: a red double ring with the bank's name, hidden until signed.
func _make_stamp() -> Control:
	var stamp := Control.new()
	stamp.size = Vector2(250, 250)
	stamp.pivot_offset = stamp.size / 2.0
	stamp.position = Vector2(PAPER_RECT.size.x - 330, PAPER_RECT.size.y - 400)   # over the signature
	stamp.rotation = -0.3
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.visible = false
	stamp.draw.connect(func():   # two rings, with rules above and below APPROVED
		var c := stamp.size / 2.0
		stamp.draw_arc(c, 120, 0, TAU, 72, STAMP, 7, true)
		stamp.draw_arc(c, 106, 0, TAU, 72, STAMP, 3, true)
		stamp.draw_line(Vector2(30, 92), Vector2(220, 92), STAMP, 3)
		stamp.draw_line(Vector2(30, 164), Vector2(220, 164), STAMP, 3)
		for x in [26.0, 224.0]:
			stamp.draw_circle(Vector2(x, 126), 5, STAMP))
	var top := _text("BANK OF\nAD VALOREM", 17, BODY_FONT, STAMP)
	top.position = Vector2(0, 38)
	top.size = Vector2(250, 50)
	stamp.add_child(top)
	var middle := _text("APPROVED", 40, FONT, STAMP)
	middle.position = Vector2(0, 82)   # (the handwriting sits low in its line)
	middle.size = Vector2(250, 64)
	middle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_child(middle)
	var notary := _text("NOTARIZED\nROUND %d" % Global.ROUND, 16, BODY_FONT, STAMP)
	notary.position = Vector2(0, 168)
	notary.size = Vector2(250, 44)
	stamp.add_child(notary)
	stamp.modulate.a = 0.88   # ink, not paint
	return stamp


## ---- THE NUMBERS ----
func _change(by: int) -> void:
	if _signed:
		return
	var wanted := clampi(_amount + by, _min, maxi(MAX_LOAN, _min))
	if wanted == _amount:
		Sound.play("error")
		return
	_amount = wanted
	Sound.play("switch")
	_amount_label.scale = Vector2(1.12, 1.12)
	_amount_label.create_tween().tween_property(_amount_label, "scale", Vector2.ONE, 0.15)
	_update()

func _update() -> void:
	if _amount_label == null:
		return
	_amount_label.text = "$%d" % _amount
	_min_label.text = "Minimum $%d  ·  adjust in steps of $%d" % [_min, STEP]
	_minus.disabled = _amount <= _min
	_plus.disabled = _amount >= maxi(MAX_LOAN, _min)
	var first := Global.interest_due(_amount)
	_first_interest.text = "Next round: +$%d" % first
	_terms.text = TERMS % [_borrower(), _amount, roundi(Global.interest_rate * 100), first]

const TERMS := """1. PARTIES. This Loan Agreement is made between the Bank of Ad Valorem (the "Lender") and %s (the "Borrower").

2. PRINCIPAL. The Lender agrees to lend the Borrower $%d (the "Principal"), paid into the Borrower's account as soon as this Agreement is signed.

3. INTEREST. At the start of every round, interest of %d%% of the outstanding balance, rounded up to the nearest whole dollar, is added to the balance. On this loan that is $%d at the start of the next round, and more if the balance grows.

4. REPAYMENT. The Borrower may repay part or all of the balance at any time from the My Loans app. Each payment, of any size, uses one Action.

5. NO RELIEF. This loan cannot be forgiven, sabotaged, auctioned, swapped, insured, or blocked with Just Say No.

6. END OF GAME. Any balance still owed is subtracted from the Borrower's net worth when the game ends. A Borrower who owes the Lender anything cannot win the game.

7. ENTIRE AGREEMENT. This document is the whole agreement between the parties. The Lender has never lost a game and does not intend to start now.

By signing below, the Borrower accepts these terms."""


## ---- ARRIVING, SIGNING, CANCELLING ----
func _arrive() -> void:
	Sound.play("open")
	_paper.position.y += 60
	_paper.modulate.a = 0.0
	var slide := _paper.create_tween().set_parallel(true)
	slide.tween_property(_paper, "position:y", PAPER_RECT.position.y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_property(_paper, "modulate:a", 1.0, 0.2)

func _on_sign() -> void:
	if _signed:
		return
	_signed = true
	_sign.disabled = true
	_cancel.disabled = true
	_minus.disabled = true
	_plus.disabled = true
	Sound.play("scribble")
	# The pen writes the name across the line (as long as the scribble lasts)...
	var pen := _signature.create_tween()
	pen.tween_property(_signature, "visible_ratio", 1.0, 1.1)
	await pen.finished
	await get_tree().create_timer(0.2).timeout
	# ...then the notary stamp comes down hard.
	_stamp.visible = true
	_stamp.scale = Vector2(2.6, 2.6)
	_stamp.modulate.a = 0.0
	var drop := _stamp.create_tween().set_parallel(true)
	drop.tween_property(_stamp, "scale", Vector2.ONE * STAMP_SCALE, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	drop.tween_property(_stamp, "modulate:a", 0.88, 0.12)
	await drop.finished
	Sound.play("stamp")
	_thud()
	_ink_specks()
	await get_tree().create_timer(1.1).timeout
	Global.take_loan(_amount)
	Global.add_cash(_amount, "Loan")
	completed.emit()
	await _leave()

func _on_cancel() -> void:
	if _signed:
		return
	Sound.play("back")
	await _leave()

func _leave() -> void:
	var out := _paper.create_tween().set_parallel(true)
	out.tween_property(_paper, "position:y", PAPER_RECT.position.y + 80, 0.2).set_ease(Tween.EASE_IN)
	out.tween_property(_layer.get_node("dim"), "modulate:a", 0.0, 0.2)
	await out.finished
	queue_free()

# The paper jolts under the stamp.
func _thud() -> void:
	var shake := _paper.create_tween()
	for offset in [Vector2(0, 7), Vector2(-4, -3), Vector2(3, 2), Vector2.ZERO]:
		shake.tween_property(_paper, "position", PAPER_RECT.position + offset, 0.04)

# A few spatters of ink around the stamp.
func _ink_specks() -> void:
	var centre := _stamp.position + _stamp.size / 2.0
	for i in 9:
		var speck := Panel.new()
		var s := randf_range(4, 9)
		speck.size = Vector2(s, s)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(STAMP, 0.75)
		style.set_corner_radius_all(int(s))
		speck.add_theme_stylebox_override("panel", style)
		speck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speck.position = centre + Vector2.from_angle(randf() * TAU) * randf_range(122, 140)
		ColorTheme.keep(speck)
		_paper.add_child(speck)
