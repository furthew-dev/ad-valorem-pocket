extends Control
## The home screen's second page (swipe left from the apps): the Activity log, newest at
## the top. Each line says what happened and when, so a burst of notices (a Fortuna, the
## insurance paying out, rent...) can be read back in order.
##
## Built for phones: nothing is made until the page is first looked at, only the newest
## PAGE_SIZE lines are made at a time ("Show older" adds more), every line is just a few
## cheap nodes coloured here (so the theme code doesn't have to walk them), and the list
## scrolls by dragging a finger on it.

const PAGE_SIZE := 40
const INK := Color("ddcf99")
const CARD := Color(0.32549, 0.235294, 0.266667, 0.9)
const KIND_COLORS := {
	"gain": Color("4c9a52"), "loss": Color("c94040"),
	"fortuna_good": Color("4c9a52"), "fortuna_bad": Color("c94040"),
	"error": Color("d08a3c"), "notice": Color("a78767"), "info": Color("92868b"),
}

var _built := false
var _shown := 0            # how many entries (newest first) have rows
var _list: VBoxContainer
var _scroll: ScrollContainer
var _empty: Label
var _older: Button
var _ink := INK

# finger scrolling
var _drag_from := -1.0     # finger y where the drag started (-1: not dragging)
var _drag_scroll := 0
var _velocity := 0.0
var _last_y := 0.0
var _dragged_far := false


func _ready() -> void:
	theme = preload("res://main_theme.tres")   # the game's font, like every other screen
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Activity.added.connect(_on_added)

# Called by the home screen the first time this page slides into view.
func build() -> void:
	if _built:
		return
	_built = true
	_ink = ColorTheme.map_color(INK, "text")
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 30
	card.offset_right = -30
	card.offset_top = 190
	card.offset_bottom = -230
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.map_color(CARD, "fill")
	style.set_corner_radius_all(36)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	_keep(card)
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep(box)
	card.add_child(box)
	var title := _label("Activity", 44, _ink)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label("Everything that happened, newest first", 18, Color(_ink, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # the finger scrolls it
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE   # our own drag code below does the scrolling
	_keep(_scroll)
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep(_list)
	_scroll.add_child(_list)

	_older = Button.new()
	_older.text = "Show older"
	_older.flat = true
	_older.focus_mode = Control.FOCUS_NONE
	_older.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		_older.add_theme_color_override(state, Color(_ink, 0.8))
	_older.pressed.connect(_show_more)
	_keep(_older)
	_list.add_child(_older)

	_empty = _label("Nothing yet. Notices, Fortunas, purchases and sales will show up here.", 22, Color(_ink, 0.7))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_empty)
	_show_more()

# Adds the next PAGE_SIZE older rows under the ones already shown.
func _show_more() -> void:
	if _dragged_far:
		_dragged_far = false
		return
	var entries: Array = Activity.entries
	var stop := maxi(entries.size() - _shown - PAGE_SIZE, 0)
	for i in range(entries.size() - _shown - 1, stop - 1, -1):
		var row := _make_row(entries[i])
		_list.add_child(row)
		_list.move_child(_older, _list.get_child_count() - 1)   # keep the button last
		_shown += 1
	_older.visible = _shown < entries.size()
	_empty.visible = entries.is_empty()

func _on_added(entry: Dictionary) -> void:
	if not _built:
		return   # rows are made when the page is opened
	_list.add_child(_make_row(entry))
	_list.move_child(_list.get_child(_list.get_child_count() - 1), 0)
	_shown += 1
	_empty.visible = false
	# Don't let the list grow without end while the page stays open.
	while _list.get_child_count() > PAGE_SIZE * 3:
		var last := _list.get_child(_list.get_child_count() - 2)   # the row above "Show older"
		_list.remove_child(last)
		last.queue_free()
		_shown -= 1
		_older.visible = true

func _make_row(entry: Dictionary) -> Control:
	var kind: String = entry.get("kind", "info")
	if kind == "round":
		var header := _label("—  %s  —" % entry.get("text", ""), 20, Color(_ink, 0.75))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return header
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep(row)
	var dot := Panel.new()   # colour says what kind of line it is
	dot.add_theme_stylebox_override("panel", _dot_style(kind))
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep(dot)
	row.add_child(dot)
	var text := _label(str(entry.get("text", "")), 23, _ink)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep(words)
	words.add_child(text)
	words.add_child(_label("Round %d  ·  %s" % [int(entry.get("round", 0)), entry.get("time", "")], 15, Color(_ink, 0.55)))
	row.add_child(words)
	return row

var _dot_styles: Dictionary = {}   # kind -> one shared round StyleBox

func _dot_style(kind: String) -> StyleBoxFlat:
	if not _dot_styles.has(kind):
		var style := StyleBoxFlat.new()
		style.bg_color = KIND_COLORS.get(kind, KIND_COLORS["info"])
		style.set_corner_radius_all(7)
		_dot_styles[kind] = style
	return _dot_styles[kind]

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_keep(label)
	return label

# Already in the theme's colours: the theme code can skip it.
func _keep(node: Node) -> void:
	node.set_meta("ct_skip", true)


## ---- FINGER SCROLLING ----
# Drag up / down anywhere on the list; it keeps gliding a little after letting go.
func _input(event: InputEvent) -> void:
	if not _built or not is_visible_in_tree() or _scroll == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _scroll.get_global_rect().has_point(event.position) and _on_screen():
			_drag_from = event.position.y
			_drag_scroll = _scroll.scroll_vertical
			_last_y = event.position.y
			_velocity = 0.0
			_dragged_far = false
			set_process(true)
		elif not event.pressed and _drag_from >= 0.0:
			_drag_from = -1.0
			set_process(true)   # glide
	elif event is InputEventMouseButton and event.pressed and _on_screen() \
			and _scroll.get_global_rect().has_point(event.position):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll.scroll_vertical -= 60
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll.scroll_vertical += 60
	elif event is InputEventMouseMotion and _drag_from >= 0.0:
		_scroll.scroll_vertical = _drag_scroll - int(event.position.y - _drag_from)
		if absf(event.position.y - _drag_from) > 12.0:
			_dragged_far = true   # a scroll, not a tap on "Show older"
		_velocity = _last_y - event.position.y
		_last_y = event.position.y

func _process(delta: float) -> void:
	if _drag_from >= 0.0:
		return
	if absf(_velocity) < 0.5 or _scroll == null:
		set_process(false)
		return
	_scroll.scroll_vertical += int(_velocity)
	_velocity = lerpf(_velocity, 0.0, minf(delta * 6.0, 1.0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		set_process(false)

# Only when this page is the one in view (not mid-swipe off to the side).
func _on_screen() -> bool:
	return absf(position.x) < 4.0
