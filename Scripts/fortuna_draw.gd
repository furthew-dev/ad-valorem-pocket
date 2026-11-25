extends CanvasLayer
## The new-round Fortuna draw, with a little mystery: a deck of face-down Fortuna cards
## fans out on a dark curtain and shuffles while the card is drawn. Then one card rises,
## trembles, and flips over to show the drawn card's picture with a flash, and the normal
## Fortuna card screen (fortuna.tscn, layer 100) takes over on top.
## After a few shuffles the player picks any card (luck of the draw); that one turns over.
## A second Fortuna in the same round shows the first pick face-up in its place, and the
## player picks from the rest.
##     var draw = FortunaDraw.start(get_tree(), earlier)   # earlier: [{slot, card}] this round
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
const SHOW_FACE := 1.6          # seconds the turned-over card is shown before its details
const MARKS = preload("res://Assets/icons/question_marks_icon.png")
# Draws a one-colour icon (black art) in one colour: the question marks in gold.
const SOLID_SHADER := "shader_type canvas_item;\nuniform vec4 tint : source_color;\nvoid fragment() { COLOR = vec4(tint.rgb, COLOR.a * tint.a); }"

var _curtain: ColorRect
var _title: Label
var _cards: Array[Control] = []
var _shuffled := false
var _started := 0
var _earlier: Array = []          # [{slot, card}] already drawn this round: shown face up
var _picking := false
var _picked: Control = null
var picked_slot := -1             # where the player's pick sat in the fan (for the next draw)
var _bobs: Array = []
const AUTO_PICK := 25.0           # nobody tapped: fate picks for them

signal picked


static func start(tree: SceneTree, earlier: Array = []) -> Node:
	var draw = load("res://Scripts/fortuna_draw.gd").new()
	draw.name = "FortunaDraw"
	draw._earlier = earlier
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
		var tap := Button.new()   # tap a card to pick it (only while picking)
		tap.flat = true
		tap.focus_mode = Control.FOCUS_NONE
		tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		tap.pressed.connect(func(): _pick(card))
		card.add_child(tap)
	for entry in _earlier:   # this round's earlier pick stays face up where it was
		var slot: int = clampi(int(entry.get("slot", DECK / 2)), 0, DECK - 1)
		_turn_face_up(_cards[slot], entry.get("card", {}))
		_cards[slot].set_meta("used", true)
		_cards[slot].modulate = Color(0.75, 0.75, 0.75, 0.0)
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
	card.draw.connect(func():   # solid purple with an inner gold frame
		var inner := Rect2(Vector2(14, 14), CARD - Vector2(28, 28))
		card.draw_rect(inner, Color(GOLD, 0.7), false, 2))
	var mark := TextureRect.new()   # Matt's question marks, in gold
	mark.name = "mark"
	mark.texture = MARKS
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.position = Vector2(CARD.x * 0.15, (CARD.y - CARD.x * 0.7) / 2.0)
	mark.size = Vector2(CARD.x * 0.7, CARD.x * 0.7)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold := ShaderMaterial.new()
	gold.shader = _solid_shader()
	gold.set_shader_parameter("tint", GOLD)
	mark.material = gold
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

var _shader: Shader
func _solid_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SOLID_SHADER
	return _shader

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
	# Deal the fan up from the bottom (a card sound for every other card: five at once blur).
	for i in DECK:
		var card := _cards[i]
		var deal := card.create_tween().set_parallel(true)
		deal.tween_property(card, "position", _fan(i), 0.35).set_delay(0.06 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		deal.tween_property(card, "rotation", _fan_angle(i), 0.35).set_delay(0.06 * i)
		deal.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(0.06 * i)
		if i % 2 == 0:
			get_tree().create_timer(0.06 * i).timeout.connect(func(): Sound.play("deal"))
	await get_tree().create_timer(0.35 + 0.06 * DECK).timeout
	# Shuffle: pairs of face-down cards swap places with a hop, a few times.
	var free := _free_slots()
	for rounds in 4:
		if not is_inside_tree() or free.size() < 2:
			break
		var a: int = free.pick_random()
		var b: int = a
		while b == a:
			b = free.pick_random()
		_swap(a, b)
		Sound.play("deal")
		await get_tree().create_timer(0.3).timeout
	_shuffled = true
	_start_picking()

# Slots holding face-down cards (an earlier pick this round stays put, face up).
func _free_slots() -> Array:
	var free := []
	for i in DECK:
		if not _cards[i].has_meta("used"):
			free.append(i)
	return free


## ---- PICKING ----
# The face-down cards bob gently, waiting for a tap. Any one will do.
func _start_picking() -> void:
	if not is_inside_tree():
		return
	_picking = true
	var sub: Label = _curtain.get_node("sub")
	sub.text = "Pick a card, any card!"
	sub.pivot_offset = sub.size / 2.0
	var nudge := sub.create_tween()
	nudge.tween_property(sub, "scale", Vector2(1.1, 1.1), 0.15)
	nudge.tween_property(sub, "scale", Vector2.ONE, 0.2)
	for i in _free_slots():
		var card := _cards[i]
		var rest := _fan(i)
		var bob := card.create_tween().set_loops()
		bob.tween_property(card, "position:y", rest.y - 14, 0.5 + 0.07 * i).set_trans(Tween.TRANS_SINE)
		bob.tween_property(card, "position:y", rest.y, 0.5 + 0.07 * i).set_trans(Tween.TRANS_SINE)
		_bobs.append(bob)
	var timer := Timer.new()   # (a child, so it goes away with this screen)
	timer.one_shot = true
	timer.wait_time = AUTO_PICK
	timer.timeout.connect(func():
		if _picking:
			_pick(_cards[_free_slots().pick_random()]))
	add_child(timer)
	timer.start()

func _pick(card: Control) -> void:
	if not _picking or card.has_meta("used"):
		return
	_picking = false
	_picked = card
	picked_slot = _cards.find(card)
	for bob in _bobs:
		if bob.is_valid():
			bob.kill()
	_bobs.clear()
	Sound.play("deal")
	picked.emit()

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
	if _picked == null:
		await picked   # the player hasn't chosen yet
	var chosen := _picked
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
	var mark: Control = chosen.get_node("mark")
	var pulse := mark.create_tween()
	mark.pivot_offset = mark.size / 2.0
	pulse.tween_property(mark, "scale", Vector2(1.18, 1.18), 0.2).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(mark, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)
	await tremble.finished
	# ...and flips over.
	var close := chosen.create_tween()
	close.tween_property(chosen, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
	await close.finished
	_turn_face_up(chosen, card)
	_flash(chosen)
	Sound.play("sparkle")   # turned over (a good card then gets the "bloop", see Fortunas)
	var open := chosen.create_tween()
	open.tween_property(chosen, "scale", Vector2(BIG * 1.08, BIG * 1.08), 0.14).set_ease(Tween.EASE_OUT)
	open.tween_property(chosen, "scale", Vector2(BIG, BIG), 0.1)
	var sub: Label = _curtain.get_node("sub")
	sub.create_tween().tween_property(sub, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(SHOW_FACE).timeout
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
	_picking = false
	var fade := create_tween()
	fade.tween_property(_curtain, "modulate:a", 0.0, 0.25)
	fade.tween_callback(queue_free)
