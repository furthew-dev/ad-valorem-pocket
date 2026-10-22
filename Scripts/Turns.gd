extends Node
## Rounds and the end of the game. Autoloaded as "Turns".
##
## Everyone plays at the same time; pressing End Turn marks you as done and shows a
## "Waiting on ..." bar. When the last player ends their turn the host either:
##   - ends the game, if anyone has more than Global.END_GOAL cash and no loans, or
##   - starts the next round on every phone: a "Round N" curtain, the Home Screen
##     reloads, then Fortuna / rent / interest run (Global.process_new_round).
## Game over: each player sees their bank summary, then the final standings.

signal waiting_changed(names: Array)   # names still playing; [] = nobody waiting
signal round_started(number: int)
signal results_ready

const CURTAIN_COLOR := Color("533c44")
const HOME_SCENE := "res://Scenes/home_screen.tscn"
const BANK_SCENE := "res://Scenes/bank_account.tscn"
const RESULTS_SCENE := "res://Scenes/final_results.tscn"
const LOBBY_SCENE := "res://Scenes/lobby.tscn"
const TITLE_SCENE := "res://Scenes/main.tscn"
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")

var my_turn_done := false
var waiting_on: Array = []         # player names, kept in sync by the host
var game_over := false
var final_results: Array = []      # [{name, net_worth}], best first

var _finished: Dictionary = {}     # host only: peer id -> {cash, loans}
var _final_reports: Dictionary = {}  # host only: peer id -> {name, net_worth}
var _was_online := false


func _ready() -> void:
	Network.players_changed.connect(_on_players_changed)
	Network.game_starting.connect(_on_game_starting)
	Network.session_ended.connect(_on_session_ended)

func is_waiting() -> bool:
	return my_turn_done and not waiting_on.is_empty()


## ---- END TURN ----
func end_turn() -> void:
	if my_turn_done or game_over:
		return
	my_turn_done = true
	Global.ACTIONS = 0   # browsing only until the next round
	if Network.is_online():
		_player_done.rpc_id(1, Global.CASH, Global.all_loans())
	elif _is_winner(Global.CASH, Global.all_loans()):
		_end_game()   # solo
	else:
		_start_round(Global.ROUND + 1)

func _is_winner(cash: int, loans: int) -> bool:
	return cash > Global.END_GOAL and loans == 0

@rpc("any_peer", "call_local", "reliable")
func _player_done(cash: int, loans: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_finished[id if id != 0 else 1] = {"cash": cash, "loans": loans}
	_check_round()

# Host: who is still playing? Nobody -> game over or next round for everyone.
func _check_round() -> void:
	var still_playing := []
	for id in Network.players:
		if not _finished.has(id):
			still_playing.append(Network.players[id])
	if not still_playing.is_empty():
		_sync_waiting.rpc(still_playing)
		return
	var someone_won := false
	for stats in _finished.values():
		if _is_winner(stats["cash"], stats["loans"]):
			someone_won = true
	_finished.clear()
	if someone_won:
		_final_reports.clear()
		_end_game.rpc()
	else:
		_start_round.rpc(Global.ROUND + 1)

@rpc("authority", "call_local", "reliable")
func _sync_waiting(names: Array) -> void:
	waiting_on = names
	waiting_changed.emit(names)

func _on_players_changed() -> void:
	if not (Network.in_game and multiplayer.is_server()):
		return
	# Someone left: they may have been the last one we were waiting on / reporting.
	if not _finished.is_empty():
		for id in _finished.keys():
			if not Network.players.has(id):
				_finished.erase(id)
		_check_round()
	if game_over:
		_check_final_reports()


## ---- NEXT ROUND ----
@rpc("authority", "call_local", "reliable")
func _start_round(number: int) -> void:
	waiting_on = []
	waiting_changed.emit([])
	await _play_curtain("Round %d" % number, HOME_SCENE, func():
		Global.ROUND = number
		Global.ACTIONS = Global.A_CAPACITY)
	my_turn_done = false
	round_started.emit(number)
	await Global.process_new_round()

# Fades to a full-screen title card, switches scene behind it, then fades back.
# `before_scene` runs while the screen is covered.
func _play_curtain(text: String, scene: String, before_scene := Callable()) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90   # above every screen; Fortuna (100) still goes on top
	var curtain := ColorRect.new()
	curtain.color = CURTAIN_COLOR
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.modulate.a = 0.0
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 140)
	label.add_theme_color_override("font_color", Color(0.866667, 0.811765, 0.6))
	curtain.add_child(label)
	layer.add_child(curtain)
	get_tree().root.add_child(layer)
	Sound.play("notify")

	var fade_in := create_tween()
	fade_in.tween_property(curtain, "modulate:a", 1.0, 0.4)
	await fade_in.finished

	if before_scene.is_valid():
		before_scene.call()
	Global.erase_scenes()
	Cards.reset_id()
	get_tree().change_scene_to_file(scene)
	await get_tree().create_timer(1.2).timeout   # hold the card; the new screen loads behind it

	var fade_out := create_tween()
	fade_out.tween_property(curtain, "modulate:a", 0.0, 0.4)
	await fade_out.finished
	layer.queue_free()


## ---- GAME OVER ----
@rpc("authority", "call_local", "reliable")
func _end_game() -> void:
	game_over = true
	waiting_on = []
	waiting_changed.emit([])
	final_results = []
	var report := {"name": Global.PLAYER, "net_worth": Global.net_worth()}
	if Network.is_online():
		_report_final.rpc_id(1, report)
	else:
		_set_results([report])
	await _play_curtain("Game Over", BANK_SCENE)   # bank_account.gd shows the summary + OK

@rpc("any_peer", "call_local", "reliable")
func _report_final(report: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_final_reports[id if id != 0 else 1] = report
	_check_final_reports()

func _check_final_reports() -> void:
	for id in Network.players:
		if not _final_reports.has(id):
			return
	var list := []
	for id in Network.players:
		list.append(_final_reports[id])
	_publish_results.rpc(list)

@rpc("authority", "call_local", "reliable")
func _publish_results(list: Array) -> void:
	_set_results(list)

func _set_results(list: Array) -> void:
	list.sort_custom(func(a, b): return a["net_worth"] > b["net_worth"])
	final_results = list
	results_ready.emit()

# Final results screen buttons.
func back_to_lobby() -> void:
	reset()
	Network.return_to_lobby()
	get_tree().change_scene_to_file(LOBBY_SCENE)

func quit_to_title() -> void:
	reset()
	Network.leave()
	get_tree().change_scene_to_file(TITLE_SCENE)


## ---- SESSION ----
# Clears round / game-over state. Also used when leaving on purpose (settings pop-up),
# so no "lost connection" notice shows.
func reset() -> void:
	my_turn_done = false
	waiting_on = []
	game_over = false
	final_results = []
	_finished.clear()
	_final_reports.clear()
	_was_online = false
	waiting_changed.emit([])

func _on_game_starting() -> void:
	reset()
	_was_online = true
	# Players still on the results screen when the host starts again come along too.
	var scene := get_tree().current_scene
	if scene and scene.name != "lobby":
		get_tree().change_scene_to_file(HOME_SCENE)

func _on_session_ended(message: String) -> void:
	var was_online := _was_online
	reset()
	if not was_online:
		return   # the lobby handles its own exit
	await Global.show_notice(message)
	get_tree().change_scene_to_file(TITLE_SCENE)
