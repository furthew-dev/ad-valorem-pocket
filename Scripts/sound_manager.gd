extends Node
## Sound effects. Autoloaded as "Sound". Use Sound.play("click") anywhere.
## The on/off setting is saved between sessions (settings pop-up).

const SOUNDS := {
	"click": preload("res://Assets/sounds/mouse_click.mp3"),     # title-screen / app choices
	"continue": preload("res://Assets/sounds/continue.mp3"),     # confirm, move forward
	"back": preload("res://Assets/sounds/going_back.mp3"),       # back, close, minimise
	"open": preload("res://Assets/sounds/open.mp3"),             # a pop-up or form opens
	"error": preload("res://Assets/sounds/error.mp3"),           # can't do that
	"switch": preload("res://Assets/sounds/switch.mp3"),         # toggle on / select
	"switch_off": preload("res://Assets/sounds/switch2.mp3"),    # toggle off
	"saved": preload("res://Assets/sounds/saved.mp3"),           # a setting was saved
	"dice": preload("res://Assets/sounds/dice_rolling.mp3"),     # rolling to sell
	"cash_in": preload("res://Assets/sounds/cash_register.mp3"),   # money received
	"cash_out": preload("res://Assets/sounds/coins_dropping.mp3"), # money paid / lost
	"aww": preload("res://Assets/sounds/crowd_aww.mp3"),           # an unlucky Fortuna
	"shield": preload("res://Assets/sounds/shield_block.mp3"),     # Insurance / Just Say No blocks it
	"gavel": preload("res://Assets/sounds/gavel.mp3"),
	"trash": preload("res://Assets/sounds/thrown_in_trash.mp3"),    # a lost property lands in the bin             # an Attorney blocks it
	"joker": preload("res://Assets/sounds/joker_laugh_sabotage.mp3"),  # you've been sabotaged
	"thunder": preload("res://Assets/sounds/thunder_clap.mp3"),    # Flood
	"trumpet_fail": preload("res://Assets/sounds/trumpet_fail.mp3"),  # the sale roll failed
	"char_prev": preload("res://Assets/sounds/back.mp3"),          # character maker: previous style
	"char_next": preload("res://Assets/sounds/next.mp3"),          # character maker: next style
	"hammer": preload("res://Assets/sounds/hammer_contractor.mp3"),   # a Contractor builds / improves
	"double": preload("res://Assets/sounds/double_pop.mp3"),        # Double applied to a property
	# Fortuna cards with their own sound (see Fortunas.CARD_SOUNDS)
	"radon_lead": preload("res://Assets/sounds/radon_leadbased_paint.mp3"),
	"screaming": preload("res://Assets/sounds/screaming_mad.mp3"),
	"hack_error": preload("res://Assets/sounds/error_sound_hack_sound.mp3"),
	"car_crash": preload("res://Assets/sounds/car_crash.mp3"),
	"storm": preload("res://Assets/sounds/flood_thunder_tornado.mp3"),
	"spray_paint": preload("res://Assets/sounds/spray_paint.mp3"),
	"water_drop": preload("res://Assets/sounds/water_drop.mp3"),    # Mold, Flood
	# Matt's "new sounds" (Nov 2026)
	"coin": preload("res://Assets/sounds/new sounds/90sCoin.mp3"),          # rent comes in; a Jackpot! deed
	"bloop": preload("res://Assets/sounds/new sounds/bloopSuccess.mp3"),    # a good Fortuna
	"thud": preload("res://Assets/sounds/new sounds/thud_sound_losing.mp3"),   # "seriously?!" moments
	"lose_trumpet": preload("res://Assets/sounds/new sounds/losing_trumpet.mp3"),  # Final Results, not first
	"victory": preload("res://Assets/sounds/victory_game_over.mp3"),   # Final Results, you won
	"sparkle": preload("res://Assets/sounds/sparkle_reveal.mp3"),      # a Fortuna card is revealed
	"fire": preload("res://Assets/sounds/fire.mp3"),                   # Fire (faded, see FADES)
	"earthquake": preload("res://Assets/sounds/earthquake.mp3"),       # Earthquake (faded)
	"bugs": preload("res://Assets/sounds/bugs_crawling.mp3"),          # Termites, Pests (faded)
	"paper_rip": preload("res://Assets/sounds/paper_ripping.mp3"),     # Breach of Contract, Wasted
	"honk": preload("res://Assets/sounds/rubber_chicken_honk.mp3"),    # a poke while waiting
	"rubber_launch": preload("res://Assets/sounds/rubber_launch.mp3"), # the slingshot lets go
	"scribble": preload("res://Assets/sounds/scribbling.mp3"),         # signing the loan
	"stamp": preload("res://Assets/sounds/stamp.mp3"),                 # the notary stamp
	"ticktock": preload("res://Assets/sounds/tick-tock.mp3"),          # last-player countdown (loop_sync)
}

# Sounds with several recordings: one is picked at random each time (never the same
# one twice in a row), so repeated actions don't sound copy-pasted.
const VARIANTS := {
	"notify": [   # banners: the usual chime and a softer one, taking turns
		preload("res://Assets/sounds/notification.mp3"),
		preload("res://Assets/sounds/soft_notification.mp3"),
	],
	"rubber_pull": [   # drawing the slingshot back
		preload("res://Assets/sounds/rubber_pull1.mp3"),
		preload("res://Assets/sounds/rubber_pull2.mp3"),
	],
	"envelope": [   # opening a starting deed
		preload("res://Assets/sounds/new sounds/opening envelope1.mp3"),
		preload("res://Assets/sounds/new sounds/opening envelope2.mp3"),
		preload("res://Assets/sounds/new sounds/opening envelope3.mp3"),
	],
	"deal": [   # Fortuna cards dealt / shuffled / turned over
		preload("res://Assets/sounds/new sounds/dealing_cards1.mp3"),
		preload("res://Assets/sounds/new sounds/dealing_cards2.mp3"),
		preload("res://Assets/sounds/new sounds/dealing_cards3.mp3"),
	],
	"sale_fail": [   # a private sale that didn't sell
		preload("res://Assets/sounds/crowd_aww.mp3"),
		preload("res://Assets/sounds/trumpet_fail.mp3"),
	],
}
# Loudness fixes (dB) so the new recordings sit level with the rest.
const VOLUME := {"deal": 10.0, "thud": -6.0, "coin": -3.0, "lose_trumpet": -4.0, "sale_fail": -1.0,
		"rubber_pull": 9.0, "scribble": 14.0, "bugs": 8.0, "fire": -6.0, "victory": 4.0, "sparkle": -3.0}
# Long recordings that play just a part, fading in and out: [seconds, fade in, fade out].
const FADES := {"fire": [4.5, 0.6, 1.6], "earthquake": [4.0, 0.4, 1.4], "bugs": [3.6, 0.5, 1.3]}
const SILENT := -40.0
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

# Returns the player (so a sound can be stopped early, e.g. the slingshot pull), or null.
func play(sound: String) -> AudioStreamPlayer:
	if not enabled:
		return null
	if FADES.has(sound):
		return _play_faded(sound)
	var stream = SOUNDS.get(sound)
	if VARIANTS.has(sound):
		stream = _variant(sound)
	if stream == null:
		push_warning("Unknown sound: %s" % sound)
		return null
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.volume_db = VOLUME.get(sound, 0.0)
	player.play()
	return player

# A slice of a long recording on its own player, faded in and out, then freed.
func _play_faded(sound: String) -> AudioStreamPlayer:
	var shape: Array = FADES[sound]
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = SOUNDS[sound]
	player.volume_db = SILENT
	player.play()
	var loud: float = VOLUME.get(sound, 0.0)
	var fade := player.create_tween()
	fade.tween_property(player, "volume_db", loud, shape[1]).set_ease(Tween.EASE_OUT)
	fade.tween_interval(maxf(0.0, shape[0] - shape[1] - shape[2]))
	fade.tween_property(player, "volume_db", SILENT, shape[2]).set_ease(Tween.EASE_IN)
	fade.tween_callback(player.queue_free)
	return player


## ---- A LOOP KEPT IN TIME (the last-player tick-tock) ----
# loop_sync() every frame with how long the countdown has run: the recording plays from
# the matching point (its ticks fall on whole seconds), so the ticks stay on the clock.
var _loops: Dictionary = {}   # sound -> AudioStreamPlayer

func loop_sync(sound: String, elapsed: float, volume_db: float) -> void:
	if not enabled:
		stop_loop(sound)
		return
	var player: AudioStreamPlayer = _loops.get(sound)
	if player == null:
		player = AudioStreamPlayer.new()
		add_child(player)
		player.stream = SOUNDS[sound]
		_loops[sound] = player
	var period := floorf(player.stream.get_length())   # whole seconds of ticks (8 s)
	var at := fposmod(elapsed, period)
	if not player.playing:
		player.play(at)
	elif absf(player.get_playback_position() - at) > 0.08 and absf(player.get_playback_position() - at) < period - 0.08:
		player.seek(at)
	player.volume_db = volume_db

func stop_loop(sound: String) -> void:
	var player: AudioStreamPlayer = _loops.get(sound)
	if player:
		player.stop()

var _last_variant: Dictionary = {}   # sound -> index played last time

func _variant(sound: String) -> AudioStream:
	var options: Array = VARIANTS[sound]
	var pick := randi() % options.size()
	if options.size() > 1 and pick == _last_variant.get(sound, -1):
		pick = (pick + 1 + randi() % (options.size() - 1)) % options.size()
	_last_variant[sound] = pick
	return options[pick]

func set_enabled(on: bool) -> void:
	enabled = on
	Network.save_setting("audio", "enabled", on)
	if not on:
		for player in _players:
			player.stop()
		for sound in _loops:
			stop_loop(sound)
