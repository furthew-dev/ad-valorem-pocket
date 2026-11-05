extends Control
## The card behind pop-ups (Settings, Game Settings, How to Play, the character editor,
## the property deck picker and the "are you sure" pop-up): a rounded panel in a palette
## colour with an outline and a soft shadow, like the game's other framed menus. Themes
## recolour it like any other palette colour.
## It always fits between the top bar and the bottom menu bar: if a pop-up is taller than
## the room, the whole card (contents and all) is scaled down a little and centred there.
##     var paper := PaperArt.make()          # in code: size/anchor it as before
## or give a Control node in a scene this script.
## The card covers the same area the old pop_up.png did (that picture had see-through
## margins), so the pop-ups' layouts stay the same.

const FILL := Color("99966d")       # the card (a palette colour: themes recolour it)
const OUTLINE := Color("f6f2e1")    # cream outline, as on the game's other framed buttons
const OUTLINE_WIDTH := 4
const SHEET := Rect2(34.0 / 400.0, 60.0 / 600.0, 332.0 / 400.0, 503.0 / 600.0)
const CORNER := 0.07                # corner radius, as a share of the card's width
# The room between the top bar and the bottom menu bar (game units; bottom from the
# screen's bottom edge), with a small gap to each.
const ROOM_TOP := 168.0
const ROOM_BOTTOM := 180.0

## false: the owner positions and scales it itself (How to Play animates it); use fit().
var auto_fit := true

var _sheet: Panel
var _fitting := false


static func make() -> Control:
	var paper: Control = load("res://Scripts/paper_art.gd").new()
	return paper

# For a card whose full area (see-through margins included) is `area` tall when scaled 1:
# {"scale": what fits it between the bars, "centre_y": where its middle should go}.
static func fit(area_height: float, screen_height: float) -> Dictionary:
	var card := area_height * SHEET.size.y
	var room := screen_height - ROOM_TOP - ROOM_BOTTOM
	var card_middle := area_height * (SHEET.position.y + SHEET.size.y / 2.0)   # from the top of the area
	var scale := minf(1.0, room / card)
	return {"scale": scale, "centre_y": ROOM_TOP + room / 2.0 - (card_middle - area_height / 2.0) * scale}

func _init() -> void:
	_sheet = Panel.new()
	_sheet.name = "sheet"
	_sheet.anchor_left = SHEET.position.x
	_sheet.anchor_top = SHEET.position.y
	_sheet.anchor_right = SHEET.end.x
	_sheet.anchor_bottom = SHEET.end.y
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = OUTLINE
	style.set_border_width_all(OUTLINE_WIDTH)
	style.set_corner_radius_all(30)   # until it knows its size (see _round_corners)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	style.anti_aliasing = true
	_sheet.add_theme_stylebox_override("panel", style)
	add_child(_sheet, false, Node.INTERNAL_MODE_FRONT)   # always behind the contents

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
		_round_corners()
		if auto_fit and is_inside_tree():
			_fit_between_bars.call_deferred()

func _round_corners() -> void:
	# Read the override itself: a colour theme may have swapped in a recoloured copy.
	var style := _sheet.get_theme_stylebox("panel") as StyleBoxFlat
	if style and size.x > 0:
		style.set_corner_radius_all(maxi(12, int(size.x * SHEET.size.x * CORNER)))

# Shrink (never grow) and centre the card in the room between the bars.
func _fit_between_bars() -> void:
	if _fitting or not is_inside_tree() or size.y <= 0:
		return
	_fitting = true
	var screen := get_viewport_rect().size
	var wanted := fit(size.y, screen.y)
	pivot_offset = size / 2.0
	scale = Vector2.ONE * wanted["scale"]
	var middle := (get_global_transform() * pivot_offset).y   # the card's middle stays put when scaled
	if wanted["scale"] < 1.0 or _sheet_rect().position.y < ROOM_TOP or _sheet_rect().end.y > screen.y - ROOM_BOTTOM:
		position.y += wanted["centre_y"] - middle
	_fitting = false

func _sheet_rect() -> Rect2:
	return _sheet.get_global_rect()
