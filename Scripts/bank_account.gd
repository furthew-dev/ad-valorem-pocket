extends Node2D
## Bank app: balances and net worth. At game over it doubles as your final summary:
## the button becomes OK and leads to the final standings.

const RESULTS_SCENE := "res://Scenes/final_results.tscn"

@onready var player_name: Label = $CanvasLayer/Panel/VBoxContainer/Panel4/header/player_name
@onready var balances: VBoxContainer = $CanvasLayer/Panel/VBoxContainer/Panel2/VBoxContainer
@onready var cash_bal: Label = $CanvasLayer/Panel/VBoxContainer/Panel2/VBoxContainer/checking/cash_bal
@onready var assets_bal: Label = $CanvasLayer/Panel/VBoxContainer/Panel2/VBoxContainer/assets/assets_bal
@onready var investments_bal: Label = $CanvasLayer/Panel/VBoxContainer/Panel2/VBoxContainer/investments/investments_bal
@onready var loan_bal: Label = $CanvasLayer/Panel/VBoxContainer/Panel2/VBoxContainer/loans/loan_bal
@onready var make_payment: Button = $CanvasLayer/Panel/VBoxContainer/Panel3/make_payment
@onready var net_worth_bal: Label = $"CanvasLayer/Panel/VBoxContainer/Panel/Total Net Worth/net_worth_bal"
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"

var current_scene := "res://Scenes/bank_account.tscn"


func _ready() -> void:
	player_name.text = "Hello, %s" % Global.PLAYER
	cash_bal.text = "$%d" % Global.CASH
	assets_bal.text = "$%d" % Global.equity()
	investments_bal.text = "$%d" % Actions.get_CD_worth()
	loan_bal.text = "$%d" % Global.all_loans()
	net_worth_bal.text = "$%d" % Global.net_worth()
	if Turns.game_over:
		_show_final_summary()

func _show_final_summary() -> void:
	player_name.text = "Final Summary: %s" % Global.PLAYER
	make_payment.text = "OK"
	ui_menu_frame.custom_navigation = true   # Home / Back do nothing now
	balances.add_child(_property_icons())
	var owned := Label.new()
	owned.text = _owned_text()
	owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.add_theme_font_size_override("font_size", 22)
	balances.add_child(owned)

const ICON_SIZE := 78

# Your properties as a row of small round pictures. Tap one to see its name and value.
func _property_icons() -> Control:
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for p in Cards.properties_owned:
		var icon := TextureRect.new()
		icon.texture = Cards.round_icon(p["art"])
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = _property_caption(p)
		icon.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Sound.play("click")
				Global.banner(_property_caption(p)))
		flow.add_child(icon)
	if Cards.properties_owned.is_empty():
		var none := Label.new()
		none.text = "No properties"
		none.add_theme_font_size_override("font_size", 22)
		flow.add_child(none)
	return flow

func _property_caption(p: Dictionary) -> String:
	var condition: String = str(p.get("condition", ""))
	var name_text: String = p["name"] if condition == "" else "%s (%s)" % [p["name"], condition.capitalize()]
	return "%s: worth $%d" % [name_text, p.get("value", 0)]

func _owned_text() -> String:
	var tokens := {}
	for key in Actions.actions_owned:
		tokens[key] = tokens.get(key, 0) + 1
	var token_text := PackedStringArray()
	for key in tokens:
		token_text.append("%s x%d" % [Actions.all_actions[key]["name"], tokens[key]])
	return "Actions: %s" % (", ".join(token_text) if not token_text.is_empty() else "none")

func _on_make_payment_pressed() -> void:
	if Turns.game_over:
		Sound.play("continue")
		get_tree().change_scene_to_file(RESULTS_SCENE)
		return
	if Global.loans.is_empty():
		Global.error("You have no loans.")
		return
	Sound.play("click")
	Global.save_scene(current_scene)
	get_tree().change_scene_to_file("res://Scenes/my_loans.tscn")
