extends Node2D
## Title screen: steam rising from the coffee mug, drawn in code (no sprite sheet).
## Three soft wisps sway and drift upward in a loop. It redraws only FPS times a second,
## and main.gd pauses it when nobody has touched the screen for a while.
##     play() / pause() / is_playing()   (the same calls the old AnimatedSprite2D had)

const FPS := 20.0
const WISPS := [   # x offset, height, sway, speed, phase, width
	[-38.0, 230.0, 20.0, 1.00, 0.0, 15.0],
	[0.0, 280.0, 24.0, 0.85, 2.1, 17.0],
	[38.0, 215.0, 18.0, 1.15, 4.2, 15.0],
]
const STEPS := 22                       # points along each wisp
const STEAM := Color(1.0, 0.99, 0.96)  # the wisp
const SHADE := Color(0.70, 0.78, 0.95)  # a cool edge on one side, like the old drawing
const CYCLE := 3.2                      # seconds for a wisp to rise and fade once

var _time := 0.0
var _since_draw := 0.0
var _playing := true


func play() -> void:
	_playing = true

func pause() -> void:
	_playing = false

func is_playing() -> bool:
	return _playing

func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	_since_draw += delta
	if _since_draw >= 1.0 / FPS:
		_since_draw = 0.0
		queue_redraw()

func _draw() -> void:
	for i in WISPS.size():
		var w: Array = WISPS[i]
		var t: float = _time * w[3] + w[4]
		# Each wisp rises, fades out at the top, and starts again from the cup.
		var life := fmod(_time * float(w[3]) / CYCLE + i * 0.33, 1.0)
		var rise := lerpf(0.75, 1.0, life)              # it stretches up as it goes
		var alpha := sin(life * PI)                     # fades in, then out
		var points := PackedVector2Array()
		for s in STEPS + 1:
			var k := float(s) / STEPS                   # 0 at the cup, 1 at the top
			var y: float = -k * float(w[1]) * rise
			var sway: float = sin(k * 4.2 - t * 2.0) * w[2] * (0.25 + k)
			points.append(Vector2(w[0] + sway, y))
		var shade := PackedColorArray()
		var steam := PackedColorArray()
		for s in STEPS + 1:
			var k := float(s) / STEPS
			var fade := minf(1.0, alpha * 1.3) * (1.0 - k) * clampf(k * 4.0 - 0.1, 0.0, 1.0)   # soft at both ends (it rises out of the cup)
			shade.append(Color(SHADE, fade * 0.7))
			steam.append(Color(STEAM, fade))
		# One stroke per colour (separate segments overlapped at the joins and looked striped).
		var offset := PackedVector2Array()
		for p in points:
			offset.append(p + Vector2(3, 1))
		draw_polyline_colors(offset, shade, float(w[5]), true)
		draw_polyline_colors(points, steam, float(w[5]) * 0.75, true)
