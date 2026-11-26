extends CanvasLayer
## A forced loan (you had to pay more than you had): no form to sign, since there's no
## choice to make. Instead the loan agreement flashes up already filled in, a red
## "AUTO-ISSUED" stamp thumps onto it, and it slides away into My Loans.
##     AutoLoan.show_for(get_tree(), loan, "Gothic Mansion")
## Doesn't block anything: it plays on top while the game carries on.

const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const PAPER := Color("fbf7ec")
const INK := Color("2e2328")
const FAINT := Color("6d5f63")
const RULE := Color("c9bfa8")
const STAMP := Color("a3303a")
const SIZE := Vector2(540, 400)

var loan: Dictionary = {}
var reason := ""
var _paper: Control
var _stamp: Control

static func show_for(tree: SceneTree, the_loan: Dictionary, why: String) -> Node:
	if tree.root.has_node("Tutorial"):
		return null
	var overlay = load("res://Scripts/auto_loan.gd").new()
	overlay.loan = the_loan
	overlay.reason = why
	tree.root.add_child(overlay)
	return overlay

func _ready() -> void:
	layer = 105   # over the Fortuna card (100) and pop-ups (101)
	_build()
	_play()

func _build() -> void:
	var screen := get_viewport().get_visible_rect().size
	_paper = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = RULE
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	_paper.add_theme_stylebox_override("panel", style)
	_paper.size = SIZE
	_paper.pivot_offset = SIZE / 2.0
	_paper.position = Vector2((screen.x - SIZE.x) / 2.0, screen.y * 0.42 - SIZE.y / 2.0)
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)

	_add(_text("LOAN AGREEMENT", 22, BODY_FONT, FAINT), Vector2(0, 22), Vector2(SIZE.x, 30))
	_add(_text("Bank of Ad Valorem  ·  No. %d" % int(loan.get("loan_number", 0)), 18, BODY_FONT, FAINT), Vector2(0, 52), Vector2(SIZE.x, 26))
	_add(_line(), Vector2(30, 92), Vector2(SIZE.x - 60, 2))
	_add(_text("$%d" % int(loan.get("loan_balance", 0)), 72, FONT, INK), Vector2(0, 104), Vector2(SIZE.x, 90))
	var why := _text("You were short for %s, so the bank covered the rest." % reason if reason != "" else "You were short, so the bank covered the rest.", 21, BODY_FONT, INK)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(why, Vector2(40, 196), Vector2(SIZE.x - 80, 60))
	_add(_text("%d%% interest each round until paid. See My Loans." % roundi(Global.interest_rate * 100), 17, BODY_FONT, FAINT), Vector2(0, 262), Vector2(SIZE.x, 26))
	_add(_line(), Vector2(40, 346), Vector2(250, 2))
	var signature := _text(Global.PLAYER, 34, FONT, INK)
	signature.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_add(signature, Vector2(48, 300), Vector2(250, 46))
	_add(_text("Borrower", 15, BODY_FONT, FAINT), Vector2(40, 352), Vector2(250, 22)).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_stamp = Control.new()
	_stamp.size = Vector2(250, 120)
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.position = Vector2(SIZE.x - 280, 262)
	_stamp.rotation = -0.22
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.draw.connect(func():
		var rect := Rect2(Vector2(6, 6), _stamp.size - Vector2(12, 12))
		_stamp.draw_rect(rect, STAMP, false, 6.0)
		_stamp.draw_rect(rect.grow(-10), STAMP, false, 2.0))
	var word := _text("AUTO-ISSUED", 36, FONT, STAMP)
	word.position = Vector2(0, 22)
	word.size = Vector2(250, 56)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp.add_child(word)
	var round_label := _text("ROUND %d" % Global.ROUND, 15, BODY_FONT, STAMP)
	round_label.position = Vector2(0, 78)
	round_label.size = Vector2(250, 22)
	_stamp.add_child(round_label)
	_stamp.modulate.a = 0.0
	_paper.add_child(_stamp)
	_keep_all(self)

func _play() -> void:
	_paper.scale = Vector2(0.7, 0.7)
	_paper.modulate.a = 0.0
	_paper.rotation = 0.05
	var arrive := create_tween().set_parallel()
	arrive.tween_property(_paper, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arrive.tween_property(_paper, "modulate:a", 1.0, 0.2)
	arrive.tween_property(_paper, "rotation", 0.0, 0.3)
	Sound.play("open")
	await arrive.finished
	await get_tree().create_timer(0.35).timeout
	# The stamp comes down hard.
	_stamp.scale = Vector2(2.2, 2.2)
	var thump := create_tween().set_parallel()
	thump.tween_property(_stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	thump.tween_property(_stamp, "modulate:a", 0.9, 0.1)
	await thump.finished
	Sound.play("stamp")
	var shake := create_tween()
	for offset in [Vector2(6, 3), Vector2(-5, -2), Vector2(3, 1), Vector2.ZERO]:
		shake.tween_property(_paper, "position", _paper.position + offset, 0.04)
	await get_tree().create_timer(1.5).timeout
	# Off it goes, down towards the bottom bar (My Loans).
	var leave := create_tween().set_parallel()
	leave.tween_property(_paper, "position:y", _paper.position.y + 420, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leave.tween_property(_paper, "scale", Vector2(0.35, 0.35), 0.45)
	leave.tween_property(_paper, "modulate:a", 0.0, 0.45)
	await leave.finished
	queue_free()

func _add(control: Control, at: Vector2, size: Vector2) -> Control:
	control.position = at
	control.size = size
	_paper.add_child(control)
	return control

func _line() -> ColorRect:
	var line := ColorRect.new()
	line.color = RULE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _text(text: String, size: int, font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label

# Paper looks like paper in every theme.
func _keep_all(node: Node) -> void:
	ColorTheme.keep(node)
	for child in node.get_children():
		_keep_all(child)
