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


func _ready() -> void:
	art.texture = Expansion.region_texture(Expansion.my_region, false)
	_build()
	Expansion.changed.connect(_build)

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
	box.add_child(_label("%d" % Expansion.tokens, 96, ink))
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
	for i in range(Expansion.earned.size() - 1, -1, -1):   # newest first
		list.add_child(_earned_row(str(Expansion.earned[i]), ink))

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
