extends Node2D
## Card-reveal screen (Scenes/fortuna.tscn). Fortunas.gd spawns this on top of whatever
## screen is open, fills it with the drawn card, and waits for the `dismissed` signal.

signal dismissed

@onready var image: TextureRect = $CanvasLayer/Panel/VBoxContainer/image
@onready var title: Label = $CanvasLayer/Panel/VBoxContainer/title
@onready var description: Label = $CanvasLayer/Panel/VBoxContainer/Panel/description
@onready var ok_btn: Button = $CanvasLayer/Panel/Panel/ok_btn
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"


func _ready() -> void:
	$CanvasLayer.layer = 100          # draw above every other screen
	ui_menu_frame.disable_buttons()   # no Home/Back while a Fortuna is on screen
	ok_btn.pressed.connect(_on_ok_pressed)

func show_card(card: Dictionary) -> void:
	Sound.play("open")
	title.text = card["name"]
	description.text = card["description"]
	if ResourceLoader.exists(card["art"]):
		image.texture = load(card["art"])
	else:
		image.texture = null
		push_warning("Fortuna art missing: %s" % card["art"])

func _on_ok_pressed() -> void:
	ok_btn.disabled = true
	Sound.play("continue")
	dismissed.emit()
	queue_free()
