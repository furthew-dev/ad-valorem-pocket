class_name StealFx
extends CanvasLayer
## Full-screen "your property was stolen" animation, shown on the victim's screen when an
## opponent swaps a property away (Cabin swap, Swap Fortuna). Their deed pops up, a red
## STOLEN stamp slams onto it, it is yanked off screen, and the deed they were left with
## slides in to take its place.
##
##   StealFx.play(get_tree(), lost_property, received_property, "Matt", "Cabin swap")

const STARTING_HAND = preload("res://Scripts/starting_hand.gd")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const CREAM := Color("f6f2e1")
const RED := Color("c8343c")
const CARD := STARTING_HAND.CARD
const BIG := 1.35   # deeds are shown a little larger than in the hand


static func play(tree: SceneTree, lost: Dictionary, received: Dictionary, thief: String, how: String = "") -> void:
	var fx := StealFx.new()
	tree.root.add_child(fx)
	await fx._run(lost, received, thief, how)

func _run(lost: Dictionary, received: Dictionary, thief: String, how: String) -> void:
	layer = 99   # above screens, below Fortuna cards (100) and choice pop-ups (101)
	var size := get_viewport().get_visible_rect().size
	var centre := Vector2(size.x / 2.0, size.y * 0.45)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # nothing behind is tappable meanwhile
	dim.modulate.a = 0.0
	add_child(dim)

	var title := _label(how if how != "" else "Swap!", FONT, 64, CREAM)
	title.position = Vector2(0, size.y * 0.1)
	title.size = Vector2(size.x, 90)
	dim.add_child(title)

	var thief_line := _label("%s is taking your property!" % thief, BODY_FONT, 30, CREAM)
	thief_line.position = Vector2(40, title.position.y + 92)
	thief_line.size = Vector2(size.x - 80, 50)
	dim.add_child(thief_line)

	var gone: Control = STARTING_HAND.deed(lost)
	_place(gone, centre)
	gone.scale = Vector2(0.4, 0.4)
	gone.modulate.a = 0.0
	dim.add_child(gone)

	var stamp := _stamp()
	stamp.position = (CARD - stamp.size) / 2.0
	stamp.pivot_offset = stamp.size / 2.0
	stamp.rotation_degrees = -14.0
	stamp.scale = Vector2(2.4, 2.4)
	stamp.modulate.a = 0.0
	gone.add_child(stamp)

	var fresh: Control = STARTING_HAND.deed(received)
	_place(fresh, Vector2(-CARD.x, centre.y))
	fresh.scale = Vector2(BIG, BIG)
	fresh.rotation_degrees = -18.0
	dim.add_child(fresh)

	var caption := "%s took your %s and left you their %s." % [thief, lost.get("name", "property"), received.get("name", "property")]
	var note := _label(caption, BODY_FONT, 30, CREAM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.position = Vector2(50, centre.y + CARD.y * BIG / 2.0 + 40)
	note.size = Vector2(size.x - 100, 120)
	note.modulate.a = 0.0
	dim.add_child(note)

	Sound.play("joker")
	var t := create_tween()
	# 1. The deed they're about to lose pops up
	t.tween_property(dim, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(gone, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(gone, "scale", Vector2(BIG, BIG), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.35)
	# 2. STOLEN slams on
	t.tween_callback(Sound.play.bind("thud"))
	t.tween_property(stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(stamp, "modulate:a", 1.0, 0.1)
	for angle in [-6.0, 6.0, -4.0, 4.0, 0.0]:
		t.tween_property(gone, "rotation_degrees", angle, 0.05)
	t.tween_interval(0.5)
	# 3. Yanked off to the right
	t.tween_callback(Sound.play.bind("paper_rip"))
	t.tween_property(gone, "position:x", size.x + CARD.x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(gone, "rotation_degrees", 28.0, 0.35)
	# 4. What they were left with slides in from the left
	t.tween_callback(Sound.play.bind("switch"))
	t.tween_property(fresh, "position:x", centre.x - CARD.x / 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(fresh, "rotation_degrees", 0.0, 0.45)
	t.parallel().tween_property(thief_line, "modulate:a", 0.0, 0.2)
	t.tween_property(note, "modulate:a", 1.0, 0.25)
	t.tween_interval(2.0)
	t.tween_property(dim, "modulate:a", 0.0, 0.3)
	await t.finished
	queue_free()

func _place(card: Control, at: Vector2) -> void:
	card.position = at - CARD / 2.0
	card.pivot_offset = CARD / 2.0

func _label(text: String, font: Font, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	ColorTheme.keep_text(label)
	return label

# A red rubber stamp: outlined box with STOLEN inside.
func _stamp() -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.82)
	style.set_corner_radius_all(10)
	style.set_border_width_all(7)
	style.border_color = RED
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", style)
	var word := Label.new()
	word.text = "STOLEN"
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.add_theme_font_override("font", BODY_FONT)
	word.add_theme_font_size_override("font_size", 50)
	word.add_theme_color_override("font_color", RED)
	ColorTheme.keep_text(word)
	box.add_child(word)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.reset_size()
	return box
