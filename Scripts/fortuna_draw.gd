extends CanvasLayer
## The new-round Fortuna draw, with a little mystery: a deck of face-down Fortuna cards
## fans out on a dark curtain and shuffles while the card is drawn. Then one card rises,
## trembles, and flips over to show the drawn card's picture with a flash, and the normal
## Fortuna card screen (fortuna.tscn, layer 100) takes over on top.
##     var draw = FortunaDraw.start(get_tree())    # right away, before the card is drawn
##     var card = await draw_fortuna()               # (the deck shuffles meanwhile)
##     await draw.reveal(card)                       # or draw.cancel() if nothing was drawn
## Like the sabotage curtain (Fortunas._play_sabotage_curtain), it sits under the card.

const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")

const SCREEN := Vector2(720, 1280)
const CARD := Vector2(200, 290)
const BIG := 1.75               # the chosen card's size, raised and turned over
const DECK := 5
const CENTRE := Vector2(360, 690)
const CURTAIN := Color("1d1426")
const BACK := Color("3a1f4d")
const GOLD := Color("d4af37")
const CREAM := Color("f6f2e1")
const MIN_SHUFFLE := 1.1        # seconds of shuffling, however fast the card is drawn

var _curtain: ColorRect
var _title: Label
var _cards: Array[Control] = []
var _shuffled := false
var _started := 0


static func start(tree: SceneTree) -> Node:
	var draw = load("res://Scripts/fortuna_draw.gd").new()
	draw.name = "FortunaDraw"
	tree.root.add_child(draw)
	return draw

func _ready() -> void:
	layer = 95   # under the Fortuna card (100), like the sabotage curtain
	_started = Time.get_ticks_msec()
	_build()
	_play_shuffle()


## ---- BUILDING ----
func _build() -> void:
	_curtain = ColorRect.new()
	_curtain.color = CURTAIN
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_curtain.modulate.a = 0.0
	add_child(_curtain)
	_curtain.draw.connect(_draw_glow)

	_title = Label.new()
	_title.text = "Fortuna"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 250)
	_title.size = Vector2(SCREEN.x, 90)
	_title.add_theme_font_override("font", FONT)
	_title.add_theme_font_size_override("font_size", 84)
	_title.add_theme_color_override("font_color", GOLD)
	_title.pivot_offset = _title.size / 2.0
	_curtain.add_child(_title)
	var sub := Label.new()
	sub.text = "Fate deals you a card..."
	sub.name = "sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 345)
	sub.size = Vector2(SCREEN.x, 40)
	sub.add_theme_font_override("font", BODY_FONT)
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(CREAM, 0.8))
	_curtain.add_child(sub)

	for i in DECK:
		var card := _card_back()
		card.position = CENTRE - CARD / 2.0 + Vector2(0, 400)   # below the screen, then dealt up
		card.modulate.a = 0.0
		_curtain.add_child(card)
		_cards.append(card)
	for node in find_children("*", "", true, false):
		ColorTheme.keep(node)   # the same in every theme, like the Fortuna card itself
	ColorTheme.keep(_curtain)

# A soft light behind the middle of the table.
func _draw_glow() -> void:
	for i in 6:
		var r := 340.0 - i * 50.0
		_curtain.draw_circle(CENTRE, r, Color(0.45, 0.25, 0.6, 0.05))

func _card_back() -> Control:
	var card := Panel.new()
	card.size = CARD
	card.pivot_offset = CARD / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BACK
	style.border_color = GOLD
	style.set_border_width_all(5)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	card.add_theme_stylebox_override("panel", style)
	card.draw.connect(func():   # an inner gold frame and a diamond pattern
		var inner := Rect2(Vector2(14, 14), CARD - Vector2(28, 28))
		card.draw_rect(inner, Color(GOLD, 0.55), false, 2)
		for y in range(40, int(CARD.y) - 30, 36):
			for x in range(36, int(CARD.x) - 24, 36):
				var c := Vector2(x, y)
				card.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), Color(GOLD, 0.16)))
	var mark := Label.new()
	mark.name = "mark"
	mark.text = "?"
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_override("font", FONT)
	mark.add_theme_font_size_override("font_size", 120)
	mark.add_theme_color_override("font_color", GOLD)
	card.add_child(mark)
	var face := TextureRect.new()   # the drawn card's picture, shown after the flip
	face.name = "face"
	face.position = Vector2(16, 16)
	face.size = CARD - Vector2(32, 32)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.visible = false
	card.add_child(face)
	return card

# Where card i sits in the fan.
func _fan(i: int) -> Vector2:
	var offset := (i - (DECK - 1) / 2.0)
	return CENTRE - CARD / 2.0 + Vector2(offset * 92, absf(offset) * 18)

func _fan_angle(i: int) -> float:
	return (i - (DECK - 1) / 2.0) * 0.12


## ---- THE SHUFFLE ----
func _play_shuffle() -> void:
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_curtain, "modulate:a", 1.0, 0.25)
	fade.tween_property(_title, "scale", Vector2.ONE, 0.45).from(Vector2(0.6, 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("open")
	# Deal the fan up from the bottom.
	for i in DECK:
		var card := _cards[i]
		var deal := card.create_tween().set_parallel(true)
		deal.tween_property(card, "position", _fan(i), 0.35).set_delay(0.06 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal.tween_property(card, "rotation", _fan_angle(i), 0.35).set_delay(0.06 * i)
		deal.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(0.06 * i)
	await get_tree().create_timer(0.35 + 0.06 * DECK).timeout
	# Shuffle: pairs of cards swap places with a hop, a few times (until the card is in).
	var rounds := 0
	while is_inside_tree() and (rounds < 3 or not _card_ready):
		var a := randi() % DECK
		var b := (a + 1 + randi() % (DECK - 1)) % DECK
		_swap(a, b)
		Sound.play("switch")
		await get_tree().create_timer(0.3).timeout
		rounds += 1
		if rounds > 20:
			break   # never shuffle forever (a lost connection is handled elsewhere)
	_shuffled = true

var _card_ready := false

func _swap(a: int, b: int) -> void:
	var card_a := _cards[a]
	var card_b := _cards[b]
	_cards[a] = card_b
	_cards[b] = card_a
	for pair in [[card_b, a, -1.0], [card_a, b, 1.0]]:
		var card: Control = pair[0]
		var slot: int = pair[1]
		var hop := card.create_tween().set_parallel(true)
		hop.tween_property(card, "position", _fan(slot), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hop.tween_property(card, "rotation", _fan_angle(slot), 0.26)
		var lift := card.create_tween()
		lift.tween_property(card, "scale", Vector2(1.12, 1.12), 0.13)
		lift.tween_property(card, "scale", Vector2.ONE, 0.13)
	_curtain.move_child(card_a, -1)   # the moving cards pass over the others


## ---- THE REVEAL ----
func reveal(card: Dictionary) -> void:
	_card_ready = true
	while not _shuffled and is_inside_tree():
		await get_tree().process_frame
	while Time.get_ticks_msec() - _started < MIN_SHUFFLE * 1000.0:
		await get_tree().process_frame
	var chosen := _cards[DECK / 2]
	_curtain.move_child(chosen, -1)
	(_curtain.get_node("sub") as Label).text = card.get("name", "")
	(_curtain.get_node("sub") as Label).modulate.a = 0.0
	# The others slide away; the chosen one rises to the middle and grows.
	for other in _cards:
		if other == chosen:
			continue
		var away := other.create_tween().set_parallel(true)
		away.tween_property(other, "position:y", other.position.y + 520, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		away.tween_property(other, "modulate:a", 0.0, 0.3)
	var rise := chosen.create_tween().set_parallel(true)
	rise.tween_property(chosen, "position", CENTRE - CARD / 2.0 - Vector2(0, 30), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(chosen, "rotation", 0.0, 0.4)
	rise.tween_property(chosen, "scale", Vector2(BIG, BIG), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await rise.finished
	# It trembles...
	var tremble := chosen.create_tween()
	for i in 8:
		tremble.tween_property(chosen, "rotation", 0.05 if i % 2 == 0 else -0.05, 0.045)
	tremble.tween_property(chosen, "rotation", 0.0, 0.05)
	var mark: Label = chosen.get_node("mark")
	var pulse := mark.create_tween()
	pulse.tween_property(mark, "modulate", Color(1.6, 1.4, 1.0), 0.2)
	pulse.tween_property(mark, "modulate", Color.WHITE, 0.2)
	await tremble.finished
	# ...and flips over.
	var close := chosen.create_tween()
	close.tween_property(chosen, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
	await close.finished
	_turn_face_up(chosen, card)
	_flash(chosen)
	Sound.play("double")
	var open := chosen.create_tween()
	open.tween_property(chosen, "scale", Vector2(BIG * 1.08, BIG * 1.08), 0.14).set_ease(Tween.EASE_OUT)
	open.tween_property(chosen, "scale", Vector2(BIG, BIG), 0.1)
	var sub: Label = _curtain.get_node("sub")
	sub.create_tween().tween_property(sub, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(0.75).timeout
	# The card screen comes up on top; the curtain fades behind it.
	_fade_out()

func _turn_face_up(chosen: Control, card: Dictionary) -> void:
	var style: StyleBoxFlat = chosen.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color("807269")   # the Fortuna screen's own backdrop, so the pale art reads
	chosen.add_theme_stylebox_override("panel", style)
	chosen.get_node("mark").visible = false
	var face: TextureRect = chosen.get_node("face")
	var art := str(card.get("art", ""))
	if art != "" and ResourceLoader.exists(art):
		face.texture = load(art)
	face.visible = true
	for connection in chosen.draw.get_connections():   # plain cream, no pattern
		chosen.draw.disconnect(connection["callable"])
	chosen.queue_redraw()

# A burst of light behind the card as it turns over.
func _flash(chosen: Control) -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 0.92, 0.7, 0.75)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(flash)
	_curtain.add_child(flash)
	_curtain.move_child(flash, chosen.get_index())   # under the card, over the curtain
	var fade := flash.create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.35)
	fade.tween_callback(flash.queue_free)

func _fade_out() -> void:
	var fade := create_tween()
	fade.tween_property(_curtain, "modulate:a", 0.0, 0.5).set_delay(0.25)
	fade.tween_callback(queue_free)

# Nothing was drawn (the deck ran out): just fade away.
func cancel() -> void:
	_card_ready = true
	var fade := create_tween()
	fade.tween_property(_curtain, "modulate:a", 0.0, 0.25)
	fade.tween_callback(queue_free)
