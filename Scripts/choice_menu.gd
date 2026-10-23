extends CanvasLayer
# Generic "pick one" pop-up, built entirely in code (no .tscn needed).
# Fortunas.ask_player_to_choose() creates one, calls setup(), and awaits `chosen`.
# Options can be Strings (Yes/No, tokens, conditions) or property Dictionaries.

signal chosen(selection)

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
		if option is Dictionary and ResourceLoader.exists(str(option.get("art", ""))):
			btn.icon = Cards.round_icon(option["art"])   # the property's picture, for a quick visual reference
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 64)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size.y = 84
			btn.add_theme_constant_override("h_separation", 14)
		btn.pressed.connect(_on_option_pressed.bind(option))
		list.add_child(btn)

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
