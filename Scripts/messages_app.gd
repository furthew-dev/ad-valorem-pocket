extends CanvasLayer
## Messages app (Scenes/messages.tscn): the texts in messages.gd.
## The list: one row per conversation (face, name, last text, unread count), newest first.
## A conversation: speech bubbles (theirs on the left, yours on the right, a line for each
## round), and for players / Everyone a row of preset replies to send back.

const AvatarArt = preload("res://Scripts/avatar.gd")
const HAND_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")
const BANK_ICON := "res://Assets/icons/bank_icon.png"
const FORTUNA_ICON := "res://Assets/icons/question_marks_icon.png"
const GROUP_ICON := "res://Assets/icons/person.png"

const CREAM := Color("f6f2e1")
const ROW_BG := Color("533c44")
const THEIRS := Color("533c44")
const MINE := Color("5d6558")
const FACE_BG := Color("49343d")
const UNREAD := Color("e0453a")
const GAIN := Color("7fd17f")
const LOSS := Color("ff8a7e")
const BUBBLE_MAX := 430.0
const TINT_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * COLOR.a); }
"""

@onready var content: Control = $Content
@onready var ui_menu_frame: Control = $"UI Menu Frame"

var current_scene := "res://Scenes/messages.tscn"
var thread := ""                 # the conversation on screen ("" = the list)
var _scroll: ScrollContainer
var _tint: ShaderMaterial


func _ready() -> void:
	var wanted := Messages.take_wanted()
	_show(wanted if Messages.threads.has(wanted) else "")
	Messages.changed.connect(_on_changed)
	Messages.open_asked.connect(func():
		var contact := Messages.take_wanted()
		if Messages.threads.has(contact):
			_show(contact))

func _exit_tree() -> void:
	Messages.viewing = ""

func _on_changed() -> void:
	_show.call_deferred(thread)

func _show(contact: String) -> void:
	thread = contact
	Messages.viewing = contact
	if contact != "":
		Messages.mark_read(contact)
	for child in content.get_children():
		child.queue_free()
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_top = 178
	page.offset_bottom = -178
	page.offset_left = 22
	page.offset_right = -22
	page.add_theme_constant_override("separation", 12)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(page)
	if contact == "":
		_build_list(page)
	else:
		_build_thread(page, contact)


## ---- THE LIST ----
func _build_list(page: VBoxContainer) -> void:
	var title := _label("Messages", HAND_FONT, 64, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	_scroll = _make_scroll(page)
	var list := _scroll.get_child(0) as VBoxContainer
	var contacts := Messages.contacts()
	if contacts.is_empty():
		var empty := _label("No messages yet.\nWhen another player, the Bank or a Fortuna has something to tell you, it shows up here.", FONT, 24, Color(CREAM, 0.75))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(600, 0)
		list.add_child(_gap(30))
		list.add_child(empty)
		return
	for contact in contacts:
		list.add_child(_row(contact))

func _row(contact: String) -> Control:
	var row := PanelContainer.new()
	var style := _style(ROW_BG, 30)
	style.content_margin_left = 16
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	row.add_theme_stylebox_override("panel", style)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(line)
	line.add_child(_face(contact, 76))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(words)
	var count: int = int(Messages.unread.get(contact, 0))
	words.add_child(_label(_title_of(contact), BOLD if count > 0 else FONT, 30, CREAM))
	var texts: Array = Messages.threads.get(contact, [])
	var last: Dictionary = texts[-1] if not texts.is_empty() else {}
	var preview := _label(_preview(contact, last), FONT, 21, Color(CREAM, 0.72))
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview.clip_text = true
	preview.custom_minimum_size.x = 380
	words.add_child(preview)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 6)
	side.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(side)
	if not last.is_empty():
		var when := _label("Round %d" % int(last.get("round", 1)), FONT, 17, Color(CREAM, 0.6))
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		side.add_child(when)
	if count > 0:
		side.add_child(_badge(count))
	_on_tap(row, _open.bind(contact))
	return row

func _title_of(contact: String) -> String:
	return "Everyone at the table" if contact == Messages.EVERYONE else contact

func _preview(contact: String, last: Dictionary) -> String:
	if last.is_empty():
		return ""
	var text: String = str(last.get("text", ""))
	if last.get("mine", false):
		return text if text.begins_with("You ") else "You: " + text
	if contact == Messages.EVERYONE and last.get("kind", "") == "reaction":
		return "%s: %s" % [last.get("from", "?"), text]
	return text

func _badge(count: int) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(40, 40)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func():
		badge.draw_circle(Vector2(20, 20), 19, CREAM, true, -1.0, true)
		badge.draw_circle(Vector2(20, 20), 16, UNREAD, true, -1.0, true))
	var number := _label(str(mini(count, 99)), BOLD, 18 if count < 10 else 15, CREAM)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(number)
	ColorTheme.keep(badge)
	return badge

func _open(contact: String) -> void:
	Sound.play("click")
	_show(contact)


## ---- A CONVERSATION ----
func _build_thread(page: VBoxContainer, contact: String) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	page.add_child(top)
	var back := Button.new()
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(64, 64)
	for state in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	back.draw.connect(func():   # a chevron (the fonts have no arrow characters)
		var c := Vector2(32, 32)
		back.draw_polyline(PackedVector2Array([c + Vector2(8, -16), c + Vector2(-8, 0), c + Vector2(8, 16)]), CREAM, 6.0, true))
	back.pressed.connect(func():
		Sound.play("back")
		_show(""))
	ColorTheme.keep(back)
	top.add_child(back)
	top.add_child(_face(contact, 64))
	var name_label := _label(_title_of(contact), BOLD, 32, CREAM)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)

	_scroll = _make_scroll(page)
	var list := _scroll.get_child(0) as VBoxContainer
	list.add_theme_constant_override("separation", 10)
	var shown_round := -1
	for entry in Messages.threads.get(contact, []):
		var r: int = int(entry.get("round", 1))
		if r != shown_round:
			shown_round = r
			list.add_child(_round_line(r))
		list.add_child(_bubble(contact, entry))
	_scroll_to_end.call_deferred()

	if Messages.is_player(contact) or contact == Messages.EVERYONE:
		page.add_child(_reply_bar(contact))
	else:
		var note := _label("Automatic messages from the game.", FONT, 18, Color(CREAM, 0.6))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(note)

func _round_line(r: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in 2:
		var rule := ColorRect.new()
		rule.color = Color(CREAM, 0.25)
		rule.custom_minimum_size = Vector2(0, 2)
		rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ColorTheme.keep(rule)
		row.add_child(rule)
		if i == 0:
			row.add_child(_label("Round %d" % r, FONT, 18, Color(CREAM, 0.6)))
	return row

func _bubble(contact: String, entry: Dictionary) -> Control:
	var mine: bool = entry.get("mine", false)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 2)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	if contact == Messages.EVERYONE and not mine and entry.get("kind", "") == "reaction":   # who said it
		var who := _label(str(entry.get("from", "?")), BOLD, 17, Color(CREAM, 0.7))
		who.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		who.custom_minimum_size.x = 0
		var indent := MarginContainer.new()   # line up with the bubble, past the face
		indent.add_theme_constant_override("margin_left", 54)
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indent.add_child(who)
		holder.add_child(indent)
	var bubble := PanelContainer.new()
	var style := _style(MINE if mine else THEIRS, 26)
	if mine:
		style.corner_radius_bottom_right = 6
	else:
		style.corner_radius_bottom_left = 6
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", style)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	bubble.mouse_filter = Control.MOUSE_FILTER_PASS
	var text: String = str(entry.get("text", ""))
	var colour := CREAM
	match str(entry.get("kind", "")):
		"gain": colour = GAIN.lerp(CREAM, 0.35)
		"loss": colour = LOSS.lerp(CREAM, 0.35)
	var size := 28 if entry.get("kind", "") == "reaction" else 24
	var label := _label(text, BOLD if entry.get("kind", "") == "reaction" else FONT, size, colour)
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 4
	if width > BUBBLE_MAX:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = BUBBLE_MAX
	bubble.add_child(label)
	if mine:
		holder.add_child(bubble)
		holder.alignment = BoxContainer.ALIGNMENT_END
		return holder
	# Theirs: who it's from, as a small face beside the bubble (a player, the Bank, Fortuna).
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	var sender := str(entry.get("from", contact))
	var face := _face(sender if contact == Messages.EVERYONE else contact, 44)
	face.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(face)
	line.add_child(bubble)
	holder.add_child(line)
	return holder

func _reply_bar(contact: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var in_game := contact == Messages.EVERYONE or Messages._peer_of(contact) != 0
	if not Network.is_online() or not in_game:
		var gone := _label("%s isn't in this game anymore." % contact if Network.is_online() else "Replies work in online games.", FONT, 18, Color(CREAM, 0.6))
		gone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(gone)
		return box
	var hint := _label("Reply to everyone:" if contact == Messages.EVERYONE else "Reply to %s:" % contact, FONT, 18, Color(CREAM, 0.65))
	box.add_child(hint)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	box.add_child(chips)
	for phrase in Messages.REACTIONS:
		var chip := Button.new()
		chip.text = phrase
		chip.focus_mode = Control.FOCUS_NONE
		chip.add_theme_font_override("font", BOLD)
		chip.add_theme_font_size_override("font_size", 21)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			chip.add_theme_color_override(c, CREAM)
		ColorTheme.keep_text(chip)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := _style(MINE.darkened(0.15) if state == "pressed" else MINE, 22, Color(CREAM, 0.5), 2)
			style.content_margin_left = 16
			style.content_margin_right = 16
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			chip.add_theme_stylebox_override(state, style)
		chip.pressed.connect(func():
			if not Messages.react(contact, phrase):
				Sound.play("error"))
		chips.add_child(chip)
	return box


## ---- FACES ----
func _face(contact: String, size: float) -> Control:
	if Messages.is_player(contact) and AvatarArt.has_name(contact):
		var art := AvatarArt.for_player(contact, size)
		art.custom_minimum_size = Vector2(size, size)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_ignore(art)
		return art
	var face := Control.new()
	face.custom_minimum_size = Vector2(size, size)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func():
		face.draw_circle(Vector2(size, size) / 2.0, size / 2.0, FACE_BG, true, -1.0, true)
		face.draw_circle(Vector2(size, size) / 2.0, size / 2.0 - 1.5, Color(CREAM, 0.6), false, 2.0, true))
	var icon_path: String = {Messages.BANK: BANK_ICON, Messages.FORTUNA: FORTUNA_ICON, Messages.EVERYONE: GROUP_ICON}.get(contact, "")
	if icon_path != "":
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(size, size) * 0.22
		icon.size = Vector2(size, size) * 0.56
		icon.material = _tint_material()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(icon)
	else:   # a player with no character: their initial
		var initial := _label(contact.left(1).to_upper(), HAND_FONT, int(size * 0.5), CREAM)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.add_child(initial)
	_keep_all(face)
	return face

func _tint_material() -> ShaderMaterial:
	if _tint == null:
		var shader := Shader.new()
		shader.code = TINT_SHADER
		_tint = ShaderMaterial.new()
		_tint.shader = shader
		_tint.set_shader_parameter("tint", CREAM)
	return _tint


## ---- HELPERS ----
func _make_scroll(page: VBoxContainer) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	return scroll

func _scroll_to_end() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

# A tap (finger barely moved, list didn't scroll) runs `action`; a drag scrolls.
func _on_tap(control: Control, action: Callable) -> void:
	var down := {"at": Vector2.ZERO, "scroll": 0, "active": false}
	control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				down["at"] = event.global_position
				down["scroll"] = _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
				down["active"] = true
			elif down["active"]:
				down["active"] = false
				var still: bool = event.global_position.distance_to(down["at"]) <= Global.TAP_SLOP
				var same: bool = not is_instance_valid(_scroll) or absi(_scroll.scroll_vertical - int(down["scroll"])) < 4
				if still and same:
					action.call())

func _style(bg: Color, radius: int, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	return style

func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorTheme.keep(label)   # cream on the dark rows and bubbles in every theme
	return label

func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap

func _ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore(child)

func _keep_all(node: Node) -> void:
	ColorTheme.keep(node)
	for child in node.get_children():
		_keep_all(child)
