class_name DiscardFx
extends CanvasLayer
## Full-screen "into the trash" animation for a property you lose (destroyed, seized,
## auctioned away, swapped away). The property card pops up in front, shakes, then
## crumples and drops into a bin.
##
##   await DiscardFx.play(get_tree(), property, "Destroyed by a Tornado")

const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const CREAM := Color(0.866667, 0.811765, 0.6)
const CARD_COLOR := Color("533c44")
const BIN_COLOR := Color("8a7a70")

var _done := false


static func play(tree: SceneTree, property: Dictionary, caption: String = "") -> void:
	var fx := DiscardFx.new()
	tree.root.add_child(fx)
	await fx._run(property, caption)

func _run(property: Dictionary, caption: String) -> void:
	layer = 99   # above screens and auctions, below Fortuna cards (100) and choice pop-ups
	var size := get_viewport().get_visible_rect().size

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # nothing behind is tappable meanwhile
	dim.modulate.a = 0.0
	add_child(dim)

	var bin := _Bin.new()
	bin.size = Vector2(220, 240)
	bin.position = Vector2(size.x / 2 - 110, size.y - 330)
	bin.modulate.a = 0.0
	dim.add_child(bin)

	var card := _make_card(property)
	card.position = Vector2(size.x / 2 - card.size.x / 2, size.y * 0.22)
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.5, 0.5)
	card.modulate.a = 0.0
	dim.add_child(card)

	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(40, card.position.y + card.size.y + 30)
	label.size = Vector2(size.x - 80, 120)
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", CREAM)
	label.modulate.a = 0.0
	dim.add_child(label)

	Sound.play("error")
	# 1. Pop in
	var t := create_tween()
	t.tween_property(dim, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(card, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(bin, "modulate:a", 1.0, 0.4)
	# 2. Shake
	for angle in [-7.0, 7.0, -5.0, 5.0, 0.0]:
		t.tween_property(card, "rotation_degrees", angle, 0.06)
	t.tween_interval(0.5)
	# 3. Lid opens, the card crumples and drops in
	t.tween_property(bin, "lid_angle", -50.0, 0.2)
	t.tween_property(label, "modulate:a", 0.0, 0.2)
	var drop_to := Vector2(bin.position.x + bin.size.x / 2 - card.size.x / 2, bin.position.y - card.size.y / 2 + 60)
	t.tween_property(card, "position", drop_to, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(card, "scale", Vector2(0.12, 0.12), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(card, "rotation_degrees", 260.0, 0.55)
	t.parallel().tween_property(card, "modulate", Color(0.6, 0.55, 0.5, 1.0), 0.55)
	t.tween_property(card, "modulate:a", 0.0, 0.08)
	# 4. Lid closes with a little bounce, then fade out
	t.tween_property(bin, "lid_angle", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(bin, "scale", Vector2(1.06, 0.94), 0.08)
	t.tween_property(bin, "scale", Vector2.ONE, 0.12)
	t.tween_interval(0.35)
	t.tween_property(dim, "modulate:a", 0.0, 0.3)
	bin.pivot_offset = Vector2(bin.size.x / 2, bin.size.y)
	await t.finished
	queue_free()

func _make_card(property: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.set_corner_radius_all(30)
	style.set_border_width_all(4)
	style.border_color = CREAM
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", style)
	card.size = Vector2(420, 440)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var art := TextureRect.new()
	if ResourceLoader.exists(str(property.get("art", ""))):
		art.texture = load(property["art"])
	art.custom_minimum_size = Vector2(0, 300)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(art)
	var name_label := Label.new()
	name_label.text = str(property.get("name", "Property"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 56)
	name_label.add_theme_color_override("font_color", CREAM)
	box.add_child(name_label)
	return card


# A simple drawn bin: body with stripes, and a lid that tilts open (lid_angle, degrees).
class _Bin extends Control:
	var lid_angle := 0.0:
		set(value):
			lid_angle = value
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := PackedVector2Array([
			Vector2(w * 0.12, h * 0.25), Vector2(w * 0.88, h * 0.25),
			Vector2(w * 0.78, h), Vector2(w * 0.22, h)])
		draw_colored_polygon(body, BIN_COLOR)
		for x in [0.38, 0.5, 0.62]:
			draw_line(Vector2(w * x, h * 0.34), Vector2(w * (0.5 + (x - 0.5) * 0.8), h * 0.92), Color(0, 0, 0, 0.25), 6)
		# Lid, hinged at its right end
		var hinge := Vector2(w * 0.95, h * 0.22)
		draw_set_transform(hinge, deg_to_rad(lid_angle))
		draw_rect(Rect2(Vector2(-w * 0.95, -h * 0.07), Vector2(w * 0.9, h * 0.07)), BIN_COLOR.lightened(0.15))
		draw_rect(Rect2(Vector2(-w * 0.58, -h * 0.13), Vector2(w * 0.16, h * 0.06)), BIN_COLOR.lightened(0.15))
		draw_set_transform(Vector2.ZERO)
