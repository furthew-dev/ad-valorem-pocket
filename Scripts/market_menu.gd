extends Node2D
## Market app: choose Actions or Real Estate.

@onready var actions_btn: Button = $CanvasLayer/Panel/VBoxContainer/MarginContainer/options/buttons/actions/actions_btn
@onready var real_estate_btn: Button = $CanvasLayer/Panel/VBoxContainer/MarginContainer/options/buttons/actions2/real_estate_btn

var current_scene := "res://Scenes/market.tscn"


func _on_actions_btn_pressed() -> void:
	Sound.play("click")
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/market_actions.tscn")

func _on_real_estate_btn_pressed() -> void:
	Sound.play("click")
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/realtor_or_random.tscn")
