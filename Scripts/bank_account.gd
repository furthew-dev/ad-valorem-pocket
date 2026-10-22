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
	var owned := Label.new()
	owned.text = _owned_text()
	owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.add_theme_font_size_override("font_size", 22)
	balances.add_child(owned)
	balances.move_child(owned, balances.get_child_count() - 1)

func _owned_text() -> String:
	var properties := PackedStringArray()
	for p in Cards.properties_owned:
		properties.append(p["name"] if p["condition"] == "" else "%s (%s)" % [p["name"], p["condition"]])
	var tokens := {}
	for key in Actions.actions_owned:
		tokens[key] = tokens.get(key, 0) + 1
	var token_text := PackedStringArray()
	for key in tokens:
		token_text.append("%s x%d" % [Actions.all_actions[key]["name"], tokens[key]])
	return "Properties: %s\nActions: %s" % [
		", ".join(properties) if not properties.is_empty() else "none",
		", ".join(token_text) if not token_text.is_empty() else "none"]

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
