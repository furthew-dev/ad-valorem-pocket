extends CanvasLayer
## Phone home screen: app buttons and End Turn.
## Hold an app (or start dragging it) to pick it up, then drop it on another app to swap
## their places. The layout is remembered on this phone.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const AppLaunch = preload("res://Scripts/app_launch.gd")

@onready var ui_menu_frame: Control = $"UI Menu Frame"
@onready var end_turn_btn: Button = $"Apps/Apps Container/second_row/End Turn/actions/end_turn_btn"

var current_scene := "res://Scenes/home_screen.tscn"

const HOLD_TIME := 0.35      # seconds held still before an app lifts up
const DRAG_START := 24.0     # ...or start moving this far (pixels) to pick it up at once

@onready var first_row: HBoxContainer = $"Apps/Apps Container/first_row"
@onready var second_row: HBoxContainer = $"Apps/Apps Container/second_row"

var _tiles: Array[Control] = []    # the six app tiles (each: picture + label)
var _pressed_tile: Control         # finger is down on this tile
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _dragging: Control             # tile being moved
var _ghost: Control                # the floating copy that follows the finger
var _ghost_offset := Vector2.ZERO
var _hover_tile: Control
var _swallow_tap := false          # the release that ends a drag must not open the app


func _ready() -> void:
	_setup_tiles()
	_let_taps_through($Apps)
	end_turn_btn.disabled = Turns.my_turn_done
	_setup_pages()
	_shrink_back_from_app()
	Turns.waiting_changed.connect(func(_names): end_turn_btn.disabled = Turns.my_turn_done)

# The Apps panel and its layout boxes are scaled 1.25x and reach past the bottom of the
# screen, invisibly covering the UI frame's Home / Settings buttons. Only the app buttons
# themselves should take taps, so everything else in there lets them through.
func _let_taps_through(node: Node) -> void:
	if node is Control and not node is BaseButton:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_let_taps_through(child)

## ---- REARRANGING APPS ----
func _setup_tiles() -> void:
	for row in [first_row, second_row]:
		for child in row.get_children():
			if child is VBoxContainer:
				_tiles.append(child)
	_apply_saved_order()
	for tile in _tiles:
		var button := _tile_button(tile)
		if button:
			button.button_down.connect(_on_tile_down.bind(tile))

func _tile_button(tile: Control) -> Button:
	var buttons := tile.find_children("*", "Button", true, false)
	return buttons[0] if not buttons.is_empty() else null

# Slots are the six places apps can sit, in reading order.
func _slots() -> Array:
	var slots := []
	for row in [first_row, second_row]:
		for child in row.get_children():
			if child is VBoxContainer:
				slots.append([row, child.get_index()])
	return slots

func _apply_saved_order() -> void:
	var order: Array = Network.load_setting("home", "app_order", [])
	if order.size() != _tiles.size():
		return
	var by_name := {}
	for tile in _tiles:
		by_name[String(tile.name)] = tile
	for tile_name in order:
		if not by_name.has(tile_name):
			return   # an app was renamed/added since: keep the default layout
	var slots := _slots()
	for tile in _tiles:
		tile.get_parent().remove_child(tile)
	for i in slots.size():   # slots are in increasing index order per row, so inserting works
		var row: HBoxContainer = slots[i][0]
		var tile: Control = by_name[order[i]]
		row.add_child(tile)
		row.move_child(tile, slots[i][1])

func _save_order() -> void:
	var order := []
	for row in [first_row, second_row]:
		for child in row.get_children():
			if child is VBoxContainer:
				order.append(String(child.name))
	Network.save_setting("home", "app_order", order)

func _on_tile_down(tile: Control) -> void:
	_pressed_tile = tile
	_press_pos = get_viewport().get_mouse_position()
	_press_time = 0.0

func _process(delta: float) -> void:
	if _pressed_tile and not _dragging:
		_press_time += delta
		if _press_time >= HOLD_TIME:
			_start_drag(_pressed_tile)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_swipe_start = event.position
		_swipe_tracking = not _blocked_by_overlay(event.position)
		_swiping = false
	if event is InputEventMouseMotion and _swipe_tracking and not _dragging:
		var moved: Vector2 = event.position - _swipe_start
		if not _swiping and absf(moved.x) > DRAG_START and absf(moved.x) > absf(moved.y) * 1.5:
			_swiping = true   # a sideways swipe turns the page instead of picking up an app
			_pressed_tile = null
		if _swiping:
			_place_pages(moved.x)
			return
	if event is InputEventMouseMotion and _pressed_tile:
		var pos: Vector2 = event.position
		if not _dragging and pos.distance_to(_press_pos) > DRAG_START:
			_start_drag(_pressed_tile)
		if _dragging:
			_move_ghost(pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _swiping:
			_end_swipe(event.position.x - _swipe_start.x)
		_swipe_tracking = false
		if _dragging:
			_drop(event.position)
		_pressed_tile = null

func _start_drag(tile: Control) -> void:
	_dragging = tile
	Sound.play("switch")
	_ghost = tile.duplicate(0)   # a look-alike with no signals or scripts
	_ghost.top_level = true
	_set_ignore(_ghost)
	var rect := tile.get_global_rect()
	_ghost.size = tile.size
	_ghost.scale = tile.get_global_transform().get_scale() * 1.1
	_ghost.modulate = Color(1, 1, 1, 0.9)
	_ghost_offset = _press_pos - rect.position
	$Apps.add_child(_ghost)
	tile.modulate.a = 0.3
	_move_ghost(get_viewport().get_mouse_position())

func _set_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_ignore(child)

func _move_ghost(pos: Vector2) -> void:
	if not is_instance_valid(_ghost):
		return
	_ghost.global_position = pos - _ghost_offset * 1.1
	var over := _tile_at(pos)
	if over != _hover_tile:
		if is_instance_valid(_hover_tile) and _hover_tile != _dragging:
			_hover_tile.modulate = Color.WHITE
		_hover_tile = over
		if _hover_tile and _hover_tile != _dragging:
			_hover_tile.modulate = Color(1.25, 1.25, 1.25)

func _tile_at(pos: Vector2) -> Control:
	for tile in _tiles:
		if tile.get_global_rect().has_point(pos):
			return tile
	return null

func _drop(pos: Vector2) -> void:
	var target := _tile_at(pos)
	if target and target != _dragging:
		_swap_tiles(_dragging, target)
		_save_order()
		Sound.play("continue")
	for tile in _tiles:
		tile.modulate = Color.WHITE
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_dragging = null
	_hover_tile = null
	_swallow_tap = true   # the button's "pressed" comes right after this release
	_clear_swallow.call_deferred()

func _clear_swallow() -> void:
	await get_tree().process_frame
	_swallow_tap = false

func _swap_tiles(a: Control, b: Control) -> void:
	var pa := a.get_parent()
	var pb := b.get_parent()
	var ia := a.get_index()
	var ib := b.get_index()
	if pa == pb:
		var low := a if ia < ib else b
		var high := b if ia < ib else a
		var low_index := mini(ia, ib)
		var high_index := maxi(ia, ib)
		pa.move_child(high, low_index)
		pa.move_child(low, high_index)
	else:
		pa.remove_child(a)
		pb.remove_child(b)
		pa.add_child(b)
		pa.move_child(b, ia)
		pb.add_child(a)
		pb.move_child(a, ib)


# Saves this screen for the Back button and plays the app's opening animation.
var _opening := false   # an app is already opening (ignore repeat taps)

# Like a phone: the app's tile grows to fill the screen (app_launch.gd).
func _open_app(app: Dictionary, tile_name: String) -> void:
	if _swallow_tap or _dragging or _opening:
		return
	var tile := _tile_named(tile_name)
	if tile == null:
		return
	_opening = true
	Sound.play("click")
	Global.save_scene(current_scene)
	AppLaunch.open(get_tree(), tile, _tile_panel(tile), _tile_icon(tile), app.app_url)

# Back on the home screen from an app: it shrinks into its tile.
func _shrink_back_from_app() -> void:
	var tile := _tile_named(AppLaunch.returning_to)
	AppLaunch.returning_to = ""
	if tile:
		AppLaunch.close_into(get_tree(), _tile_panel(tile))

func _tile_named(tile_name: String) -> Control:
	for tile in _tiles:
		if String(tile.name) == tile_name:
			return tile
	return null

# The coloured rounded square of a tile, and the picture on it.
func _tile_panel(tile: Control) -> Control:
	return _tile_icon(tile).get_parent() as Control

func _tile_icon(tile: Control) -> TextureRect:
	return tile.find_children("*", "TextureRect", true, false)[0]

func _on_bank_button_pressed() -> void:
	_open_app(Global.bank_app, "bank")

func _on_my_properties_button_pressed() -> void:
	_open_app(Global.my_properties_app, "my_properties")

func _on_market_button_pressed() -> void:
	_open_app(Global.market_app, "market")

func _on_my_loans_button_pressed() -> void:
	_open_app(Global.my_loans_app, "My Loans")

func _on_actions_button_pressed() -> void:
	_open_app(Global.my_actions_app, "My Actions")

func _on_end_turn_btn_pressed() -> void:
	if _swallow_tap or _dragging:
		return
	if Turns.my_turn_done:
		Global.error("You already ended your turn.")
		return
	var popup = POPUP_SCENE.instantiate()
	ui_menu_frame.add_child(popup)
	popup.layout("Are you sure you want to end your turn?", "Yes", "No")
	popup.left_pressed.connect(_on_end_turn_confirmed)

func _on_end_turn_confirmed() -> void:
	end_turn_btn.disabled = true   # re-enabled when the next round starts
	Global.end_turn()


## ---- PAGES: apps | activity ----
# Like a phone's home screen: swipe left for the Activity log, right to come back.
# The two dots above the bottom bar show which page is up (and can be tapped).
const ActivityPage = preload("res://Scripts/activity_page.gd")
const PAGE_COUNT := 2
var _page := 0
var _activity: Control
var _dots: Array[Panel] = []
var _apps_home_x := 0.0
var _swipe_start := Vector2.ZERO
var _swipe_tracking := false
var _swiping := false
var _page_tween: Tween

func _setup_pages() -> void:
	_activity = ActivityPage.new()
	_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_activity)
	move_child(_activity, ui_menu_frame.get_index())   # under the header and bottom bar
	var dots := HBoxContainer.new()
	dots.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dots.offset_bottom = -186
	dots.offset_left = -60
	dots.offset_right = 60
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 18)
	for i in PAGE_COUNT:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(36, 36)   # a comfortable tap target...
		var style := StyleBoxFlat.new()   # ...drawn as a small dot in the middle
		style.bg_color = Color("533c44")
		style.set_corner_radius_all(9)
		style.set_expand_margin_all(-9)
		dot.add_theme_stylebox_override("panel", style)
		dot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_go_to_page(i))
		dots.add_child(dot)
		_dots.append(dot)
	add_child(dots)
	move_child(dots, ui_menu_frame.get_index())
	get_viewport().size_changed.connect(func(): _place_pages.call_deferred(0.0))
	_remember_apps_spot.call_deferred()

func _remember_apps_spot() -> void:
	_apps_home_x = $Apps.position.x
	_place_pages(0.0)

func _page_width() -> float:
	return get_viewport().get_visible_rect().size.x

# drag: how far the finger has moved sideways (0 = resting on the current page).
func _place_pages(drag: float) -> void:
	var width := _page_width()
	if (_page == 0 and drag > 0) or (_page == PAGE_COUNT - 1 and drag < 0):
		drag *= 0.3   # rubber band past the first / last page
	var shift := -_page * width + drag
	$Apps.position.x = _apps_home_x + shift
	_activity.position.x = width + shift
	_update_dots()

func _update_dots() -> void:
	for i in _dots.size():
		_dots[i].modulate.a = 1.0 if i == _page else 0.35

func _end_swipe(drag: float) -> void:
	_swiping = false
	_swallow_tap = true   # the release must not also open an app
	_clear_swallow.call_deferred()
	var target := _page
	if drag < -_page_width() * 0.18:
		target = mini(_page + 1, PAGE_COUNT - 1)
	elif drag > _page_width() * 0.18:
		target = maxi(_page - 1, 0)
	_go_to_page(target, drag)

func _go_to_page(page: int, from_drag: float = 0.0) -> void:
	var width := _page_width()
	if (_page == 0 and from_drag > 0) or (_page == PAGE_COUNT - 1 and from_drag < 0):
		from_drag *= 0.3
	var start := -_page * width + from_drag
	if page != _page:
		Sound.play("switch")
	_page = page
	_update_dots()
	var finish := -_page * width
	if _page_tween:
		_page_tween.kill()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_page_tween.tween_method(func(shift: float):
		$Apps.position.x = _apps_home_x + shift
		_activity.position.x = width + shift, start, finish, 0.3)

# A pop-up or card is open on top (something on a higher layer that takes taps covers
# the spot): leave the pages alone.
func _blocked_by_overlay(point: Vector2) -> bool:
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var canvas := node as CanvasLayer
		if canvas == self or canvas.layer <= layer or not canvas.visible:
			continue
		for child in canvas.get_children():
			if _covers(child, point):
				return true
	return false

func _covers(node: Node, point: Vector2) -> bool:
	if not node is Control or not (node as Control).is_visible_in_tree():
		return false
	var control := node as Control
	if control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(point):
		return true
	for child in control.get_children():
		if _covers(child, point):
			return true
	return false
