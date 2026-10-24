extends Node
## Activity log ("what just happened?"): every banner, notice and money change, every
## Fortuna drawn, purchases and sales, in the order they happened. Shown on the home
## screen's second page (swipe left). Autoloaded as "Activity". Saved with the game.

signal added(entry: Dictionary)

const MAX_ENTRIES := 400

# kind: "info" (banners), "error", "gain", "loss", "fortuna_good", "fortuna_bad", "round", "notice"
var entries: Array = []   # oldest first: {text, kind, round, time}


func _ready() -> void:
	Global.animation_requested.connect(_on_money)
	Global.round_changed.connect(func(n: int): add("Round %d begins" % n, "round"))
	Fortunas.fortuna_drawn.connect(func(card: Dictionary):
		var bad: bool = Fortunas.is_unlucky(card)
		add("Drew a Fortuna: %s" % card.get("name", "?"), "fortuna_bad" if bad else "fortuna_good"))

func clear() -> void:
	entries.clear()

func add(text: String, kind: String = "info") -> void:
	if text.strip_edges() == "":
		return
	var entry := {"text": text, "kind": kind, "round": Global.ROUND, "time": Time.get_time_string_from_system()}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries = entries.slice(entries.size() - MAX_ENTRIES)
	added.emit(entry)

func _on_money(type: String, total: int, reason: String) -> void:
	var text := ("+$%d" if type == "gain" else "-$%d") % total
	if reason != "":
		text += "  " + reason
	add(text, type)   # "gain" / "loss"

func snapshot() -> Array:
	return entries.duplicate(true)

func restore(saved: Array) -> void:
	entries = saved.duplicate(true)
