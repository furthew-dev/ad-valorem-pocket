extends CanvasLayer
## Title screen: "How to Play". Opened by tapping the notepad on the desk; a little
## book grows out of the notepad with three short pages. < and > turn the pages (the
## page folds over at the spine), Close (or a tap outside) shrinks it back to the pad.
##     HowToPlay.open(get_tree(), notepad_control)

const PAPER = preload("res://Assets/icons/pop_up.png")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const INK := Color(0.1, 0.1, 0.1)
const PAGE_COLOR := Color("c0b18f")   # a palette colour, so themes follow it
const BOOK_SIZE := Vector2(680, 1100)   # the card art fills about 81% x 88% of this
const TURN_TIME := 0.3

const PAGES := [
	{"title": "The Goal",
	"body": "Build the best real estate portfolio.\n\nEveryone plays their turn at the same time. When a round ends with a player holding more than $200 cash (the host can change this) and no loans, the game is over.\n\nThe highest net worth wins: cash, properties and savings, minus anything you owe."},
	{"title": "Your Turn",
	"body": "You have 3 Actions each round (5 with an LLC).\n\nSpend them in the Market: buy properties (up to 4), tokens like SkyBnB, Double and Insurance, or cards like Contractor and Sabotage.\n\nShort on cash? The Bank will lend, but loans grow 10% every round.\n\nTap End Turn when you're done."},
	{"title": "Each New Round",
	"body": "Once everyone has ended their turn:\n\nFortunas: finish with $25 or more and you draw a Fortuna card, good luck or bad. $100 or more draws two.\n\nInterest is added to your loans, then rent is paid on every property you own.\n\nProtect your homes, sabotage your rivals, and watch your fortune grow!"},
]

var _from: Control          # the notepad it opens out of
var _book: Control
var _dim: ColorRect
var _page_holder: Control
var _page: Control          # the page you're reading
var _page_number: Label
var _prev: Button
var _next: Button
var _index := 0
var _busy := false


static func open(tree: SceneTree, from: Control) -> Node:
	var book = load("res://Scripts/how_to_play.gd").new()
	book._from = from
	tree.root.add_child(book)
	return book

func _ready() -> void:
	layer = 60   # above the title screen, below the Fortuna card (100)
	Sound.play("open")
	_build()
	_show_page(0)
	_open_animation()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(event: InputEvent):   # a tap outside the book closes it
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close())
	add_child(_dim)

	_book = TextureRect.new()
	_book.texture = PAPER
	_book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book.size = BOOK_SIZE
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.add_child(_book)

	_page_holder = Control.new()
	_page_holder.position = Vector2(86, 100)
	_page_holder.size = Vector2(BOOK_SIZE.x - 172, 796)
	_book.add_child(_page_holder)

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(86, 914)
	bottom.size = Vector2(BOOK_SIZE.x - 172, 84)
	bottom.add_theme_constant_override("separation", 14)
	_book.add_child(bottom)
	_prev = _button("<", _turn.bind(-1))
	_next = _button(">", _turn.bind(1))
	for arrow in [_prev, _next]:
		arrow.custom_minimum_size = Vector2(96, 84)
		arrow.add_theme_font_override("font", BODY_FONT)
		arrow.add_theme_font_size_override("font_size", 46)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", -6)
	_page_number = _label("", 30, FONT)
	_page_number.modulate.a = 0.8
	var close := Button.new()
	close.text = "Close"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	_ink(close, 40, FONT)
	close.pressed.connect(_close)
	middle.add_child(close)
	middle.add_child(_page_number)
	bottom.add_child(_prev)
	bottom.add_child(middle)
	bottom.add_child(_next)

# One page: a sheet of paper with a title and the text.
func _make_page(index: int) -> Control:
	var sheet := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAGE_COLOR
	style.set_corner_radius_all(14)
	style.border_color = Color(INK, 0.18)
	style.set_border_width_all(2)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3, 4)
	sheet.add_theme_stylebox_override("panel", style)
	sheet.size = _page_holder.size
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.position = Vector2(10, 6)
	box.size = sheet.size - Vector2(20, 12)
	box.add_theme_constant_override("separation", 14)
	sheet.add_child(box)
	box.add_child(_label(PAGES[index]["title"], 66, FONT))
	var body := _label(PAGES[index]["body"], 30, BODY_FONT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	return sheet

func _show_page(index: int) -> void:
	_index = index
	if _page:
		_page.queue_free()
	_page = _make_page(index)
	_page_holder.add_child(_page)
	_update_controls()

func _update_controls() -> void:
	_page_number.text = "Page %d of %d" % [_index + 1, PAGES.size()]
	_prev.disabled = _index == 0
	_next.disabled = _index == PAGES.size() - 1
	for arrow in [_prev, _next]:
		arrow.modulate.a = 0.3 if arrow.disabled else 1.0


## ---- TURNING THE PAGE ----
# The spine is on the left. Forward: the page you're reading folds over to the left,
# uncovering the next one. Back: the previous page folds back in from the spine.
func _turn(direction: int) -> void:
	var target := _index + direction
	if _busy or target < 0 or target >= PAGES.size():
		return
	_busy = true
	Sound.play("char_next" if direction > 0 else "back")
	var under: Control
	var flap: Control
	if direction > 0:
		under = _make_page(target)
		flap = _page
		_page_holder.add_child(under)
		_page_holder.move_child(under, 0)
	else:
		under = _page
		flap = _make_page(target)
		_page_holder.add_child(flap)
		flap.scale.x = 0.0
	flap.pivot_offset = Vector2(0, flap.size.y / 2.0)
	var shade := Color(0.75, 0.75, 0.75)
	var tween := create_tween().set_parallel(true)
	if direction > 0:
		tween.tween_property(flap, "scale:x", 0.0, TURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(flap, "modulate", shade, TURN_TIME)
	else:
		flap.modulate = shade
		tween.tween_property(flap, "scale:x", 1.0, TURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(flap, "modulate", Color.WHITE, TURN_TIME)
	await tween.finished
	if direction > 0:
		flap.queue_free()
		_page = under
	else:
		under.queue_free()
		_page = flap
	_index = target
	_update_controls()
	_busy = false


## ---- OPEN / CLOSE ----
func _start_rect() -> Rect2:
	if is_instance_valid(_from) and _from.is_visible_in_tree():
		return _from.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	return Rect2(screen / 2.0, Vector2.ONE)

func _open_animation() -> void:
	var screen := get_viewport().get_visible_rect().size
	var start := _start_rect()
	_book.pivot_offset = BOOK_SIZE / 2.0
	_book.position = start.get_center() - BOOK_SIZE / 2.0
	_book.scale = Vector2.ONE * clampf(start.size.x / BOOK_SIZE.x, 0.08, 0.6)
	_book.rotation = -0.3
	_book.modulate.a = 0.0
	_dim.color.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_book, "position", (screen - BOOK_SIZE) / 2.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_book, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_book, "rotation", 0.0, 0.35)
	tween.tween_property(_book, "modulate:a", 1.0, 0.15)
	tween.tween_property(_dim, "color:a", 0.5, 0.3)

func _close() -> void:
	if _busy:
		return
	_busy = true
	Sound.play("back")
	var start := _start_rect()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_book, "position", start.get_center() - BOOK_SIZE / 2.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_book, "scale", Vector2.ONE * clampf(start.size.x / BOOK_SIZE.x, 0.08, 0.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_book, "rotation", -0.3, 0.3)
	tween.tween_property(_book, "modulate:a", 0.0, 0.3).set_delay(0.1)
	tween.tween_property(_dim, "color:a", 0.0, 0.3)
	await tween.finished
	queue_free()


## ---- LOOKS (pencil on paper, like the other pop-ups) ----
func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	_ink(button, 46, FONT)
	InkBox.apply(button, INK)
	button.pressed.connect(action)
	return button

func _label(text: String, size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink(label, size, font)
	return label

func _ink(control: Control, size: int, font: Font) -> void:
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		control.add_theme_color_override(state, INK)
