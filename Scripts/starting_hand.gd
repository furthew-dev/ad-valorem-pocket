extends CanvasLayer
## The start of a new game (solo or online): the starting properties arrive as sealed
## deed envelopes on top of the home screen. Tap one (or "Open all") to break its wax
## seal and flip it over; the better the condition, the bigger the burst. When they're
## all open, OK files them away: each card shrinks and drops into the My Properties app.
##     add_child(StartingHand.new())   # home_screen.gd does this once per new game
## Global.start_game() sets Global.starting_hand_pending; the cards are the hand it drew.

const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")

const SCREEN := Vector2(720, 1280)
const CARD := Vector2(272, 356)
const GAP := Vector2(26, 24)
const GRID_TOP := 330.0

const CREAM := Color("f6f2e1")
const INK := Color("2e2328")
const KRAFT := Color("d6b585")
const KRAFT_EDGE := Color("8a6f5b")
const WAX := Color("8e2b30")

# Condition: ribbon colour, ribbon text, the stamp, how many sparkles.
const LOOKS := {
	"excellent": [Color("d4af37"), "EXCELLENT", "Jackpot!", 34],
	"good": [Color("5f8f4e"), "GOOD", "Nice find!", 22],
	"fair": [Color("c2855f"), "FAIR", "Solid start", 14],
	"poor": [Color("8c8088"), "POOR", "Fixer-upper", 8],
	"special": [Color("6c5ce7"), "ONE OF A KIND", "Rare!", 26],
	"lot": [Color("7b7e63"), "EMPTY LOT", "Room to build", 12],
}

var _hand: Array = []
var _cards: Array[Control] = []
var _opened := 0
var _busy := false
var _dim: ColorRect
var _title: Label
var _hint: Label
var _open_all: Button
var _ok: Button


func _ready() -> void:
	layer = 50   # over the home screen and its bars; Fortunas and pop-ups still go on top
	if not Global.starting_hand_ready:
		await Global.starting_hand_dealt   # online, the deal can land after the intro
	_hand = Cards.properties_owned.duplicate()
	if _hand.is_empty():
		queue_free()
		return
	_build()
	_arrive()


## ---- BUILDING ----
func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.07, 0.05, 0.06, 0.82)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP   # nothing behind can be tapped
	add_child(_dim)

	_title = _label("Your Starting Portfolio", 58, FONT, CREAM)
	_title.position = Vector2(0, 190)
	_title.size = Vector2(SCREEN.x, 70)
	_dim.add_child(_title)
	_hint = _label(_hint_text(), 26, BODY_FONT, Color(CREAM, 0.85))
	_hint.position = Vector2(30, 262)
	_hint.size = Vector2(SCREEN.x - 60, 40)
	_dim.add_child(_hint)

	for i in _hand.size():
		var card := _make_card(_hand[i])
		card.position = _slot(i)
		_dim.add_child(card)
		_cards.append(card)

	_open_all = _button("Open all", _on_open_all)
	_open_all.position = Vector2((SCREEN.x - 300) / 2.0, 1110)
	_open_all.size = Vector2(300, 84)
	_dim.add_child(_open_all)
	_ok = _button("OK", _on_ok)
	_ok.position = Vector2((SCREEN.x - 420) / 2.0, 1100)
	_ok.size = Vector2(420, 100)
	_ok.add_theme_font_size_override("font_size", 52)
	_ok.visible = false
	_dim.add_child(_ok)
	_keep_all(self)

func _hint_text() -> String:
	var n := _hand.size()
	if n == 1:
		return "A deed just arrived. Tap it to open it."
	return "%d deeds just arrived. Tap one to open it." % n

# Two columns, centred; an odd last card sits in the middle.
func _slot(i: int) -> Vector2:
	var n := _hand.size()
	var cols := 1 if n == 1 else 2
	var row := i / cols
	var col := i % cols
	var in_row := mini(cols, n - row * cols)
	var row_width := in_row * CARD.x + (in_row - 1) * GAP.x
	var left := (SCREEN.x - row_width) / 2.0
	var top := GRID_TOP if n > 2 else GRID_TOP + (CARD.y + GAP.y) / 2.0
	return Vector2(left + col * (CARD.x + GAP.x), top + row * (CARD.y + GAP.y))

# One card: the sealed envelope on top of the property's face (hidden until opened).
func _make_card(property: Dictionary) -> Control:
	var card := Control.new()
	card.size = CARD
	card.pivot_offset = CARD / 2.0
	card.set_meta("property", property)
	card.add_child(_make_face(property))
	var envelope := _make_envelope()
	card.add_child(envelope)
	var tap := Button.new()   # the whole card is the button
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tap.pressed.connect(func(): _open(card))
	card.add_child(tap)
	card.set_meta("tap", tap)
	return card

func _make_envelope() -> Control:
	var envelope := Panel.new()
	envelope.name = "envelope"
	envelope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope.add_theme_stylebox_override("panel", _box(KRAFT, KRAFT_EDGE, 3, 20))
	envelope.draw.connect(func():   # the folded flap and a little twine
		var w := CARD.x
		var flap := PackedVector2Array([Vector2(6, 8), Vector2(w / 2.0, CARD.y * 0.46), Vector2(w - 6, 8)])
		envelope.draw_colored_polygon(flap, KRAFT.darkened(0.08))
		envelope.draw_polyline(flap, KRAFT_EDGE, 3, true)
		envelope.draw_line(Vector2(w / 2.0, CARD.y * 0.46), Vector2(w / 2.0, CARD.y - 10), Color(KRAFT_EDGE, 0.35), 2))
	var deed := _label("PROPERTY DEED", 20, BODY_FONT, Color(INK, 0.7))
	deed.position = Vector2(0, CARD.y - 74)
	deed.size = Vector2(CARD.x, 30)
	envelope.add_child(deed)
	var tap_me := _label("tap to open", 22, FONT, Color(INK, 0.55))
	tap_me.position = Vector2(0, CARD.y - 46)
	tap_me.size = Vector2(CARD.x, 30)
	envelope.add_child(tap_me)

	var seal := Panel.new()   # the wax seal, where the flap meets
	seal.name = "seal"
	seal.size = Vector2(84, 84)
	seal.position = Vector2(CARD.x / 2.0 - 42, CARD.y * 0.46 - 42)
	seal.pivot_offset = seal.size / 2.0
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wax := _box(WAX, WAX.darkened(0.35), 4, 42)
	wax.shadow_color = Color(0, 0, 0, 0.3)
	wax.shadow_size = 4
	wax.shadow_offset = Vector2(0, 2)
	seal.add_theme_stylebox_override("panel", wax)
	var mark := _label("AV", 34, FONT, Color("f3c9a0"))
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(mark)
	envelope.add_child(seal)
	return envelope

func _look(property: Dictionary) -> Array:
	if Cards.is_lot(property):
		return LOOKS["lot"]
	if not property.get("has_condition", false):
		return LOOKS["special"]
	return LOOKS.get(str(property.get("condition", "good")), LOOKS["good"])

func _make_face(property: Dictionary) -> Control:
	var look := _look(property)
	var colour: Color = look[0]
	var face := Panel.new()
	face.name = "face"
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", _box(CREAM, colour, 6, 20))
	face.visible = false

	var ribbon := Panel.new()   # the condition, across the top
	ribbon.position = Vector2(6, 6)
	ribbon.size = Vector2(CARD.x - 12, 44)
	var ribbon_style := StyleBoxFlat.new()
	ribbon_style.bg_color = colour
	ribbon_style.corner_radius_top_left = 15
	ribbon_style.corner_radius_top_right = 15
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	var ribbon_text := _label(look[1], 22, BODY_FONT, CREAM)
	ribbon_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ribbon_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ribbon.add_child(ribbon_text)
	face.add_child(ribbon)

	var icon := TextureRect.new()
	var art := str(property.get("art", ""))
	if art != "" and ResourceLoader.exists(art):
		icon.texture = Cards.round_icon(art)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2((CARD.x - 148) / 2.0, 62)
	icon.size = Vector2(148, 148)
	face.add_child(icon)

	var name_label := _label(str(property.get("name", "Property")), 30, FONT, INK)
	name_label.position = Vector2(10, 214)
	name_label.size = Vector2(CARD.x - 20, 70)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_child(name_label)

	var numbers := "Value $%d   ·   Rent $%d" % [int(property.get("value", 0)), int(property.get("rent", 0))]
	if Cards.is_lot(property):
		numbers = "Value $%d   ·   Build here" % int(property.get("value", 0))
	var numbers_label := _label(numbers, 21, BODY_FONT, Color(INK, 0.85))
	numbers_label.position = Vector2(6, 290)
	numbers_label.size = Vector2(CARD.x - 12, 30)
	face.add_child(numbers_label)

	var region := str(property.get("region", ""))
	if Network.expansion_on() and region != "":
		var badge := TextureRect.new()
		badge.texture = Expansion.region_icon(region)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.position = Vector2(CARD.x - 62, 58)
		badge.size = Vector2(48, 48)
		face.add_child(badge)

	var stamp := _label(look[2], 30, FONT, colour.darkened(0.15))   # pops on when opened
	stamp.name = "stamp"
	stamp.position = Vector2(0, CARD.y - 46)
	stamp.size = Vector2(CARD.x, 40)
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation = -0.08
	stamp.modulate.a = 0.0
	face.add_child(stamp)
	return face


## ---- ARRIVING ----
# The envelopes slide in from below, one after another.
func _arrive() -> void:
	_busy = true
	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.25)
	Sound.play("open")
	for i in _cards.size():
		var card := _cards[i]
		var rest := card.position
		card.position.y = SCREEN.y + 40
		card.rotation = randf_range(-0.25, 0.25)
		var slide := card.create_tween().set_parallel(true)
		slide.tween_property(card, "position:y", rest.y, 0.45).set_delay(0.1 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slide.tween_property(card, "rotation", randf_range(-0.04, 0.04), 0.45).set_delay(0.1 * i)
	await get_tree().create_timer(0.45 + 0.1 * _cards.size()).timeout
	_busy = false


## ---- OPENING ----
func _open(card: Control) -> void:
	if _busy and not card.has_meta("opening_all"):
		return
	if card.get_meta("opened", false):
		return
	card.set_meta("opened", true)
	var envelope: Control = card.get_node("envelope")
	var face: Control = card.get_node("face")
	var seal: Control = envelope.get_node("seal")
	Sound.play("switch")
	# 1. A little shake, like there's something inside.
	var shake := card.create_tween()
	for angle in [-0.07, 0.07, -0.05, 0.04, 0.0]:
		shake.tween_property(card, "rotation", angle, 0.05)
	await shake.finished
	# 2. The seal pops off.
	var pop := seal.create_tween().set_parallel(true)
	pop.tween_property(seal, "scale", Vector2(1.6, 1.6), 0.14)
	pop.tween_property(seal, "modulate:a", 0.0, 0.14)
	await pop.finished
	# 3. Flip it over.
	var close := card.create_tween()
	close.tween_property(card, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
	await close.finished
	envelope.visible = false
	face.visible = true
	Sound.play("double")
	var look := _look(card.get_meta("property"))
	if look == LOOKS["excellent"]:
		Sound.play("cash_in")
	var open := card.create_tween()
	open.tween_property(card, "scale", Vector2(1.08, 1.08), 0.14).set_ease(Tween.EASE_OUT)
	open.tween_property(card, "scale", Vector2.ONE, 0.12)
	_burst(card, look[0], look[3])
	if look == LOOKS["excellent"] or look == LOOKS["special"]:
		_glow(card, look[0])
	# 4. The stamp thumps on.
	var stamp: Control = face.get_node("stamp")
	stamp.scale = Vector2(2.2, 2.2)
	var thump := stamp.create_tween().set_parallel(true)
	thump.tween_property(stamp, "scale", Vector2.ONE, 0.22).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	thump.tween_property(stamp, "modulate:a", 1.0, 0.1).set_delay(0.12)
	await open.finished
	_opened += 1
	if _opened == _cards.size():
		_all_open()

func _on_open_all() -> void:
	if _busy:
		return
	_busy = true
	_open_all.disabled = true
	Sound.play("click")
	for card in _cards:
		if not card.get_meta("opened", false):
			card.set_meta("opening_all", true)
			_open(card)
			await get_tree().create_timer(0.28).timeout
	_busy = false

func _all_open() -> void:
	_hint.text = "Welcome to the market! They'll earn rent every round."
	var hide := _open_all.create_tween()
	hide.tween_property(_open_all, "modulate:a", 0.0, 0.15)
	hide.tween_callback(func(): _open_all.visible = false)
	await get_tree().create_timer(0.35).timeout
	_ok.visible = true
	_ok.pivot_offset = _ok.size / 2.0
	_ok.scale = Vector2(0.6, 0.6)
	_ok.modulate.a = 0.0
	var show := _ok.create_tween().set_parallel(true)
	show.tween_property(_ok, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_property(_ok, "modulate:a", 1.0, 0.2)


## ---- FILING THEM AWAY ----
# Each card shrinks and drops along an arc into the My Properties app, which bounces
# as it catches it.
func _on_ok() -> void:
	if _busy:
		return
	_busy = true
	_ok.disabled = true
	Sound.play("continue")
	var tile := _my_properties_tile()
	var target := tile.get_global_rect().get_center() if tile else Vector2(SCREEN.x / 2.0, SCREEN.y - 90)
	var fade := create_tween().set_parallel(true)
	for node in [_title, _hint, _ok]:
		fade.tween_property(node, "modulate:a", 0.0, 0.2)
	fade.tween_property(_dim, "color:a", 0.25, 0.5)
	for i in _cards.size():
		_drop(_cards[i], target, tile, 0.16 * i)
	await get_tree().create_timer(0.16 * _cards.size() + 0.75).timeout
	var gone := create_tween()
	gone.tween_property(_dim, "modulate:a", 0.0, 0.2)
	await gone.finished
	var n := _hand.size()
	Global.banner("%d %s filed in My Properties." % [n, "property" if n == 1 else "properties"])
	queue_free()

func _drop(card: Control, target: Vector2, tile: Control, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	var start := card.position + card.pivot_offset   # the card's middle
	var end := target
	var lift := Vector2((start.x + end.x) / 2.0, minf(start.y, end.y) - 160)   # the top of the arc
	var spin := randf_range(-0.9, 0.9)
	var fly := card.create_tween().set_parallel(true)
	fly.tween_method(_along_arc.bind(card, start, lift, end), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fly.tween_property(card, "scale", Vector2(0.12, 0.12), 0.6).set_ease(Tween.EASE_IN)
	fly.tween_property(card, "rotation", spin, 0.6)
	fly.tween_property(card, "modulate:a", 0.0, 0.12).set_delay(0.5)
	await fly.finished
	Sound.play("switch")
	if is_instance_valid(tile):
		_bounce(tile)

# A curve from start, up towards lift, and down into end (t = 0..1).
func _along_arc(t: float, card: Control, start: Vector2, lift: Vector2, end: Vector2) -> void:
	var p := start.lerp(lift, t).lerp(lift.lerp(end, t), t)
	card.position = p - card.pivot_offset

func _bounce(tile: Control) -> void:
	tile.pivot_offset = tile.size / 2.0
	var bounce := tile.create_tween()
	bounce.tween_property(tile, "scale", Vector2(1.18, 1.18), 0.08).set_ease(Tween.EASE_OUT)
	bounce.tween_property(tile, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# The coloured square of the My Properties app on the home screen (if it's showing).
func _my_properties_tile() -> Control:
	var home := get_parent()
	if home and home.has_method("_tile_named"):
		var tile: Control = home._tile_named("my_properties")
		if tile and tile.is_visible_in_tree():
			return home._tile_panel(tile)
	return null


## ---- SPARKLE ----
# Confetti-ish bits fly out from behind the card and fade.
func _burst(card: Control, colour: Color, count: int) -> void:
	var centre := card.position + card.pivot_offset
	var palette := [colour, colour.lightened(0.35), CREAM, Color("ffe08a")]
	for i in count:
		var bit := Panel.new()
		var s := randf_range(8, 16)
		bit.size = Vector2(s, s)
		bit.pivot_offset = bit.size / 2.0
		bit.position = centre - bit.pivot_offset
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = palette[i % palette.size()]
		style.set_corner_radius_all(int(s / 2.0) if i % 2 == 0 else 2)   # dots and little squares
		bit.add_theme_stylebox_override("panel", style)
		bit.set_meta("ct_skip", true)
		_dim.add_child(bit)
		_dim.move_child(bit, card.get_index())   # behind the card
		var angle := randf() * TAU
		var dist := randf_range(130, 230) * (1.2 if count > 25 else 1.0)
		var fly := bit.create_tween().set_parallel(true)
		fly.tween_property(bit, "position", bit.position + Vector2.from_angle(angle) * dist, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.tween_property(bit, "rotation", randf_range(-4.0, 4.0), 0.6)
		fly.tween_property(bit, "modulate:a", 0.0, 0.3).set_delay(0.35)
		fly.chain().tween_callback(bit.queue_free)

# Excellent and one-of-a-kind cards keep a soft pulsing glow.
func _glow(card: Control, colour: Color) -> void:
	var glow := Panel.new()
	var style := _box(Color(0, 0, 0, 0), colour.lightened(0.2), 6, 24)
	style.expand_margin_left = 8
	style.expand_margin_right = 8
	style.expand_margin_top = 8
	style.expand_margin_bottom = 8
	style.shadow_color = Color(colour, 0.6)
	style.shadow_size = 18
	glow.add_theme_stylebox_override("panel", style)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	glow.set_meta("ct_skip", true)
	card.add_child(glow)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.45, 0.6)
	pulse.tween_property(glow, "modulate:a", 1.0, 0.6)


## ---- HELPERS ----
func _box(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style

func _label(text: String, size: int, font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 40)
	var style := _box(Color("2e2328"), Color("ddcf99"), 3, 40)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, CREAM)
	button.pressed.connect(action)
	return button

# These cards look the same in every colour theme (like the listing posters).
func _keep_all(node: Node) -> void:
	ColorTheme.keep(node)
	for child in node.get_children():
		_keep_all(child)
