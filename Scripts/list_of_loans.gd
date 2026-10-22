extends Control
## One loan row in My Loans (Scenes/list_of_loans.tscn), with an expandable payment panel.

signal payment_made

const INFO := "Panel/VBoxContainer2/HBoxContainer/VBoxContainer/"
const COLLAPSED_HEIGHT := 300
const EXPANDED_HEIGHT := 400

@onready var loan_number: Label = get_node(INFO + "loan_number")
@onready var next_fee: Label = get_node(INFO + "HBoxContainer2/next_fee")
@onready var interest_rate: Label = get_node(INFO + "HBoxContainer2/interest_rate")
@onready var outstanding_bal: Label = get_node(INFO + "HBoxContainer2/outstanding_bal")
@onready var make_pymt_btn: Button = get_node(INFO + "HBoxContainer/make_payment/make_pymt_btn")
@onready var make_payment: Panel = $make_payment
@onready var spin_box: SpinBox = $make_payment/VBoxContainer2/HBoxContainer/VBoxContainer/HBoxContainer/SpinBox
@onready var pay: Button = $make_payment/VBoxContainer2/HBoxContainer/VBoxContainer/HBoxContainer/make_payment/pay
@onready var close_tab: Button = $close_tab

var loan_id := 0


func _ready() -> void:
	custom_minimum_size.x = 300
	_set_expanded(false)

func setup_loans(loan_data: Dictionary) -> void:
	var balance: int = loan_data["loan_balance"]
	loan_id = loan_data["loan_number"]
	loan_number.text = "Loan#: %d" % loan_id
	outstanding_bal.text = "Loan Balance: $%d" % balance
	interest_rate.text = "APR: %d%%" % roundi(Global.interest_rate * 100)
	next_fee.text = "Upcoming Interest: $%d" % Global.interest_due(balance)
	# The scene's SpinBox had step 5, which silently snapped typed amounts to a
	# multiple of 5 (typing 23 paid 20). Any whole dollar is allowed; arrows still jump by 5.
	spin_box.step = 1
	spin_box.custom_arrow_step = 5
	spin_box.rounded = true
	spin_box.min_value = 1
	spin_box.max_value = balance   # set max first...
	spin_box.value = balance       # ...then auto-fill the full balance
	spin_box.get_line_edit().text_submitted.connect(func(_t): _on_pay_pressed())

func _set_expanded(expanded: bool) -> void:
	make_payment.visible = expanded
	close_tab.visible = expanded
	custom_minimum_size.y = EXPANDED_HEIGHT if expanded else COLLAPSED_HEIGHT

func _on_make_pymt_btn_pressed() -> void:
	Sound.play("open")
	_set_expanded(true)

func _on_close_tab_pressed() -> void:
	Sound.play("back")
	_set_expanded(false)

func _on_pay_pressed() -> void:
	spin_box.apply()   # use what is typed right now, even if the box still has focus
	var amount := int(spin_box.value)
	if amount > Global.CASH:
		Global.error("You only have $%d." % Global.CASH)
		return
	if Global.pay_loan(loan_id, amount):
		Sound.play("continue")
		Global.action_used()
		_set_expanded(false)
		payment_made.emit()
