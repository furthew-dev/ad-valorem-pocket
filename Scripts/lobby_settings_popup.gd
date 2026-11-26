extends CanvasLayer
## Host-only "Game Settings" pop-up (lobby / Play Solo): a framed card in the pop-up style.
##
##   MONEY & PROPERTIES   Starting Cash      [-]  $20  [+]
##                        Starting Properties [-]   4  [+]
##                        End Goal           [-] $200 [+]
##   RULES                Last-Turn Timer          (switch)
##   EDITIONS             Base Edition / Expansion (switches)
##   PROPERTY DECK        [ Random  > ]
##                        [ Save ]   [ Cancel ]
##
## Each number has big - / + buttons (hold to repeat) and can also be tapped to type.
## Starting cash must be less than the end goal (Network.settings_problem).

const FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const BOLD = preload("res://Assets/fonts/Comfortaa-Bold.ttf")
const TITLE_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
# Palette colours, so the themes recolour it.
const FRAME_BG := Color("99966d")
const FRAME_EDGE := Color("f6f2e1")
const ROW_BG := Color("7b7e63")
const INK := Color("2e2328")
const CREAM := Color("f6f2e1")
const GREEN := Color("5d6558")
const RED := Color("b03030")

# key, label, hint, step, prefix
const ROWS := [
	["start_cash", "Starting Cash", "Each player starts with", 5, "$"],
	["start_properties", "Starting Properties", "Deeds dealt to each player", 1, ""],
	["end_goal", "End Goal", "Cash to end the game (no loans)", 10, "$"],
]

var _boxes: Dictionary = {}   # key -> LineEdit (the number)
var _timer_switch: InkSwitch
var _base_switch: InkSwitch
var _expansion_switch: InkSwitch
var _error: Label
var _deck_picks: Array = []   # [] = random deck
var _deck_button: Button
var _frame: PanelContainer
var _dim: ColorRect


func _ready() -> void:
	layer = 60
	Sound.play("open")
	_build()
	_pop_in()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(centre)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(660, 0)
	_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := _style(FRAME_BG, 30, FRAME_EDGE, 4)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 18
	style.content_margin_bottom = 22
	_frame.add_theme_stylebox_override("panel", style)
	centre.add_child(_frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_frame.add_child(box)

	var title := _label("Game Settings", TITLE_FONT, 60, INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_heading("MONEY & PROPERTIES"))
	for row in ROWS:
		box.add_child(_stepper_row(row))

	box.add_child(_heading("RULES"))
	_timer_switch = _switch_row(box, "Last-Turn Timer", "The last player gets 30 seconds", Network.game_settings.get("turn_timer", true))

	box.add_child(_heading("EDITIONS"))
	_base_switch = _switch_row(box, "Base Edition", "The original 20 properties", Network.game_settings.get("base", true))
	_expansion_switch = _switch_row(box, "Expansion", "Regions, new properties and Fortunas", Network.game_settings.get("expansion", false))

	box.add_child(_heading("PROPERTY DECK"))
	_deck_picks = Network.game_settings.get("deck_picks", []).duplicate()
	_deck_button = _wide_button("", ROW_BG, _open_deck_picker)
	box.add_child(_deck_button)
	for toggle in [_base_switch, _expansion_switch]:
		toggle.toggled.connect(func(_on): _update_deck_button())
	_update_deck_button()

	_error = _label("", BOLD, 24, RED)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	box.add_child(_error)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	var save := _wide_button("Save", GREEN, _save)
	var cancel := _wide_button("Cancel", ROW_BG, _close)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(cancel)
	buttons.add_child(save)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	box.add_child(gap)
	box.add_child(buttons)

# "Starting Cash  (Cash each player starts with)       [-]  $20  [+]"
func _stepper_row(row: Array) -> Control:
	var key: String = row[0]
	var limits: Array = Network.SETTING_LIMITS[key]
	var card := PanelContainer.new()
	var style := _style(ROW_BG, 22)
	style.content_margin_left = 18
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	card.add_child(line)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.add_child(_label(row[1], BOLD, 27, CREAM))
	var hint := _label("%s%d to %s%d" % [row[4], limits[0], row[4], limits[1]], FONT, 19, Color(CREAM, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(hint)
	line.add_child(words)

	var minus := _round_button("–")
	line.add_child(minus)
	var field := LineEdit.new()
	field.text = str(Network.game_settings.get(key, Network.DEFAULT_SETTINGS[key]))
	field.placeholder_text = "%d to %d" % [limits[0], limits[1]]   # also the phone prompt's title
	field.max_length = 3
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.custom_minimum_size = Vector2(104, 64)
	field.add_theme_font_override("font", BOLD)
	field.add_theme_font_size_override("font_size", 40)
	field.add_theme_color_override("font_color", CREAM)
	field.add_theme_color_override("caret_color", CREAM)
	field.add_theme_color_override("font_placeholder_color", Color(CREAM, 0.4))
	for state in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	field.text_changed.connect(_digits_only.bind(field))
	field.text_submitted.connect(func(_t): _save())
	field.set_meta("prefix", row[4])
	line.add_child(field)
	var plus := _round_button("+")
	line.add_child(plus)
	_boxes[key] = field
	_hold_to_repeat(minus, func(): _step(key, -int(row[3])))
	_hold_to_repeat(plus, func(): _step(key, int(row[3])))
	return card

func _step(key: String, by: int) -> void:
	var field: LineEdit = _boxes[key]
	var limits: Array = Network.SETTING_LIMITS[key]
	var value := int(field.text) if field.text.is_valid_int() else int(Network.DEFAULT_SETTINGS[key])
	var next := clampi(value + by, limits[0], limits[1])
	if by > 0 and value % by != 0 and absi(by) > 1:   # land on round numbers ($23 -> $25)
		next = clampi(value + by - posmod(value, by), limits[0], limits[1])
	elif by < 0 and posmod(value, -by) != 0:
		next = clampi(value - posmod(value, -by), limits[0], limits[1])
	if next == value:
		Sound.play("error")
		return
	field.text = str(next)
	Sound.play("click")
	_error.visible = false
	field.pivot_offset = field.size / 2.0
	var pop := field.create_tween()
	pop.tween_property(field, "scale", Vector2(1.15, 1.15), 0.06)
	pop.tween_property(field, "scale", Vector2.ONE, 0.1)

# Press: one step. Keep holding: it repeats, faster and faster.
func _hold_to_repeat(button: Button, action: Callable) -> void:
	var timer := Timer.new()
	timer.one_shot = false
	button.add_child(timer)
	timer.timeout.connect(func():
		action.call()
		timer.wait_time = maxf(0.06, timer.wait_time * 0.8))
	button.button_down.connect(func():
		action.call()
		timer.wait_time = 0.4
		timer.start())
	button.button_up.connect(timer.stop)

func _switch_row(box: VBoxContainer, title: String, hint: String, on: bool) -> InkSwitch:
	var card := PanelContainer.new()
	var style := _style(ROW_BG, 22)
	style.content_margin_left = 18
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	card.add_child(line)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.add_child(_label(title, BOLD, 27, CREAM))
	var small := _label(hint, FONT, 18, Color(CREAM, 0.75))
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(small)
	line.add_child(words)
	var toggle := InkSwitch.new()
	toggle.button_pressed = on
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(toggle)
	box.add_child(card)
	return toggle

func _editions() -> Array:
	var base: bool = _base_switch.button_pressed
	var expansion: bool = _expansion_switch.button_pressed
	if not base and not expansion:
		base = true
	return [base, expansion]

# Keeps only picks that are still possible with the editions switched on.
func _update_deck_button() -> void:
	var editions := _editions()
	var target := Cards.deck_target(editions[0], editions[1])
	var allowed := Cards.deck_kinds(editions[0], editions[1])
	var valid := _deck_picks.filter(func(n): return n in allowed)
	if valid.size() != target:
		_deck_picks = []
	_deck_button.text = ("Random deck of %d   ›" % target) if _deck_picks.is_empty() else ("Custom deck (%d)   ›" % _deck_picks.size())

func _open_deck_picker() -> void:
	var editions := _editions()
	var picker = load("res://Scripts/deck_picker.gd").open(get_tree(), editions[0], editions[1], _deck_picks)
	var picks: Array = await picker.chosen
	if not is_instance_valid(self):
		return
	_deck_picks = picks
	_update_deck_button()

func _digits_only(new_text: String, field: LineEdit) -> void:
	var digits := ""
	for c in new_text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != new_text:
		var caret := field.caret_column
		field.text = digits
		field.caret_column = mini(caret, digits.length())
	_error.visible = false

func current_values() -> Dictionary:
	var values := {}
	for key in _boxes:
		var text: String = _boxes[key].text.strip_edges()
		values[key] = int(text) if text.is_valid_int() else -1   # -1 fails the range check
	values["turn_timer"] = _timer_switch.button_pressed
	values["base"] = _base_switch.button_pressed
	values["expansion"] = _expansion_switch.button_pressed
	_update_deck_button()
	values["deck_picks"] = _deck_picks.duplicate()
	return values

func _save() -> void:
	var problem := Network.set_game_settings(current_values())
	if problem != "":
		Sound.play("error")
		_error.text = problem
		_error.visible = true
		return
	Sound.play("saved")
	queue_free()

func _close() -> void:
	Sound.play("back")
	queue_free()

func _pop_in() -> void:
	await get_tree().process_frame
	_frame.pivot_offset = _frame.size / 2.0
	_frame.scale = Vector2(0.92, 0.92)
	_dim.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.12)

## ---- LITTLE BUILDERS ----
func _style(bg: Color, radius: int, border := Color(0, 0, 0, 0), width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	return style

func _heading(text: String) -> Label:
	return _label(text, BOLD, 19, Color(INK, 0.7))

func _label(text: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _round_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(64, 64)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 38)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(c, CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := _style(GREEN.darkened(0.15) if state == "pressed" else GREEN, 32, CREAM, 2)
		button.add_theme_stylebox_override(state, style)
	return button

func _wide_button(text: String, colour: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 76)
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 30)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(c, CREAM)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := _style(colour.darkened(0.12) if state == "pressed" else colour, 38, CREAM, 3)
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 3)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	return button
