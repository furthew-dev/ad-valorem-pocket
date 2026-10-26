extends CanvasLayer
## Final standings, shown after your bank summary at game over:
##     1st
##   Timmy ———————— $450 Net
##   - - - - - - - - - - - -
## then an awards box under them that fades through fun facts from the game
## ("Black Cat Award: Erika drew 5 unfortunate Fortunas."). Stats come from Stats.gd.

const ORDINALS := ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"]
const INK := Color(0.1, 0.1, 0.1)
const CREAM := Color("ddcf99")
const PLUM := Color("533c44")
const GOLD := Color("8a6a1c")
const HAND_FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")

# {who} = winner name(s), {n} = the number, {s} = "" or "s", {ies} = "y" or "ies".
# "low": true means the smallest number wins. "money": show {n} as dollars.
const AWARDS := [
	{"key": "fortunas_bad", "title": "Black Cat Award", "text": "{who} drew {n} unfortunate Fortuna{s}. Someone walked under a ladder."},
	{"key": "fortunas_good", "title": "Four-Leaf Clover", "text": "{who} drew {n} lucky Fortuna{s}. Fortune favors the bold."},
	{"key": "sabotages_sent", "title": "The Joker", "text": "{who} played {n} sabotage{s} on the rest of the table."},
	{"key": "sabotages_received", "title": "Biggest Target", "text": "{who} got sabotaged {n} time{s}. Everyone's favorite victim."},
	{"key": "cd_worth", "money": true, "title": "The Investor", "text": "{who} kept {n} safely tucked away in Certificates of Deposit."},
	{"key": "priciest_value", "money": true, "title": "Champagne Taste", "text": "{who} owned the priciest property of the game, worth {n}."},
	{"key": "portfolio", "money": true, "title": "Real Estate Mogul", "text": "{who} finished with {n} worth of property."},
	{"key": "expenses", "money": true, "title": "Big Spender", "text": "{who} spent {n} over the game. Money is for spending, right?"},
	{"key": "loans", "title": "Loan Master", "text": "{who} took out {n} loan{s}. The bank sends its warmest regards."},
	{"key": "properties_owned", "title": "Land Baron", "text": "{who} owned {n} propert{ies} over the game, sold ones included."},
	{"key": "rent", "money": true, "title": "Landlord of the Year", "text": "{who} collected {n} in rent."},
	{"key": "sales", "title": "The Flipper", "text": "{who} sold {n} propert{ies}. Buy low, sell high."},
	{"key": "interest_paid", "money": true, "title": "The Bank's Best Friend", "text": "{who} paid {n} in loan interest."},
	{"key": "loans_paid_off", "title": "Debt Slayer", "text": "{who} paid off {n} loan{s} in full."},
	{"key": "auctions_won", "title": "Going, Going, Gone!", "text": "{who} won {n} auction{s}."},
	{"key": "actions_bought", "title": "Shopaholic", "text": "{who} bought {n} item{s} from the Market."},
	{"key": "blocks", "title": "Untouchable", "text": "{who} shut down {n} sabotage{s} with Just Say No."},
	{"key": "peak_cash", "money": true, "title": "Money Bags", "text": "{who} once had {n} in cash at the same time."},
	{"key": "fortuna_losses", "money": true, "title": "Disaster Magnet", "text": "{who} lost {n} to Fortunas and sabotage."},
	{"key": "sabotage_income", "money": true, "title": "Ill-Gotten Gains", "text": "{who} pocketed {n} from the players they sabotaged."},
	{"key": "env_tokens", "title": "Nature Lover", "text": "{who} earned {n} Environment token{s} in their own region."},
	{"key": "expenses", "low": true, "money": true, "title": "Penny Pincher", "text": "{who} spent just {n} all game. Frugal!"},
]
const FADE_TIME := 0.5
const HOLD_TIME := 3.6

@onready var ui_menu_frame: Control = $"UI Menu Frame"
@onready var title: Label = $Content/title
@onready var players_title: Label = $Content/Players/Margin/VBox/players_title
@onready var player_list: VBoxContainer = $Content/Players/Margin/VBox/player_list
@onready var card_vbox: VBoxContainer = $Content/Players/Margin/VBox
@onready var status: Label = $Content/status
@onready var lobby_btn: Button = $Content/lobby_btn
@onready var quit_btn: Button = $Content/quit_btn

var _award_box: PanelContainer
var _award_body: VBoxContainer
var _award_title: Label
var _award_faces: HBoxContainer
const AvatarArt = preload("res://Scripts/avatar.gd")
var _award_text: Label
var _awards: Array = []   # [{title, text}]
var _award_index := 0


func _ready() -> void:
	ui_menu_frame.clear_ui()
	ui_menu_frame.checking_bal.text = "Game Over"
	ui_menu_frame.custom_navigation = true   # use the buttons below
	lobby_btn.visible = Network.is_online()   # solo games have no lobby to return to
	_tidy_layout()
	if Turns.final_results.is_empty():
		status.visible = true
		await Turns.results_ready
	_show_results()

# Smaller title and buttons so the standings and the awards box both fit; the
# standings scroll when there are lots of players.
func _tidy_layout() -> void:
	title.add_theme_font_size_override("font_size", 64)
	players_title.visible = false
	var content: Control = title.get_parent()
	content.offset_top = 180
	content.offset_bottom = -180
	content.add_theme_constant_override("separation", 14)
	# Both buttons on one row.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	content.add_child(buttons)
	for button in [lobby_btn, quit_btn]:
		button.reparent(buttons, false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 90)
		button.add_theme_font_size_override("font_size", 36)
	lobby_btn.text = "Back to Lobby"
	quit_btn.text = "Main Menu"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_vbox.add_child(scroll)
	card_vbox.move_child(scroll, player_list.get_index())
	player_list.reparent(scroll, false)
	player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_list.add_theme_constant_override("separation", 4)
	card_vbox.add_theme_constant_override("separation", 16)
	get_viewport().size_changed.connect(_keep_phone_width)
	_keep_phone_width()

const MAX_WIDTH := 640.0

# On a wide (desktop) window keep the results phone-width and centred.
func _keep_phone_width() -> void:
	var content: Control = title.get_parent()
	var width: float = content.get_parent_area_size().x if content.is_inside_tree() else 720.0
	var side := maxf(60.0, (width - MAX_WIDTH) / 2.0)
	content.offset_left = side
	content.offset_right = -side


## ---- STANDINGS ----
func _show_results() -> void:
	status.visible = false
	for child in player_list.get_children():
		child.queue_free()
	var list: Array = Turns.final_results
	for i in list.size():
		if i > 0:
			player_list.add_child(_divider())
		_add_standing(i, list[i])
	_build_awards(list)
	Sound.play("notify")

func _add_standing(i: int, entry: Dictionary) -> void:
	var place := _label(ORDINALS[mini(i, ORDINALS.size() - 1)], 46 if i == 0 else 36, GOLD if i == 0 else INK)
	place.add_theme_font_override("font", HAND_FONT)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_list.add_child(place)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(AvatarArt.for_player(str(entry["name"]), 60))
	var who := _label(str(entry["name"]), 32, INK)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := Control.new()   # a thin rule joining the name to the money
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.custom_minimum_size = Vector2(40, 0)
	line.draw.connect(func(): line.draw_line(
			Vector2(0, line.size.y * 0.6), Vector2(line.size.x, line.size.y * 0.6), Color(INK, 0.35), 2.0))
	var net := _label("$%d Net" % int(entry["net_worth"]), 26, Color(INK, 0.8))
	net.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	row.add_child(line)
	row.add_child(net)
	player_list.add_child(row)

func _divider() -> Control:
	var gap := Control.new()   # dashed line between players
	gap.custom_minimum_size = Vector2(0, 16)
	gap.draw.connect(func():
		var y := gap.size.y / 2.0
		var x := 20.0
		while x < gap.size.x - 20.0:
			gap.draw_line(Vector2(x, y), Vector2(minf(x + 14.0, gap.size.x - 20.0), y), Color(INK, 0.3), 2.0)
			x += 24.0)
	return gap

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## ---- AWARDS ----
func _build_awards(list: Array) -> void:
	_awards = awards_for(list)
	if _awards.is_empty():
		return
	_award_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PLUM
	style.set_corner_radius_all(30)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	_award_box.add_theme_stylebox_override("panel", style)
	_award_box.custom_minimum_size.y = 250   # room for the faces and two lines, so the box doesn't jump
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	var header := _label("AWARDS", 18, Color(CREAM, 0.55))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(header)
	_award_body = VBoxContainer.new()
	_award_body.add_theme_constant_override("separation", 6)
	_award_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_award_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_award_faces = HBoxContainer.new()   # the winner(s), over the award's name
	_award_faces.alignment = BoxContainer.ALIGNMENT_CENTER
	_award_faces.add_theme_constant_override("separation", -8)
	_award_body.add_child(_award_faces)
	_award_title = _label("", 34, CREAM)
	_award_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_award_text = _label("", 24, Color(CREAM, 0.9))
	_award_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_award_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_award_body.add_child(_award_title)
	_award_body.add_child(_award_text)
	outer.add_child(_award_body)
	_award_box.add_child(outer)
	card_vbox.add_child(_award_box)
	ColorTheme.keep(_award_box)
	_award_index = 0
	_next_award()

# Fade in, hold, fade out, next one... round and round until the player leaves.
func _next_award() -> void:
	if not is_inside_tree():
		return
	var award: Dictionary = _awards[_award_index % _awards.size()]
	_award_index += 1
	_award_title.text = award["title"]
	_award_text.text = award["text"]
	for child in _award_faces.get_children():
		child.queue_free()
	for winner in award.get("who", []).slice(0, 4):
		_award_faces.add_child(AvatarArt.for_player(str(winner), 64))
	_award_body.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_award_body, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_award_body, "modulate:a", 0.0, FADE_TIME)
	tween.tween_interval(0.15)
	tween.finished.connect(_next_award)

# Works out which awards were earned. Pure function of the published results, so every
# phone shows the same awards. Skips awards nobody earned (all zero) and, with more than
# one player, awards everybody tied for.
static func awards_for(list: Array) -> Array:
	var out := []
	for award in AWARDS:
		var low: bool = award.get("low", false)
		var best = null
		var winners := []
		for entry in list:
			var stats: Dictionary = entry.get("stats", {})
			if not stats.has(award["key"]):
				continue
			var n := int(stats[award["key"]])
			if best == null or (n < best if low else n > best):
				best = n
				winners = [str(entry["name"])]
			elif n == best:
				winners.append(str(entry["name"]))
		if best == null or winners.is_empty():
			continue
		if not low and best <= 0:
			continue
		if list.size() > 1 and winners.size() == list.size():
			continue   # everyone tied: not much of an award
		if low and list.size() < 2:
			continue
		var n_text: String = "$%d" % best if award.get("money", false) else str(best)
		var text: String = award["text"].format({
			"who": _join_names(winners), "n": n_text,
			"s": "" if best == 1 else "s", "ies": "y" if best == 1 else "ies"})
		out.append({"title": award["title"], "text": text, "who": winners})
	return out

static func _join_names(names: Array) -> String:
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " & " + names[-1]


func _on_lobby_btn_pressed() -> void:
	Sound.play("continue")
	Turns.back_to_lobby()

func _on_quit_btn_pressed() -> void:
	Sound.play("back")
	Turns.quit_to_title()
