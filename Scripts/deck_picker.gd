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
	box.position = Vector2(86, 180)   # below the tape
	box.size = Vector2(SIZE.x - 172, SIZE.y - 290)
	box.add_theme_constant_override("separation", 8)
	paper.add_child(box)
	box.add_child(_label("Property Deck", 58, FONT))
	_count = _label("", 26, BODY_FONT)
	box.add_child(_count)

	var scroll := ScrollContainer.new()
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
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(grid)
	for kind in kinds:
		grid.add_child(_card(kind))

# One property: its picture and name; tap to put it in (or take it out of) the deck.
func _card(kind: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var off := StyleBoxFlat.new()
	off.bg_color = Color(INK, 0.05)
	off.border_color = Color(INK, 0.3)
	off.set_border_width_all(2)
	off.set_corner_radius_all(16)
	var on := off.duplicate()
	on.bg_color = PICKED
	on.border_color = Color("ddcf99")
	on.set_border_width_all(3)
	for state in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, off)
	for state in ["pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, on)
	var inside := HBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 8
	inside.offset_right = -6
	inside.add_theme_constant_override("separation", 8)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inside)
	var icon := TextureRect.new()
	icon.texture = Cards.round_icon(Cards.templates_by_name[kind]["art"])
	icon.custom_minimum_size = Vector2(58, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(icon)
	var name := _label(kind, 19, BODY_FONT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.autowrap_mode = TextServer.AUTOWRAP_WORD
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.add_child(name)
	button.set_meta("label", name)
	button.button_pressed = kind in _picked
	button.toggled.connect(_on_toggled.bind(kind, button))
	_cards[kind] = button
	return button

func _on_toggled(on: bool, kind: String, button: Button) -> void:
	if on and not kind in _picked:
		if _picked.size() >= _target:   # full: say so instead of going over
			button.set_pressed_no_signal(false)
			Sound.play("error")
			_count.text = "That's %d already. Tap one to take it out first." % _target
			return
		_picked.append(kind)
	elif not on:
		_picked.erase(kind)
	Sound.play("switch" if on else "switch_off")
	_update()

func _update() -> void:
	_count.text = "Choose %d  ·  %d chosen" % [_target, _picked.size()]
	_done.disabled = _picked.size() != _target
	_done.modulate.a = 1.0 if not _done.disabled else 0.45
	for kind in _cards:
		var label: Label = _cards[kind].get_meta("label")
		label.add_theme_color_override("font_color", Color("f6f2e1") if kind in _picked else INK)

func _clear() -> void:
	Sound.play("switch_off")
	_picked.clear()
	for kind in _cards:
		_cards[kind].set_pressed_no_signal(false)
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
