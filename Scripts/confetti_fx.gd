class_name ConfettiFx
extends CanvasLayer
## Confetti that bursts up from the bottom of the screen, flutters, then falls away
## (like Outlook's celebration). Taps pass straight through it.
##
##   ConfettiFx.play(get_tree())

const PIECES := 230
const GRAVITY := 1500.0
const LIFETIME := 4.2          # seconds until the last piece is gone
# Palette colours (they follow the colour theme), plus a gold and a green for sparkle.
const COLORS := ["b76051", "cba77a", "7b7e63", "92868b", "c2855f", "ddcf99", "744145", "5d6558"]
const EXTRA_COLORS := [Color("e8c547"), Color("4c9a52")]

var _pieces: Array = []   # [position, velocity, rotation, spin, size, color, wobble phase]
var _age := 0.0
var _canvas: Control


static func play(tree: SceneTree) -> void:
	var fx := ConfettiFx.new()
	tree.root.add_child(fx)

func _ready() -> void:
	layer = 98   # above screens and auctions, below Fortuna cards (100)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_pieces)
	add_child(_canvas)
	var screen := get_viewport().get_visible_rect().size
	var colors: Array = COLORS.map(func(h): return ColorTheme.map_color(Color(h)))
	colors.append_array(EXTRA_COLORS)
	# Three bursts along the bottom edge: left, middle, right.
	for i in PIECES:
		var origin_x: float = [0.15, 0.5, 0.85][i % 3] * screen.x + randf_range(-60, 60)
		var angle := deg_to_rad(randf_range(-28, 28))   # mostly straight up
		var speed := randf_range(1150, 1900)
		_pieces.append({
			"pos": Vector2(origin_x, screen.y + randf_range(0, 40)),
			"vel": Vector2(sin(angle), -cos(angle)) * speed,
			"rot": randf_range(0, TAU),
			"spin": randf_range(-9, 9),
			"size": Vector2(randf_range(14, 24), randf_range(8, 14)),
			"color": colors[randi() % colors.size()],
			"phase": randf_range(0, TAU),
			"delay": randf_range(0, 0.35),   # pieces leave a little staggered
		})

func _process(delta: float) -> void:
	_age += delta
	for p in _pieces:
		if _age < p["delay"]:
			continue
		var vel: Vector2 = p["vel"]
		vel.y += GRAVITY * delta
		if vel.y > 0:   # falling: air resistance and a side-to-side flutter
			vel.y = minf(vel.y, 260.0)
			vel.x = lerpf(vel.x, sin(_age * 5.0 + p["phase"]) * 120.0, 2.5 * delta)
		else:
			vel.x *= 1.0 - 1.2 * delta
		p["vel"] = vel
		p["pos"] += vel * delta
		p["rot"] += p["spin"] * delta
	_canvas.queue_redraw()
	if _age >= LIFETIME:
		queue_free()

func _draw_pieces() -> void:
	var fade := clampf((LIFETIME - _age) / 0.8, 0.0, 1.0)   # fade over the last 0.8 s
	for p in _pieces:
		if _age < p["delay"]:
			continue
		var size: Vector2 = p["size"]
		# A thin edge-on look as the piece tumbles.
		var squash := absf(cos(_age * 6.0 + p["phase"])) * 0.8 + 0.2
		_canvas.draw_set_transform(p["pos"], p["rot"], Vector2(1.0, squash))
		_canvas.draw_rect(Rect2(-size / 2, size), Color(p["color"], fade))
	_canvas.draw_set_transform(Vector2.ZERO)
