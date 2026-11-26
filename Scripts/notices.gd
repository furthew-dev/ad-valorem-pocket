extends Node
## "What's new" red dots. Rather than hooking every Fortuna, round step and purchase, this
## remembers what the player last SAW and compares it with what they own now:
##   - My Properties app: a dot until the app is opened. Each changed (or newly arrived)
##     property also gets its own dot in the list until its Property Details is opened,
##     where the change plays (tenants, value/rent counting, condition moving).
##   - My Loans app: a dot when a loan is new or its balance went up (interest); the
##     balance is highlighted when the app is opened.
##   - My Actions app: a dot when you have more of an action (bought, Nordic Cottage,
##     kept Fortunas); those rows pulse when the app is opened.
## Anything that changes while its own screen is open counts as seen.
##
##     Notices.app_dirty("my_properties")       # home screen dot?
##     Notices.property_before(id)              # {} = nothing new, else what it looked like
##     Notices.mark_property(id)                # seen

const DOT_COLOR := Color("e0453a")
# Only what the player can see on a property counts as a change. (Comparing the whole card
# flagged every property after round 1: the rent step quietly adds a "no_rent_rounds"
# counter to each card.) Missing keys count as their default.
const WATCHED := {"name": "", "value": 0, "rent": 0, "condition": "", "tenants": 0,
		"has_skybnb": false, "has_double": false, "has_golden_lock": false, "has_insurance": false,
		"has_attorney": false, "no_rent_rounds": 0, "lot_kind": ""}

signal enabled_changed
var enabled := true:   # Settings > "New-item dots" (saved on this phone)
	set(value):
		enabled = value
		Network.save_setting("notices", "enabled", value)
		enabled_changed.emit()

var _props_app := {}    # property id -> snapshot when My Properties was last open
var _props_item := {}   # property id -> snapshot when its Property Details was last open
var _loans := {}        # loan number -> balance when My Loans was last open
var _actions := {}      # action key -> count when My Actions was last open
var _env := {"tokens": 0, "earned": []}   # Environment tokens when that app was last open
var _has_baseline := false


func _ready() -> void:
	Global.starting_hand_dealt.connect(baseline)
	enabled = Network.load_setting("notices", "enabled", true)

# Everything as it is now counts as seen (a new game, Resume Game, the tutorial).
func baseline() -> void:
	_props_app = _property_snapshots()
	_props_item = _property_snapshots()
	_loans = _loan_balances()
	_actions = _action_counts()
	_env = _env_now()
	_has_baseline = true

func _active() -> bool:
	if not _has_baseline:
		baseline()
	return enabled and not get_tree().root.has_node("Tutorial")   # the tour points at things itself

## ---- WHAT IS THERE NOW ----
static func _snapshot(property: Dictionary) -> Dictionary:
	var view := {}
	for key in WATCHED:
		view[key] = property.get(key, WATCHED[key])
	view["suites"] = property.get("suites", []).size()
	# Terraced House grows $1 every round by itself: that alone isn't news.
	view["growth"] = int(property.get("round", 0)) if property.get("name", "") == "Terraced House" else 0
	return view

# Same as far as the player can see? (Terraced House's own yearly +1 doesn't count.)
static func _same(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	for v in [x, y]:
		v["value"] = int(v.get("value", 0)) - int(v.get("growth", 0))
		v["rent"] = int(v.get("rent", 0)) - int(v.get("growth", 0))
		v.erase("growth")
	return x == y

func _property_snapshots() -> Dictionary:
	var out := {}
	for p in Cards.properties_owned:
		out[p.get("id", 0)] = _snapshot(p)
	return out

func _loan_balances() -> Dictionary:
	var out := {}
	for loan in Global.loans:
		out[loan["loan_number"]] = int(loan["loan_balance"])
	return out

# Actions by key, plus kept Fortunas (Just Say No...) as "fortuna:<effect>".
func _action_counts() -> Dictionary:
	var out := {}
	for key in Actions.actions_owned:
		out[key] = out.get(key, 0) + 1
	for card in Fortunas.fortunas_owned:
		var key := "fortuna:" + str(card.get("effect", card.get("name", "")))
		out[key] = out.get(key, 0) + 1
	return out

func _env_now() -> Dictionary:
	return {"tokens": Expansion.tokens, "earned": Expansion.earned.duplicate()}

## ---- QUESTIONS ----
func app_dirty(app: String) -> bool:
	if not _active():
		return false
	match app:
		"my_properties":
			for p in Cards.properties_owned:
				var id = p.get("id", 0)
				if not _props_app.has(id) or not _same(_props_app[id], _snapshot(p)):
					return true
		"my_loans":
			for loan in Global.loans:
				if loan_before(loan["loan_number"]) != -1:
					return true
		"my_actions":
			return not new_actions().is_empty()
		"environment":
			return not env_news().is_empty()
		"messages":
			return Messages.total_unread() > 0
	return false

# Environment tokens since the app was last open: {} = nothing new, else
# {"before": tokens then, "new_rows": how many "Earned from" rows are new, "wiped": {...}}.
func env_news() -> Dictionary:
	if not _active() or not Network.expansion_on():
		return {}
	var now := _env_now()
	if now == _env:
		return {}
	var seen_rows: Array = _env["earned"]
	var rows: Array = now["earned"]
	var fresh := rows.size() - seen_rows.size() if rows.slice(0, seen_rows.size()) == seen_rows else rows.size()
	var wiped: Dictionary = Expansion.last_wipe if Expansion.last_wipe.get("lost", 0) > 0 else {}   # cleared when the app is opened
	return {"before": int(_env["tokens"]), "new_rows": maxi(fresh, 0), "wiped": wiped}

# What the property looked like when its details were last opened; {} if nothing changed.
# A property that just arrived returns {"new": true}.
func property_before(id: int) -> Dictionary:
	if not _active():
		return {}
	for p in Cards.properties_owned:
		if p.get("id", 0) == id:
			if not _props_item.has(id):
				return {"new": true}
			var seen: Dictionary = _props_item[id]
			return {} if _same(seen, _snapshot(p)) else seen
	return {}

func property_dirty(id: int) -> bool:
	return not property_before(id).is_empty()

# The balance before the interest (or 0 for a loan that's new); -1 = nothing new.
func loan_before(number: int) -> int:
	if not _active():
		return -1
	for loan in Global.loans:
		if loan["loan_number"] == number:
			if not _loans.has(number):
				return 0
			var seen: int = _loans[number]
			return seen if int(loan["loan_balance"]) > seen else -1
	return -1

# Action keys you have more of than when My Actions was last open.
func new_actions() -> Array:
	if not _active():
		return []
	var out := []
	var now := _action_counts()
	for key in now:
		if now[key] > _actions.get(key, 0):
			out.append(key)
	return out

## ---- SEEN ----
func mark_app(app: String) -> void:
	match app:
		"my_properties":
			_props_app = _property_snapshots()
		"my_loans":
			_loans = _loan_balances()
		"my_actions":
			_actions = _action_counts()
		"environment":
			_env = _env_now()
			Expansion.last_wipe = {}

func mark_property(id: int) -> void:
	for p in Cards.properties_owned:
		if p.get("id", 0) == id:
			_props_item[id] = _snapshot(p)
			_props_app[id] = _snapshot(p)

## ---- THE DOT ----
# A small red dot for the top-right corner of `host` (an app tile or a property card).
# Pops in; call again to keep it (returns the existing dot).
static func dot(host: Control, diameter: float = 34.0, inset := Vector2(-10, -10)) -> Control:
	var existing := host.get_node_or_null("NewDot") as Control
	if existing:
		return existing
	var d := Panel.new()
	d.name = "NewDot"
	var style := StyleBoxFlat.new()
	style.bg_color = DOT_COLOR
	style.set_corner_radius_all(int(diameter))
	style.border_color = Color("f6f2e1")
	style.set_border_width_all(3)
	style.anti_aliasing = true
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	d.add_theme_stylebox_override("panel", style)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.anchor_left = 1.0   # pinned to the host's top-right corner at any size
	d.anchor_right = 1.0
	d.offset_left = -diameter - inset.x
	d.offset_right = -inset.x
	d.offset_top = inset.y
	d.offset_bottom = inset.y + diameter
	d.pivot_offset = Vector2(diameter, diameter) / 2
	d.z_index = 5
	ColorTheme.keep(d)
	host.add_child(d)
	d.scale = Vector2.ZERO
	d.create_tween().tween_property(d, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return d

static func clear_dot(host: Control) -> void:
	var d := host.get_node_or_null("NewDot")
	if d:
		d.queue_free()

# A rounded outline around `target` that fades in and out a few times (the "look here").
static func pulse_outline(target: Control, radius: int = 24, pad: float = 8.0, cycles: int = 4) -> Panel:
	var ring := Panel.new()
	ring.name = "NewPulse"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DOT_COLOR, 0.08)
	style.border_color = DOT_COLOR
	style.set_border_width_all(5)
	style.set_corner_radius_all(radius)
	style.expand_margin_left = pad
	style.expand_margin_right = pad
	style.expand_margin_top = pad
	style.expand_margin_bottom = pad
	style.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", style)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 4
	ColorTheme.keep(ring)
	target.add_child(ring)
	if target is Container:   # a layout box would line the ring up as one of its items
		ring.top_level = true
		var follow := func():
			if is_instance_valid(ring) and is_instance_valid(target):
				ring.global_position = target.global_position
				ring.size = target.size * target.get_global_transform().get_scale()
		follow.call_deferred()
		target.item_rect_changed.connect(follow)
	ring.modulate.a = 0.0
	var tween := ring.create_tween()
	for i in cycles:
		tween.tween_property(ring, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
		tween.tween_property(ring, "modulate:a", 0.15, 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)
	return ring
