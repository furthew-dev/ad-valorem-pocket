extends Node2D
## My Loans: one row per loan. Rebuilds itself after each payment.

const LOAN_ROW_SCENE = preload("res://Scenes/list_of_loans.tscn")

@onready var list_of_loans: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/ScrollContainer/list_of_loans
@onready var title: Label = $CanvasLayer/Panel/VBoxContainer/Title/header/title


func _ready() -> void:
	Cards.reset_id()
	refresh_loans()

func refresh_loans() -> void:
	for child in list_of_loans.get_children():
		list_of_loans.remove_child(child)
		child.queue_free()
	for loan in Global.loans:
		var row = LOAN_ROW_SCENE.instantiate()
		list_of_loans.add_child(row)
		row.setup_loans(loan)
		row.payment_made.connect(refresh_loans)
	title.text = "You have no Loans" if Global.loans.is_empty() else ""
