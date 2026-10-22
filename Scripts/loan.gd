extends Control
## Loan offer pop-up (Scenes/loan.tscn). Frees itself when accepted or escaped,
## so callers can `await loan.tree_exited`.

signal completed

@onready var loan_amount: SpinBox = $CanvasLayer/Container/NinePatchRect/VBoxContainer/loan_amount
@onready var disclosure_script: Label = $CanvasLayer/Container/NinePatchRect/VBoxContainer/disclosure_script
@onready var i_agree: Button = $CanvasLayer/Container/NinePatchRect/VBoxContainer/Button/i_agree
@onready var escape: Button = $CanvasLayer/Container/NinePatchRect/Panel/escape


func _ready() -> void:
	Sound.play("open")

func set_min_value(value: int) -> void:
	loan_amount.min_value = value

func _on_i_agree_pressed() -> void:
	Sound.play("continue")
	var amount := int(loan_amount.value)
	Global.take_loan(amount)
	Global.add_cash(amount)
	completed.emit()
	queue_free()

func _on_escape_pressed() -> void:
	Sound.play("back")
	queue_free()
