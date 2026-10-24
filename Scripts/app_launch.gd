extends RefCounted
## Phone-style app opening: the tapped app's tile grows from where it sits on the home
## screen to fill the screen (corners straightening out, the icon swelling and fading),
## the app opens underneath, then the cover fades away. Coming back Home, the cover
## shrinks back into that app's tile. (The old full-screen transition animations are
## still used for buying, selling and the game intro: see transition.gd.)
##
##     AppLaunch.open(tree, tile_panel, icon, "res://Scenes/bank_account.tscn")
##     AppLaunch.close_into(tree, tile_panel)   # home_screen.gd, when it opens

const OPEN_TIME := 0.34
const CLOSE_TIME := 0.3
const REVEAL_TIME := 0.16
const LAYER := 60

static var returning_to := ""   # name of the tile the last app was opened from

# Where a control is on screen (its size includes any scaling of its parents).
static func screen_rect(control: Control) -> Rect2:
	var xform := control.get_global_transform_with_canvas()
	return Rect2(xform.origin, control.size * xform.get_scale())

static func _cover(tree: SceneTree, tile_panel: Control) -> Array:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	var cover := Panel.new()
	cover.mouse_filter = Control.MOUSE_FILTER_STOP   # no taps while it animates
	var style := StyleBoxFlat.new()
	var tile_style := tile_panel.get_theme_stylebox("panel")
	style.bg_color = tile_style.bg_color if tile_style is StyleBoxFlat else Color("533c44")
	style.set_corner_radius_all(30)
	style.anti_aliasing = true
	cover.add_theme_stylebox_override("panel", style)
	ColorTheme.keep(cover)   # the colour is already the themed one
	layer.add_child(cover)
	tree.root.add_child(layer)
	return [layer, cover, style]

static func _icon_copy(cover: Control, icon: TextureRect) -> TextureRect:
	var copy := TextureRect.new()
	copy.texture = icon.texture
	copy.material = icon.material   # keeps the theme's tint
	copy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	copy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(copy)
	cover.add_child(copy)
	return copy

static func open(tree: SceneTree, tile: Control, tile_panel: Control, icon: TextureRect, destination: String) -> void:
	returning_to = String(tile.name)
	var parts := _cover(tree, tile_panel)
	var layer: CanvasLayer = parts[0]
	var cover: Panel = parts[1]
	var style: StyleBoxFlat = parts[2]
	var from := screen_rect(tile_panel)
	var screen := Rect2(Vector2.ZERO, tree.root.get_visible_rect().size)
	cover.position = from.position
	cover.size = from.size
	var copy := _icon_copy(cover, icon)
	var icon_rect := screen_rect(icon)
	var icon_size := icon_rect.size
	copy.size = icon_size
	copy.position = icon_rect.position - from.position
	icon.modulate.a = 0.0   # the icon "lifts off" the home screen

	var tween := cover.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cover, "position", screen.position, OPEN_TIME)
	tween.tween_property(cover, "size", screen.size, OPEN_TIME)
	tween.tween_method(func(r: float): style.set_corner_radius_all(int(r)), 30.0, 0.0, OPEN_TIME)
	var big := icon_size * 2.2
	tween.tween_property(copy, "size", big, OPEN_TIME)
	tween.tween_property(copy, "position", (screen.size - big) / 2.0, OPEN_TIME)
	tween.tween_property(copy, "modulate:a", 0.0, OPEN_TIME * 0.9).set_ease(Tween.EASE_IN)
	await tween.finished

	tree.change_scene_to_file(destination)
	await tree.process_frame
	await tree.process_frame   # the app is drawn under the cover now
	if not is_instance_valid(cover):
		return
	var reveal := cover.create_tween()
	reveal.tween_property(cover, "modulate:a", 0.0, REVEAL_TIME)
	await reveal.finished
	layer.queue_free()

# Home screen just opened after an app: the app shrinks back into its tile.
static func close_into(tree: SceneTree, tile_panel: Control) -> void:
	var parts := _cover(tree, tile_panel)
	var layer: CanvasLayer = parts[0]
	var cover: Panel = parts[1]
	var style: StyleBoxFlat = parts[2]
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE   # don't block the home screen
	style.set_corner_radius_all(0)
	cover.position = Vector2.ZERO
	cover.size = tree.root.get_visible_rect().size
	await tree.process_frame   # let the home screen lay itself out first
	if not is_instance_valid(tile_panel):
		layer.queue_free()
		return
	var to := screen_rect(tile_panel)
	var tween := cover.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cover, "position", to.position, CLOSE_TIME)
	tween.tween_property(cover, "size", to.size, CLOSE_TIME)
	tween.tween_method(func(r: float): style.set_corner_radius_all(int(r)), 0.0, 30.0, CLOSE_TIME)
	tween.tween_property(cover, "modulate:a", 0.0, CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	layer.queue_free()
