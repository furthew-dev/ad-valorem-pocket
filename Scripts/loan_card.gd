extends PanelContainer
## One loan in My Loans, in the shared card look (cozy.gd): what you owe in big numbers,
## the interest coming next round, and Make a Payment, which opens a small payment panel
## right on the card (– / + by $5, "Pay all", then Pay). Paying uses 1 Action.

signal payment_made

const Cozy = preload("res://Scripts/cozy.gd")
const LOAN_ICON := preload("res://Assets/icons/tokens/draft_icon.png")
const STEP := 5

var loan_id := 0
var balance := 0
var amount := 0
# (The tour and tests use these names, as the old row had them.)
var outstanding_bal: Label     # "$40"
var next_fee: Label
var make_pymt_btn: Button      # opens the payment panel
var make_payment: Control      # the payment panel
var pay: Button
var _amount_label: Label


func setup_loans(loan: Dictionary) -> void:
	loan_id = int(loan["loan_number"])
	balance = int(loan["loan_balance"])
	amount = balance
	var s := Cozy.style(Cozy.CARD, 34, Color(Cozy.EDGE, 0.45), 2, true)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	add_theme_stylebox_override("panel", s)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	top.add_child(Cozy.badge(LOAN_ICON, 64))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	top.add_child(words)
	words.add_child(Cozy.caption("Loan #%d" % loan_id))
	words.add_child(Cozy.label("You owe", Cozy.FONT, 22, Color(Cozy.CREAM, 0.75)))
	outstanding_bal = Cozy.label("$%d" % balance, Cozy.BOLD, 56)
	outstanding_bal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(outstanding_bal)

	var fee := Global.interest_due(balance)
	next_fee = Cozy.label("Next round: +$%d interest (%d%%)" % [fee, roundi(Global.interest_rate * 100)], Cozy.FONT, 21, Cozy.DOWN.lerp(Cozy.CREAM, 0.45))
	box.add_child(next_fee)
	if loan.has("for"):
		box.add_child(Cozy.label(str(loan["for"]), Cozy.FONT, 19, Color(Cozy.CREAM, 0.7)))

	var holder := VBoxContainer.new()   # the tour rings this
	box.add_child(holder)
	make_pymt_btn = Cozy.button("Make a Payment", Cozy.GREEN, 76, 28)
	make_pymt_btn.pressed.connect(func(): _set_expanded(true))
	holder.add_child(make_pymt_btn)

	make_payment = _payment_panel()
	box.add_child(make_payment)
	_set_expanded(false, false)

func _payment_panel() -> Control:
	var panel := PanelContainer.new()
	var s := Cozy.style(Cozy.INSET, 26)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", s)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var caption := Cozy.caption("How much?")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var stepper := HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper.add_theme_constant_override("separation", 18)
	box.add_child(stepper)
	stepper.add_child(_round_button("-", func(): _change(-STEP)))
	_amount_label = Cozy.label("$%d" % amount, Cozy.BOLD, 52)
	_amount_label.custom_minimum_size.x = 170
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stepper.add_child(_amount_label)
	stepper.add_child(_round_button("+", func(): _change(STEP)))
	var all := Button.new()
	all.text = "Pay it all ($%d)" % balance
	all.flat = true
	all.focus_mode = Control.FOCUS_NONE
	all.add_theme_font_override("font", Cozy.BOLD)
	all.add_theme_font_size_override("font_size", 20)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		all.add_theme_color_override(c, Cozy.EDGE)
	ColorTheme.keep_text(all)
	all.pressed.connect(func():
		Sound.play("switch")
		amount = balance
		_show_amount())
	box.add_child(all)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var cancel := Cozy.button("Cancel", Cozy.PURPLE, 76, 26)
	cancel.size_flags_stretch_ratio = 0.6
	cancel.pressed.connect(func():
		Sound.play("back")
		_set_expanded(false))
	buttons.add_child(cancel)
	var pay_holder := HBoxContainer.new()   # the tour rings this
	pay_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(pay_holder)
	pay = Cozy.button("", Cozy.GREEN, 76, 28)
	pay.pressed.connect(_on_pay_pressed)
	pay_holder.add_child(pay)
	_show_amount()
	return panel

func _round_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 72)
	b.add_theme_font_override("font", Cozy.BOLD)
	b.add_theme_font_size_override("font_size", 40)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Cozy.CREAM)
	ColorTheme.keep_text(b)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, Cozy.style(Cozy.GREEN.darkened(0.12 if state == "pressed" else 0.0), 36, Cozy.CREAM, 2))
	b.pressed.connect(action)
	return b

# Steps of $5 that land on round numbers ($23 -> $25 / $20), never below $1 or above the balance.
func _change(by: int) -> void:
	var wanted: int
	if by > 0:
		wanted = mini(balance, (amount / STEP + 1) * STEP)
	else:
		wanted = maxi(1, ((amount - 1) / STEP) * STEP)
	if wanted == amount:
		Sound.play("error")
		return
	Sound.play("switch")
	amount = wanted
	_show_amount()

func _show_amount() -> void:
	_amount_label.text = "$%d" % amount
	pay.text = "Pay $%d" % amount
	Cozy.pop(_amount_label, 1.06)

func _set_expanded(open: bool, sound: bool = true) -> void:
	if open and sound:
		Sound.play("open")
	make_payment.visible = open
	make_pymt_btn.get_parent().visible = not open

# What's new (notices.gd): interest was added -> the balance counts up from the old
# figure inside a pulsing outline; a brand-new loan -> the whole card pulses.
func show_news(before: int) -> void:
	if not is_inside_tree():
		return
	if before <= 0:
		Notices.pulse_outline(self, 34, 6.0, 5)
		return
	Notices.pulse_outline(outstanding_bal, 14, 8.0, 5)
	outstanding_bal.text = "$%d" % before
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	var tween := outstanding_bal.create_tween()
	tween.tween_method(func(v: int): outstanding_bal.text = "$%d" % v, before, balance, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(outstanding_bal, "modulate", Color("ff7a6e"), 0.35)
	tween.tween_property(outstanding_bal, "modulate", Color.WHITE, 0.5)

func _on_pay_pressed() -> void:
	if amount > Global.CASH:
		Global.error("You only have $%d." % Global.CASH)
		return
	if Global.pay_loan(loan_id, amount):
		Sound.play("continue")
		Global.action_used()
		_set_expanded(false, false)
		payment_made.emit()
