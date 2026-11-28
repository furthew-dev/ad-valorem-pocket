extends Node2D
## Bank app: your net worth and how close you are to ending the game, then the account line by
## line (cash, properties, investments, environment tokens, loans) and Make a Payment.
## At game over it doubles as your final summary: the button becomes OK and leads to the
## final standings. Built in code in the shared card look (cozy.gd); the scene's old
## layout is hidden.

const Cozy = preload("res://Scripts/cozy.gd")
const RESULTS_SCENE := "res://Scenes/final_results.tscn"
const CASH_ICON := preload("res://Assets/icons/bank_icon.png")
const HOMES_ICON := preload("res://Assets/icons/home_icon.png")
const SAVINGS_ICON := preload("res://Assets/icons/sell_icon.png")
const LOAN_ICON := preload("res://Assets/icons/tokens/draft_icon.png")

@onready var old_layout: Control = $CanvasLayer/Panel/VBoxContainer
@onready var ui_menu_frame: Control = $"CanvasLayer/Panel/UI Menu Frame"

var current_scene := "res://Scenes/bank_account.tscn"
var account_card: Control      # the account, line by line (the tour points at it)
var loans_line: Control
var pay_button: Button
var make_payment: Button       # (same button; the old name, used by the Game Over flow)
var _page: VBoxContainer


func _ready() -> void:
	old_layout.visible = false
	_page = Cozy.page($CanvasLayer/Panel, ui_menu_frame)
	_build()
	if Turns.game_over:
		_show_final_summary()

func _build() -> void:
	# Hello
	var hello := VBoxContainer.new()
	hello.add_theme_constant_override("separation", 0)
	var title := Cozy.label("Game Over" if Turns.game_over else "Hello, %s" % Global.PLAYER, Cozy.HAND, 58, Cozy.CREAM, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hello.add_child(title)
	var sub := Cozy.label("Bank of Ad Valorem  ·  Round %d" % Global.ROUND, Cozy.FONT, 20, Color(Cozy.CREAM, 0.75), false)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hello.add_child(sub)
	_page.add_child(hello)

	# Net worth, and how far you are from ending the game
	var hero := Cozy.card(26)
	_page.add_child(hero)
	var hero_box := VBoxContainer.new()
	hero_box.add_theme_constant_override("separation", 8)
	hero.add_child(hero_box)
	hero_box.add_child(Cozy.caption("Net worth"))
	var worth := Cozy.label("$0", Cozy.BOLD, 76)
	hero_box.add_child(worth)
	Cozy.count(worth, 0, Global.net_worth(), "$%d", 0.9)
	hero_box.add_child(Cozy.rule())
	var bar := Cozy.bar(16.0)
	hero_box.add_child(bar)
	var won := Cozy.can_win()
	var progress := Cozy.win_progress()
	bar.create_tween().tween_method(func(v: float): Cozy.set_bar(bar, v, Cozy.UP if won else Cozy.GOLD), 0.0, progress, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not Turns.game_over:   # once the game is over these would only confuse
		var status := Cozy.label("You can end the game this round" if won
				else "$%d away from ending the game" % Cozy.cash_to_end(), Cozy.BOLD, 22)
		hero_box.add_child(status)
		var how := Cozy.label(Cozy.end_rule(), Cozy.FONT, 19, Color(Cozy.CREAM, 0.75))
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hero_box.add_child(how)

	# The account, line by line
	account_card = Cozy.card(22)
	_page.add_child(account_card)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 12)
	account_card.add_child(lines)
	lines.add_child(Cozy.caption("Your account"))
	lines.add_child(Cozy.line("Checking", "$%d" % Global.CASH, CASH_ICON))
	var count := Cards.properties_owned.size()
	lines.add_child(Cozy.line("Properties (%d)" % count, "$%d" % Global.equity(), HOMES_ICON))
	lines.add_child(Cozy.line("Investments", "$%d" % Actions.get_CD_worth(), SAVINGS_ICON))
	if Network.expansion_on():
		var env := Cozy.line("Environment tokens (%d)" % Expansion.tokens, "$%d" % Expansion.token_worth())
		env.add_child(Cozy.badge(Expansion.region_icon(Expansion.my_region) if Expansion.my_region != "" else null, 52, Cozy.INSET, "picture"))
		env.move_child(env.get_child(env.get_child_count() - 1), 0)
		lines.add_child(env)
	var owed := Global.all_loans()
	loans_line = Cozy.line("Loans", ("-$%d" % owed) if owed > 0 else "$0", LOAN_ICON, Cozy.DOWN if owed > 0 else Cozy.CREAM)
	lines.add_child(loans_line)

	pay_button = Cozy.button("Make a Payment" if owed > 0 else "No loans to pay")
	pay_button.pressed.connect(_on_make_payment_pressed)
	make_payment = pay_button
	if owed <= 0 and not Turns.game_over:
		pay_button.modulate.a = 0.55
	_page.add_child(pay_button)

func _show_final_summary() -> void:
	pay_button.text = "OK"
	pay_button.modulate.a = 1.0
	ui_menu_frame.custom_navigation = true   # Home / Back do nothing now
	var card := Cozy.card(22)
	_page.add_child(card)
	_page.move_child(card, pay_button.get_index())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(Cozy.caption("Final summary"))
	box.add_child(_property_icons())
	var owned := Cozy.label(_owned_text(), Cozy.FONT, 22)
	owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(owned)

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
		flow.add_child(Cozy.label("No properties", Cozy.FONT, 22))
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
		token_text.append("%s ×%d" % [Actions.all_actions[key]["name"], tokens[key]])
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
