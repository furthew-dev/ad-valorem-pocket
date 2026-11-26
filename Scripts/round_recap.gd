extends CanvasLayer
## Between rounds, before the "Round N" curtain: what happened last round, and the standings.
##   Highlights: the biggest buy, the best and the roughest round, sabotage, a bad Fortuna.
##   Standings: every player's net worth, how much it moved this round, and a bar towards
##   the win (cash over the End Goal with no loans).
## Each phone builds it from what it already has: the table's moments (messages.gd) and
## every player's shared status (Turns.statuses, which carries net worth / cash / loans).
##     await RoundRecap.show_for(get_tree(), data).closed
## `data` comes from Turns.recap_data(), taken the moment the next round is called.

signal closed

const AvatarArt = preload("res://Scripts/avatar.gd")
const HAND_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")
const CREAM := Color("f6f2e1")
const GOLD := Color("ddcf99")
const CARD := Color("533c44")
const ROW := Color("49343d")
const ME_EDGE := Color("ddcf99")
const UP := Color("7fd17f")
const DOWN := Color("ff8a7e")
const BAR_BG := Color(1, 1, 1, 0.12)
const BAR := Color("d4af37")
const AUTO_CLOSE := 20.0   # seconds, so an idle phone doesn't sit here

var data: Dictionary = {}
var _left := AUTO_CLOSE
var _button: Button
var _done := false

static func show_for(tree: SceneTree, recap: Dictionary) -> Node:
	var overlay = load("res://Scripts/round_recap.gd").new()
	overlay.data = recap
	tree.root.add_child(overlay)
	return overlay

func _ready() -> void:
	layer = 92   # over screens and the header; the Round curtain (90) comes after
	_build()
	Sound.play("open")

func _process(delta: float) -> void:
	if _done:
		return
	_left -= delta
	if is_instance_valid(_button):
		_button.text = "Start Round %d  (%d)" % [int(data.get("next_round", 2)), maxi(ceili(_left), 0)]
	if _left <= 0.0:
		_close()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.1, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 34
	page.offset_right = -34
	page.offset_top = 70
	page.offset_bottom = -60
	page.add_theme_constant_override("separation", 14)
	add_child(page)

	var title := _label("Round %d Recap" % int(data.get("round", 1)), HAND_FONT, 76, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)

	var highlights := _highlights()
	if not highlights.is_empty():
		page.add_child(_heading("HIGHLIGHTS"))
		for h in highlights:
			page.add_child(_highlight_card(h[0], h[1], h[2]))

	page.add_child(_heading("STANDINGS"))
	var standings := VBoxContainer.new()
	standings.add_theme_constant_override("separation", 10)
	standings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(standings)
	var players: Array = data.get("players", [])
	for i in players.size():
		standings.add_child(_standing_row(i + 1, players[i]))
	var goal := _label("The game ends after a round where someone has more than $%d cash and no loans. Highest net worth wins." % int(data.get("goal", 0)), FONT, 19, Color(CREAM, 0.65))
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(goal)

	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size.y = 92
	_button.add_theme_font_override("font", BOLD)
	_button.add_theme_font_size_override("font_size", 32)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_button.add_theme_color_override(c, CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := _style(Color("5d6558").darkened(0.12 if state == "pressed" else 0.0), 46, CREAM, 3)
		_button.add_theme_stylebox_override(state, style)
	_button.pressed.connect(_close)
	page.add_child(_button)
	_keep_all(self)
	_pop_in(page)

# [caption, line, colour] for each highlight worth showing (at most 4).
func _highlights() -> Array:
	var me := Turns.my_name()
	var list := []
	var moments: Array = data.get("moments", [])
	var buys := moments.filter(func(m): return m.get("kind", "") in ["buy", "auction"])
	if not buys.is_empty():
		buys.sort_custom(func(a, b): return int(a.get("amount", 0)) > int(b.get("amount", 0)))
		list.append(["BIGGEST BUY", Messages.describe(buys[0]), GOLD])
	var players: Array = data.get("players", [])
	var solo := players.size() <= 1
	var by_delta := players.duplicate()
	by_delta.sort_custom(func(a, b): return int(a["delta"]) > int(b["delta"]))
	if solo and not players.is_empty():
		var d: int = players[0]["delta"]
		if d != 0:
			list.append(["YOUR ROUND", "Your net worth %s $%d." % ["grew by" if d > 0 else "fell by", absi(d)], UP if d > 0 else DOWN])
	elif not by_delta.is_empty():
		var best: Dictionary = by_delta[0]
		if int(best["delta"]) > 0:
			list.append(["BEST ROUND", "%s  +$%d" % ["You" if best["name"] == me else best["name"], best["delta"]], UP])
		var worst: Dictionary = by_delta[-1]
		if int(worst["delta"]) < 0:
			list.append(["ROUGH ROUND", "%s  -$%d" % ["You" if worst["name"] == me else worst["name"], absi(worst["delta"])], DOWN])
	var sabotage := moments.filter(func(m): return m.get("kind", "") == "sabotage")
	if not sabotage.is_empty():
		list.append(["SABOTAGE", Messages.describe(sabotage[-1]), DOWN])
	var sales := moments.filter(func(m): return m.get("kind", "") == "sell")
	if list.size() < 4 and not sales.is_empty():
		sales.sort_custom(func(a, b): return int(a.get("amount", 0)) > int(b.get("amount", 0)))
		list.append(["BIGGEST SALE", Messages.describe(sales[0]), GOLD])
	var unlucky := moments.filter(func(m): return m.get("kind", "") == "fortuna_bad")
	if list.size() < 4 and not unlucky.is_empty():
		list.append(["FORTUNA", Messages.describe(unlucky[-1]), DOWN])
	if list.is_empty():
		list.append(["QUIET ROUND", "Nobody bought, sold or sabotaged anything.", Color(CREAM, 0.8)])
	return list.slice(0, 4)

func _highlight_card(caption: String, line: String, colour: Color) -> Control:
	var card := PanelContainer.new()
	var style := _style(CARD, 24)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	box.add_child(_label(caption, BOLD, 17, colour))
	var text := _label(line, FONT, 25, CREAM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 600   # (a wrapping label needs a width, or it stands tall)
	box.add_child(text)
	return card

func _standing_row(rank: int, p: Dictionary) -> Control:
	var me: bool = p["name"] == Turns.my_name()
	var row := PanelContainer.new()
	var style := _style(ROW, 26, ME_EDGE if me else Color(0, 0, 0, 0), 3 if me else 0)
	style.content_margin_left = 14
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)
	var place := _label(str(rank), HAND_FONT, 40, GOLD if rank == 1 else Color(CREAM, 0.7))
	place.custom_minimum_size.x = 30
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(place)
	line.add_child(_face(str(p["name"]), 62))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 6)
	line.add_child(middle)
	middle.add_child(_label("You" if me else str(p["name"]), BOLD, 26, CREAM))
	middle.add_child(_bar(float(p.get("progress", 0.0))))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size.x = 104   # the bars all end in the same place
	line.add_child(right)
	var worth := _label("$%d" % int(p["worth"]), BOLD, 30, CREAM)
	worth.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(worth)
	var d: int = int(p["delta"])
	var change := _label(("+$%d" % d) if d >= 0 else ("-$%d" % -d), BOLD, 20, UP if d > 0 else (DOWN if d < 0 else Color(CREAM, 0.6)))
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(change)
	return row

# Towards the win: cash minus loans, as a share of the End Goal.
func _bar(progress: float) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func():
		var r := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r, BAR_BG)
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * clampf(progress, 0.0, 1.0), bar.size.y)), BAR))
	return bar

func _face(player_name: String, size: float) -> Control:
	if AvatarArt.has_name(player_name):
		var art := AvatarArt.for_player(player_name, size)
		art.custom_minimum_size = Vector2(size, size)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return art
	var face := Control.new()
	face.custom_minimum_size = Vector2(size, size)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.draw.connect(func(): face.draw_circle(Vector2(size, size) / 2.0, size / 2.0, CARD, true, -1.0, true))
	var initial := _label(player_name.left(1).to_upper(), HAND_FONT, int(size * 0.5), CREAM)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_child(initial)
	return face

func _heading(text: String) -> Control:
	var label := _label(text, BOLD, 20, GOLD)
	return label

func _pop_in(page: Control) -> void:
	page.modulate.a = 0.0
	page.position.y += 30
	var tween := create_tween().set_parallel()
	tween.tween_property(page, "modulate:a", 1.0, 0.3)
	tween.tween_property(page, "position:y", page.position.y - 30, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _close() -> void:
	if _done:
		return
	_done = true
	Sound.play("continue")
	var tween := create_tween()
	tween.tween_property(get_child(1), "modulate:a", 0.0, 0.2)
	await tween.finished
	closed.emit()
	queue_free()

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
	return label

# Its own dark look in every theme (like the Round curtain).
func _keep_all(node: Node) -> void:
	ColorTheme.keep(node)
	for child in node.get_children():
		_keep_all(child)
