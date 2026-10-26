extends RefCounted
## "Your protection worked": the Insurance (or Attorney) symbol pops up in the middle of
## the screen with the shield sound (a gavel for an Attorney), holds for a moment, then shatters into pieces that
## fly apart, so it's clear the token was used up. Doesn't block taps.
##     ShieldFx.play(get_tree(), "insurance", "Mad Renter")

const ICONS := {
	"insurance": "res://Assets/icons/insurance_icon.png",
	"attorney": "res://Assets/icons/attorney_icon.png",
}
const SIZE := 260.0
const PIECES := 4   # 4 x 4 shards
const LAYER := 102  # over the Fortuna card and menus

static func play(tree: SceneTree, kind: String, card_name: String = "") -> void:
	var texture: Texture2D = load(ICONS.get(kind, ICONS["insurance"]))
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	tree.root.add_child(layer)
	var screen := tree.root.get_visible_rect().size
	var centre := screen / 2.0

	# The badge: a round cream plate with the symbol on it.
	var badge := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ddcf99")
	style.border_color = Color("533c44")
	style.set_border_width_all(8)
	style.set_corner_radius_all(int(SIZE))
	badge.add_theme_stylebox_override("panel", style)
	badge.size = Vector2(SIZE, SIZE)
	badge.position = centre - badge.size / 2.0
	badge.pivot_offset = badge.size / 2.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_meta("ct_skip", true)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 40
	icon.offset_top = 40
	icon.offset_right = -40
	icon.offset_bottom = -40
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("ct_skip", true)
	badge.add_child(icon)
	layer.add_child(badge)

	var caption := Label.new()
	caption.text = "%s blocked %s!" % ["Insurance" if kind == "insurance" else "Attorney", card_name] if card_name != "" else "Protected!"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 40)
	caption.add_theme_color_override("font_color", Color("f6f2e1"))
	caption.add_theme_color_override("font_outline_color", Color("2e2328"))
	caption.add_theme_constant_override("outline_size", 10)
	caption.size = Vector2(screen.x, 60)
	caption.position = Vector2(0, centre.y + SIZE / 2.0 + 24)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.theme = preload("res://main_theme.tres")
	caption.set_meta("ct_skip", true)
	layer.add_child(caption)

	Sound.play("gavel" if kind == "attorney" else "shield")
	badge.scale = Vector2(0.3, 0.3)
	badge.modulate.a = 0.0
	var pop := badge.create_tween().set_parallel(true)
	pop.tween_property(badge, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(badge, "modulate:a", 1.0, 0.2)
	await pop.finished
	if not is_instance_valid(badge):
		return
	# A little shudder as it takes the hit...
	var hit := badge.create_tween()
	for angle in [0.08, -0.08, 0.05, 0.0]:
		hit.tween_property(badge, "rotation", angle, 0.05)
	hit.tween_interval(0.35)
	await hit.finished
	if not is_instance_valid(badge):
		return
	# ...then it breaks: the badge is swapped for shards of itself that fly apart.
	var image := _snapshot(texture)
	badge.visible = false
	var piece_size := SIZE / PIECES
	for row in PIECES:
		for col in PIECES:
			var shard := TextureRect.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = image
			var src := Vector2(image.get_size()) / float(PIECES)
			atlas.region = Rect2(Vector2(col, row) * src, src)
			shard.texture = atlas
			shard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shard.size = Vector2(piece_size, piece_size)
			shard.position = badge.position + Vector2(col, row) * piece_size
			shard.pivot_offset = shard.size / 2.0
			shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shard.set_meta("ct_skip", true)
			layer.add_child(shard)
			var away := (shard.position + shard.size / 2.0 - centre).normalized()
			if away == Vector2.ZERO:
				away = Vector2.DOWN
			var fly := shard.create_tween().set_parallel(true)
			var distance := randf_range(260.0, 520.0)
			fly.tween_property(shard, "position", shard.position + away * distance + Vector2(0, 220), 0.9).set_ease(Tween.EASE_OUT)
			fly.tween_property(shard, "rotation", randf_range(-4.0, 4.0), 0.9)
			fly.tween_property(shard, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	var fade := caption.create_tween()
	fade.tween_interval(0.6)
	fade.tween_property(caption, "modulate:a", 0.0, 0.5)
	await fade.finished
	if is_instance_valid(layer):
		layer.queue_free()

# The symbol drawn on its plate, as one texture to cut into shards.
static func _snapshot(icon: Texture2D) -> Texture2D:
	var side := 200
	var plate := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	plate.fill(Color(0, 0, 0, 0))
	var centre := Vector2(side, side) / 2.0
	for y in side:
		for x in side:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centre)
			if d <= side / 2.0:
				plate.set_pixel(x, y, Color("533c44") if d > side / 2.0 - 6 else Color("ddcf99"))
	var source := icon.get_image()
	if source:
		source = source.duplicate()
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		source.resize(side - 60, side - 60, Image.INTERPOLATE_BILINEAR)
		plate.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(30, 30))
	return ImageTexture.create_from_image(plate)
