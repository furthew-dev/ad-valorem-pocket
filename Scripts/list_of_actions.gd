extends Control
## One owned-action row in My Actions (Scenes/list_of_actions.tscn).

signal use_requested(action_data: Dictionary)

@onready var action_button: Button = $Panel/action_button
@onready var texture_rect: TextureRect = $Panel/VBoxContainer2/HBoxContainer/TextureRect
@onready var action_name: Label = $Panel/VBoxContainer2/HBoxContainer/VBoxContainer/action_name
@onready var details: Label = $Panel/VBoxContainer2/HBoxContainer/VBoxContainer/details
@onready var count_panel: Panel = $Panel/count
@onready var count_label: Label = $Panel/count/count_label

var action_data: Dictionary = {}


func setup_card(data: Dictionary, count: int = 1) -> void:
	action_data = data
	action_name.text = str(action_data.get("name", "Unknown action"))
	details.text = str(action_data.get("description", ""))
	var art_path: String = action_data.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		texture_rect.texture = load(art_path)
		ColorTheme.ink_icon(texture_rect)   # Fortuna card art matches the black token icons
	count_label.text = "x%d" % count
	count_panel.visible = count > 1   # hidden when there's only one
	_fit_height()

# Tall enough for the whole description (long ones used to spill out of the panel).
const MIN_HEIGHT := 150.0
func _fit_height() -> void:
	var font: Font = details.get_theme_font("font")
	var font_size := details.get_theme_font_size("font_size")
	var width := maxf(details.custom_minimum_size.x, 350.0) - 12.0
	var text_height := font.get_multiline_string_size(details.text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size).y
	var name_height := action_name.get_theme_font("font").get_height(action_name.get_theme_font_size("font_size"))
	var needed := maxf(MIN_HEIGHT, 10.0 + name_height + text_height + 24.0)
	$Panel.offset_bottom = $Panel.offset_top + needed
	custom_minimum_size.y = needed + 10.0   # a little gap so the shadows don't touch
	count_panel.offset_top = (needed - 75.0) / 2.0
	count_panel.offset_bottom = count_panel.offset_top + 75.0

func _on_action_button_pressed() -> void:
	Sound.play("click")
	use_requested.emit(action_data)
