extends Control
## The home screen's second page (swipe left from the apps): the Activity log, newest at
## the top, grouped by round. Each line says what happened and when, so a burst of
## notices (a Fortuna, the insurance paying out, rent...) can be read back in order.

const INK := Color("ddcf99")
const CARD := Color(0.32549, 0.235294, 0.266667, 0.9)
const KIND_COLORS := {
	"gain": Color("4c9a52"), "loss": Color("c94040"),
	"fortuna_good": Color("4c9a52"), "fortuna_bad": Color("c94040"),
	"error": Color("d08a3c"), "notice": Color("a78767"), "info": Color("92868b"),
}

var _list: VBoxContainer
var _empty: Label
var _last_round := -1   # round of the newest row shown (for the round headers)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 30
	card.offset_right = -30
	card.offset_top = 190
	card.offset_bottom = -230
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(36)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := _label("Activity", 44, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label("Everything that happened, newest first", 18, Color(INK, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_empty = _label("Nothing yet. Notices, Fortunas, purchases and sales will show up here.", 22, Color(INK, 0.7))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_empty)

	for entry in Activity.entries:
		_add_row(entry)
	_empty.visible = Activity.entries.is_empty()
	Activity.added.connect(func(entry: Dictionary):
		_add_row(entry)
		_empty.visible = false)

# Newest go on top, so each new row is inserted at index 0 (with a round header above it
# when the round changes).
func _add_row(entry: Dictionary) -> void:
	var kind: String = entry.get("kind", "info")
	if kind == "round":
		_list.add_child(_round_header(entry))
		_list.move_child(_list.get_child(_list.get_child_count() - 1), 0)
		_last_round = int(entry.get("round", 0))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var dot := Panel.new()   # colour says what kind of line it is
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = KIND_COLORS.get(kind, KIND_COLORS["info"])
	dot_style.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	var text := _label(str(entry.get("text", "")), 23, INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(text)
	words.add_child(_label("Round %d  ·  %s" % [int(entry.get("round", 0)), entry.get("time", "")], 15, Color(INK, 0.55)))
	row.add_child(words)
	_list.add_child(row)
	_list.move_child(row, 0)

func _round_header(entry: Dictionary) -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	for side in 2:
		var line := ColorRect.new()
		line.color = Color(INK, 0.3)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(line)
		if side == 0:
			header.add_child(_label(str(entry.get("text", "")), 20, Color(INK, 0.8)))
	return header

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
