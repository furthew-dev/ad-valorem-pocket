extends CanvasLayer
## Sale result screen. Reads Global.SOLD set by sell_property.gd.

@onready var result: Label = $app_color/Panel2/Panel/VBoxContainer/result
@onready var details: Label = $app_color/Panel2/Panel/VBoxContainer/HBoxContainer/details
@onready var ok_button: Button = $app_color/Panel2/Panel/VBoxContainer/ok_button


func _ready() -> void:
	if Global.SOLD:
		result.text = "SOLD!"
		details.text = "Congratulations! You successfully sold your property!"
	else:
		result.text = "SALE FAILED"
		details.text = "Unfortunately, your property didn't sell."

func _on_ok_button_pressed() -> void:
	Sound.play("continue")
	Global.erase_scenes()
	Global.action_used()
	get_tree().change_scene_to_file("res://Scenes/my_properties.tscn")
