extends Node
## Sound effects. Autoloaded as "Sound". Use Sound.play("click") anywhere.
## The on/off setting is saved between sessions (settings pop-up).

const SOUNDS := {
	"click": preload("res://Assets/sounds/mouse_click.mp3"),     # title-screen / app choices
	"continue": preload("res://Assets/sounds/continue.mp3"),     # confirm, move forward
	"back": preload("res://Assets/sounds/going_back.mp3"),       # back, close, minimise
	"open": preload("res://Assets/sounds/open.mp3"),             # a pop-up or form opens
	"error": preload("res://Assets/sounds/error.mp3"),           # can't do that
	"notify": preload("res://Assets/sounds/notification.mp3"),   # banners, new round
	"switch": preload("res://Assets/sounds/switch.mp3"),         # toggle on / select
	"switch_off": preload("res://Assets/sounds/switch2.mp3"),    # toggle off
	"saved": preload("res://Assets/sounds/saved.mp3"),           # a setting was saved
	"dice": preload("res://Assets/sounds/dice_rolling.mp3"),     # rolling to sell
	"cash_in": preload("res://Assets/sounds/cash_register.mp3"),   # money received
	"cash_out": preload("res://Assets/sounds/coins_dropping.mp3"), # money paid / lost
	"aww": preload("res://Assets/sounds/crowd_aww.mp3"),           # an unlucky Fortuna
	"shield": preload("res://Assets/sounds/shield_block.mp3"),     # Insurance / Attorney / Just Say No blocks it
	"joker": preload("res://Assets/sounds/joker_laugh_sabotage.mp3"),  # you've been sabotaged
	"thunder": preload("res://Assets/sounds/thunder_clap.mp3"),    # Flood
	"trumpet_fail": preload("res://Assets/sounds/trumpet_fail.mp3"),  # the sale roll failed
}
const VOICES := 6   # how many sounds can overlap

var enabled := true

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = Network.load_setting("audio", "enabled", true)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

func play(sound: String) -> void:
	if not enabled:
		return
	var stream = SOUNDS.get(sound)
	if stream == null:
		push_warning("Unknown sound: %s" % sound)
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.play()

func set_enabled(on: bool) -> void:
	enabled = on
	Network.save_setting("audio", "enabled", on)
	if not on:
		for player in _players:
			player.stop()
