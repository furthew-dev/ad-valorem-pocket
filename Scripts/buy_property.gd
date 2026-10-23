extends Node2D
## Market > Real Estate (Scenes/realtor_or_random.tscn): choose Realtor (3 reveals)
## or Private Purchase (1 reveal), then go to property_reveal.

const SELECT := "CanvasLayer/Panel/VBoxContainer/list_of_properties/MarginContainer2/Panel/MarginContainer/VBoxContainer/"

@onready var realtor_toggle: Button = get_node(SELECT + "select/Realtor/realtor_toggle")
@onready var realtor_select: Label = get_node(SELECT + "select/Realtor/realtor_select")
@onready var ps_toggle: Button = get_node(SELECT + "select/Private Purchase/ps_toggle")
@onready var proceed_btn: Button = get_node(SELECT + "proceed/proceed_btn")
@onready var realtor_emblem: Panel = $"CanvasLayer/Panel/realtor emblem"
@onready var personal_emblem: Panel = $"CanvasLayer/Panel/personal emblem"

var current_scene := "res://Scenes/realtor_or_random.tscn"


func _ready() -> void:
	realtor_emblem.visible = false
	personal_emblem.visible = false
	proceed_btn.disabled = true
	Global.using_realtor = false
	realtor_toggle.disabled = not Actions.actions_owned.has("realtor")
	for toggle in [realtor_toggle, ps_toggle]:
		InkBox.soft_hover(toggle)
	if realtor_toggle.disabled:
		realtor_select.text = "Not Available"

func _on_proceed_btn_pressed() -> void:
	if Global.ACTIONS <= 0:
		Global.error("You are out of Actions.")
		return
	if Cards.properties_owned.size() >= Global.PROPERTY_CAPACITY:
		Global.error("Your properties are maxed out!")
		return
	Sound.play("continue")
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/property_reveal.tscn")

func _on_realtor_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(true)

func _on_ps_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		_choose(false)

func _choose(use_realtor: bool) -> void:
	Sound.play("switch")
	Global.using_realtor = use_realtor
	# set_deferred avoids fighting the toggle that is being pressed this frame
	(ps_toggle if use_realtor else realtor_toggle).set_deferred("button_pressed", false)
	realtor_emblem.visible = use_realtor
	personal_emblem.visible = not use_realtor
	proceed_btn.disabled = false
