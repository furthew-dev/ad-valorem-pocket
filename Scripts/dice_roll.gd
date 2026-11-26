extends CanvasLayer
## Selling a property: the player rolls a black die with white writing, in 3D with real
## physics. Whatever face lands on top decides the sale: with a Listing Agent 5 of the 6
## faces say SOLD, on your own only 2 do (the other faces say FAIL).
##     DiceRoll.open(get_tree(), using_agent, settle)
## `settle` is called with true/false once the die stops. It applies the sale and returns
## {"message": String, "cash": int}. Then this goes to My Properties and the result shows
## in the banner (with the cash notice when it sold).
## Throwing is a slingshot: press anywhere in the tray, pull back (down), and let go. The
## die flies the opposite way, harder the further you pulled. The tray and die are there
## from the moment the screen opens.
## In the guided tour a FAIL just lets the player roll again (nothing happens).

const AGENT_SOLD_FACES := 5
const PRIVATE_SOLD_FACES := 2
const BG := Color("534650")
const TRAY := Color("3f3540")
const CREAM := Color("f6f2e1")
const TERRACOTTA := Color("b76051")
const FONT = preload("res://Assets/fonts/Handwriting-Regular.otf")
const BODY_FONT = preload("res://Assets/fonts/Comfortaa-Regular.ttf")
const DESTINATION := "res://Scenes/my_properties.tscn"
const TRAY_SIZE := 640.0
const WALL := 1.9            # the die stays inside -WALL..WALL (x and z)
const SETTLE_TIME := 0.35    # still for this long = stopped
const GIVE_UP_AFTER := 8.0   # still tumbling (or balanced on an edge): nudge it
const CAMERA_HEIGHT := 8.0     # sees the whole tray from straight above
# A throw: from a random point around the tray's edge, toward (roughly) the middle.
const THROW_SPEED := Vector2(3.0, 6.5)    # how hard, sideways (m/s, randomly in this range)
const THROW_LIFT := Vector2(0.5, 2.5)     # and upward
const THROW_AIM := 0.45                   # up to ~25 degrees off the middle
const THROW_SPIN := Vector2(8.0, 24.0)    # spin (rad/s), around a random axis
# The sound: a click each time the die hits something, as loud as the hit.
const HIT_MIN := 0.7          # a change of speed (m/s) smaller than this is silent
const HIT_LOUD := 7.0         # ...this or more is full volume
const HIT_GAP := 0.045        # at most one click per this many seconds
const SHADOW_MAP := 1024      # px; 16-bit, about 2 MB
const BOX_HEIGHT := 1.0        # the tray's walls: as high as the die
const BOX_THICK := 0.32        # how thick they are
const BOX_ROUND := 0.38        # their rounded inside corners
const BOX_BEVEL := 0.07        # the bevel along their top edges
const BOX_WOOD := Color("6d574f")
const HITS := [preload("res://Assets/sounds/dice_hit1.mp3"), preload("res://Assets/sounds/dice_hit2.mp3"), preload("res://Assets/sounds/dice_hit3.mp3")]
const SETTLING = preload("res://Assets/sounds/dice_settling.mp3")
const CORNER_RADIUS := 0.16   # rounded edges (the die is 1 x 1 x 1)
const FACES := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
# The slingshot (screen pixels in the tray).
const MAX_PULL := 230.0       # pulling further than this adds nothing
const MIN_PULL := 45.0        # less than this and the die just springs back
const PULL_SHOWS := 0.6       # the die follows the finger back this much
const LAUNCH_SPEED := Vector2(5.5, 14.0)  # m/s, from a gentle pull to a full one
const LAUNCH_LIFT := Vector2(1.5, 4.5)
const LAUNCH_SPIN := Vector2(16.0, 40.0)  # rad/s: it tumbles and caroms off the walls
const REST := Vector3(0, 0.5, 1.2)        # where the die waits: low in the tray, in the slingshot
const PULL_ROOM := 1.4                    # how far (m) it can be drawn back: up and over the rim
const POST_Z := 1.5                       # the slingshot's posts, just below the die
const POST_X := 0.95
const OVER_RIM := 1.75                    # drawn back as far as this, the die tips onto the rim (still in view)
const BAND := Color("e8d9b0")

signal finished

var _agent := false
var _settle: Callable
var _labels: Array = []         # face index -> "SOLD" / "FAIL"
var _die: RigidBody3D
var _viewport: SubViewport
var _tray: Control         # the box on screen (the tour points at it)
var _band: Control         # the rubber band and aim arrow, drawn over the tray
var _camera: Camera3D
var _pulling := false
var _pull_start := Vector2.ZERO
var _pull := Vector2.ZERO
var _last_notch := 0
var _stretch: AudioStreamPlayer   # the rubber band's creak while it's drawn back
var _idle_time := 0.0
var _title: Label
var _hint: Label
var _rolling := false
var _still := 0.0
var _clock := 0.0
var _done := false
var _nudges := 0          # times it was nudged this throw (never more than MAX_NUDGES)
const MAX_NUDGES := 3


static func open(tree: SceneTree, agent: bool, settle: Callable) -> Node:
	var roll = load("res://Scripts/dice_roll.gd").new()
	roll.name = "DiceRoll"
	roll._agent = agent
	roll._settle = settle
	tree.root.add_child(roll)
	return roll

func _ready() -> void:
	layer = 50   # over the screen and its menu bar; under the guided tour (110)
	# The die's soft shadow only needs a small shadow map (the default is 2048 x 2048,
	# about 16 MB of video memory, for one little shadow). Nothing else in the game is 3D.
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_MAP, true)
	_pick_faces()
	_build_ui()
	_build_world()
	Sound.play("open")


## ---- THE FACES ----
func _pick_faces() -> void:
	var sold := AGENT_SOLD_FACES if _agent else PRIVATE_SOLD_FACES
	var order := range(6)
	order.shuffle()
	_labels.resize(6)
	for i in 6:
		_labels[order[i]] = "SOLD" if i < sold else "FAIL"


## ---- SCREEN ----
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 110
	column.offset_bottom = -80
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	bg.add_child(column)

	_title = _label("Roll to sell", 66, FONT)
	column.add_child(_title)
	var odds := "Listing Agent: SOLD on 5 of the 6 sides" if _agent else "Selling on your own: SOLD on 2 of the 6 sides"
	_hint = _label(odds, 26, BODY_FONT)
	_hint.modulate.a = 0.85
	column.add_child(_hint)

	# The tray: a rounded felt box with the 3D die in it. Press, pull back and let go to throw.
	var tray := Panel.new()
	_tray = tray
	tray.custom_minimum_size = Vector2(TRAY_SIZE, TRAY_SIZE)
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tray.add_theme_stylebox_override("panel", StyleBoxEmpty.new())   # the 3D box is the tray
	tray.gui_input.connect(_on_tray_input)
	column.add_child(tray)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	# No anti-aliasing: the Compatibility renderer has no FXAA (Godot 4.5 reports it as an
	# error), and MSAA costs ~6 MB here. The matte die on felt looks clean without it.
	view.add_child(_viewport)
	_band = Control.new()
	_band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.draw.connect(_draw_band)
	tray.add_child(_band)

	var how := _label("Press, pull back, and let go to throw", 30, BODY_FONT)
	how.name = "how"
	column.add_child(how)
	# The box pops in as the screen opens (the die is already sitting in it).
	tray.pivot_offset = Vector2(TRAY_SIZE, TRAY_SIZE) / 2.0
	tray.scale = Vector2(0.92, 0.92)
	tray.create_tween().tween_property(tray, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for node in find_children("*", "", true, false):
		ColorTheme.keep(node)   # the same look in every theme, like the old sale animation

func _label(text: String, size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", CREAM)
	return label


## ---- THE 3D TRAY AND DIE ----
func _build_world() -> void:
	var world := Node3D.new()
	_viewport.add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BG   # around the box: the same as the screen
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var camera := Camera3D.new()
	camera.fov = 40
	_camera = camera
	world.add_child(camera)
	# Straight down from above (a bird's-eye view of the tray).
	camera.look_at_from_position(Vector3(0, CAMERA_HEIGHT, 0), Vector3.ZERO, Vector3.FORWARD)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	world.add_child(sun)
	sun.look_at_from_position(Vector3(1.5, 6, 2.5), Vector3.ZERO)   # a little off to the side: a soft shadow

	# The felt floor inside the box (it catches the shadow), the box itself, and tall
	# invisible walls along its inside faces so nothing can jump out.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WALL * 2 + 0.2, WALL * 2 + 0.2)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = TRAY
	felt.roughness = 1.0
	plane.material = felt
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)
	_build_box(world)
	_add_box_body(world, Vector3(0, -0.5, 0), Vector3(14, 1, 14))
	for side in [Vector3(WALL + 0.5, 0, 0), Vector3(-WALL - 0.5, 0, 0)]:
		_add_box_body(world, side + Vector3(0, 3, 0), Vector3(1, 6, 14))
	for side in [Vector3(0, 0, WALL + 0.5), Vector3(0, 0, -WALL - 0.5)]:
		_add_box_body(world, side + Vector3(0, 3, 0), Vector3(14, 6, 1))
	_add_box_body(world, Vector3(0, 6.5, 0), Vector3(14, 1, 14))   # a lid: nothing flies out

	_die = RigidBody3D.new()
	_die.mass = 1.0
	_die.gravity_scale = 2.2   # snappier than real life, so a roll takes a couple of seconds
	_die.continuous_cd = true
	var bounce := PhysicsMaterial.new()
	bounce.bounce = 0.45   # lively off the walls
	bounce.friction = 0.7
	_die.physics_material_override = bounce
	_die.angular_damp = 0.6
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.06, 0.06, 0.07)
	black.roughness = 0.55
	black.metallic_specular = 0.3
	var body := MeshInstance3D.new()
	body.mesh = _rounded_cube(CORNER_RADIUS, 8)
	body.material_override = black
	_die.add_child(body)
	var shape := CollisionShape3D.new()   # rounded too, so it tumbles off its edges like a real die
	shape.shape = _rounded_cube(CORNER_RADIUS, 3).create_convex_shape(true, true)
	_die.add_child(shape)
	for i in 6:
		_die.add_child(_face_label(FACES[i], _labels[i]))
	world.add_child(_die)
	_die.freeze = true   # resting in the middle until the player throws it
	_die.position = REST
	_die.rotation = Vector3(0, deg_to_rad(randf_range(-25, 25)), 0)

# A 1 x 1 x 1 cube with rounded edges and corners: each face is a grid of points pushed
# out onto a rounded box (the inner box, plus `radius` along the way out).
func _rounded_cube(radius: float, steps: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := Vector3.ONE * (0.5 - radius)
	for normal in FACES:
		var n: Vector3 = normal
		var u := Vector3(n.y, n.z, n.x) if absf(n.x) < 0.5 else Vector3(0, 1, 0)
		var v := n.cross(u)
		var grid: Array = []
		for row in steps + 1:
			var line: Array = []
			for col in steps + 1:
				var a := (float(col) / steps - 0.5)
				var b := (float(row) / steps - 0.5)
				var on_cube: Vector3 = n * 0.5 + u * a + v * b
				var core := on_cube.clamp(-inner, inner)
				var out := (on_cube - core).normalized()
				line.append([core + out * radius, out])
			grid.append(line)
		for row in steps:
			for col in steps:
				var quad := [grid[row][col], grid[row][col + 1], grid[row + 1][col + 1], grid[row + 1][col]]
				for index in [0, 2, 1, 0, 3, 2]:
					tool.set_normal(quad[index][1])
					tool.add_vertex(quad[index][0])
	tool.index()
	return tool.commit()

# The tray's four walls as one piece: a ring around the felt with rounded inside corners
# and a bevel along the top edges, BOX_HEIGHT tall. Its shape also blocks the die (so the
# rounded corners are solid too).
func _build_box(world: Node3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The wall's cross-section, from the inside bottom, over the top, to the outside bottom:
	# [distance out from the inside face, height].
	var h := BOX_HEIGHT
	var b := BOX_BEVEL
	var t := BOX_THICK
	var profile := [Vector2(0, 0), Vector2(0, h - b), Vector2(b, h), Vector2(t - b, h), Vector2(t, h - b), Vector2(t, 0)]
	# The path around the box: each rounded corner as a quarter circle (straight walls join them).
	var path: Array = []   # [corner centre, outward direction]
	var inner := WALL - BOX_ROUND
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for c in 4:
		var start_angle := c * PI / 2.0
		for step in 9:
			var angle := start_angle + step * (PI / 2.0) / 8.0
			path.append([Vector3(corners[c].x * inner, 0, corners[c].y * inner), Vector3(cos(angle), 0, sin(angle))])
	path.append(path[0])
	for i in path.size() - 1:
		for k in profile.size() - 1:
			var p0: Vector2 = profile[k]
			var p1: Vector2 = profile[k + 1]
			var flat := Vector2(-(p1.y - p0.y), p1.x - p0.x).normalized()   # this strip's facing
			var quad := []
			for j in [i, i + 1]:
				var centre: Vector3 = path[j][0]
				var out: Vector3 = path[j][1]
				var normal := (out * flat.x + Vector3.UP * flat.y).normalized()
				quad.append([centre + out * (BOX_ROUND + p0.x) + Vector3.UP * p0.y, normal])
				quad.append([centre + out * (BOX_ROUND + p1.x) + Vector3.UP * p1.y, normal])
			for index in [0, 1, 3, 0, 3, 2]:
				tool.set_normal(quad[index][1])
				tool.add_vertex(quad[index][0])
	var mesh := tool.commit()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = BOX_WOOD
	wood.roughness = 0.75
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	var walls := MeshInstance3D.new()
	walls.mesh = mesh
	walls.material_override = wood
	world.add_child(walls)
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	solid.add_child(shape)
	world.add_child(solid)

func _add_box_body(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = at
	parent.add_child(wall)

# White writing on one face, facing out.
func _face_label(normal: Vector3, text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT   # the game's handwriting, like the titles
	label.font_size = 48        # (a bigger size only fills a bigger font texture: the faces are small)
	label.pixel_size = 0.0064   # small and centred, clear of the rounded edges
	label.outline_size = 3      # a white outline thickens the thin pen strokes a little
	label.outline_modulate = Color.WHITE
	label.modulate = Color.WHITE
	label.shaded = false
	label.double_sided = false
	var up := Vector3.FORWARD if absf(normal.y) > 0.5 else Vector3.UP
	label.transform = Transform3D(Basis.looking_at(-normal, up), normal * 0.502)
	return label


## ---- ROLLING ----
## ---- THE SLINGSHOT ----
func _on_tray_input(event: InputEvent) -> void:
	if _rolling or _done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pulling = true
			_pull_start = event.position
			_pull = Vector2.ZERO
			_last_notch = 0
			(find_child("how", true, false) as Label).text = "Press, pull back, and let go to throw"
			_stretch = Sound.play("rubber_pull")   # one of two stretch recordings
		elif _pulling:
			_pulling = false
			_release()
	elif event is InputEventMouseMotion and _pulling:
		_pull = (event.position - _pull_start).limit_length(MAX_PULL)
		_follow_pull()

# The die is drawn back with the finger, tilting a little; the band creaks as it stretches.
func _follow_pull() -> void:
	var back := Vector3(_pull.x, 0, _pull.y) * PULL_SHOWS / _pixels_per_metre()
	back = back.limit_length(PULL_ROOM)
	var spot := REST + back
	spot.x = clampf(spot.x, -WALL + 0.6, WALL - 0.6)
	spot.z = clampf(spot.z, -WALL + 0.6, OVER_RIM)
	# Pulled towards you, it rides up and over the box's bottom edge (the wall is 1 high).
	spot.y = REST.y + smoothstep(WALL - 0.6, WALL, spot.z) * (BOX_HEIGHT + 0.02)
	_die.position = spot
	_die.rotation.x = -_pull.y / MAX_PULL * 0.35
	_die.rotation.z = _pull.x / MAX_PULL * 0.35
	_band.queue_redraw()

func _release() -> void:
	_stop_stretch()
	if _pull.length() < MIN_PULL:   # not a throw: spring back and say how
		var spring := create_tween()
		spring.tween_method(func(p: Vector3): _die.position = p, _die.position, REST, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_die.rotation = Vector3(0, _die.rotation.y, 0)
		_pull = Vector2.ZERO
		_band.queue_redraw()
		var how: Label = find_child("how", true, false)
		how.text = "Pull back further, then let go!"
		how.pivot_offset = how.size / 2.0
		var nudge := how.create_tween()
		nudge.tween_property(how, "scale", Vector2(1.12, 1.12), 0.1)
		nudge.tween_property(how, "scale", Vector2.ONE, 0.15)
		return
	var power := _pull.length() / MAX_PULL
	_launch(-_pull.normalized(), power)

# Throws the die along `direction` (screen space: up is away from you) with 0..1 power.
func _launch(direction: Vector2, power: float) -> void:
	_rolling = true
	_still = 0.0
	_clock = 0.0
	_nudges = 0
	_title.remove_theme_color_override("font_color")
	_title.add_theme_color_override("font_color", CREAM)
	_title.text = "Rolling..."
	_title.scale = Vector2.ONE
	(find_child("how", true, false) as Label).modulate.a = 0.0
	var aim := Vector3(direction.x, 0, direction.y).normalized()
	_die.freeze = false
	# Back inside the box (it may be sitting on the rim), just above the floor, then away.
	_die.position = Vector3(clampf(_die.position.x, -WALL + 0.6, WALL - 0.6), REST.y + 0.5, minf(_die.position.z, WALL - 0.62))
	_die.linear_velocity = aim * lerpf(LAUNCH_SPEED.x, LAUNCH_SPEED.y, power) + Vector3.UP * lerpf(LAUNCH_LIFT.x, LAUNCH_LIFT.y, power)
	var axis := (aim.cross(Vector3.UP) + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))).normalized()
	_die.angular_velocity = axis * lerpf(LAUNCH_SPIN.x, LAUNCH_SPIN.y, power)
	_last_velocity = _die.linear_velocity
	_settled_sound = false
	_pull = Vector2.ZERO
	_band.queue_redraw()
	Sound.play("rubber_launch")   # the band lets go

func _stop_stretch() -> void:
	if is_instance_valid(_stretch) and _stretch.playing and _stretch.stream in Sound.VARIANTS["rubber_pull"]:
		_stretch.stop()   # (only if that voice is still ours)
	_stretch = null

# A throw without a finger (tests): straight away from you at a good strength.
func _roll() -> void:
	if not _rolling and not _done:
		_launch(Vector2(randf_range(-0.3, 0.3), -1.0).normalized(), 0.75)

# The practice FAIL: back to the middle for another go.
func _reset_die() -> void:
	_die.freeze = true
	_die.linear_velocity = Vector3.ZERO
	_die.angular_velocity = Vector3.ZERO
	_die.position = REST
	_die.rotation = Vector3(0, deg_to_rad(randf_range(-25, 25)), 0)
	(find_child("how", true, false) as Label).modulate.a = 1.0
	_band.queue_redraw()

func _pixels_per_metre() -> float:
	var a := _camera.unproject_position(Vector3(0, 0.5, 0))
	var b := _camera.unproject_position(Vector3(1, 0.5, 0))
	return maxf(1.0, a.distance_to(b))

func _process(delta: float) -> void:
	if not _pulling and not _rolling and not _done:
		_idle_time += delta
		_band.queue_redraw()   # the "pull me" hint bobs

# The band: from two posts beside the die's resting spot to the die, and a dotted arrow
# showing where it will fly. At rest, a little bobbing chevron says "pull down".
func _draw_band() -> void:
	if _camera == null or _rolling or _done:
		return
	# The slingshot's posts stand either side of the die, just below it; the band runs
	# from each post to the back of the die (its pouch), so pulling down makes a V.
	var left := _camera.unproject_position(Vector3(-POST_X, 0.5, POST_Z))
	var right := _camera.unproject_position(Vector3(POST_X, 0.5, POST_Z))
	for post in [left, right]:   # the slingshot's two posts
		_band.draw_circle(post, 11, Color(0.2, 0.15, 0.13))
		_band.draw_circle(post, 7, BAND)
	var pouch := _camera.unproject_position(_die.position + Vector3(0, 0.5, 0.3))   # the back of the die
	if not _pulling or _pull.length() < 4.0:
		_band.draw_line(left, pouch, Color(BAND, 0.6), 4, true)
		_band.draw_line(right, pouch, Color(BAND, 0.6), 4, true)
		var bob := sin(_idle_time * 4.0) * 8.0   # "pull me down"
		for i in 2:
			var tip := Vector2(pouch.x, pouch.y + 34 + i * 22 + bob)
			_band.draw_polyline(PackedVector2Array([tip + Vector2(-20, -14), tip, tip + Vector2(20, -14)]), Color(BAND, 0.75 - i * 0.3), 6, true)
		return
	var power := _pull.length() / MAX_PULL
	var die := _camera.unproject_position(_die.position + Vector3.UP * 0.5)
	var colour := BAND.lerp(TERRACOTTA, power)
	_band.draw_line(left, pouch, colour, 6, true)
	_band.draw_line(right, pouch, colour, 6, true)
	var direction := -_pull.normalized()   # the aim: dots growing ahead of the die
	for i in 6:
		var dot := die + direction * (70 + i * 26) * (0.6 + power)
		_band.draw_circle(dot, 4 + i * 0.8 * power, Color(CREAM, 0.85 - i * 0.12))

func _physics_process(delta: float) -> void:
	if not _rolling or _die.freeze:
		return
	_listen_for_hits(delta)
	_clock += delta
	if _die.linear_velocity.length() < 0.05 and _die.angular_velocity.length() < 0.08:
		if _still == 0.0 and _top_face() >= 0:
			_settle_sound()   # it has come to rest on a face: the last little sound
		_still += delta
	else:
		_still = 0.0
	if _still >= SETTLE_TIME or _clock >= GIVE_UP_AFTER:
		var face := _top_face()
		if _nudges >= MAX_NUDGES:   # wedged somewhere odd: read whichever face is most nearly up
			face = _top_face(0.0)
		elif face < 0 or _clock >= GIVE_UP_AFTER:   # leaning on a wall or an edge: nudge it over
			_nudges += 1
			_clock = 0.0
			_still = 0.0
			_die.apply_central_impulse(Vector3(randf_range(-1, 1), 2.5, randf_range(-1, 1)))
			_die.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))
			return
		_rolling = false
		_landed(_labels[face] == "SOLD")

## ---- SOUND ----
# One hit sound each time the die hits the felt or a wall, as loud as the hit was hard
# (judged by how suddenly its speed changed, beyond what gravity does), picked at random
# from three recordings. The settling sound plays once, when it comes to rest for good.
var _last_velocity := Vector3.ZERO
var _since_hit := 1.0
var _hit_players: Array = []
var _settled_sound := false

func _listen_for_hits(delta: float) -> void:
	var velocity := _die.linear_velocity
	var gravity := Vector3.DOWN * 9.8 * _die.gravity_scale * delta
	var jolt := (velocity - _last_velocity - gravity).length()
	_last_velocity = velocity
	_since_hit += delta
	if jolt >= HIT_MIN and _since_hit >= HIT_GAP:
		_since_hit = 0.0
		_click(clampf(inverse_lerp(HIT_MIN, HIT_LOUD, jolt), 0.0, 1.0))

func _player() -> AudioStreamPlayer:
	if _hit_players.is_empty():
		for i in 5:
			var player := AudioStreamPlayer.new()
			add_child(player)
			_hit_players.append(player)
	var player: AudioStreamPlayer = _hit_players.pop_front()
	_hit_players.append(player)
	return player

func _click(strength: float, pitch: float = 1.0) -> void:
	if not Sound.enabled:
		return
	var player := _player()
	player.stream = HITS.pick_random()
	player.volume_db = lerpf(-24.0, 0.0, sqrt(strength))
	player.pitch_scale = pitch * randf_range(0.93, 1.07)
	player.play()

func _settle_sound() -> void:
	if _settled_sound or not Sound.enabled:
		return
	_settled_sound = true
	var player := _player()
	player.stream = SETTLING
	player.volume_db = 0.0
	player.pitch_scale = 1.0
	player.play()

# The die rattling in your hand for a moment before it's thrown: a few quick, soft,
# slightly higher hits.
func _shake_in_hand() -> void:
	for i in 4:
		_click(randf_range(0.03, 0.1), 1.25)
		await get_tree().create_timer(randf_range(0.05, 0.09)).timeout

# The face pointing up, or -1 if none is flat enough to read.
func _top_face(flat_enough := 0.97) -> int:
	var best := -1
	var best_dot := 0.0
	for i in 6:
		var dot: float = (_die.global_transform.basis * FACES[i]).normalized().dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best = i
	return best if best_dot > flat_enough else -1


## ---- THE RESULT ----
func _landed(sold: bool) -> void:
	_die.freeze = true
	# The result in big letters above the tray (never over the die).
	_title.text = "SOLD!" if sold else "FAIL"
	_title.add_theme_color_override("font_color", CREAM if sold else Color("f2b0a4"))
	_title.pivot_offset = _title.size / 2.0
	_title.scale = Vector2(0.3, 0.3)
	_title.create_tween().tween_property(_title, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not sold and get_tree().root.has_node("Tutorial"):   # practice: a FAIL costs nothing
		Sound.play("sale_fail")
		_hint.text = "Practice roll: a FAIL costs nothing here. Throw again!"
		await get_tree().create_timer(1.0).timeout
		_title.text = "Roll to sell"
		_title.scale = Vector2.ONE
		_title.remove_theme_color_override("font_color")
		_title.add_theme_color_override("font_color", CREAM)
		_reset_die()
		return
	_done = true
	if sold:
		Sound.play("continue")
	elif _agent:
		Sound.play("thud")        # 5 of 6 sides said SOLD... and it still failed
	else:
		Sound.play("sale_fail")   # an "aww" or a sad trumpet, at random
	await get_tree().create_timer(1.4).timeout
	var outcome: Dictionary = _settle.call(sold)
	get_tree().change_scene_to_file(DESTINATION)
	await get_tree().process_frame
	await get_tree().process_frame
	if outcome.get("cash", 0) > 0:
		Global.add_cash(outcome["cash"], "Property Sale")
	var message: String = outcome.get("message", "")
	if sold:
		Global.banner(message)
	else:   # logged as a setback, no second sound (the "aww" already played)
		Activity.add(message, "error")
		Global.banner_requested.emit(message, "")
	finished.emit()
	queue_free()
