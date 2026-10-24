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
	if event is InputEventMouseMotion and _pressed_tile:
		var pos: Vector2 = event.position
		if not _dragging and pos.distance_to(_press_pos) > DRAG_START:
			_start_drag(_pressed_tile)
		if _dragging:
			_move_ghost(pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
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
