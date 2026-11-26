extends CanvasLayer
## Lobby > Game Settings > Property Deck: the host picks exactly which 20 kinds of property
## are in this game's deck (each comes with its usual number of cards). Opened with the
## editions currently switched on in Game Settings.
##     var picker = DeckPicker.open(get_tree(), base_on, expansion_on, current_picks)
##     var picks = await picker.chosen     # [] = random, or the chosen names

signal chosen(picks: Array)

const PaperArt = preload("res://Scripts/paper_art.gd")   # the taped-paper card (drawn, not a picture)
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const INK := Color(0.1, 0.1, 0.1)
const PICKED := Color("5d6558")
const SIZE := Vector2(680, 1120)

var _base := true
var _expansion := false
var _target := 20
var _picked: Array = []
var _cards: Dictionary = {}   # name -> Button
var _count: Label
var _done: Button
var _scroll: ScrollContainer


static func open(tree: SceneTree, base: bool, expansion: bool, picks: Array) -> Node:
	var picker = load("res://Scripts/deck_picker.gd").new()
	picker._base = base
	picker._expansion = expansion
	picker._picked = picks.filter(func(n): return n in Cards.deck_kinds(base, expansion))
	tree.root.add_child(picker)
	return picker

func _ready() -> void:
	layer = 70   # over Game Settings (60)
	Sound.play("open")
	_target = Cards.deck_target(_base, _expansion)
	if _picked.is_empty():   # start from everything if that's exactly the deck
		var kinds := Cards.deck_kinds(_base, _expansion)
		if kinds.size() == _target:
			_picked = kinds.duplicate()
	_build()
	_update()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var paper := PaperArt.make()
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.offset_left = -SIZE.x / 2.0
	paper.offset_right = SIZE.x / 2.0
	paper.offset_top = -SIZE.y / 2.0 - 30
	paper.offset_bottom = SIZE.y / 2.0 - 30
	dim.add_child(paper)

	var box := VBoxContainer.new()
	box.position = Vector2(62, 180)   # below the tape
	box.size = Vector2(SIZE.x - 124, SIZE.y - 290)
	box.add_theme_constant_override("separation", 8)
	paper.add_child(box)
	box.add_child(_label("Property Deck", 58, FONT))
	_count = _label("", 26, BODY_FONT)
	box.add_child(_count)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var room := MarginContainer.new()   # keeps the cards clear of the scroll bar
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.add_theme_constant_override("margin_right", 16)
	scroll.add_child(room)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	room.add_child(list)
	if _base:
		_section(list, "Base Edition", Cards.deck_kinds(true, false))
	if _expansion:
		_section(list, "Expansion", Cards.deck_kinds(false, true))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var random := _button("Random", _choose_random)
	var clear := _button("Clear", _clear)
	_done = _button("Done", _finish)
	for b in [random, clear, _done]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)

func _section(list: VBoxContainer, title: String, kinds: Array) -> void:
	var heading := _label(title, 34, FONT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	for kind in kinds:
		grid.add_child(_card(kind))

# One property: its picture and name; tap to put it in (or take it out of) the deck.
# Not a Button: a Button swallowed the finger, so dragging on a card didn't scroll the
# list. The card lets the drag through to the list, and only a real tap (the finger
# barely moved and the list didn't scroll) flips it.
const CARD_HEIGHT := 96.0

func _card(kind: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS   # the scroll list still sees the drag
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(20)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.anti_aliasing = true
	card.add_theme_stylebox_override("panel", style)
	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 10)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inside)
	var icon := TextureRect.new()
	icon.texture = Cards.round_icon(Cards.templates_by_name[kind]["art"])
	icon.custom_minimum_size = Vector2(66, 66)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(icon)
	var name := _label(kind, 22, BODY_FONT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.add_child(name)
	var tick := Panel.new()   # picked: a small tick on the picture's corner
	var tick_style := StyleBoxFlat.new()
	tick_style.bg_color = PICKED.lightened(0.15)
	tick_style.border_color = Color("f6f2e1")
	tick_style.set_border_width_all(2)
	tick_style.set_corner_radius_all(15)
	tick.add_theme_stylebox_override("panel", tick_style)
	tick.size = Vector2(30, 30)
	tick.position = Vector2(42, -4)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := Control.new()   # drawn: phone browsers have no font with a ✓ in it
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func():
		var w := mark.size
		mark.draw_polyline(PackedVector2Array([Vector2(w.x * 0.27, w.y * 0.52), Vector2(w.x * 0.44, w.y * 0.69), Vector2(w.x * 0.74, w.y * 0.33)]),
				Color("f6f2e1"), 3.0, true))
	tick.add_child(mark)
	icon.add_child(tick)
	card.set_meta("label", name)
	card.set_meta("tick", tick)
	card.set_meta("style", style)
	card.gui_input.connect(_on_card_input.bind(kind, card))
	_cards[kind] = card
	_paint(kind)
	return card

var _press_pos := Vector2.INF
var _press_scroll := 0

func _on_card_input(event: InputEvent, kind: String, card: Control) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_press_pos = event.global_position
		_press_scroll = _scroll.scroll_vertical
		return
	var moved: float = _press_pos.distance_to(event.global_position)
	_press_pos = Vector2.INF
	if moved > Global.TAP_SLOP or absi(_scroll.scroll_vertical - _press_scroll) > 4:
		return   # that was a scroll, not a tap
	_toggle(kind, card)

func _toggle(kind: String, card: Control) -> void:
	var on := not kind in _picked
	if on:
		if _picked.size() >= _target:   # full: say so instead of going over
			Sound.play("error")
			_count.text = "That's %d already. Tap one to take it out first." % _target
			card.pivot_offset = card.size / 2.0
			var shake := card.create_tween()
			for x in [8.0, -8.0, 5.0, 0.0]:
				shake.tween_property(card, "position:x", card.position.x + x, 0.04)
			return
		_picked.append(kind)
	else:
		_picked.erase(kind)
	Sound.play("switch" if on else "switch_off")
	card.pivot_offset = card.size / 2.0
	var pop := card.create_tween()
	pop.tween_property(card, "scale", Vector2(0.95, 0.95), 0.05)
	pop.tween_property(card, "scale", Vector2.ONE, 0.09)
	_update()

func _paint(kind: String) -> void:
	var card: Control = _cards[kind]
	var on := kind in _picked
	var style: StyleBoxFlat = card.get_meta("style")
	style.bg_color = PICKED if on else Color(INK, 0.06)
	style.border_color = Color("ddcf99") if on else Color(INK, 0.3)
	style.set_border_width_all(3 if on else 2)
	(card.get_meta("label") as Label).add_theme_color_override("font_color", Color("f6f2e1") if on else INK)
	(card.get_meta("tick") as Control).visible = on

func _update() -> void:
	_count.text = "Choose %d  ·  %d chosen" % [_target, _picked.size()]
	_done.disabled = _picked.size() != _target
	_done.modulate.a = 1.0 if not _done.disabled else 0.45
	for kind in _cards:
		_paint(kind)

func _clear() -> void:
	Sound.play("switch_off")
	_picked.clear()
	_update()

func _choose_random() -> void:
	Sound.play("back")
	chosen.emit([])
	queue_free()

func _finish() -> void:
	if _picked.size() != _target:
		return
	Sound.play("saved")
	chosen.emit(_picked.duplicate())
	queue_free()

func _label(text: String, size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 40)
	InkBox.apply(button, INK)
	button.pressed.connect(action)
	return button
