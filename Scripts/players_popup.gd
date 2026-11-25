extends CanvasLayer
## Tap your name in the header: who's in the game and how their turn is going.
## You (character + name) at the top, a line, then every other player with their
## character, name and status ("2 Actions Remaining", "Finished turn", "Reconnecting...").
## Same framed look as pop_up.tscn; updates live; tap outside or Close to put it away.

const AvatarArt = preload("res://Scripts/avatar.gd")
const HAND_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const TEXT_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const FRAME_BG := Color("99966d")
const FRAME_BORDER := Color("f6f2e1")
const INK := Color(0, 0, 0)
const DONE_COLOR := Color("3f6b3f")     # "Finished turn"
const WAIT_COLOR := Color("793c44")     # the last player's countdown

var _dim: ColorRect
var _frame: PanelContainer
var _list: VBoxContainer
var _me_status: Label
var _rows := {}   # player name -> status Label


func _ready() -> void:
	layer = 60   # like the settings pop-up: above screens, below the Fortuna card
	Sound.play("open")
	_build()
	Turns.statuses_changed.connect(_refresh)
	Turns.waiting_changed.connect(func(_n): _refresh())
	Network.players_changed.connect(_rebuild_rows)
	var timer := Timer.new()   # the last player's seconds tick down
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	Turns.share_status()   # make sure our own line is current

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(centre)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(580, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_BG
	style.border_color = FRAME_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(26)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	style.anti_aliasing = true
	_frame.add_theme_stylebox_override("panel", style)
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP   # taps on the card don't close it
	centre.add_child(_frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_frame.add_child(box)

	# You
	var me := HBoxContainer.new()
	me.add_theme_constant_override("separation", 18)
	me.alignment = BoxContainer.ALIGNMENT_CENTER
	me.add_child(_face(Global.PLAYER, 96))
	var me_text := VBoxContainer.new()
	me_text.add_theme_constant_override("separation", 0)
	me_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	me_text.add_child(_label(Global.PLAYER, HAND_FONT, 52))
	_me_status = _label("", TEXT_FONT, 24)
	me_text.add_child(_me_status)
	me.add_child(me_text)
	box.add_child(me)

	var line := ColorRect.new()   # the divider
	line.color = INK
	line.custom_minimum_size = Vector2(0, 3)
	box.add_child(line)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	var scroll := ScrollContainer.new()   # 8 players fit; a scroll just in case
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_scroll = scroll

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 76)
	close.add_theme_font_override("font", HAND_FONT)
	close.add_theme_font_size_override("font_size", 44)
	close.focus_mode = Control.FOCUS_NONE
	InkBox.apply(close)
	close.pressed.connect(_close)
	box.add_child(close)

	_rebuild_rows()
	_pop_in()

var _scroll: ScrollContainer

func _others() -> Array:
	var names := []
	for id in Network.players:
		var n: String = Network.players[id]
		if n != Turns.my_name() and n != Global.PLAYER:
			names.append(n)
	for n in Network.away_names:   # dropped out, may come back
		if not n in names and n != Global.PLAYER:
			names.append(n)
	names.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	return names

func _rebuild_rows() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var others := _others()
	if others.is_empty():
		var alone := _label("No other players in this game.", TEXT_FONT, 26)
		alone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(alone)
	for n in others:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.add_child(_face(n, 72))
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := _label(n, HAND_FONT, 40)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(name_label)
		var status := _label("", TEXT_FONT, 24)
		text.add_child(status)
		row.add_child(text)
		_list.add_child(row)
		_rows[n] = status
	# up to ~5 rows without scrolling, then it scrolls
	_scroll.custom_minimum_size.y = clampf(others.size(), 1, 5) * 86.0
	_refresh()

func _refresh() -> void:
	if _me_status:
		var mine := Turns.status_text(Turns.my_name())
		if Turns.my_turn_done:
			mine = "You finished your turn"
		elif mine == "Playing...":
			mine = "%d Action%s Remaining" % [Global.ACTIONS, "" if Global.ACTIONS == 1 else "s"]
		_me_status.text = "Round %d  ·  %s" % [Global.ROUND, mine]
	for n in _rows:
		var label: Label = _rows[n]
		var text := Turns.status_text(n)
		label.text = text
		var colour := INK
		if text == "Finished turn":
			colour = DONE_COLOR
		elif Turns.countdown_name == n:
			colour = WAIT_COLOR
		label.add_theme_color_override("font_color", colour)

func _face(player_name: String, size: float) -> Control:
	var face: Control
	if AvatarArt.has_name(player_name):
		face = AvatarArt.for_player(player_name, size)
	else:   # no character yet: a plain circle with their initial
		face = Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("533c44")
		style.set_corner_radius_all(int(size))
		face.add_theme_stylebox_override("panel", style)
		var initial := _label(player_name.left(1).to_upper(), HAND_FONT, int(size * 0.5))
		initial.add_theme_color_override("font_color", FRAME_BORDER)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.add_child(initial)
	face.custom_minimum_size = Vector2(size, size)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ignore_taps(face)
	return face

func _ignore_taps(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_taps(child)

func _label(text: String, font: Font, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	return label

func _pop_in() -> void:
	await get_tree().process_frame
	_frame.pivot_offset = _frame.size / 2.0
	_frame.scale = Vector2(0.9, 0.9)
	_dim.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.12)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_close()

var _closing := false
func _close() -> void:
	if _closing:
		return
	_closing = true
	Sound.play("back")
	var tween := create_tween()
	tween.tween_property(_dim, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)
