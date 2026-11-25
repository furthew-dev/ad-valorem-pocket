extends Node2D
## My Loans: one row per loan. Rebuilds itself after each payment.

const LOAN_ROW_SCENE = preload("res://Scenes/list_of_loans.tscn")

@onready var list_of_loans: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/ScrollContainer/list_of_loans
@onready var title: Label = $CanvasLayer/Panel/VBoxContainer/Title/header/title


func _ready() -> void:
	Cards.reset_id()
	var news := {}   # loan number -> balance before (0 = a new loan)
	for loan in Global.loans:
		var before := Notices.loan_before(loan["loan_number"])
		if before != -1:
			news[loan["loan_number"]] = before
	Notices.mark_app("my_loans")
	refresh_loans(news)

func _exit_tree() -> void:
	Notices.mark_app("my_loans")

func refresh_loans(news: Dictionary = {}) -> void:
	for child in list_of_loans.get_children():
		list_of_loans.remove_child(child)
		child.queue_free()
	for loan in Global.loans:
		var row = LOAN_ROW_SCENE.instantiate()
		list_of_loans.add_child(row)
		row.setup_loans(loan)
		row.payment_made.connect(refresh_loans.bind({}))
		if news.has(loan["loan_number"]):
			row.show_news.call_deferred(news[loan["loan_number"]])
	title.text = "You have no Loans" if Global.loans.is_empty() else ""
