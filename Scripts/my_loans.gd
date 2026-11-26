extends Node2D
## My Loans: a card per loan (loan_card.gd) under a short summary of what you owe in all.
## Rebuilds itself after each payment. Built in code in the shared card look (cozy.gd).

const Cozy = preload("res://Scripts/cozy.gd")
const LOAN_CARD = preload("res://Scripts/loan_card.gd")

@onready var old_layout: Control = $CanvasLayer/Panel/VBoxContainer
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"

var list_of_loans: VBoxContainer
var _page: VBoxContainer
var _summary: Label
var _summary_note: Label


func _ready() -> void:
	Cards.reset_id()
	old_layout.visible = false
	_page = Cozy.page($CanvasLayer/Panel, ui_menu_frame)
	var title := Cozy.label("My Loans", Cozy.HAND, 58, Cozy.CREAM, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(title)
	_summary = Cozy.label("", Cozy.BOLD, 26, Cozy.CREAM, false)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(_summary)
	_summary_note = Cozy.label("", Cozy.FONT, 19, Color(Cozy.CREAM, 0.75), false)
	_summary_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(_summary_note)
	list_of_loans = VBoxContainer.new()
	list_of_loans.add_theme_constant_override("separation", 18)
	list_of_loans.mouse_filter = Control.MOUSE_FILTER_PASS
	_page.add_child(list_of_loans)

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
	var owed := Global.all_loans()
	var interest := 0
	for loan in Global.loans:
		interest += Global.interest_due(int(loan["loan_balance"]))
		var row = LOAN_CARD.new()
		list_of_loans.add_child(row)
		row.setup_loans(loan)
		row.payment_made.connect(refresh_loans.bind({}))
		if news.has(loan["loan_number"]):
			row.show_news.call_deferred(news[loan["loan_number"]])
	if Global.loans.is_empty():
		_summary.text = "You're debt free!"
		_summary_note.text = "No loans, no interest. Borrowing happens when you're short of cash for a purchase (you sign a Loan Agreement) or when bad luck costs more than you have."
		list_of_loans.add_child(_debt_free_card())
	else:
		_summary.text = "You owe $%d in all" % owed
		_summary_note.text = "Interest adds $%d next round. You can't win while you owe anything." % interest

func _debt_free_card() -> Control:
	var card := Cozy.card(26)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var art := Cozy.badge(preload("res://Assets/icons/bank_icon.png"), 96)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	var line := Cozy.label("Every dollar you earn is yours to keep.", Cozy.FONT, 24)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	return card
