extends CanvasLayer
# Generic "pick one" pop-up, built entirely in code (no .tscn needed).
# Fortunas.ask_player_to_choose() creates one, calls setup(), and awaits `chosen`.
# Options can be Strings (Yes/No, tokens, conditions) or property Dictionaries.

signal chosen(selection)

const STARTING_HAND = preload("res://Scripts/starting_hand.gd")
const THEME_PATH = "res://main_theme.tres"
const NICE_NAMES = {"llc": "LLC", "skybnb": "SkyBnB", "certificate_of_deposit": "Certificate of Deposit"}

var _done: bool = false

func setup(prompt: String, options: Array) -> void:
	layer = 101   # above the Fortuna card screen (100)
	Sound.play("open")

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(THEME_PATH):
		root.theme = load(THEME_PATH)
	add_child(root)

	var dim = ColorRect.new()          # darkens the screen and blocks clicks behind the menu
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.32549, 0.235294, 0.266667)
	panel_style.set_corner_radius_all(30)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var margin = MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 30)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var label = Label.new()
	label.text = prompt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(560, 0)
	label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(label)

	var deeds = options.filter(func(o): return o is Dictionary)
	var keys = options.map(_token_key)
	if not deeds.is_empty():
		# Properties (tied properties, where to put a token, swaps): shown as their deeds,
		# like when a deed is opened. Anything else (Cancel / Don't swap) stays a button.
		_add_deeds(vbox, deeds)
		_add_buttons(vbox, options.filter(func(o): return not o is Dictionary))
	elif keys.all(func(k): return k != ""):
		_add_tokens(vbox, options, keys)   # tokens: their round emblems with the name below
	else:
		_add_buttons(vbox, options)

func _add_buttons(vbox: VBoxContainer, options: Array) -> void:
	if options.is_empty():
		return
	var scroll = ScrollContainer.new()   # long lists (e.g. every property type) scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, mini(options.size(), 6) * 96)
	vbox.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	for option in options:
		var btn = Button.new()
		btn.text = _label_for(option)
		btn.custom_minimum_size = Vector2(0, 72)
		btn.add_theme_font_size_override("font_size", 30)
		btn.add_theme_stylebox_override("normal", _button_style(Color(0.501961, 0.447059, 0.411765)))
		btn.add_theme_stylebox_override("hover", _button_style(Color(0.588235, 0.317647, 0.294118)))
		btn.add_theme_stylebox_override("pressed", _button_style(Color(0.47451, 0.235294, 0.266667)))
		btn.pressed.connect(_on_option_pressed.bind(option))
		list.add_child(btn)

## ---- DEEDS ----
const DEED_SIZE := Vector2(272, 356)
const DEED_GAP := 16

func _add_deeds(vbox: VBoxContainer, deeds: Array) -> void:
	var grid = GridContainer.new()
	grid.columns = 2 if deeds.size() > 1 else 1
	grid.add_theme_constant_override("h_separation", DEED_GAP)
	grid.add_theme_constant_override("v_separation", DEED_GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rows: int = ceili(deeds.size() / 2.0)
	if rows > 2:   # more than four: the deeds scroll
		var scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(560, 2 * DEED_SIZE.y + DEED_GAP + DEED_SIZE.y * 0.35)
		vbox.add_child(scroll)
		var centre = CenterContainer.new()
		centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(centre)
		centre.add_child(grid)
	else:
		vbox.add_child(grid)
	var order := 0
	for property in deeds:
		var card: Control = STARTING_HAND.deed(property)
		var cell = Control.new()   # the grid places the cell; the card can pop inside it
		cell.custom_minimum_size = DEED_SIZE
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(card)
		var tap = _tap_button(cell)
		tap.pressed.connect(_pick.bind(card, property))
		grid.add_child(cell)
		_deal_in(card, order)
		order += 1

## ---- TOKENS ----
const BADGE := 132.0
const BADGE_BG := Color("3a2a31")
const BADGE_RING := Color("ddcf99")
const CREAM := Color("f6f2e1")
const TINT_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * COLOR.a); }
"""
static var _tint: ShaderMaterial

func _add_tokens(vbox: VBoxContainer, options: Array, keys: Array) -> void:
	var grid = GridContainer.new()
	grid.columns = mini(options.size(), 3)
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 22)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_gap(6))
	vbox.add_child(grid)
	vbox.add_child(_gap(6))
	for i in options.size():
		var action: Dictionary = Actions.all_actions[keys[i]]
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		column.custom_minimum_size.x = 150
		column.mouse_filter = Control.MOUSE_FILTER_PASS
		var badge = Control.new()   # a dark circle with a light ring, the emblem in cream
		badge.custom_minimum_size = Vector2(BADGE, BADGE)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.pivot_offset = Vector2(BADGE, BADGE) / 2.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.draw.connect(func():
			var c := Vector2(BADGE, BADGE) / 2.0
			badge.draw_circle(c, BADGE / 2.0 - 2.0, BADGE_BG, true, -1.0, true)
			badge.draw_circle(c, BADGE / 2.0 - 3.0, BADGE_RING, false, 3.0, true))
		var icon = TextureRect.new()
		if ResourceLoader.exists(str(action.get("art", ""))):
			icon.texture = load(action["art"])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(BADGE, BADGE) * 0.2
		icon.size = Vector2(BADGE, BADGE) * 0.6
		icon.material = _tint_material()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
		ColorTheme.keep(badge)
		ColorTheme.keep(icon)
		column.add_child(badge)
		var name_label = Label.new()
		name_label.text = str(action.get("name", _label_for(options[i])))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(name_label)
		var cell = PanelContainer.new()   # stacks the column and the tap button on each other
		cell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(column)
		var tap = _tap_button(cell)
		tap.pressed.connect(_pick.bind(badge, options[i]))
		grid.add_child(cell)
		_deal_in(badge, i)

func _tint_material() -> ShaderMaterial:
	if _tint == null:
		var shader = Shader.new()
		shader.code = TINT_SHADER
		_tint = ShaderMaterial.new()
		_tint.shader = shader
		_tint.set_shader_parameter("tint", CREAM)
	return _tint

# The option's token key ("skybnb"), from a key or a token's name ("SkyBnB"); "" if not a token.
func _token_key(option) -> String:
	if not option is String:
		return ""
	if Actions.all_actions.has(option):
		return option
	for key in Actions.all_actions:
		if str(Actions.all_actions[key].get("name", "")).to_lower() == option.to_lower():
			return key
	return ""

## ---- SHARED ----
# An invisible button over the whole of `holder`.
func _tap_button(holder: Control) -> Button:
	var tap = Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.mouse_filter = Control.MOUSE_FILTER_PASS   # drags still reach a scroll list
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	holder.add_child(tap)
	return tap

# Each choice pops in, one after another.
func _deal_in(item: Control, order: int) -> void:
	item.scale = Vector2(0.6, 0.6)
	item.modulate.a = 0.0
	var tween = item.create_tween().set_parallel()
	tween.tween_property(item, "scale", Vector2.ONE, 0.28).set_delay(0.06 * order) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "modulate:a", 1.0, 0.18).set_delay(0.06 * order)

# The chosen one pops, then the menu closes with it.
func _pick(item: Control, option) -> void:
	if _done:
		return
	_done = true
	Sound.play("continue")
	var tween = item.create_tween()
	tween.tween_property(item, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", Vector2.ONE, 0.1)
	tween.tween_callback(func():
		chosen.emit(option)
		queue_free())

func _gap(height: int) -> Control:
	var gap = Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap

func _button_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	return style

func _label_for(option) -> String:
	if option is Dictionary:   # a property
		var cond = str(option.get("condition", ""))
		var text = str(option.get("name", "Property"))
		if cond != "":
			text += " (%s)" % cond.capitalize()
		return text + "  |  value $%d  rent $%d" % [option.get("value", 0), option.get("rent", 0)]
	var s = str(option)
	if NICE_NAMES.has(s):
		return NICE_NAMES[s]
	if s == s.to_lower():      # snake_case keys like "golden_lock"
		return s.replace("_", " ").capitalize()
	return s

func _on_option_pressed(option) -> void:
	if _done:
		return
	_done = true
	Sound.play("continue")
	chosen.emit(option)
	queue_free()
