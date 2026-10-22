extends CanvasLayer
## Phone home screen: app buttons and End Turn.

const POPUP_SCENE = preload("res://Scenes/pop_up.tscn")
const TRANSITION_SCENE = preload("res://Scenes/transition.tscn")

@onready var ui_menu_frame: Control = $"UI Menu Frame"
@onready var end_turn_btn: Button = $"Apps/Apps Container/second_row/End Turn/actions/end_turn_btn"

var current_scene := "res://Scenes/home_screen.tscn"


func _ready() -> void:
	_let_taps_through($Apps)
	end_turn_btn.disabled = Turns.my_turn_done
	Turns.waiting_changed.connect(func(_names): end_turn_btn.disabled = Turns.my_turn_done)

# The Apps panel and its layout boxes are scaled 1.25x and reach past the bottom of the
# screen, invisibly covering the UI frame's Home / Settings buttons. Only the app buttons
# themselves should take taps, so everything else in there lets them through.
func _let_taps_through(node: Node) -> void:
	if node is Control and not node is BaseButton:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_let_taps_through(child)

# Saves this screen for the Back button and plays the app's opening animation.
func _open_app(app: Dictionary) -> void:
	Sound.play("click")
	Global.save_scene(current_scene)
	var transition = TRANSITION_SCENE.instantiate()
	add_child(transition)
	transition.run_animation(app.app_color, app.app_anim, app.app_url)

func _on_bank_button_pressed() -> void:
	_open_app(Global.bank_app)

func _on_my_properties_button_pressed() -> void:
	_open_app(Global.my_properties_app)

func _on_market_button_pressed() -> void:
	_open_app(Global.market_app)

func _on_my_loans_button_pressed() -> void:
	_open_app(Global.my_loans_app)

func _on_actions_button_pressed() -> void:
	_open_app(Global.my_actions_app)

func _on_end_turn_btn_pressed() -> void:
	if Turns.my_turn_done:
		Global.error("You already ended your turn.")
		return
	var popup = POPUP_SCENE.instantiate()
	ui_menu_frame.add_child(popup)
	popup.layout("Are you sure you want to end your turn?", "Yes", "No")
	popup.left_pressed.connect(_on_end_turn_confirmed)

func _on_end_turn_confirmed() -> void:
	end_turn_btn.disabled = true   # re-enabled when the next round starts
	Global.end_turn()
