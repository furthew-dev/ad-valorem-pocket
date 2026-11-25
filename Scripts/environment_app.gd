extends CanvasLayer
## Environment app (Expansion only): your region's picture fills the screen, with a card
## showing your region, your Environment tokens and what they're worth, and which
## properties earned them. Everyone's regions are listed at the bottom.

const CARD := Color(0.32549, 0.235294, 0.266667, 0.88)
const INK := Color("ddcf99")
const MAX_WIDTH := 640.0

@onready var art: TextureRect = $Art
@onready var shade: ColorRect = $Shade
@onready var content: Control = $Content
@onready var ui_menu_frame: Control = $"UI Menu Frame"

var _card_box: VBoxContainer


var _count_label: Label
var _rows: Array = []   # "Earned from" rows, newest first

func _ready() -> void:
	art.texture = Expansion.region_texture(Expansion.my_region, false)
	var news := Notices.env_news()   # what changed since this app was last open
	Notices.mark_app("environment")
	_build()
	Expansion.changed.connect(_build)
	if not news.is_empty():
		_play_news(news)

func _exit_tree() -> void:
	Notices.mark_app("environment")

# Tokens counted up (green) or down (red) from what you last saw; new "Earned from" rows
# pulse; if a Fortuna wiped them, a note says so, then fades away.
func _play_news(news: Dictionary) -> void:
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree() or _count_label == null:
		return
	var before: int = news["before"]
	var now := Expansion.tokens
	if before != now:
		var label := _count_label
		label.pivot_offset = label.size / 2
		var tween := label.create_tween()
		tween.tween_method(func(v: int): label.text = "%d" % v, before, now, 0.9) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate", Color("7fd17f") if now > before else Color("ff7a6e"), 0.35)
		tween.parallel().tween_property(label, "scale", Vector2(1.25, 1.25), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate", Color.WHITE, 0.4)
		tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.4)
		Sound.play("bloop" if now > before else "sale_fail")
	for i in mini(int(news["new_rows"]), _rows.size()):
		Notices.pulse_outline(_rows[i], 20, 6.0, 4)
	var wiped: Dictionary = news.get("wiped", {})
	if not wiped.is_empty():
		_flash_message("%s wiped out your %d Environment token%s." % [wiped.get("reason", "A Fortuna"),
				int(wiped["lost"]), "" if int(wiped["lost"]) == 1 else "s"])

# A note in the middle of the screen that fades in, stays a moment and fades out.
func _flash_message(text: String) -> void:
	var note := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.08, 0.92)
	style.border_color = Notices.DOT_COLOR
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	note.add_theme_stylebox_override("panel", style)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(480, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://Assets/fonts/Comfortaa-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("f6f2e1"))
	note.add_child(label)
	ColorTheme.keep(note)
	ColorTheme.keep(label)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(note)
	add_child(centre)
	note.modulate.a = 0.0
	var tween := note.create_tween()
	tween.tween_property(note, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.8)
	tween.tween_property(note, "modulate:a", 0.0, 0.5)
	tween.tween_callback(centre.queue_free)

func _build() -> void:
	for child in content.get_children():
		child.queue_free()
	var ink := ColorTheme.map_color(INK, "text")
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side := maxf(40.0, (content.get_viewport_rect().size.x - MAX_WIDTH) / 2.0)
	card.offset_left = side
	card.offset_right = -side
	card.offset_top = 200
	card.offset_bottom = -210
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.map_color(CARD, "fill")
	style.set_corner_radius_all(40)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", style)
	ColorTheme.keep(card)
	content.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_label("YOUR REGION", 22, Color(ink, 0.65)))
	box.add_child(_label(Expansion.my_region if Expansion.my_region != "" else "No region", 72, ink))
	box.add_child(_gap(10))
	_count_label = _label("%d" % Expansion.tokens, 96, ink)
	box.add_child(_count_label)
	box.add_child(_label("Environment token%s" % ("" if Expansion.tokens == 1 else "s"), 30, ink))
	box.add_child(_label("Worth $%d at the end  ($%d each)" % [Expansion.token_worth(), Expansion.TOKEN_WORTH], 24, Color(ink, 0.8)))
	box.add_child(_gap(10))

	var hint := _label("Every %s property you get earns a token, and you keep it even if the property is sold or lost later." % Expansion.my_region, 20, Color(ink, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	if not Expansion.earned.is_empty():
		list.add_child(_label("Earned from", 22, Color(ink, 0.65)))
	_rows.clear()
	for i in range(Expansion.earned.size() - 1, -1, -1):   # newest first
		var row := _earned_row(str(Expansion.earned[i]), ink)
		list.add_child(row)
		_rows.append(row)

	if Expansion.regions.size() > 1:
		var others := PackedStringArray()
		for player_name in Expansion.regions:
			others.append("%s: %s" % [player_name, Expansion.regions[player_name]])
		var everyone := _label("  ·  ".join(others), 18, Color(ink, 0.65))
		everyone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(everyone)

func _earned_row(property_name: String, ink: Color) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var template: Dictionary = Cards.templates_by_name.get(property_name, {})
	if template.has("art"):
		var icon := TextureRect.new()
		icon.texture = Cards.round_icon(template["art"])
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	row.add_child(_label(property_name, 26, ink))
	row.add_child(_label("+1", 26, Color("7fd17f")))
	return row

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	ColorTheme.keep(label)
	return label

func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap
