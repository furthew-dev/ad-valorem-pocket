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
	count_label.text = "x%d" % count
	count_panel.visible = count > 1   # hidden when there's only one

func _on_action_button_pressed() -> void:
	Sound.play("click")
	use_requested.emit(action_data)
