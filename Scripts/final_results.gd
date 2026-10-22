extends CanvasLayer
## Final standings, shown after your bank summary at game over.
## "1st Place Timmy, net worth $450". Then back to the lobby or the title screen.

const ORDINALS := ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"]

@onready var ui_menu_frame: Control = $"UI Menu Frame"
@onready var player_list: VBoxContainer = $Content/Players/Margin/VBox/player_list
@onready var status: Label = $Content/status
@onready var lobby_btn: Button = $Content/lobby_btn
@onready var quit_btn: Button = $Content/quit_btn


func _ready() -> void:
	ui_menu_frame.clear_ui()
	ui_menu_frame.checking_bal.text = "Game Over"
	ui_menu_frame.custom_navigation = true   # use the buttons below
	lobby_btn.visible = Network.is_online()   # solo games have no lobby to return to
	if Turns.final_results.is_empty():
		status.visible = true
		await Turns.results_ready
	_show_results()

func _show_results() -> void:
	status.visible = false
	for child in player_list.get_children():
		child.queue_free()
	var list: Array = Turns.final_results
	for i in list.size():
		var entry: Dictionary = list[i]
		var row := Label.new()
		row.text = "%s Place %s, net worth $%d" % [ORDINALS[mini(i, ORDINALS.size() - 1)], entry["name"], entry["net_worth"]]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_color_override("font_color", Color.BLACK)
		row.add_theme_font_size_override("font_size", 44 if i == 0 else 34)
		player_list.add_child(row)
	Sound.play("notify")

func _on_lobby_btn_pressed() -> void:
	Sound.play("continue")
	Turns.back_to_lobby()

func _on_quit_btn_pressed() -> void:
	Sound.play("back")
	Turns.quit_to_title()
