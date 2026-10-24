extends Node
## Activity log ("what just happened?"): every banner, notice and money change, every
## Fortuna drawn, purchases and sales, in the order they happened. Shown on the home
## screen's second page (swipe left). Autoloaded as "Activity". Saved with the game.

signal added(entry: Dictionary)

const MAX_ENTRIES := 200   # older lines are dropped (and only these are saved)

# kind: "info" (banners), "error", "gain", "loss", "fortuna_good", "fortuna_bad", "round", "notice"
var entries: Array = []   # oldest first: {text, kind, round, time}
var dirty := false        # changed since SaveGame last stored it


func _ready() -> void:
	Global.animation_requested.connect(_on_money)
	Global.round_changed.connect(func(n: int): add("Round %d begins" % n, "round"))
	Fortunas.fortuna_drawn.connect(func(card: Dictionary):
		var bad: bool = Fortunas.is_unlucky(card)
		add("Drew a Fortuna: %s" % card.get("name", "?"), "fortuna_bad" if bad else "fortuna_good"))

func clear() -> void:
	entries.clear()
	dirty = true

func add(text: String, kind: String = "info") -> void:
	if text.strip_edges() == "":
		return
	var entry := {"text": text, "kind": kind, "round": Global.ROUND, "time": Time.get_time_string_from_system()}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES + 20:   # trim in chunks, not on every line
		entries = entries.slice(entries.size() - MAX_ENTRIES)
	dirty = true
	added.emit(entry)

func _on_money(type: String, total: int, reason: String) -> void:
	var text := ("+$%d" if type == "gain" else "-$%d") % total
	if reason != "":
		text += "  " + reason
	add(text, type)   # "gain" / "loss"

func snapshot() -> Array:
	return entries.duplicate(true)

func restore(saved: Array) -> void:
	entries = []
	for entry in saved:   # only well-formed lines (an old or damaged save can't break the page)
		if entry is Dictionary and entry.has("text"):
			entries.append(entry)
	dirty = false
