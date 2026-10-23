extends Control
## Loan offer pop-up (Scenes/loan.tscn). Frees itself when accepted or escaped,
## so callers can `await loan.tree_exited`.

signal completed

@onready var loan_amount: SpinBox = $CanvasLayer/Container/NinePatchRect/VBoxContainer/loan_amount
@onready var disclosure_script: Label = $CanvasLayer/Container/NinePatchRect/VBoxContainer/disclosure_script
@onready var i_agree: Button = $CanvasLayer/Container/NinePatchRect/VBoxContainer/Button/i_agree
@onready var escape: Button = $CanvasLayer/Container/NinePatchRect/Panel/escape


const DISCLOSURE := """LOAN DISCLOSURE AGREEMENT (please read carefully, or at least scroll quickly while nodding).

By tapping "I Agree", you (the "Borrower") promise to repay the full loan balance of $%d to the Bank of Ad Valorem (the "Bank"), which has never once lost a game.

At the start of every round, interest equal to 10%% of your outstanding balance, rounded up to the nearest whole Rebuck, will be added to what you owe. On this loan that is $%d next round alone, and it only grows from there. Interest does not take holidays, weekends, or your feelings into account.

You may pay back part or all of your loan at any time from My Loans. Each payment, however large or small, uses one Action. The Bank thanks you for your patience, and for your Actions.

Loans cannot be forgiven, forgotten, sabotaged, auctioned, swapped, insured, blocked with Just Say No, or cried away. Your loan balance is subtracted from your net worth at the end of the game, and nobody can win the game while still owing the Bank a single Rebuck.

The Bank may spend your interest on a slightly nicer coffee mug. Side effects of borrowing may include sudden confidence, impulsive castle purchases, and regret.

If you have read this far, congratulations: you are the first person ever to do so. There is no prize. Please tap "I Agree"."""


func _ready() -> void:
	Sound.play("open")
	# Fine print in a small scrolling box: the joke is that nobody scrolls it.
	var box := ScrollContainer.new()
	box.custom_minimum_size = Vector2(330, 150)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var parent := disclosure_script.get_parent()
	parent.add_child(box)
	parent.move_child(box, disclosure_script.get_index())
	disclosure_script.reparent(box)
	disclosure_script.custom_minimum_size = Vector2(310, 0)
	disclosure_script.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	disclosure_script.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	loan_amount.value_changed.connect(func(_v): _update_disclosure())
	_update_disclosure()

func _update_disclosure() -> void:
	var amount := int(loan_amount.value)
	disclosure_script.text = DISCLOSURE % [amount, Global.interest_due(amount)]

func set_min_value(value: int) -> void:
	loan_amount.min_value = value
	_update_disclosure()

func _on_i_agree_pressed() -> void:
	Sound.play("continue")
	var amount := int(loan_amount.value)
	Global.take_loan(amount)
	Global.add_cash(amount, "Loan")
	completed.emit()
	queue_free()

func _on_escape_pressed() -> void:
	Sound.play("back")
	queue_free()
