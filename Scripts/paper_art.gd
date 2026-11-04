extends Control
## The taped-paper card behind pop-ups (Settings, Game Settings, How to Play, the
## character editor, the property deck picker and the "are you sure" pop-up), drawn as a
## rounded panel in a palette colour with a strip of tape, instead of a picture. Themes
## recolour the panel like any other palette colour. It covers the same area the old
## pop_up.png did (that picture had see-through margins), so layouts stay the same.
##     var paper := PaperArt.make()          # in code: size/anchor it like the old TextureRect
## or give a Control node in a scene this script.

const PAPER := Color("99966d")
const TAPE := Color(0.89, 0.77, 0.75, 0.85)
# Where the paper and the tape sat inside the old 400 x 600 picture (fractions).
const SHEET := Rect2(34.0 / 400.0, 60.0 / 600.0, 332.0 / 400.0, 503.0 / 600.0)
const STRIP := Rect2(98.0 / 400.0, 34.0 / 600.0, 196.0 / 400.0, 54.0 / 600.0)
const CORNER := 0.07   # corner radius, as a share of the sheet's width


static func make() -> Control:
	var paper: Control = load("res://Scripts/paper_art.gd").new()
	return paper

var _sheet: Panel
var _tape: Panel

func _init() -> void:
	var sheet := Panel.new()
	_sheet = sheet
	sheet.name = "sheet"
	_place(sheet, SHEET)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_theme_stylebox_override("panel", _style(PAPER))
	add_child(sheet, false, Node.INTERNAL_MODE_FRONT)   # always behind the contents
	var tape := Panel.new()
	_tape = tape
	tape.name = "tape"
	_place(tape, STRIP)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tape_style := StyleBoxFlat.new()
	tape_style.bg_color = TAPE
	tape_style.set_corner_radius_all(3)
	tape.add_theme_stylebox_override("panel", tape_style)
	tape.rotation = -0.035
	tape.set_meta("ct_skip", true)   # tape is tape in every theme
	add_child(tape, false, Node.INTERNAL_MODE_FRONT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
		_round_corners()

func _place(node: Control, area: Rect2) -> void:
	node.anchor_left = area.position.x
	node.anchor_top = area.position.y
	node.anchor_right = area.end.x
	node.anchor_bottom = area.end.y
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.anti_aliasing = true
	style.set_corner_radius_all(30)   # until it knows its size (see _round_corners)
	return style

func _round_corners() -> void:
	# Read the override itself: a colour theme may have swapped in a recoloured copy.
	var style := _sheet.get_theme_stylebox("panel") as StyleBoxFlat
	if style and size.x > 0:
		style.set_corner_radius_all(maxi(12, int(size.x * SHEET.size.x * CORNER)))
	_tape.pivot_offset = _tape.size / 2.0
